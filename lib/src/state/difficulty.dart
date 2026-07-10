import 'package:open_chess/src/rust/api/ai.dart';

/// A difficulty profile mapped to an engine [AiConfigDto]. The Elo values are
/// calibrated target bands, not externally rated claims.
class Difficulty {
  final String name;
  final int? targetElo;
  final int maxDepth;
  final int moveTimeMs;
  final int maxEvalLossCp;
  final double randomMoveChance;
  final int candidateDepth;
  final int contempt;

  const Difficulty(
    this.name, {
    this.targetElo,
    required this.maxDepth,
    required this.moveTimeMs,
    this.maxEvalLossCp = 0,
    this.randomMoveChance = 0.0,
    this.candidateDepth = 3,
    this.contempt = 0,
  });

  AiConfigDto toConfig(int seed, {int? remainingClockMs}) {
    final clockBudget = remainingClockMs == null
        ? moveTimeMs
        : (remainingClockMs ~/ 20).clamp(100, moveTimeMs);
    return AiConfigDto(
      maxDepth: maxDepth,
      moveTimeMs: BigInt.from(clockBudget),
      maxEvalLossCp: maxEvalLossCp,
      randomMoveChance: randomMoveChance,
      candidateDepth: candidateDepth,
      contempt: contempt,
      seed: BigInt.from(seed),
    );
  }

  Difficulty copyWith({
    String? name,
    int? targetElo,
    int? maxDepth,
    int? moveTimeMs,
    int? maxEvalLossCp,
    double? randomMoveChance,
    int? candidateDepth,
    int? contempt,
  }) => Difficulty(
    name ?? this.name,
    targetElo: targetElo ?? this.targetElo,
    maxDepth: maxDepth ?? this.maxDepth,
    moveTimeMs: moveTimeMs ?? this.moveTimeMs,
    maxEvalLossCp: maxEvalLossCp ?? this.maxEvalLossCp,
    randomMoveChance: randomMoveChance ?? this.randomMoveChance,
    candidateDepth: candidateDepth ?? this.candidateDepth,
    contempt: contempt ?? this.contempt,
  );

  static const veryEasy = Difficulty(
    'Very Easy',
    targetElo: 500,
    maxDepth: 2,
    moveTimeMs: 180,
    maxEvalLossCp: 380,
    randomMoveChance: 0.60,
    candidateDepth: 2,
  );
  static const easy = Difficulty(
    'Easy',
    targetElo: 800,
    maxDepth: 3,
    moveTimeMs: 450,
    maxEvalLossCp: 140,
    randomMoveChance: 0.22,
    candidateDepth: 3,
  );
  static const normal = Difficulty(
    'Normal',
    targetElo: 1000,
    maxDepth: 4,
    moveTimeMs: 700,
    maxEvalLossCp: 80,
    randomMoveChance: 0.10,
    candidateDepth: 4,
  );
  static const hard = Difficulty(
    'Hard',
    targetElo: 1500,
    maxDepth: 8,
    moveTimeMs: 2000,
    maxEvalLossCp: 18,
    randomMoveChance: 0.04,
    candidateDepth: 5,
  );
  static const veryHard = Difficulty(
    'Very Hard',
    targetElo: 2000,
    maxDepth: 11,
    moveTimeMs: 5000,
    maxEvalLossCp: 8,
    randomMoveChance: 0.01,
    candidateDepth: 5,
  );
  static const impossible = Difficulty(
    'Impossible',
    maxDepth: 16,
    moveTimeMs: 10000,
    candidateDepth: 5,
  );

  static const presets = <Difficulty>[
    veryEasy,
    easy,
    normal,
    hard,
    veryHard,
    impossible,
  ];
}
