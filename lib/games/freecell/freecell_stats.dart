class FreeCellStats {
  const FreeCellStats({
    this.dealsStarted = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  final int dealsStarted;
  final int wins;
  final int currentStreak;
  final int bestStreak;

  double get winRate => dealsStarted == 0 ? 0 : wins / dealsStarted;

  FreeCellStats copyWith({int? dealsStarted, int? wins, int? currentStreak, int? bestStreak}) {
    return FreeCellStats(
      dealsStarted: dealsStarted ?? this.dealsStarted,
      wins: wins ?? this.wins,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  FreeCellStats recordDealStarted() => copyWith(dealsStarted: dealsStarted + 1);
  FreeCellStats recordAbandonedDeal() => copyWith(currentStreak: 0);
  FreeCellStats recordWin() {
    final nextStreak = currentStreak + 1;
    return copyWith(
      wins: wins + 1,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
    );
  }
}
