class SpiderStats {
  const SpiderStats({
    this.dealsStarted = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  final int dealsStarted;
  final int wins;
  final int currentStreak;
  final int bestStreak;

  double get winRate {
    if (dealsStarted == 0) {
      return 0;
    }
    return wins / dealsStarted;
  }

  SpiderStats copyWith({
    int? dealsStarted,
    int? wins,
    int? currentStreak,
    int? bestStreak,
  }) {
    return SpiderStats(
      dealsStarted: dealsStarted ?? this.dealsStarted,
      wins: wins ?? this.wins,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  SpiderStats recordDealStarted() {
    return copyWith(dealsStarted: dealsStarted + 1);
  }

  SpiderStats recordAbandonedDeal() {
    return copyWith(currentStreak: 0);
  }

  SpiderStats recordWin() {
    final nextStreak = currentStreak + 1;
    return copyWith(
      wins: wins + 1,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
    );
  }
}
