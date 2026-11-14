import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/rust/api/analyze.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/analysis_provider.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/widgets/board_widget.dart';
import 'package:open_chess/src/widgets/eval_bar.dart';
import 'package:open_chess/src/widgets/eval_graph.dart';
import 'package:open_chess/src/widgets/move_class.dart';
import 'package:open_chess/src/widgets/window_chrome.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final List<String> moves;
  final String startFen;
  final GameVariant variant;
  final int? knownWhiteElo;
  final int? knownBlackElo;

  const AnalysisScreen({
    super.key,
    required this.moves,
    this.startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.variant = GameVariant.standard,
    this.knownWhiteElo,
    this.knownBlackElo,
  });

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  int _viewPly = 0; // number of moves played from the start
  late ChessGame _nav;
  bool _animate = false; // slide pieces only when stepping one move at a time
  bool _flipped = false; // view from Black's side

  @override
  void initState() {
    super.initState();
    _nav = _newNavigator();
    _viewPly = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analysisProvider.notifier)
          .run(
            widget.moves,
            startFen: widget.startFen,
            variant: widget.variant,
            knownWhiteElo: widget.knownWhiteElo,
            knownBlackElo: widget.knownBlackElo,
          );
    });
  }

  ChessGame _newNavigator() => ChessGame.fromFenVariant(
    fen: widget.startFen,
    variant: widget.variant,
    baseMinutes: 0,
    incrementSeconds: 0,
  );

  void _goto(int ply, {bool animate = false}) {
    final clamped = ply.clamp(0, widget.moves.length);
    final g = _newNavigator();
    for (var i = 0; i < clamped; i++) {
      g.playUci(uci: widget.moves[i]);
    }
    setState(() {
      _nav = g;
      _viewPly = clamped;
      _animate = animate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(analysisProvider);
    final settings = ref.watch(settingsProvider);
    final view = _nav.view();

    // Eval shown = eval after the move reached; at the start ply use the eval
    // before the first move (the start position) instead of a flat 0.
    int evalCp = 0, mateIn = 0;
    if (_viewPly > 0 && _viewPly - 1 < st.moves.length) {
      evalCp = st.moves[_viewPly - 1].evalCp;
      mateIn = st.moves[_viewPly - 1].mateIn;
    } else if (st.moves.isNotEmpty) {
      evalCp = st.moves[0].evalBeforeCp;
      mateIn = st.moves[0].mateBeforeIn;
    }

    // Highlight the played move's squares by classification, and draw the best
    // move as an arrow when the played move wasn't the engine's choice.
    final t = AppLocalizations.of(context);
    final cb = settings.colorblind;
    Map<int, Color> tints = const {};
    BestArrow? arrow;
    MoveBadge? badge;
    String coach = '';
    Color coachColor = Colors.grey;
    if (_viewPly > 0 && _viewPly - 1 < st.moves.length) {
      final m = st.moves[_viewPly - 1];
      final cs = classStyle(m.classification, colorblind: cb);
      final pf = uciSquare(m.uci);
      final pt = m.uci.length >= 4 ? uciSquare(m.uci.substring(2, 4)) : null;
      final col = cs.color.withValues(alpha: 0.55);
      tints = {?pf: col, ?pt: col};
      if (pt != null && cs.sym.isNotEmpty) {
        badge = MoveBadge(square: pt, symbol: cs.sym, color: cs.color);
      }
      if (m.bestUci.length >= 4 && m.bestUci != m.uci) {
        final bf = uciSquare(m.bestUci);
        final bt = uciSquare(m.bestUci.substring(2, 4));
        if (bf != null && bt != null) {
          arrow = BestArrow(from: bf, to: bt, color: const Color(0xCC2E7D32));
        }
      }
      coach = coachText(t, m.classification, m.bestSan);
      coachColor = cs.color;
    }

    final coachCard = coach.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: coachColor.withValues(alpha: 0.15),
                border: Border(left: BorderSide(color: coachColor, width: 4)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(coach),
            ),
          );

    // Eval bar + a square board at an explicit `side`.
    Widget boardOf(double side) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EvalBar(
          evalCp: evalCp,
          mateIn: mateIn,
          height: side,
          flipped: _flipped,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: side,
          height: side,
          child: BoardWidget(
            view: view,
            flipped: _flipped,
            light: settings.theme.light,
            dark: settings.theme.dark,
            showHints: false,
            animate: _animate,
            tints: tints,
            arrow: arrow,
            badge: badge,
            onTap: (_) {},
            onDrop: (_, _) {},
          ),
        ),
      ],
    );

    final evalGraph = st.moves.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: EvalGraph(
              moves: st.moves,
              viewPly: _viewPly,
              onSeek: _goto,
              height: 56,
              colorblind: cb,
            ),
          );

    final navBar = _NavBar(
      viewPly: _viewPly,
      total: widget.moves.length,
      onFirst: () => _goto(0),
      onPrev: () => _goto(_viewPly - 1, animate: true),
      onNext: () => _goto(_viewPly + 1, animate: true),
      onLast: () => _goto(widget.moves.length),
    );

    final moveList = _MoveList(
      st: st,
      viewPly: _viewPly,
      onTap: _goto,
      colorblind: cb,
    );

    // Summary + move list share one scroll viewport (used below the board on
    // narrow/portrait layouts so the board itself stays large).
    final infoScroll = SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (st.done) ...[
            _OpeningPanel(st: st, variant: widget.variant),
            const SizedBox(height: 8),
            _SummaryPanel(st: st),
            const SizedBox(height: 8),
          ],
          moveList,
        ],
      ),
    );

    return Scaffold(
      appBar: WindowAppBar(
        title: Text(t.analysis),
        actions: [
          IconButton(
            tooltip: t.flipBoard,
            icon: const Icon(Icons.flip),
            onPressed: () => setState(() => _flipped = !_flipped),
          ),
          if (st.running)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (st.running)
            LinearProgressIndicator(
              value: st.total == 0 ? null : st.progress / st.total,
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Wide: board left filling the height, info panel (width-capped,
                // centred) on the right. Narrow/portrait: board on top filling
                // the width, summary + moves scroll below it.
                if (constraints.maxWidth > 720) {
                  final side = min(
                    constraints.maxHeight - 16,
                    constraints.maxWidth - 360.0,
                  ).clamp(160.0, 900.0).toDouble();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(child: boardOf(side)),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AccuracyHeader(st: st),
                                  if (st.done)
                                    _OpeningPanel(
                                      st: st,
                                      variant: widget.variant,
                                    ),
                                  if (st.done)
                                    _SummaryPanel(st: st, colorblind: cb),
                                  evalGraph,
                                  coachCard,
                                  navBar,
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  moveList,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _AccuracyHeader(st: st),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final side = min(
                              c.maxWidth - 46,
                              c.maxHeight,
                            ).clamp(120.0, 900.0).toDouble();
                            return Center(child: boardOf(side));
                          },
                        ),
                      ),
                    ),
                    evalGraph,
                    coachCard,
                    navBar,
                    const Divider(height: 1),
                    Expanded(flex: 2, child: infoScroll),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyHeader extends StatelessWidget {
  final AnalysisState st;
  const _AccuracyHeader({required this.st});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final status = switch (st.job) {
      AnalysisIdle() || AnalysisCancelled() => t.preparingAnalysis,
      AnalysisRunning(:final progress, :final total) => t.analyzingProgress(
        progress,
        total,
      ),
      AnalysisFailed(:final error) => t.analysisFailed(error),
      AnalysisDone() => null,
    };
    if (status != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          status,
          style: st.job is AnalysisFailed
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
      );
    }
    String confidence(EloConfidence confidence) => switch (confidence) {
      EloConfidence.low => t.ratingConfidenceLow,
      EloConfidence.medium => t.ratingConfidenceMedium,
      EloConfidence.high => t.ratingConfidenceHigh,
    };
    Widget chip(String who, double acc, EloEstimate? elo, Color c) => Column(
      children: [
        Text(who, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '${acc.toStringAsFixed(1)}%',
          style: TextStyle(color: c, fontSize: 18),
        ),
        Text(t.accuracy, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          elo == null ? t.ratingUnavailable : '${t.ratingEstimate} ${elo.elo}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
        if (elo != null)
          Text(
            confidence(elo.confidence),
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: chip(
              t.white,
              st.whiteAccuracy,
              st.whiteElo,
              const Color(0xFF6FA84B),
            ),
          ),
          Expanded(
            child: chip(
              t.black,
              st.blackAccuracy,
              st.blackElo,
              const Color(0xFF6FA84B),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningPanel extends StatelessWidget {
  final AnalysisState st;
  final GameVariant variant;
  const _OpeningPanel({required this.st, required this.variant});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final opening = st.opening;
    final detail = opening == null
        ? t.openingNone
        : '${opening.name} (${opening.eco})';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.variant}: ${localizedVariant(t, variant)}',
            style: const TextStyle(fontSize: 13),
          ),
          Text('${t.opening}: $detail', style: const TextStyle(fontSize: 13)),
          if (opening?.gambit case final gambit?)
            Text(
              '${t.openingGambit}: $gambit',
              style: const TextStyle(fontSize: 13),
            ),
          if (opening?.variation case final variation?)
            Text(
              '${t.openingVariation}: $variation',
              style: const TextStyle(fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final AnalysisState st;
  final bool colorblind;
  const _SummaryPanel({required this.st, this.colorblind = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // White plays even plies, Black odd plies.
    final white = <String, int>{};
    final black = <String, int>{};
    for (final m in st.moves) {
      final map = m.ply.isEven ? white : black;
      map[m.classification] = (map[m.classification] ?? 0) + 1;
    }
    final rows = analysisClassOrder
        .where((c) => (white[c] ?? 0) > 0 || (black[c] ?? 0) > 0)
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    Widget num(int n) => Expanded(
      child: Text(
        '$n',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
    Widget head(String s) => Expanded(
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              head(t.white),
              head(t.black),
            ],
          ),
          for (final c in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Text(
                          classStyle(c, colorblind: colorblind).sym,
                          style: TextStyle(
                            color: classStyle(c, colorblind: colorblind).color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            classLabel(t, c),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: classStyle(
                                c,
                                colorblind: colorblind,
                              ).color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  num(white[c] ?? 0),
                  num(black[c] ?? 0),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int viewPly;
  final int total;
  final VoidCallback onFirst, onPrev, onNext, onLast;
  const _NavBar({
    required this.viewPly,
    required this.total,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: viewPly > 0 ? onFirst : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          onPressed: viewPly > 0 ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$viewPly / $total'),
        IconButton(
          onPressed: viewPly < total ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: viewPly < total ? onLast : null,
          icon: const Icon(Icons.last_page),
        ),
      ],
    );
  }
}

class _MoveList extends StatelessWidget {
  final AnalysisState st;
  final int viewPly;
  final void Function(int ply) onTap;
  final bool colorblind;
  const _MoveList({
    required this.st,
    required this.viewPly,
    required this.onTap,
    this.colorblind = false,
  });

  @override
  Widget build(BuildContext context) {
    // Plain wrap — the caller provides the scroll viewport so the move list and
    // the summary scroll together.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in st.moves)
          _MoveChip(
            move: m,
            selected: viewPly == m.ply + 1,
            colorblind: colorblind,
            onTap: () => onTap(m.ply + 1),
          ),
      ],
    );
  }
}

class _MoveChip extends StatelessWidget {
  final AnalysisMove move;
  final bool selected;
  final bool colorblind;
  final VoidCallback onTap;
  const _MoveChip({
    required this.move,
    required this.selected,
    required this.onTap,
    this.colorblind = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = classStyle(move.classification, colorblind: colorblind);
    final moveNo = (move.ply ~/ 2) + 1;
    final dots = move.ply.isEven ? '.' : '…';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$moveNo$dots ${move.san}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (cs.sym.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                cs.sym,
                style: TextStyle(color: cs.color, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
