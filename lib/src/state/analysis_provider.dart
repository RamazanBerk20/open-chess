import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/analyze.dart';
import 'package:open_chess/src/rust/api/game.dart';

/// One analyzed ply.
class AnalysisMove {
  final int ply;
  final String uci;
  final String san;
  final int evalCp; // White POV after the move, clamped
  final int mateIn; // 0 = none; signed plies (White mating > 0)
  final int evalBeforeCp; // White POV before the move (best play)
  final int mateBeforeIn;
  final String bestUci;
  final String bestSan; // engine's best move in SAN (for coach text)
  final int cpLoss;
  final String classification;

  const AnalysisMove({
    required this.ply,
    required this.uci,
    required this.san,
    required this.evalCp,
    required this.mateIn,
    required this.evalBeforeCp,
    required this.mateBeforeIn,
    required this.bestUci,
    required this.bestSan,
    required this.cpLoss,
    required this.classification,
  });
}

/// Analysis job lifecycle; one header per state on the analysis screen.
sealed class AnalysisJob {
  const AnalysisJob();
}

class AnalysisIdle extends AnalysisJob {
  const AnalysisIdle();
}

class AnalysisRunning extends AnalysisJob {
  final int progress;
  final int total;
  const AnalysisRunning(this.progress, this.total);
}

class AnalysisDone extends AnalysisJob {
  const AnalysisDone();
}

class AnalysisFailed extends AnalysisJob {
  final String error;
  const AnalysisFailed(this.error);
}

class AnalysisCancelled extends AnalysisJob {
  const AnalysisCancelled();
}

class AnalysisState {
  final AnalysisJob job;
  final List<AnalysisMove> moves;
  final double whiteAccuracy;
  final double blackAccuracy;
  final AnalysisOpening? opening;
  final EloEstimate? whiteElo;
  final EloEstimate? blackElo;

  const AnalysisState({
    this.job = const AnalysisIdle(),
    this.moves = const [],
    this.whiteAccuracy = 0,
    this.blackAccuracy = 0,
    this.opening,
    this.whiteElo,
    this.blackElo,
  });

  bool get running => job is AnalysisRunning;
  bool get done => job is AnalysisDone;
  int get progress => switch (job) {
    AnalysisRunning(:final progress) => progress,
    _ => moves.length,
  };
  int get total => switch (job) {
    AnalysisRunning(:final total) => total,
    _ => moves.length,
  };
}

sealed class AnalysisEvent {
  const AnalysisEvent();
}

class AnalysisStarted extends AnalysisEvent {
  final int total;
  const AnalysisStarted(this.total);
}

class AnalysisPly extends AnalysisEvent {
  final AnalysisMove move;
  final int progress;
  final int total;
  const AnalysisPly(this.move, this.progress, this.total);
}

class AnalysisFinished extends AnalysisEvent {
  final double whiteAccuracy;
  final double blackAccuracy;
  final AnalysisOpening? opening;
  final EloEstimate? whiteElo;
  final EloEstimate? blackElo;
  const AnalysisFinished({
    required this.whiteAccuracy,
    required this.blackAccuracy,
    this.opening,
    this.whiteElo,
    this.blackElo,
  });
}

class AnalysisErrored extends AnalysisEvent {
  final String error;
  const AnalysisErrored(this.error);
}

class AnalysisStopped extends AnalysisEvent {
  const AnalysisStopped();
}

/// Pure transition. Only a running job accepts plies, a result, or an error;
/// a start always begins from a clean state.
AnalysisState reduceAnalysis(AnalysisState s, AnalysisEvent e) =>
    switch ((s.job, e)) {
      (_, AnalysisStarted(:final total)) => AnalysisState(
        job: AnalysisRunning(0, total),
      ),
      (
        AnalysisRunning(),
        AnalysisPly(:final move, :final progress, :final total),
      ) =>
        AnalysisState(
          job: AnalysisRunning(progress, total),
          moves: List.unmodifiable([...s.moves, move]),
        ),
      (AnalysisRunning(), final AnalysisFinished f) => AnalysisState(
        job: const AnalysisDone(),
        moves: s.moves,
        whiteAccuracy: f.whiteAccuracy,
        blackAccuracy: f.blackAccuracy,
        opening: f.opening,
        whiteElo: f.whiteElo,
        blackElo: f.blackElo,
      ),
      (AnalysisRunning(), AnalysisErrored(:final error)) => AnalysisState(
        job: AnalysisFailed(error),
        moves: s.moves,
      ),
      (AnalysisRunning(), AnalysisStopped()) => AnalysisState(
        job: const AnalysisCancelled(),
        moves: s.moves,
      ),
      _ => s,
    };

/// A configured in-app AI has a declared target band, so reporting its known
/// target is more truthful than inferring a rating from a short tactical game.
EloEstimate? resolvedAnalysisElo({
  required int? knownElo,
  required EloEstimate? measured,
}) {
  if (knownElo == null) return measured;
  return EloEstimate(
    elo: knownElo,
    confidence: EloConfidence.high,
    analyzedMoves: measured?.analyzedMoves ?? 0,
    averageCpLoss: measured?.averageCpLoss ?? 0,
  );
}

/// Scoped to the analysis screen: a new screen always starts Idle (never a
/// previous game's result), and leaving it stops the job.
final analysisProvider =
    NotifierProvider.autoDispose<AnalysisController, AnalysisState>(
      AnalysisController.new,
    );

class AnalysisController extends Notifier<AnalysisState> {
  StreamSubscription<AnalysisUpdate>? _sub;

  @override
  AnalysisState build() {
    ref.onDispose(() {
      _sub?.cancel();
      analysisCancel();
    });
    return const AnalysisState();
  }

  void _dispatch(AnalysisEvent e) => state = reduceAnalysis(state, e);

  /// Analyze [moves] (UCI) played from [startFen].
  void run(
    List<String> moves, {
    String startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    // Depth 6 ≈ 0.3 s/ply on this engine (~25 s for a 40-move game), a good
    // balance of classification quality and responsiveness with the progress
    // bar. Higher depths grow ~5× per level and become impractical per-ply.
    int depth = 6,
    GameVariant variant = GameVariant.standard,
    int? knownWhiteElo,
    int? knownBlackElo,
  }) {
    _sub?.cancel();
    analysisCancel();
    _dispatch(AnalysisStarted(moves.length));
    _sub =
        analyzeGameRequest(
          request: AnalyzeGameRequest(
            startFen: startFen,
            moves: moves,
            depth: depth,
            variant: variant,
          ),
        ).listen(
          (u) {
            if (u.done) {
              _dispatch(
                AnalysisFinished(
                  whiteAccuracy: u.whiteAccuracy,
                  blackAccuracy: u.blackAccuracy,
                  opening: u.opening,
                  whiteElo: resolvedAnalysisElo(
                    knownElo: knownWhiteElo,
                    measured: u.whiteElo,
                  ),
                  blackElo: resolvedAnalysisElo(
                    knownElo: knownBlackElo,
                    measured: u.blackElo,
                  ),
                ),
              );
              return;
            }
            _dispatch(
              AnalysisPly(
                AnalysisMove(
                  ply: u.ply,
                  uci: u.uci,
                  san: u.san,
                  evalCp: u.evalCp,
                  mateIn: u.mateIn,
                  evalBeforeCp: u.evalBeforeCp,
                  mateBeforeIn: u.mateBeforeIn,
                  bestUci: u.bestUci,
                  bestSan: u.bestSan,
                  cpLoss: u.cpLoss,
                  classification: u.classification,
                ),
                u.progress,
                u.total,
              ),
            );
          },
          onError: (Object e) => _dispatch(AnalysisErrored('$e')),
          // A stream that closes without a result is a failure, not "preparing".
          onDone: () => _dispatch(const AnalysisErrored('')),
        );
  }

  void cancel() {
    analysisCancel();
    _sub?.cancel();
    _dispatch(const AnalysisStopped());
  }
}
