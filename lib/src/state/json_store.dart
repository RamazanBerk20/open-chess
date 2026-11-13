import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Directory that holds every persisted JSON file. Tests point it at a temp dir.
Future<Directory> Function() appStoreDirectory = getApplicationSupportDirectory;

/// Paths of `.corrupt` backups made this session; the app shell reports them.
final ValueNotifier<List<String>> storeCorruptions = ValueNotifier(const []);

/// Bumped whenever a write fails (disk full, read-only folder); the app shell
/// tells the user once.
final ValueNotifier<int> storeWriteFailures = ValueNotifier(0);

/// Newest `.corrupt` backups kept per store; older ones are deleted.
const maxCorruptBackups = 3;

/// Lifecycle of one persisted file: nothing may be written until it is Ready.
sealed class StoreState<T> {
  const StoreState();
}

class StoreLoading<T> extends StoreState<T> {
  const StoreLoading();
}

class StoreReady<T> extends StoreState<T> {
  final T value;

  /// Where an unreadable original was preserved (null when the load was clean).
  final String? corruptBackup;
  const StoreReady(this.value, {this.corruptBackup});
}

sealed class StoreEvent<T> {
  const StoreEvent();
}

/// The file was read (or did not exist and [value] is the default).
class StoreLoaded<T> extends StoreEvent<T> {
  final T value;
  final String? corruptBackup;
  const StoreLoaded(this.value, {this.corruptBackup});
}

/// A write of [value] completed.
class StoreWritten<T> extends StoreEvent<T> {
  final T value;
  const StoreWritten(this.value);
}

/// Pure transition. A write before the load is a programming error: the store
/// serializes writes behind the load, so it can never build from an empty value.
StoreState<T> reduceStore<T>(StoreState<T> s, StoreEvent<T> e) =>
    switch ((s, e)) {
      (StoreLoading<T>(), StoreLoaded<T>(:final value, :final corruptBackup)) =>
        StoreReady(value, corruptBackup: corruptBackup),
      (StoreLoading<T>(), StoreWritten<T>()) => throw StateError(
        'write before load',
      ),
      (StoreReady<T>(), StoreLoaded<T>()) => s, // loads are memoized; ignore
      (StoreReady<T>(:final corruptBackup), StoreWritten<T>(:final value)) =>
        StoreReady(value, corruptBackup: corruptBackup),
    };

/// Thrown by a decoder when the file is only partly readable: [salvaged] is
/// kept, and the original is preserved as a `.corrupt` backup like a full
/// failure.
class PartialDecode<T> implements Exception {
  final T salvaged;
  const PartialDecode(this.salvaged);
}

/// One JSON file: a memoized load, then serialized atomic writes (temp file +
/// rename). An unreadable file is moved to `<name>.<ms>.corrupt` (so this happens
/// once; the next save writes a fresh file) and reported, never silently
/// replaced by the default. At most [maxCorruptBackups] backups are kept.
class JsonStore<T> {
  final String fileName;
  final T Function(Object? json) decode;
  final Object? Function(T value) encode;
  final T empty;

  StoreState<T> _state = const StoreLoading();
  Future<T>? _load;
  Future<void> _tail = Future.value();

  JsonStore(
    this.fileName, {
    required this.decode,
    required this.encode,
    required this.empty,
  });

  StoreState<T> get state => _state;

  Future<File> _file() async =>
      File('${(await appStoreDirectory()).path}/$fileName');

  Future<T> load() => _load ??= _doLoad();

  Future<T> _doLoad() async {
    final f = await _file();
    T value = empty;
    String? backup;
    try {
      await File('${f.path}.tmp').delete(); // stale leftover of a failed write
    } catch (_) {}
    if (await f.exists()) {
      try {
        value = decode(json.decode(await f.readAsString()));
      } catch (e) {
        if (e is PartialDecode<T>) value = e.salvaged;
        backup = '${f.path}.${DateTime.now().millisecondsSinceEpoch}.corrupt';
        try {
          await f.rename(backup);
          storeCorruptions.value = [...storeCorruptions.value, backup];
          await _pruneBackups(f);
        } catch (_) {
          // Cannot even preserve it: refuse to overwrite the original.
          _load = null;
          rethrow;
        }
      }
    }
    _state = reduceStore(_state, StoreLoaded(value, corruptBackup: backup));
    return value;
  }

  Future<void> _pruneBackups(File f) async {
    try {
      final name = fileName;
      final old = [
        await for (final e in f.parent.list())
          if (e is File &&
              e.uri.pathSegments.last.startsWith('$name.') &&
              e.path.endsWith('.corrupt'))
            e,
      ];
      // Epoch-ms names: shorter then lexicographic = oldest first.
      old.sort((a, b) {
        final byLen = a.path.length.compareTo(b.path.length);
        return byLen != 0 ? byLen : a.path.compareTo(b.path);
      });
      for (final e in old.take(
        (old.length - maxCorruptBackups).clamp(0, 1 << 30),
      )) {
        await e.delete();
      }
    } catch (_) {} // pruning is best effort
  }

  /// Apply [change] to the latest persisted value and write it. Waits for the
  /// load, runs after every earlier write, and completes with the written value
  /// (or the write error; later writes still run).
  Future<T> update(T Function(T current) change) {
    final done = _tail.then((_) async {
      final current = await load();
      final next = change(switch (_state) {
        StoreReady<T>(:final value) => value,
        StoreLoading<T>() => current,
      });
      await _write(next);
      _state = reduceStore(_state, StoreWritten(next));
      return next;
    });
    _tail = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<T> set(T value) => update((_) => value);

  Future<void> _write(T value) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    try {
      await tmp.writeAsString(json.encode(encode(value)), flush: true);
      await tmp.rename(f.path);
    } catch (_) {
      try {
        await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }
}
