import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
  });

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
  );
}

Future<File> _file() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/saved_games.json');
}

Future<List<SavedGame>> loadSavedGames() async {
  try {
    final f = await _file();
    if (!await f.exists()) return [];
    final list = json.decode(await f.readAsString()) as List;
    return list
        .map((e) => SavedGame.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveSavedGames(List<SavedGame> games) async {
  try {
    final f = await _file();
    await f.writeAsString(json.encode(games.map((g) => g.toJson()).toList()));
  } catch (_) {}
}

final savedGamesProvider =
    AsyncNotifierProvider<SavedGamesController, List<SavedGame>>(
      SavedGamesController.new,
    );

class SavedGamesController extends AsyncNotifier<List<SavedGame>> {
  @override
  Future<List<SavedGame>> build() => loadSavedGames();

  Future<void> add(SavedGame g) async {
    final list = <SavedGame>[...?state.value, g];
    await saveSavedGames(list);
    state = AsyncData(list);
  }

  Future<void> remove(String id) async {
    final list = (state.value ?? const <SavedGame>[])
        .where((g) => g.id != id)
        .toList();
    await saveSavedGames(list);
    state = AsyncData(list);
  }

  Future<void> rename(String id, String name) async {
    final list = (state.value ?? const <SavedGame>[])
        .map(
          (g) => g.id == id
              ? SavedGame(
                  id: g.id,
                  name: name,
                  moves: g.moves,
                  createdAt: g.createdAt,
                  startFen: g.startFen,
                  variantCode: g.variantCode,
                  baseMinutes: g.baseMinutes,
                  incrementSeconds: g.incrementSeconds,
                  whiteMs: g.whiteMs,
                  blackMs: g.blackMs,
                  vsAi: g.vsAi,
                  aiColorCode: g.aiColorCode,
                  difficultyName: g.difficultyName,
                )
              : g,
        )
        .toList();
    await saveSavedGames(list);
    state = AsyncData(list);
  }
}
