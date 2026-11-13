import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/l10n_labels.dart';

/// PGN date "YYYY.MM.DD".
String pgnDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}.${d.month.toString().padLeft(2, '0')}'
    '.${d.day.toString().padLeft(2, '0')}';

/// PGN `[Variant]` names for non-standard rules (null for standard chess).
String? pgnVariant(GameVariant v) => switch (v) {
  GameVariant.standard => null,
  GameVariant.threeCheck => 'Three-check',
  GameVariant.kingOfTheHill => 'King of the Hill',
  GameVariant.chess960 => 'Chess960',
  GameVariant.atomic => 'Atomic',
  GameVariant.crazyhouse => 'Crazyhouse',
  GameVariant.bughouse => 'Bughouse',
  GameVariant.fogOfWar => 'Fog of War',
};

/// Result and termination for a non-board result code ([youAreWhite] is the
/// local player's side, needed for resignations).
(String, String) _overlayResult(String code, bool youAreWhite) {
  final me = youAreWhite ? '1-0' : '0-1';
  final them = youAreWhite ? '0-1' : '1-0';
  return switch (code) {
    LanResultCode.youResigned => (them, 'resignation'),
    LanResultCode.opponentResigned => (me, 'resignation'),
    LanResultCode.drawAgreed => ('1/2-1/2', 'agreement'),
    LanResultCode.gameWhiteWins => ('1-0', 'normal'),
    LanResultCode.gameBlackWins => ('0-1', 'normal'),
    LanResultCode.gameStalemate ||
    LanResultCode.gameDrawFifty ||
    LanResultCode.gameDrawThreefold ||
    LanResultCode.gameDrawInsufficient => ('1/2-1/2', 'normal'),
    _ => ('*', 'abandoned'),
  };
}

/// Build a PGN string from a game's SAN moves + result. Pure Dart — the SAN
/// move list and outcome already come from the Rust [GameView].
String buildPgn({
  required List<String> sanMoves,
  required GameOutcome status,
  String white = 'White',
  String black = 'Black',
  String event = 'Casual game',
  String? date, // "YYYY.MM.DD"
  String? startFen, // non-null for games started from a custom position
  String? overlayResult, // non-board result code (resign, agreement, …)
  bool youAreWhite = true,
  GameVariant variant = GameVariant.standard,
}) {
  final boardResult = switch (status) {
    GameOutcome.whiteWins || GameOutcome.whiteWinsOnTime => '1-0',
    GameOutcome.blackWins || GameOutcome.blackWinsOnTime => '0-1',
    GameOutcome.stalemate ||
    GameOutcome.drawFiftyMove ||
    GameOutcome.drawThreefold ||
    GameOutcome.drawInsufficientMaterial => '1/2-1/2',
    GameOutcome.ongoing => '*',
  };
  final termination = switch (status) {
    GameOutcome.whiteWinsOnTime ||
    GameOutcome.blackWinsOnTime => 'time forfeit',
    GameOutcome.ongoing => null,
    _ => 'normal',
  };
  final (result, term) = overlayResult != null && status == GameOutcome.ongoing
      ? _overlayResult(overlayResult, youAreWhite)
      : (boardResult, termination);
  final variantName = pgnVariant(variant);

  final b = StringBuffer()
    ..writeln('[Event "$event"]')
    ..writeln('[Site "Open Chess"]')
    ..writeln('[Date "${date ?? '????.??.??'}"]')
    ..writeln('[White "${_esc(white)}"]')
    ..writeln('[Black "${_esc(black)}"]')
    ..writeln('[Result "$result"]');
  if (variantName != null) b.writeln('[Variant "$variantName"]');
  if (term != null) b.writeln('[Termination "$term"]');
  if (startFen != null &&
      (variant == GameVariant.chess960 ||
          startFen !=
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')) {
    b
      ..writeln('[SetUp "1"]')
      ..writeln('[FEN "$startFen"]');
  }
  b.writeln();

  // Movetext: "1. e4 e5 2. Nf3 …", wrapped to ~80 columns.
  final tokens = <String>[];
  for (var i = 0; i < sanMoves.length; i++) {
    if (i.isEven) tokens.add('${i ~/ 2 + 1}.');
    tokens.add(sanMoves[i]);
  }
  tokens.add(result);

  var line = '';
  for (final tok in tokens) {
    if (line.isNotEmpty && line.length + tok.length + 1 > 80) {
      b.writeln(line);
      line = '';
    }
    line = line.isEmpty ? tok : '$line $tok';
  }
  if (line.isNotEmpty) b.writeln(line);
  return b.toString();
}

String _esc(String s) => s.replaceAll('"', "'");
