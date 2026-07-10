import 'package:open_chess/src/rust/api/analyze.dart';
import 'package:open_chess/src/state/analysis_provider.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AI presets keep the declared Elo bands and gradual early progression',
    () {
      expect(Difficulty.presets.map((difficulty) => difficulty.targetElo), [
        500,
        800,
        1000,
        1500,
        2000,
        null,
      ]);
      expect(Difficulty.easy.maxDepth, 3);
      expect(Difficulty.normal.maxDepth, 4);
      expect(
        Difficulty.easy.maxEvalLossCp,
        lessThan(Difficulty.veryEasy.maxEvalLossCp),
      );
      expect(
        Difficulty.normal.maxEvalLossCp,
        lessThan(Difficulty.easy.maxEvalLossCp),
      );
    },
  );

  test(
    'known AI target rating overrides an unreliable short-game estimate',
    () {
      const measured = EloEstimate(
        elo: 2140,
        confidence: EloConfidence.low,
        analyzedMoves: 9,
        averageCpLoss: 3,
      );
      final resolved = resolvedAnalysisElo(
        knownElo: Difficulty.easy.targetElo,
        measured: measured,
      );

      expect(resolved?.elo, 800);
      expect(resolved?.confidence, EloConfidence.high);
      expect(resolved?.analyzedMoves, measured.analyzedMoves);
      expect(resolvedAnalysisElo(knownElo: null, measured: measured), measured);
    },
  );
}
