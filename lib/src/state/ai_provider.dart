import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/ai.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';

/// Live AI search progress (streamed from the off-thread engine).
class AiThinking {
  final bool active;
  final int depth;
  final int scoreCp;
  final String bestUci;
  final List<String> pv;

  const AiThinking({
    this.active = false,
    this.depth = 0,
    this.scoreCp = 0,
    this.bestUci = '',
    this.pv = const [],
  });
}

final aiControllerProvider = NotifierProvider<AiController, AiThinking>(
  AiController.new,
);

class AiController extends Notifier<AiThinking> {
  StreamSubscription<AiUpdate>? _sub;
  int _id = 0;
  int _generation = 0;

  @override
  AiThinking build() {
    ref.onDispose(() {
      _sub?.cancel();
      if (_id > 0) aiCancel(searchId: BigInt.from(_id));
    });
    return const AiThinking();
  }

  /// Ask the engine to choose + play a move for the side to move.
  void requestMove({required AiConfigDto config}) {
    final game = ref.read(gameControllerProvider);
    final mode = ref.read(gameModeProvider);
    if (game.isOver || state.active || mode.lan) return;
    final view = game.view;
    final history = ref.read(gameControllerProvider.notifier).hashHistory();
    _stopStream();
    final generation = ++_generation;
    final id = ++_id;
    final requestedFen = view.fen;
    final requestedVariant = view.variant;
    state = const AiThinking(active: true);
    _sub =
        aiSearch(
          request: AiSearchRequest(
            searchId: BigInt.from(id),
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
            if (generation != _generation) return;
            if (u.done) {
              final current = ref.read(gameControllerProvider);
              final currentMode = ref.read(gameModeProvider);
              // A search belongs to one exact position. Never let a late result
              // from an old game/session mutate a new board.
              if (u.bestUci.isNotEmpty &&
                  !currentMode.lan &&
                  !current.isOver &&
                  current.view.fen == requestedFen &&
                  current.view.variant == requestedVariant) {
                ref.read(gameControllerProvider.notifier).aiPlayUci(u.bestUci);
              }
              state = const AiThinking();
              _sub = null;
            } else {
              state = AiThinking(
                active: true,
                depth: u.depth,
                scoreCp: u.scoreCp,
                bestUci: u.bestUci,
                pv: u.pv,
              );
            }
          },
          onError: (_) {
            if (generation == _generation) state = const AiThinking();
          },
          onDone: () {
            if (generation == _generation && state.active) {
              state = const AiThinking();
            }
          },
        );
  }

  void cancel() {
    _generation++;
    _stopStream();
    state = const AiThinking();
  }

  void _stopStream() {
    if (_sub != null) {
      aiCancel(searchId: BigInt.from(_id));
      _sub?.cancel();
      _sub = null;
    }
  }
}
