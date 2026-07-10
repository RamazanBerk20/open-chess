import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/time_control.dart';

/// Drives the clock countdown on a 100ms timer, decoupled from the board so
/// ticks don't rebuild the board (which could interrupt an in-progress drag).
/// Null state means there is no clock (Infinite time control).
final clockProvider = NotifierProvider<ClockNotifier, ClockSnapshot?>(
  ClockNotifier.new,
);

class ClockNotifier extends Notifier<ClockSnapshot?> {
  Timer? _timer;
  final Stopwatch _sw = Stopwatch();

  @override
  ClockSnapshot? build() {
    final tc = ref.watch(selectedTimeControlProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _sw.stop();
    });
    if (tc.isInfinite) return null;

    final snap = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
    _sw
      ..reset()
      ..start();
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _onTick(),
    );
    return snap;
  }

  void _onTick() {
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
    if (snap.over) _timer?.cancel();
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
