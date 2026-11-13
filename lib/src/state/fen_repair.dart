import 'package:open_chess/src/rust/api/game.dart';

/// The engine's reason for rejecting [fen] under [variant], or null if it
/// loads. Bridge errors read `invalid FEN: <fen> (<reason>)`.
String? fenLoadError(String fen, GameVariant variant) {
  try {
    ChessGame.fromFenVariant(
      fen: fen,
      variant: variant,
      baseMinutes: 0,
      incrementSeconds: 0,
    );
    return null;
  } catch (e) {
    final text = '$e';
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
  }
}

/// Drop castling rights whose king or rook is no longer on its back rank (an
/// old Atomic save where the rook was blown up, for example). Returns null when
/// nothing could be repaired. Pure text surgery: the engine re-validates the
/// result, so this can only ever remove rights, never add any.
String? stripStaleCastling(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 3 || parts[2] == '-') return null;
  final ranks = parts[0].split('/');
  if (ranks.length != 8) return null;
  List<String?> expand(String rank) {
    final out = <String?>[];
    for (final c in rank.split('')) {
      final n = int.tryParse(c);
      if (n != null) {
        out.addAll(List.filled(n, null));
      } else {
        out.add(c);
      }
    }
    return out;
  }

  final white = expand(ranks[7]); // rank 1
  final black = expand(ranks[0]); // rank 8
  if (white.length != 8 || black.length != 8) return null;

  bool keep(String right) {
    final isWhite = right == right.toUpperCase();
    final row = isWhite ? white : black;
    final king = isWhite ? 'K' : 'k';
    final rook = isWhite ? 'R' : 'r';
    final k = row.indexOf(king);
    if (k < 0) return false;
    final r = right.toLowerCase();
    if (r == 'k') return row.sublist(k + 1).contains(rook);
    if (r == 'q') return row.sublist(0, k).contains(rook);
    // Shredder/X-FEN file letter: a rook must stand on that file.
    final file = r.codeUnitAt(0) - 'a'.codeUnitAt(0);
    return file >= 0 && file < 8 && row[file] == rook;
  }

  final kept = parts[2].split('').where(keep).join();
  final rights = kept.isEmpty ? '-' : kept;
  if (rights == parts[2]) return null;
  return [...parts.take(2), rights, ...parts.skip(3)].join(' ');
}

/// Drop an en-passant square that cannot be real: wrong rank for the side to
/// move, the double-stepped pawn missing, or the squares it crossed occupied.
/// Returns null when nothing changed. Like [stripStaleCastling] it can only
/// remove information.
String? stripStaleEnPassant(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 4 || parts[3] == '-') return null;
  final ranks = parts[0].split('/');
  bool ok = false;
  final ep = parts[3];
  if (ranks.length == 8 &&
      ep.length == 2 &&
      (parts[1] == 'w' || parts[1] == 'b')) {
    final file = ep.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(ep[1]) ?? 0;
    final white = parts[1] == 'w'; // white to move: black just pushed
    if (file >= 0 && file < 8 && rank == (white ? 6 : 3)) {
      String at(int r) {
        final out = StringBuffer();
        for (final c in ranks[8 - r].split('')) {
          final n = int.tryParse(c);
          out.write(n != null ? '.' * n : c);
        }
        final row = out.toString();
        return row.length == 8 ? row[file] : '?';
      }

      final pawn = white ? 'p' : 'P';
      ok =
          at(white ? 5 : 4) == pawn &&
          at(rank) == '.' &&
          at(white ? 7 : 2) == '.';
    }
  }
  if (ok) return null;
  return [...parts.take(3), '-', ...parts.skip(4)].join(' ');
}

/// What [prepareUserFen] changed, for a visible note.
enum FenNote { castlingRemoved, enPassantRemoved, chess960 }

/// A user-supplied FEN made loadable (or the reason it cannot be).
class FenPrep {
  final String fen;
  final GameVariant variant;
  final List<FenNote> notes;

  /// Engine rejection reason; non-null means [fen] must not be used.
  final String? error;
  const FenPrep(this.fen, this.variant, this.notes, this.error);
}

/// The one place user-typed/pasted FENs are leniently accepted (Import, "Play
/// from position", the hub): stale castling rights and a stale en-passant
/// square are stripped; a bare Standard FEN that is only legal as Chess960
/// (Shredder letters, off-corner king/rooks) is offered as Chess960. Anything
/// else invalid keeps the engine's reason in [FenPrep.error].
FenPrep prepareUserFen(
  String fen, [
  GameVariant variant = GameVariant.standard,
]) {
  final input = fen.trim();
  final firstError = fenLoadError(input, variant);
  if (firstError == null) return FenPrep(input, variant, const [], null);
  final notes = <FenNote>[];
  var stripped = input;
  final noCastle = stripStaleCastling(stripped);
  if (noCastle != null) {
    stripped = noCastle;
    notes.add(FenNote.castlingRemoved);
  }
  final noEp = stripStaleEnPassant(stripped);
  if (noEp != null) {
    stripped = noEp;
    notes.add(FenNote.enPassantRemoved);
  }
  final canBe960 = variant == GameVariant.standard;
  // Chess960 on the untouched text first: it keeps the user's castling rights.
  if (canBe960 && fenLoadError(input, GameVariant.chess960) == null) {
    return FenPrep(input, GameVariant.chess960, const [FenNote.chess960], null);
  }
  if (notes.isNotEmpty) {
    if (fenLoadError(stripped, variant) == null) {
      return FenPrep(stripped, variant, notes, null);
    }
    if (canBe960 && fenLoadError(stripped, GameVariant.chess960) == null) {
      return FenPrep(stripped, GameVariant.chess960, [
        ...notes,
        FenNote.chess960,
      ], null);
    }
  }
  return FenPrep(input, variant, const [], firstError);
}
