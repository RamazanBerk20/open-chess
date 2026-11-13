import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/time_control.dart';

/// Clock lifecycle. Only [ClockRunning] charges time locally; a LAN client
/// only extrapolates the host's snapshot ([ClockDisplayOnly]).
sealed class ClockPhase {
  const ClockPhase();
  bool get ticks => this is ClockRunning || this is ClockDisplayOnly;
}

/// Infinite time control, or no game screen.
class ClockOff extends ClockPhase {
  const ClockOff();
}

class ClockRunning extends ClockPhase {
  const ClockRunning();
}

class ClockDisplayOnly extends ClockPhase {
  const ClockDisplayOnly();
}

class ClockPaused extends ClockPhase {
  const ClockPaused();
}

/// The game ended (any kind of end, LAN included): the display freezes.
class ClockStopped extends ClockPhase {
  const ClockStopped();
}

sealed class ClockEvent {
  const ClockEvent();
}

class ClockStart extends ClockEvent {
  final bool infinite;
  final bool lan;
  final bool over;
  const ClockStart({
    required this.infinite,
    required this.lan,
    this.over = false,
  });
}

class ClockPause extends ClockEvent {
  const ClockPause();
}

class ClockResume extends ClockEvent {
  const ClockResume();
}

class ClockGameOver extends ClockEvent {
  const ClockGameOver();
}

class ClockClose extends ClockEvent {
  const ClockClose();
}

ClockPhase reduceClock(ClockPhase p, ClockEvent e) => switch ((p, e)) {
  (_, ClockStart(infinite: true)) => const ClockOff(),
  (_, ClockStart(over: true)) => const ClockStopped(),
  (_, ClockStart(lan: true)) => const ClockDisplayOnly(),
  (_, ClockStart()) => const ClockRunning(),
  (_, ClockClose()) => const ClockOff(),
  (ClockRunning() || ClockDisplayOnly() || ClockPaused(), ClockGameOver()) =>
    const ClockStopped(),
  (ClockRunning(), ClockPause()) => const ClockPaused(), // LAN cannot pause
  (ClockPaused(), ClockResume()) => const ClockRunning(),
  _ => p,
};

/// Drives the clock countdown on a 100ms timer, decoupled from the board so
/// ticks don't rebuild the board (which could interrupt an in-progress drag).
/// Null state means there is no clock (Infinite time control).
final clockProvider = NotifierProvider<ClockNotifier, ClockSnapshot?>(
  ClockNotifier.new,
);

class ClockNotifier extends Notifier<ClockSnapshot?> {
  Timer? _timer;
  final Stopwatch _sw = Stopwatch();
  ClockPhase _phase = const ClockOff();
  ClockPhase get phase => _phase;

  @override
  ClockSnapshot? build() {
    final tc = ref.watch(selectedTimeControlProvider);
    ref.onDispose(_stopTimer);
    _phase = reduceClock(
      _phase,
      ClockStart(
        infinite: tc.isInfinite,
        lan: ref.read(gameModeProvider).lan,
        over: ref.read(gameControllerProvider).isOver,
      ),
    );
    if (tc.isInfinite) return null;
    final snap = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
    _sync();
    return snap;
  }

  void _dispatch(ClockEvent e) {
    _phase = reduceClock(_phase, e);
    _sync();
  }

  /// Run the timer exactly while the phase ticks.
  void _sync() {
    if (_phase.ticks) {
      if (_timer != null) return;
      _sw
        ..reset()
        ..start();
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _onTick(),
      );
    } else {
      _stopTimer();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _sw.stop();
  }

  void pause() {
    flushElapsed(); // charge up to the pause instant
    _dispatch(const ClockPause());
  }

  void resume() => _dispatch(const ClockResume());

  /// Any game end (board, flag, resignation, agreement, disconnect).
  void gameOver() {
    if (_phase is ClockOff) return;
    _dispatch(const ClockGameOver());
    state = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
  }

  /// The game screen closed: nothing may keep ticking in the background.
  void close() => _dispatch(const ClockClose());

  void _onTick() {
    if (ref.read(gameControllerProvider).isOver) {
      gameOver();
      return;
    }
    final ms = _sw.elapsedMilliseconds;
    _sw
      ..reset()
      ..start();
    // LAN clients render an extrapolated host snapshot. Charging a local game
    // clock would let network latency flag a side before the host has ruled on
    // it, so only the host's Timeout message may produce a terminal result.
    final lanDisplayOnly = ref.read(gameModeProvider).lan;
    final game = ref.read(gameControllerProvider.notifier);
    final previous = state;
    final snap = lanDisplayOnly && previous != null
        ? ClockSnapshot(
            infinite: previous.infinite,
            whiteMs: previous.running == PieceColor.white
                ? max(0, previous.whiteMs - ms)
                : previous.whiteMs,
            blackMs: previous.running == PieceColor.black
                ? max(0, previous.blackMs - ms)
                : previous.blackMs,
            running: previous.running,
            over: previous.over,
          )
        : lanDisplayOnly
        ? game.clockSnapshotNow()
        : game.tickClock(ms);
    state = snap;
    if (snap.over) _dispatch(const ClockGameOver());
  }

  /// Charge the moving side's accrued time at the move instant and reset the
  /// stopwatch, so post-move time isn't mis-charged to the opponent. Called by
  /// the game controller immediately BEFORE applying a move.
  void flushElapsed() {
    if (_timer == null) return;
    final ms = _sw.elapsedMilliseconds;
    _sw
      ..reset()
      ..start();
    final game = ref.read(gameControllerProvider.notifier);
    if (ref.read(gameModeProvider).lan) {
      final projected = state ?? game.clockSnapshotNow();
      game.lanSetProjectedClock(projected);
      state = projected;
      return;
    }
    state = game.tickClock(ms);
  }

  /// Push the current authoritative clock snapshot immediately (so the running
  /// highlight + Fischer increment update without waiting for the next tick).
  void refreshSnapshot() {
    if (_timer == null) return;
    state = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
  }

  /// Discard accrued time and resync (used on undo).
  void resetAndRefresh() {
    if (_timer == null) return;
    _sw
      ..reset()
      ..start();
    state = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
  }
}
