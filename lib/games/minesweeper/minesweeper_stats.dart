class MinesweeperStats {
  const MinesweeperStats({
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestEasySeconds,
    this.bestMediumSeconds,
    this.bestHardSeconds,
  });

  final int gamesStarted;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;
  final int? bestEasySeconds;
  final int? bestMediumSeconds;
  final int? bestHardSeconds;

  double get winRate {
    if (gamesStarted == 0) {
      return 0;
    }
    return gamesWon / gamesStarted;
  }

  MinesweeperStats copyWith({
    int? gamesStarted,
    int? gamesWon,
    int? currentStreak,
    int? bestStreak,
    int? bestEasySeconds,
    int? bestMediumSeconds,
    int? bestHardSeconds,
  }) {
    return MinesweeperStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      bestEasySeconds: bestEasySeconds ?? this.bestEasySeconds,
      bestMediumSeconds: bestMediumSeconds ?? this.bestMediumSeconds,
      bestHardSeconds: bestHardSeconds ?? this.bestHardSeconds,
    );
  }

  MinesweeperStats recordGameStarted() {
    return copyWith(gamesStarted: gamesStarted + 1);
  }

  MinesweeperStats recordLoss() {
    return copyWith(currentStreak: 0);
  }

  MinesweeperStats recordWin({required String difficultyId, required int seconds}) {
    final nextStreak = currentStreak + 1;
    return copyWith(
      gamesWon: gamesWon + 1,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      bestEasySeconds: difficultyId == 'easy'
          ? _bestOf(bestEasySeconds, seconds)
          : bestEasySeconds,
      bestMediumSeconds: difficultyId == 'medium'
          ? _bestOf(bestMediumSeconds, seconds)
          : bestMediumSeconds,
      bestHardSeconds: difficultyId == 'hard'
          ? _bestOf(bestHardSeconds, seconds)
          : bestHardSeconds,
    );
  }

  int? bestTimeFor(String difficultyId) {
    return switch (difficultyId) {
      'easy' => bestEasySeconds,
      'medium' => bestMediumSeconds,
      'hard' => bestHardSeconds,
      _ => null,
    };
  }

  static int _bestOf(int? currentBest, int seconds) {
    if (currentBest == null || seconds < currentBest) {
      return seconds;
    }
    return currentBest;
  }
}
