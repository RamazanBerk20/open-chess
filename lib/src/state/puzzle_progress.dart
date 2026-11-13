import 'package:open_chess/src/state/json_store.dart';

/// Persisted puzzle progress: which puzzles are solved, where the user left off,
/// and their best solve streak.
class PuzzleProgress {
  final Set<String> solvedIds;
  final Set<String> attemptedIds;
  final int currentIndex;
  final int bestStreak;

  const PuzzleProgress({
    this.solvedIds = const {},
    this.attemptedIds = const {},
    this.currentIndex = 0,
    this.bestStreak = 0,
  });

  PuzzleProgress copyWith({
    Set<String>? solvedIds,
    Set<String>? attemptedIds,
    int? currentIndex,
    int? bestStreak,
  }) => PuzzleProgress(
    solvedIds: solvedIds ?? this.solvedIds,
    attemptedIds: attemptedIds ?? this.attemptedIds,
    currentIndex: currentIndex ?? this.currentIndex,
    bestStreak: bestStreak ?? this.bestStreak,
  );

  Map<String, dynamic> toJson() => {
    'solved': solvedIds.toList(),
    'attempted': attemptedIds.toList(),
    'currentIndex': currentIndex,
    'bestStreak': bestStreak,
  };

  factory PuzzleProgress.fromJson(Map<String, dynamic> j) => PuzzleProgress(
    solvedIds: (j['solved'] as List? ?? []).cast<String>().toSet(),
    attemptedIds: (j['attempted'] as List? ?? []).cast<String>().toSet(),
    currentIndex: j['currentIndex'] as int? ?? 0,
    bestStreak: j['bestStreak'] as int? ?? 0,
  );
}

final puzzleProgressStore = JsonStore<PuzzleProgress>(
  'puzzle_progress.json',
  decode: (j) => PuzzleProgress.fromJson(j as Map<String, dynamic>),
  encode: (p) => p.toJson(),
  empty: const PuzzleProgress(),
);

Future<PuzzleProgress> loadPuzzleProgress() async {
  try {
    return await puzzleProgressStore.load();
  } catch (_) {
    return const PuzzleProgress(); // file kept; writes stay refused
  }
}

/// Serialized, atomic, and never before the load has finished.
Future<void> savePuzzleProgress(PuzzleProgress p) =>
    puzzleProgressStore.set(p).then((_) {}, onError: (_) {});
