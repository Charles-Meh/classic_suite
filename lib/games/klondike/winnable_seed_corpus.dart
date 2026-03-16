import 'dart:math';

import 'winnable_seed_data.dart';

class WinnableSeedCorpus {
  WinnableSeedCorpus({Random? random}) : _random = random ?? Random();

  static const int _recentHistoryLimit = 12;

  final Random _random;
  final Map<int, List<int>> _bagsByDrawCount = <int, List<int>>{};
  final Map<int, List<int>> _recentSeedsByDrawCount = <int, List<int>>{};

  int nextSeed({required int drawCount}) {
    final seeds = _seedsForDrawCount(drawCount);
    if (seeds.isEmpty) {
      throw StateError(
        'No winnable seeds configured for draw count $drawCount.',
      );
    }

    final bag = _bagsByDrawCount.putIfAbsent(drawCount, () => <int>[]);
    if (bag.isEmpty) {
      _refillBag(drawCount: drawCount, allSeeds: seeds, bag: bag);
    }

    final seed = bag.removeLast();
    final recent = _recentSeedsByDrawCount.putIfAbsent(
      drawCount,
      () => <int>[],
    );
    recent.add(seed);
    final maxRecent = seeds.length <= 1
        ? 1
        : min(_recentHistoryLimit, seeds.length - 1);
    if (recent.length > maxRecent) {
      recent.removeRange(0, recent.length - maxRecent);
    }
    return seed;
  }

  void _refillBag({
    required int drawCount,
    required List<int> allSeeds,
    required List<int> bag,
  }) {
    bag
      ..clear()
      ..addAll(allSeeds);
    bag.shuffle(_random);

    final recent = _recentSeedsByDrawCount[drawCount];
    if (recent == null || recent.isEmpty || recent.length >= allSeeds.length) {
      return;
    }

    final deferred = <int>[];
    bag.removeWhere((seed) {
      if (recent.contains(seed)) {
        deferred.add(seed);
        return true;
      }
      return false;
    });
    bag.insertAll(0, deferred);
  }

  List<int> _seedsForDrawCount(int drawCount) {
    return switch (drawCount) {
      1 => kWinnableDrawOneSeeds,
      3 => kWinnableDrawThreeSeeds,
      _ => throw ArgumentError.value(
        drawCount,
        'drawCount',
        'Only 1-card and 3-card draw are supported.',
      ),
    };
  }
}
