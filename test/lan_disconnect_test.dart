import 'package:open_chess/src/state/lan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports a disconnect during a live LAN game', () {
    expect(
      shouldApplyLanDisconnect(
        connected: true,
        matchEnded: false,
        gameIsOver: false,
        activeLanGame: true,
      ),
      isTrue,
    );
  });

  test('preserves a completed LAN result after the peer closes', () {
    expect(
      shouldApplyLanDisconnect(
        connected: true,
        matchEnded: true,
        gameIsOver: true,
        activeLanGame: true,
      ),
      isFalse,
    );
  });

  test('ignores a stale LAN disconnect after switching to an AI game', () {
    expect(
      shouldApplyLanDisconnect(
        connected: true,
        matchEnded: false,
        gameIsOver: false,
        activeLanGame: false,
      ),
      isFalse,
    );
  });

  test('keeps every non-idle LAN session eligible for explicit cleanup', () {
    for (final s in const <LanSession>[
      LanConnecting(LanRole.host),
      LanLive(spectator: false),
      LanEnded(linkOpen: true),
      LanFailed('x'),
    ]) {
      expect(hasActiveLanSession(LanGameState(session: s)), isTrue);
    }
    expect(hasActiveLanSession(const LanGameState()), isFalse);
  });
}
