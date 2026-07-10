import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/state/four_player_controller.dart';
import 'package:open_chess/src/widgets/four_board_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('four-player board perspective', () {
    test('places every army home edge at the visual bottom', () {
      final expectedHomeRow = <FourPlayer, int>{
        FourPlayer.red: 0,
        FourPlayer.yellow: 13,
      };
      final expectedHomeColumn = <FourPlayer, int>{
        FourPlayer.blue: 0,
        FourPlayer.green: 13,
      };

      for (final player in FourPlayer.values) {
        for (var displayCol = 3; displayCol <= 10; displayCol++) {
          final square = fourBoardSquareForDisplay(
            perspective: player,
            displayRow: 13,
            displayCol: displayCol,
          );
          final row = square ~/ 14;
          final col = square % 14;
          if (expectedHomeRow.containsKey(player)) {
            expect(row, expectedHomeRow[player]);
          } else {
            expect(col, expectedHomeColumn[player]);
          }
        }
      }
    });

    test('maps every display cell exactly once for every perspective', () {
      for (final player in FourPlayer.values) {
        final squares = <int>{
          for (var row = 0; row < 14; row++)
            for (var col = 0; col < 14; col++)
              fourBoardSquareForDisplay(
                perspective: player,
                displayRow: row,
                displayCol: col,
              ),
        };
        expect(squares.length, 196);
        expect(squares, containsAll(List<int>.generate(196, (i) => i)));
      }
    });

    test('uses the local human seat and a stable spectator default', () {
      for (final player in FourPlayer.values) {
        final config = FourConfig(
          mode: FourMode.vsBots,
          format: FourFormat.freeForAll,
          humanSeats: {player},
        );
        expect(fourPerspectiveForConfig(config), player);
      }

      const spectator = FourConfig(
        mode: FourMode.lan,
        format: FourFormat.freeForAll,
        humanSeats: {FourPlayer.blue},
        isSpectator: true,
      );
      expect(fourPerspectiveForConfig(spectator), FourPlayer.red);
    });
  });
}
