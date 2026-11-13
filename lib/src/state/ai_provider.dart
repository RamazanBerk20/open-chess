import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/ai.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';

/// Why a search runs: the vs-AI reply, or the hot-seat "AI move" button.
enum SearchPurpose { reply, hint }

/// Engine lifecycle. A search belongs to the game session that started it.
sealed class EngineState {
  const EngineState();
  bool get active => this is EngineSearching;
}

class EngineIdle extends EngineState {
  /// The engine refused the last search (e.g. a position it rejects).
  final String? error;
  const EngineIdle({this.error});
}

class EngineSearching extends EngineState {
  final int id;
  final int session;
  final String fen;
  final SearchPurpose purpose;
  final int depth;
  final int scoreCp;
  final List<String> pv;

  const EngineSearching({
    required this.id,
    required this.session,
    required this.fen,
    required this.purpose,
    this.depth = 0,
    this.scoreCp = 0,
    this.pv = const [],
  });
}

sealed class EngineEvent {
  const EngineEvent();
}

class SearchStarted extends EngineEvent {
  final EngineSearching search;
  const SearchStarted(this.search);
}

class SearchProgress extends EngineEvent {
  final int id;
  final int depth;
  final int scoreCp;
  final List<String> pv;
  const SearchProgress(this.id, this.depth, this.scoreCp, this.pv);
}

/// The search ended (result, error, or closed stream).
class SearchFinished extends EngineEvent {
  final int id;
  final String? error;
  const SearchFinished(this.id, {this.error});
}

class SearchCancelled extends EngineEvent {
  const SearchCancelled();
}

/// Pure transition; events for a search that is no longer current are ignored.
EngineState reduceEngine(EngineState s, EngineEvent e) => switch ((s, e)) {
  (_, SearchStarted(:final search)) => search,
  (_, SearchCancelled()) => const EngineIdle(),
  (EngineSearching(:final id), SearchFinished(id: final f, :final error))
      when id == f =>
    EngineIdle(error: error),
  (
    final EngineSearching c,
    SearchProgress(:final id, :final depth, :final scoreCp, :final pv),
  )
      when c.id == id =>
    EngineSearching(
      id: c.id,
      session: c.session,
      fen: c.fen,
      purpose: c.purpose,
      depth: depth,
      scoreCp: scoreCp,
      pv: pv,
    ),
  _ => s,
};

/// A finished search may only move on the exact session and position it was
/// started for.
bool shouldPlaySearchResult({
  required EngineSearching search,
  required String bestUci,
  required int session,
  required String fen,
  required bool gameOver,
  required bool lan,
  required bool paused,
}) =>
    bestUci.isNotEmpty &&
    !lan &&
    !gameOver &&
    !paused &&
    search.session == session &&
    search.fen == fen;

/// Whether the engine owes the vs-AI reply right now.
bool engineOwesReply({
  required GameMode mode,
  required bool gameOver,
  required bool busy,
  required bool paused,
  required PieceColor sideToMove,
  required EngineState engine,
}) =>
    mode.vsAi &&
    !mode.lan &&
    !gameOver &&
    !busy &&
    !paused &&
    engine is EngineIdle &&
    sideToMove == mode.aiColor;

final aiControllerProvider = NotifierProvider<AiController, EngineState>(
  AiController.new,
);

class AiController extends Notifier<EngineState> {
  StreamSubscription<AiUpdate>? _sub;
  int? _searchId; // the Rust search to cancel
  // A position the engine refused: don't retry it in a loop on every idle.
  (int, String, DateTime)? _refused;
  static const _refusalCooldown = Duration(seconds: 5);
  static int _nextId = 0;

  @override
  EngineState build() {
    ref.onDispose(_stopStream);
    return const EngineIdle();
  }

  void _dispatch(EngineEvent e) => state = reduceEngine(state, e);

  /// Ask the engine to choose and play a move for the side to move.
  void requestMove({
    required AiConfigDto config,
    SearchPurpose purpose = SearchPurpose.reply,
  }) {
    final game = ref.read(gameControllerProvider);
    final mode = ref.read(gameModeProvider);
    if (game.isOver || state.active || mode.lan || game.paused) return;
    final controller = ref.read(gameControllerProvider.notifier);
    final view = game.view;
    // A rejected position is not retried in a tight loop, but the refusal
    // expires so the AI side is never stuck for good (e.g. after a pause).
    final refused = _refused;
    if (refused != null &&
        refused.$1 == controller.session &&
        refused.$2 == view.fen &&
        DateTime.now().difference(refused.$3) < _refusalCooldown) {
      return;
    }
    final history = controller.hashHistory();
    _stopStream();
    final search = EngineSearching(
      id: ++_nextId,
      session: controller.session,
      fen: view.fen,
      purpose: purpose,
    );
    _dispatch(SearchStarted(search));
    _searchId = search.id;
    _sub =
        aiSearch(
          request: AiSearchRequest(
            searchId: BigInt.from(search.id),
            fen: view.fen,
            config: config,
            history: history,
            variant: view.variant,
            whiteChecks: view.whiteChecks,
            blackChecks: view.blackChecks,
            whiteHand: view.whiteHand,
            blackHand: view.blackHand,
            promoted: view.promoted,
          ),
        ).listen(
          (u) {
            final current = state;
            if (current is! EngineSearching || current.id != search.id) return;
            if (!u.done) {
              _dispatch(SearchProgress(search.id, u.depth, u.scoreCp, u.pv));
              return;
            }
            _sub = null;
            _searchId = null;
            final g = ref.read(gameControllerProvider);
            final c = ref.read(gameControllerProvider.notifier);
            final play = shouldPlaySearchResult(
              search: search,
              bestUci: u.bestUci,
              session: c.session,
              fen: g.view.fen,
              gameOver: g.isOver,
              lan: ref.read(gameModeProvider).lan,
              paused: g.paused,
            );
            // Idle first, so the move's state change sees a free engine.
            _dispatch(SearchFinished(search.id));
            if (play) c.aiPlayUci(u.bestUci);
          },
          onError: (Object e) {
            _refused = (search.session, search.fen, DateTime.now());
            _dispatch(SearchFinished(search.id, error: '$e'));
          },
          onDone: () => _dispatch(SearchFinished(search.id)),
        );
  }

  void cancel() {
    _stopStream();
    if (state.active) _dispatch(const SearchCancelled());
  }

  void _stopStream() {
    final id = _searchId;
    if (id != null) aiCancel(searchId: BigInt.from(id));
    _searchId = null;
    _sub?.cancel();
    _sub = null;
  }
}
