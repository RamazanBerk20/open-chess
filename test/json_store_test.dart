import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_chess/src/state/json_store.dart';
import 'package:open_chess/src/state/saved_games.dart';

SavedGame _game(String id) =>
    SavedGame(id: id, name: id, moves: const ['e2e4'], createdAt: '');

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('store_test');
    appStoreDirectory = () async => dir;
    storeCorruptions.value = const [];
  });

  tearDown(() => dir.delete(recursive: true));

  group('reduceStore', () {
    test('loading becomes ready with the loaded value', () {
      final s = reduceStore<int>(const StoreLoading(), const StoreLoaded(3));
      expect(s, isA<StoreReady<int>>().having((r) => r.value, 'value', 3));
    });

    test('a write before the load is rejected', () {
      expect(
        () => reduceStore<int>(const StoreLoading(), const StoreWritten(1)),
        throwsStateError,
      );
    });

    test('a write keeps the corrupt-backup notice', () {
      final s = reduceStore<int>(
        const StoreReady(1, corruptBackup: 'x.corrupt'),
        const StoreWritten(2),
      );
      expect((s as StoreReady<int>).value, 2);
      expect(s.corruptBackup, 'x.corrupt');
    });

    test('a second load result is ignored', () {
      const ready = StoreReady(5);
      expect(reduceStore<int>(ready, const StoreLoaded(0)), same(ready));
    });
  });

  test('saving from a cold provider keeps every earlier saved game', () async {
    final seed = ProviderContainer();
    await seed.read(savedGamesProvider.notifier).add(_game('old1'));
    await seed.read(savedGamesProvider.notifier).add(_game('old2'));
    seed.dispose();

    // Fresh launch: nothing has watched the provider yet.
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(savedGamesProvider.notifier).add(_game('new'));
    final reloaded = await JsonStore<List<SavedGame>>(
      'saved_games.json',
      decode: decodeSavedGames,
      encode: (g) => [for (final x in g) x.toJson()],
      empty: const [],
    ).load();
    expect(reloaded.map((g) => g.id), ['old1', 'old2', 'new']);
  });

  test('concurrent updates are serialized and none is lost', () async {
    final store = JsonStore<List<int>>(
      'n.json',
      decode: (j) => (j as List).cast<int>(),
      encode: (v) => v,
      empty: const [],
    );
    await Future.wait([
      for (var i = 0; i < 20; i++) store.update((l) => [...l, i]),
    ]);
    final again = JsonStore<List<int>>(
      'n.json',
      decode: (j) => (j as List).cast<int>(),
      encode: (v) => v,
      empty: const [],
    );
    expect(await again.load(), List.generate(20, (i) => i));
    expect(File('${dir.path}/n.json.tmp').existsSync(), isFalse);
  });

  test('an unreadable file is preserved and reported, not replaced', () async {
    File('${dir.path}/s.json').writeAsStringSync('{"broken": ');
    final store = JsonStore<Map<String, dynamic>>(
      's.json',
      decode: (j) => j as Map<String, dynamic>,
      encode: (v) => v,
      empty: const {},
    );
    expect(await store.load(), isEmpty);
    final backup = (store.state as StoreReady).corruptBackup!;
    expect(backup, endsWith('.corrupt'));
    expect(File(backup).readAsStringSync(), '{"broken": ');
    expect(storeCorruptions.value, [backup]);
    expect(File('${dir.path}/s.json').existsSync(), isFalse); // moved, once
  });

  test('backups are capped at three and a stale .tmp is cleaned', () async {
    JsonStore<Map<String, dynamic>> make() => JsonStore<Map<String, dynamic>>(
      's.json',
      decode: (j) => j as Map<String, dynamic>,
      encode: (v) => v,
      empty: const {},
    );
    File('${dir.path}/s.json.tmp').writeAsStringSync('partial');
    for (var i = 0; i < 5; i++) {
      File('${dir.path}/s.json').writeAsStringSync('{"broken$i": ');
      await make().load();
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }
    final backups = dir
        .listSync()
        .where((e) => e.path.endsWith('.corrupt'))
        .toList();
    expect(backups, hasLength(maxCorruptBackups));
    expect(File('${dir.path}/s.json.tmp').existsSync(), isFalse);
    final fresh = make();
    await fresh.set({'ok': 1}); // the next save writes a fresh file
    expect(File('${dir.path}/s.json').readAsStringSync(), '{"ok":1}');
  });

  test('one bad saved-game entry is skipped, the rest are kept', () async {
    File(
      '${dir.path}/saved_games.json',
    ).writeAsStringSync('[${'{"id":"a","name":"a","moves":[]}'}, 42]');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final games = await c.read(savedGamesProvider.future);
    expect(games.map((g) => g.id), ['a']);
    expect(storeCorruptions.value, hasLength(1));
  });
}
