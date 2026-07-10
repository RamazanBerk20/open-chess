import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/difficulty.dart';

/// Human-vs-human (same device), vs the AI, or a LAN game.
class GameMode {
  final bool vsAi;
  final PieceColor? aiColor;
  final Difficulty difficulty;
  final bool lan;
  final PieceColor? lanMyColor;
  final bool lanSpectator;

  const GameMode({
    this.vsAi = false,
    this.aiColor,
    this.difficulty = Difficulty.normal,
    this.lan = false,
    this.lanMyColor,
    this.lanSpectator = false,
  });
}

final gameModeProvider = NotifierProvider<GameModeController, GameMode>(
  GameModeController.new,
);

class GameModeController extends Notifier<GameMode> {
  @override
  GameMode build() => const GameMode();

  void setTwoPlayer() => state = const GameMode();

  void setVsAi(PieceColor aiColor, Difficulty difficulty) =>
      state = GameMode(vsAi: true, aiColor: aiColor, difficulty: difficulty);

  void setLan(PieceColor myColor) =>
      state = GameMode(lan: true, lanMyColor: myColor);

  /// A live LAN spectator has no movable colour and never sends game commands.
  void setLanSpectator() =>
      state = const GameMode(lan: true, lanSpectator: true);
}
