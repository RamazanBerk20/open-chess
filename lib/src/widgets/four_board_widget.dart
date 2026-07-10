import 'package:flutter/material.dart';

import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/widgets/four_pieces.dart';

/// Converts a display-grid cell into the engine's canonical 14x14 square.
///
/// [displayRow] is measured from the visual top, while the engine stores row
/// zero at Red's bottom edge. Every perspective therefore maps its own home
/// edge to the visual bottom without rotating the underlying game state.
int fourBoardSquareForDisplay({
  required FourPlayer perspective,
  required int displayRow,
  required int displayCol,
}) {
  assert(displayRow >= 0 && displayRow < 14);
  assert(displayCol >= 0 && displayCol < 14);
  final (row, col) = switch (perspective) {
    FourPlayer.red => (13 - displayRow, displayCol),
    FourPlayer.blue => (13 - displayCol, 13 - displayRow),
    FourPlayer.yellow => (displayRow, 13 - displayCol),
    FourPlayer.green => (displayCol, displayRow),
  };
  return row * 14 + col;
}

/// The 14×14 four-player cross board. Cell index = row*14 + col (row 0 = the
/// bottom edge, Red's side); invalid corner cells render as holes. The board
/// is rendered from [perspective], but all controller callbacks use canonical
/// engine squares.
class FourBoardWidget extends StatelessWidget {
  final FourView view;
  final FourPlayer perspective;
  final int? selected;
  final Set<int> targets;
  final List<(int, int)> premoves;
  final int? premoveFrom;
  final Set<int> premoveTargets;
  final void Function(int sq) onTap;
  final void Function(int from, int to) onDrop;

  const FourBoardWidget({
    super.key,
    required this.view,
    required this.perspective,
    required this.selected,
    required this.targets,
    this.premoves = const [],
    this.premoveFrom,
    this.premoveTargets = const {},
    required this.onTap,
    required this.onDrop,
  });

  static const _light = Color(0xFFEDEAD2);
  static const _dark = Color(0xFF6E8C57);
  static const _premoveTint = Color(0x99E08A2B);

  /// Board after the queued premoves (raw relocations) so a chain renders.
  List<FourSquarePiece?> _previewBoard() {
    if (premoves.isEmpty) return view.board;
    final out = List<FourSquarePiece?>.of(view.board);
    for (final (f, t) in premoves) {
      out[t] = out[f];
      out[f] = null;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final dead = <FourPlayer>{
      for (final p in view.players)
        if (p.status != FourPlayerStatus.active) p.player,
    };
    final board = _previewBoard();
    final premoveSquares = <int>{
      for (final (f, t) in premoves) ...[f, t],
      ?premoveFrom,
    };
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final cell = c.biggest.shortestSide / 14;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int dr = 0; dr < 14; dr++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int col = 0; col < 14; col++)
                      _cell(
                        displayRow: dr,
                        displayCol: col,
                        cell: cell,
                        dead: dead,
                        board: board,
                        premoveSquares: premoveSquares,
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell({
    required int displayRow,
    required int displayCol,
    required double cell,
    required Set<FourPlayer> dead,
    required List<FourSquarePiece?> board,
    required Set<int> premoveSquares,
  }) {
    final sq = fourBoardSquareForDisplay(
      perspective: perspective,
      displayRow: displayRow,
      displayCol: displayCol,
    );
    if (!view.valid[sq]) {
      return SizedBox(width: cell, height: cell); // cut corner → hole
    }
    final piece = board[sq];
    final boardRow = sq ~/ 14;
    final boardCol = sq % 14;
    final isLight = (boardCol + boardRow) % 2 == 0;
    final isTarget = targets.contains(sq);
    final isPremoveTarget = premoveTargets.contains(sq);

    final content = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: isLight ? _light : _dark),
        if (view.lastFrom == sq || view.lastTo == sq)
          Container(color: const Color(0x66F6F669)),
        if (selected == sq) Container(color: const Color(0x8086C44E)),
        if (premoveSquares.contains(sq)) Container(color: _premoveTint),
        if (isPremoveTarget)
          Center(
            child: Container(
              width: cell * (piece != null ? 0.92 : 0.32),
              height: cell * (piece != null ? 0.92 : 0.32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: piece != null ? null : _premoveTint,
                border: piece != null
                    ? Border.all(color: _premoveTint, width: cell * 0.08)
                    : null,
              ),
            ),
          ),
        if (isTarget)
          Center(
            child: Container(
              width: cell * (piece != null ? 0.92 : 0.32),
              height: cell * (piece != null ? 0.92 : 0.32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: piece != null ? null : const Color(0x55303030),
                border: piece != null
                    ? Border.all(
                        color: const Color(0x55303030),
                        width: cell * 0.08,
                      )
                    : null,
              ),
            ),
          ),
        if (piece != null)
          Center(
            child: FourPieceGlyph(
              player: piece.player,
              kind: piece.kind,
              size: cell,
              dead: dead.contains(piece.player),
            ),
          ),
      ],
    );

    Widget w = GestureDetector(
      onTap: () => onTap(sq),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onDrop(d.data, sq),
        builder: (_, _, _) => content,
      ),
    );
    if (piece != null) {
      w = Draggable<int>(
        data: sq,
        feedback: FourPieceGlyph(
          player: piece.player,
          kind: piece.kind,
          size: cell,
          dead: dead.contains(piece.player),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        child: w,
      );
    }
    return SizedBox(width: cell, height: cell, child: w);
  }
}
