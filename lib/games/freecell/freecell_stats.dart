class FreeCellStats {
  const FreeCellStats({
    this.dealsStarted = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestTimeSeconds,
  });

  final int dealsStarted;
  final int wins;
  final int currentStreak;
  final int bestStreak;
  final int? bestTimeSeconds;

  double get winRate => dealsStarted == 0 ? 0 : wins / dealsStarted;

  FreeCellStats copyWith({
    int? dealsStarted,
    int? wins,
    int? currentStreak,
    int? bestStreak,
    int? bestTimeSeconds,
  }) {
    return FreeCellStats(
      dealsStarted: dealsStarted ?? this.dealsStarted,
      wins: wins ?? this.wins,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
    );
  }

  FreeCellStats recordDealStarted() => copyWith(dealsStarted: dealsStarted + 1);

  FreeCellStats recordAbandonedDeal() => copyWith(currentStreak: 0);

  FreeCellStats recordWin(int seconds) {
    final nextStreak = currentStreak + 1;
    final nextBestTime = bestTimeSeconds == null || seconds < bestTimeSeconds!
        ? seconds
        : bestTimeSeconds;
    return copyWith(
      wins: wins + 1,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      bestTimeSeconds: nextBestTime,
    );
  }
}
