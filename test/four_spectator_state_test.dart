import 'package:open_chess/src/state/four_lan_controller.dart';
import 'package:open_chess/src/state/multi_board_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps the four-player spectator state and chat private to the watcher',
    () {
      const state = FourLanState(
        session: MbLobby(),
        isSpectator: true,
        myName: 'watcher',
        spectatorChat: [
          FourSpectatorChatMessage('hello', false, senderName: 'other watcher'),
        ],
      );

      expect(state.isSpectator, isTrue);
      expect(state.mySeats, isEmpty);
      expect(state.spectatorChat.single.senderName, 'other watcher');
    },
  );

  test('bounds four-player spectator chat before it reaches the bridge', () {
    expect(isValidFourSpectatorChat(' hello '), isTrue);
    expect(isValidFourSpectatorChat('   '), isFalse);
    expect(isValidFourSpectatorChat(List.filled(513, 'a').join()), isFalse);
    expect(isValidFourSpectatorChat(List.filled(513, '😀').join()), isFalse);
  });
}
