import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/game_mode.dart';

/// What a game is waiting for, derived purely from its state. `GameScreen`
/// builds one set of enabled actions per phase, and end-of-game handling is
/// decided here rather than in each controller.
sealed class GamePhase {
  const GamePhase();
}

/// Terminal. Either the board result ([outcome]) or a non-board result code
/// ([overlay]: resignation, agreed draw, disconnect, desync).
class PhaseOver extends GamePhase {
  final GameOutcome outcome;
  final String? overlay;
  const PhaseOver(this.outcome, this.overlay);
}

/// A local timed game on hold: no clock, no input, no engine.
class PhasePaused extends GamePhase {
  const PhasePaused();
}

class PhaseAwaitingPromotion extends GamePhase {
  final int from;
  final int to;
  const PhaseAwaitingPromotion(this.from, this.to);
}

class PhaseAwaitingEngine extends GamePhase {
  const PhaseAwaitingEngine();
}

/// The LAN opponent (or, for a spectator, either player) is to move.
class PhaseAwaitingRemote extends GamePhase {
  const PhaseAwaitingRemote();
}

class PhaseAwaitingLocal extends GamePhase {
  const PhaseAwaitingLocal();
}

GamePhase gamePhase({
  required GameOutcome status,
  required String? overlay,
  required bool paused,
  required (int, int)? pendingPromotion,
  required GameMode mode,
  required PieceColor sideToMove,
}) {
  if (status != GameOutcome.ongoing || overlay != null) {
    return PhaseOver(status, overlay);
  }
  if (paused) return const PhasePaused();
  if (pendingPromotion case (final f, final t)) {
    return PhaseAwaitingPromotion(f, t);
  }
  if (mode.vsAi && sideToMove == mode.aiColor) {
    return const PhaseAwaitingEngine();
  }
  if (mode.lan && (mode.lanSpectator || sideToMove != mode.lanMyColor)) {
    return const PhaseAwaitingRemote();
  }
  return const PhaseAwaitingLocal();
}

/// End-of-game transition for a non-board result: returns the overlay to store,
/// or null when the game is already over (the first result is final).
String? applyResult(GamePhase phase, String code) =>
    phase is PhaseOver ? null : code;

/// Open prompts (draw offer, promotion) must close once the game is over.
bool promptsAllowed(GamePhase phase) => phase is! PhaseOver;

/// Pausing is offered for local timed games only (never LAN: the host owns the
/// clock), and only while the game is running.
bool canPause({
  required GamePhase phase,
  required GameMode mode,
  required bool timed,
}) =>
    timed &&
    !mode.lan &&
    (phase is PhaseAwaitingLocal || phase is PhaseAwaitingEngine);

/// Plies to take back. vs-AI normally removes the AI reply and your move; if
/// the human moved last (it is now the AI's turn, e.g. after the human mated or
/// the AI flagged), only that ply goes so the AI does not move again.
int takebackPlies({
  required GameMode mode,
  required PieceColor sideToMove,
  required int plies,
}) {
  if (mode.lan) return 0;
  if (!mode.vsAi) return plies > 0 ? 1 : 0;
  if (sideToMove == mode.aiColor) return plies > 0 ? 1 : 0;
  return plies >= 2 ? 2 : 0;
}
