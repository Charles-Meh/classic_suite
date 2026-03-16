import 'dart:math';

import 'package:classic_suite/games/klondike/winnable_seed_corpus.dart';
import 'package:classic_suite/games/klondike/winnable_seed_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'winnable seed corpus serves every configured seed before repeating',
    () {
      final corpus = WinnableSeedCorpus(random: Random(1234));
      final dealt = [
        for (int index = 0; index < kWinnableDrawOneSeeds.length; index++)
          corpus.nextSeed(drawCount: 1),
      ];

      expect(dealt.toSet(), kWinnableDrawOneSeeds.toSet());
    },
  );

  test('winnable seed corpus defers recent seeds after a refill', () {
    final corpus = WinnableSeedCorpus(random: Random(1234));
    final firstCycle = [
      for (int index = 0; index < kWinnableDrawOneSeeds.length; index++)
        corpus.nextSeed(drawCount: 1),
    ];
    final maxRecent = kWinnableDrawOneSeeds.length <= 1
        ? 1
        : min(12, kWinnableDrawOneSeeds.length - 1);
    final guaranteedFreshCount = kWinnableDrawOneSeeds.length - maxRecent;
    final secondCyclePrefix = [
      for (int index = 0; index < guaranteedFreshCount; index++)
        corpus.nextSeed(drawCount: 1),
    ];

    expect(
      secondCyclePrefix,
      isNot(contains(anyOf(firstCycle.skip(firstCycle.length - maxRecent)))),
    );
  });
}
