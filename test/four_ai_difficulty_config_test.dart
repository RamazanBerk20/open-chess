import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/state/four_player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local four-player bot games default to Normal difficulty', () {
    const config = FourConfig(
      mode: FourMode.vsBots,
      format: FourFormat.freeForAll,
      humanSeats: {FourPlayer.red},
    );

    expect(config.aiDifficultyCode, defaultFourAiDifficultyCode);
    expect(config.aiDifficultyCode, 2);
  });

  test('normalizes invalid local four-player difficulty codes to Normal', () {
    expect(normalizedFourAiDifficultyCode(0), 0);
    expect(normalizedFourAiDifficultyCode(5), 5);
    expect(normalizedFourAiDifficultyCode(-1), defaultFourAiDifficultyCode);
    expect(
      normalizedFourAiDifficultyCode(fourAiDifficultyCodeCount),
      defaultFourAiDifficultyCode,
    );
  });
}
