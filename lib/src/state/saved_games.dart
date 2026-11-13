import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_chess/src/state/json_store.dart';

/// A saved game with enough context to replay its exact rules and start
/// position. Older entries are upgraded with standard/infinite defaults.
class SavedGame {
  final String id;
  final String name;
  final List<String> moves;
  final String createdAt;
  final String startFen;
  final String variantCode;
  final int? baseMinutes;
  final int incrementSeconds;

  /// Remaining clocks at the save point. Null denotes an old save or an
  /// infinite game, both of which resume without a finite clock snapshot.
  final int? whiteMs;
  final int? blackMs;

  /// Original single-player context, retained for variants such as Fog of War
  /// that must never be resumed as a shared-device game.
  final bool vsAi;
  final String? aiColorCode;
  final String? difficultyName;

  /// Full engine profile, so a Custom difficulty resumes as itself.
  final Map<String, dynamic>? difficultyParams;

  /// Clock (white, black ms) just before each ply, so a takeback after resume
  /// restores the time the game really had at that move.
  final List<(int, int)>? clockHistory;

  const SavedGame({
    required this.id,
    required this.name,
    required this.moves,
    required this.createdAt,
    this.startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.variantCode = 'standard',
    this.baseMinutes,
    this.incrementSeconds = 0,
    this.whiteMs,
    this.blackMs,
    this.vsAi = false,
    this.aiColorCode,
    this.difficultyName,
    this.difficultyParams,
    this.clockHistory,
  });

  SavedGame copyWith({String? name}) => SavedGame(
    id: id,
    name: name ?? this.name,
    moves: moves,
    createdAt: createdAt,
    startFen: startFen,
    variantCode: variantCode,
    baseMinutes: baseMinutes,
    incrementSeconds: incrementSeconds,
    whiteMs: whiteMs,
    blackMs: blackMs,
    vsAi: vsAi,
    aiColorCode: aiColorCode,
    difficultyName: difficultyName,
    difficultyParams: difficultyParams,
    clockHistory: clockHistory,
  );

  int get ply => moves.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'moves': moves,
    'createdAt': createdAt,
    'startFen': startFen,
    'variantCode': variantCode,
    'baseMinutes': baseMinutes,
    'incrementSeconds': incrementSeconds,
    'whiteMs': whiteMs,
    'blackMs': blackMs,
    'vsAi': vsAi,
    'aiColorCode': aiColorCode,
    'difficultyName': difficultyName,
    'difficultyParams': difficultyParams,
    'clockHistory': clockHistory == null
        ? null
        : [
            for (final (w, b) in clockHistory!) [w, b],
          ],
  };

  factory SavedGame.fromJson(Map<String, dynamic> j) => SavedGame(
    id: j['id'] as String,
    name: j['name'] as String,
    moves: (j['moves'] as List).cast<String>(),
    createdAt: j['createdAt'] as String? ?? '',
    startFen:
        j['startFen'] as String? ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    variantCode: j['variantCode'] as String? ?? 'standard',
    baseMinutes: j['baseMinutes'] as int?,
    incrementSeconds: j['incrementSeconds'] as int? ?? 0,
    whiteMs: (j['whiteMs'] as num?)?.toInt(),
    blackMs: (j['blackMs'] as num?)?.toInt(),
    vsAi: j['vsAi'] as bool? ?? false,
    aiColorCode: j['aiColorCode'] as String?,
    difficultyName: j['difficultyName'] as String?,
    difficultyParams: j['difficultyParams'] as Map<String, dynamic>?,
    clockHistory: (j['clockHistory'] as List?)?.map((e) {
      final p = e as List;
      return ((p[0] as num).toInt(), (p[1] as num).toInt());
    }).toList(),
  );
}

/// Strict per-entry decode: one bad entry is skipped (and the file is backed
/// up by the store) instead of discarding every saved game.
List<SavedGame> decodeSavedGames(Object? j) {
  final out = <SavedGame>[];
  var bad = false;
  for (final e in j as List) {
    try {
      out.add(SavedGame.fromJson(e as Map<String, dynamic>));
    } catch (_) {
      bad = true;
    }
  }
  if (bad) throw PartialDecode(out);
  return out;
}

final savedGamesStoreProvider = Provider<JsonStore<List<SavedGame>>>(
  (_) => JsonStore(
    'saved_games.json',
    decode: decodeSavedGames,
    encode: (games) => [for (final g in games) g.toJson()],
    empty: const [],
  ),
);

final savedGamesProvider =
    AsyncNotifierProvider<SavedGamesController, List<SavedGame>>(
      SavedGamesController.new,
    );

/// Every mutation goes through the store, which waits for the load and
/// serializes writes, so a save from a cold provider never drops older games.
class SavedGamesController extends AsyncNotifier<List<SavedGame>> {
  JsonStore<List<SavedGame>> get _store => ref.read(savedGamesStoreProvider);

  @override
  Future<List<SavedGame>> build() => _store.load();

  Future<void> _apply(List<SavedGame> Function(List<SavedGame>) f) async {
    state = AsyncData(await _store.update(f));
  }

  Future<void> add(SavedGame g) => _apply((list) => [...list, g]);

  Future<void> remove(String id) => _apply(
    (list) => [
      for (final g in list)
        if (g.id != id) g,
    ],
  );

  Future<void> rename(String id, String name) => _apply(
    (list) => [for (final g in list) g.id == id ? g.copyWith(name: name) : g],
  );
}

/// The unfinished game being played, rewritten after every move and when the
/// app is backgrounded, so it can be offered for resume on the next launch.
final autosaveStoreProvider = Provider<JsonStore<SavedGame?>>(
  (_) => JsonStore(
    'current_game.json',
    decode: (j) =>
        j == null ? null : SavedGame.fromJson(j as Map<String, dynamic>),
    encode: (g) => g?.toJson(),
    empty: null,
  ),
);

final autosaveProvider = AsyncNotifierProvider<AutosaveController, SavedGame?>(
  AutosaveController.new,
);

class AutosaveController extends AsyncNotifier<SavedGame?> {
  JsonStore<SavedGame?> get _store => ref.read(autosaveStoreProvider);

  @override
  Future<SavedGame?> build() => _store.load();

  /// Store [g] as the current game, or clear it with null (finished/empty).
  Future<void> put(SavedGame? g) async {
    try {
      state = AsyncData(await _store.set(g));
    } catch (_) {
      // Autosave is best effort; the previous file is kept intact.
    }
  }
}
