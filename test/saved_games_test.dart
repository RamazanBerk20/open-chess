import 'package:flutter_test/flutter_test.dart';

import 'package:open_chess/src/state/saved_games.dart';

void main() {
  test('migrates legacy saves without a clock snapshot', () {
    final game = SavedGame.fromJson(<String, dynamic>{
      'id': 'old',
      'name': 'Legacy',
      'moves': <String>['e2e4'],
      'createdAt': '2026-01-01 00:00:00',
    });

    expect(game.variantCode, 'standard');
    expect(game.baseMinutes, isNull);
    expect(game.whiteMs, isNull);
    expect(game.blackMs, isNull);
  });

  test('round-trips variant and remaining clock state', () {
    const game = SavedGame(
      id: 'new',
      name: 'Snapshot',
      moves: <String>['e2e4', 'e7e5'],
      createdAt: '2026-01-01 00:00:00',
      variantCode: 'chess960',
      baseMinutes: 5,
      incrementSeconds: 2,
      whiteMs: 287000,
      blackMs: 294000,
      vsAi: true,
      aiColorCode: 'black',
      difficultyName: 'Hard',
    );

    final restored = SavedGame.fromJson(game.toJson());
    expect(restored.variantCode, 'chess960');
    expect(restored.baseMinutes, 5);
    expect(restored.incrementSeconds, 2);
    expect(restored.whiteMs, 287000);
    expect(restored.blackMs, 294000);
    expect(restored.vsAi, isTrue);
    expect(restored.aiColorCode, 'black');
    expect(restored.difficultyName, 'Hard');
  });
}
