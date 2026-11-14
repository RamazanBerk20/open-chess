import 'package:flutter/material.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/widgets/clock_widget.dart';
import 'package:open_chess/src/widgets/four_pieces.dart';

/// The state of play in the window bar, read like a chess clock: a face per
/// side (king + time left when timed), the move number between them, and the
/// side to move on a filled face. Only public game state is shown.
class TwoPlayerBarStatus extends StatelessWidget {
  final PieceColor sideToMove;
  final int moveNumber;
  final bool over;

  /// Remaining times, or null in an untimed game.
  final int? whiteMs;
  final int? blackMs;

  const TwoPlayerBarStatus({
    super.key,
    required this.sideToMove,
    required this.moveNumber,
    required this.over,
    this.whiteMs,
    this.blackMs,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final white = sideToMove == PieceColor.white;
    return Semantics(
      container: true,
      label:
          '${over ? '' : '${white ? t.whiteToMove : t.blackToMove}, '}'
          '${t.windowMoveNumber(moveNumber)}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ClockFace(
              glyph: '♔', // ♔
              ms: whiteMs,
              active: !over && white,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '$moveNumber',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _ClockFace(
              glyph: '♚', // ♚
              ms: blackMs,
              active: !over && !white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockFace extends StatelessWidget {
  final String glyph;
  final int? ms;
  final bool active;
  const _ClockFace({required this.glyph, this.ms, required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ms = this.ms;
    final ink = active ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? cs.secondaryContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            glyph,
            style: TextStyle(
              fontFamily: 'ChessGlyphs',
              fontSize: 19,
              height: 1,
              color: ink,
            ),
          ),
          if (ms != null) ...[
            const SizedBox(width: 6),
            Text(
              formatClock(ms),
              style: TextStyle(
                color: active && ms < 10000 ? cs.error : ink,
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Four sides do not fit as clock faces, so each seat is a pip in its colour:
/// the side to move is ringed, eliminated seats are hollow.
class FourPlayerBarStatus extends StatelessWidget {
  final List<FourPlayerPanel> players;
  final FourPlayer turn;
  final bool over;

  /// Spoken summary, e.g. "Blue to move".
  final String semanticsLabel;

  const FourPlayerBarStatus({
    super.key,
    required this.players,
    required this.turn,
    required this.over,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in players)
              Container(
                key: ValueKey(p.player),
                width: 22,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: !over && p.player == turn
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.onSurface, width: 2),
                      )
                    : null,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: p.status == FourPlayerStatus.active
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          color: fourColors[p.player],
                        )
                      : BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.onSurfaceVariant,
                            width: 1.5,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
