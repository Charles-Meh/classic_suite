class PyramidStats {
  const PyramidStats({
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestTimeSeconds,
  });

  final int gamesStarted;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;
  final int? bestTimeSeconds;

  double get winRate => gamesStarted == 0 ? 0 : gamesWon / gamesStarted;

  PyramidStats copyWith({
    int? gamesStarted,
    int? gamesWon,
    int? currentStreak,
    int? bestStreak,
    int? bestTimeSeconds,
  }) {
    return PyramidStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
    );
  }

  PyramidStats recordGameStarted() {
    return copyWith(gamesStarted: gamesStarted + 1);
  }

  PyramidStats recordLoss() {
    return copyWith(currentStreak: 0);
  }

  PyramidStats recordWin(int seconds) {
    final nextStreak = currentStreak + 1;
    final nextBest = bestTimeSeconds == null || seconds < bestTimeSeconds!
        ? seconds
        : bestTimeSeconds;
    return copyWith(
      gamesWon: gamesWon + 1,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      bestTimeSeconds: nextBest,
    );
  }
}
