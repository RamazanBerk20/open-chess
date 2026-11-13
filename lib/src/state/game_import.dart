import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/fen_repair.dart';
import 'package:open_chess/src/state/l10n_labels.dart';

/// Untrusted-input bounds for PGN/FEN import.
const maxImportChars = 256 * 1024;
const maxImportPlies = 1000;

const standardStartFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A game ready for analysis.
class ImportedGame {
  final String startFen;
  final GameVariant variant;
  final List<String> movesUci;

  /// Repairs applied to the supplied FEN, to be shown to the user.
  final List<FenNote> notes;
  const ImportedGame(
    this.startFen,
    this.variant,
    this.movesUci, [
    this.notes = const [],
  ]);
}

/// Why an import failed; the screen localises [kind] and shows [detail].
enum ImportErrorKind { empty, tooLarge, tooLong, badFen, badMove, unsupported }

class ImportError implements Exception {
  final ImportErrorKind kind;
  final String detail;
  const ImportError(this.kind, [this.detail = '']);
  @override
  String toString() => '$kind: $detail';
}

/// The first game of a PGN text: its tag pairs and SAN move tokens.
class PgnGame {
  final Map<String, String> tags;
  final List<String> sans;
  const PgnGame(this.tags, this.sans);
}

final _tagRe = RegExp(r'^\[(\w+)\s+"((?:[^"\\]|\\.)*)"\]\s*$');

/// Strip comments, variations, NAGs, move numbers and results. Pure Dart; never
/// throws on any input (bad structure surfaces as a bad move later).
PgnGame tokenizePgn(String text) {
  final tags = <String, String>{};
  final body = StringBuffer();
  var inMoves = false;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('%')) continue; // escape line
    if (!inMoves && line.startsWith('[')) {
      final m = _tagRe.firstMatch(line);
      if (m != null) tags[m.group(1)!] = m.group(2)!.replaceAll(r'\"', '"');
      continue;
    }
    if (line.isEmpty) {
      if (inMoves) break; // end of the first game's movetext
      continue;
    }
    inMoves = true;
    body.writeln(line);
  }
  final sans = <String>[];
  final s = body.toString();
  var depth = 0; // variation nesting
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '{') {
      final end = s.indexOf('}', i);
      i = end < 0 ? s.length : end + 1;
      continue;
    }
    if (c == ';') {
      final end = s.indexOf('\n', i);
      i = end < 0 ? s.length : end + 1;
      continue;
    }
    if (c == '(') {
      depth++;
      i++;
      continue;
    }
    if (c == '}') {
      i++; // stray closer: skip it, the scanner must always advance
      continue;
    }
    if (c == ')') {
      if (depth > 0) depth--;
      i++;
      continue;
    }
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    var j = i;
    while (j < s.length && !' \t\r\n{}();'.contains(s[j])) {
      j++;
    }
    final tok = s.substring(i, j);
    i = j > i ? j : i + 1; // never stall on an unforeseen delimiter
    if (depth > 0) continue;
    if (tok.startsWith(r'$')) continue; // NAG
    if (const {'1-0', '0-1', '1/2-1/2', '*'}.contains(tok)) break;
    final move = tok.replaceFirst(RegExp(r'^\d+\.+'), ''); // "12." / "12..."
    if (move.isEmpty || RegExp(r'^\d+$').hasMatch(move)) continue;
    sans.add(move.replaceAll(RegExp(r'[!?]+$'), ''));
  }
  return PgnGame(tags, sans);
}

/// A parsed SAN move (without board context).
class SanMove {
  final String? castle; // 'K' (O-O) or 'Q' (O-O-O)
  final PieceKind piece;
  final int? fromFile; // 0..7
  final int? fromRank; // 0..7
  final int? to; // 0..63
  final PieceKind? promotion;
  final bool drop; // Crazyhouse "N@e4"
  const SanMove({
    this.castle,
    this.piece = PieceKind.pawn,
    this.fromFile,
    this.fromRank,
    this.to,
    this.promotion,
    this.drop = false,
  });
}

const _pieces = {
  'N': PieceKind.knight,
  'B': PieceKind.bishop,
  'R': PieceKind.rook,
  'Q': PieceKind.queen,
  'K': PieceKind.king,
};

final _sanRe = RegExp(
  r'^([NBRQK])?([a-h])?([1-8])?(x)?([a-h][1-8])(?:=?([NBRQ]))?$',
);
final _dropRe = RegExp(r'^([PNBRQ])?@([a-h][1-8])$');

/// Parse one SAN token, or null when it is not SAN.
SanMove? parseSan(String token) {
  final t = token.replaceAll(RegExp(r'[+#]+$'), '');
  if (t == 'O-O' || t == '0-0') return const SanMove(castle: 'K');
  if (t == 'O-O-O' || t == '0-0-0') return const SanMove(castle: 'Q');
  int sq(String s) => (s.codeUnitAt(1) - 49) * 8 + (s.codeUnitAt(0) - 97);
  final d = _dropRe.firstMatch(t);
  if (d != null) {
    return SanMove(
      piece: _pieces[d.group(1)] ?? PieceKind.pawn,
      to: sq(d.group(2)!),
      drop: true,
    );
  }
  final m = _sanRe.firstMatch(t);
  if (m == null) return null;
  return SanMove(
    piece: _pieces[m.group(1)] ?? PieceKind.pawn,
    fromFile: m.group(2) == null ? null : m.group(2)!.codeUnitAt(0) - 97,
    fromRank: m.group(3) == null ? null : m.group(3)!.codeUnitAt(0) - 49,
    to: sq(m.group(5)!),
    promotion: _pieces[m.group(6)],
  );
}

String _sqName(int s) =>
    '${String.fromCharCode(97 + s % 8)}${String.fromCharCode(49 + s ~/ 8)}';

/// A bare FEN: 4–6 space-separated fields with 8 ranks.
bool looksLikeFen(String text) {
  final t = text.trim();
  if (t.contains('\n')) return false;
  final f = t.split(RegExp(r'\s+'));
  return f.length >= 4 && f.length <= 6 && f[0].split('/').length == 8;
}

GameVariant? _variantFromTag(String? tag) {
  if (tag == null) return GameVariant.standard;
  final v = tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return switch (v) {
    'standard' || 'chess' || 'normal' || '' => GameVariant.standard,
    'chess960' || 'fischerandom' || 'fischerrandom' => GameVariant.chess960,
    'threecheck' || '3check' => GameVariant.threeCheck,
    'kingofthehill' || 'koth' => GameVariant.kingOfTheHill,
    'atomic' => GameVariant.atomic,
    'crazyhouse' => GameVariant.crazyhouse,
    _ => null, // Bughouse / Fog of War / unknown: not analysable here
  };
}

/// Parse untrusted PGN or FEN text into a game the analysis screen can open.
/// Throws [ImportError]; never anything else.
ImportedGame importGame(String text) {
  final input = text.trim();
  if (input.isEmpty) throw const ImportError(ImportErrorKind.empty);
  if (input.length > maxImportChars) {
    throw const ImportError(ImportErrorKind.tooLarge);
  }
  if (looksLikeFen(input)) {
    final prep = prepareUserFen(input);
    if (prep.error != null) {
      throw ImportError(ImportErrorKind.badFen, prep.error!);
    }
    return ImportedGame(prep.fen, prep.variant, const [], prep.notes);
  }
  final pgn = tokenizePgn(input);
  var variant = _variantFromTag(pgn.tags['Variant']);
  if (variant == null || !computerVariants.contains(variant)) {
    throw ImportError(ImportErrorKind.unsupported, pgn.tags['Variant'] ?? '');
  }
  if (pgn.sans.length > maxImportPlies) {
    throw const ImportError(ImportErrorKind.tooLong);
  }
  var fen = pgn.tags['FEN'] ?? standardStartFen;
  var notes = const <FenNote>[];
  if (pgn.tags['FEN'] != null) {
    final prep = prepareUserFen(fen, variant);
    if (prep.error != null) {
      throw ImportError(ImportErrorKind.badFen, prep.error!);
    }
    fen = prep.fen;
    variant = prep.variant;
    notes = prep.notes;
  }
  final ChessGame game;
  try {
    game = ChessGame.fromFenVariant(
      fen: fen,
      variant: variant,
      baseMinutes: 0,
      incrementSeconds: 0,
    );
  } catch (e) {
    throw ImportError(ImportErrorKind.badFen, '$e');
  }
  final ucis = <String>[];
  for (var i = 0; i < pgn.sans.length; i++) {
    final token = pgn.sans[i];
    final uci = _resolve(game, parseSan(token));
    bool played;
    try {
      played = uci != null && game.playUci(uci: uci);
    } catch (_) {
      played = false;
    }
    if (!played) {
      throw ImportError(
        ImportErrorKind.badMove,
        '${i ~/ 2 + 1}${i.isEven ? '.' : '...'} $token',
      );
    }
    ucis.add(uci!);
  }
  return ImportedGame(fen, variant, ucis, notes);
}

/// The UCI of [san] in [game]'s current position, or null if no unique legal
/// move matches.
String? _resolve(ChessGame game, SanMove? san) {
  if (san == null) return null;
  final List<SquarePiece?> board;
  final PieceColor side;
  try {
    final v = game.view();
    board = v.board;
    side = v.sideToMove;
  } catch (_) {
    return null;
  }
  if (san.drop) {
    const letters = {
      PieceKind.pawn: 'P',
      PieceKind.knight: 'N',
      PieceKind.bishop: 'B',
      PieceKind.rook: 'R',
      PieceKind.queen: 'Q',
    };
    final l = letters[san.piece];
    return l == null ? null : '$l@${_sqName(san.to!)}';
  }
  Set<int> targets(int from) {
    try {
      return game.legalTargets(from: from).toSet();
    } catch (_) {
      return const {};
    }
  }

  if (san.castle != null) {
    final king = board.indexWhere(
      (p) => p != null && p.color == side && p.kind == PieceKind.king,
    );
    if (king < 0) return null;
    final rank = king ~/ 8 * 8;
    final kingSide = san.castle == 'K';
    final legal = targets(king);
    // Standard form (king to g/c file), then Chess960 king-takes-rook form.
    final dest = rank + (kingSide ? 6 : 2);
    if (legal.contains(dest) && (dest - king).abs() == 2) {
      return '${_sqName(king)}${_sqName(dest)}';
    }
    for (final t in legal) {
      final p = board[t];
      if (t ~/ 8 * 8 == rank &&
          p != null &&
          p.color == side &&
          p.kind == PieceKind.rook &&
          (kingSide ? t > king : t < king)) {
        return '${_sqName(king)}${_sqName(t)}';
      }
    }
    if (legal.contains(dest)) return '${_sqName(king)}${_sqName(dest)}';
    return null;
  }
  final to = san.to!;
  final candidates = <int>[];
  for (var from = 0; from < 64; from++) {
    final p = board[from];
    if (p == null || p.color != side || p.kind != san.piece) continue;
    if (san.fromFile != null && from % 8 != san.fromFile) continue;
    if (san.fromRank != null && from ~/ 8 != san.fromRank) continue;
    if (targets(from).contains(to)) candidates.add(from);
  }
  if (candidates.length != 1) return null; // illegal or ambiguous
  const promo = {
    PieceKind.knight: 'n',
    PieceKind.bishop: 'b',
    PieceKind.rook: 'r',
    PieceKind.queen: 'q',
  };
  return '${_sqName(candidates.single)}${_sqName(to)}'
      '${san.promotion == null ? '' : promo[san.promotion]}';
}
