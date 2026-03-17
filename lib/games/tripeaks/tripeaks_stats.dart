class TriPeaksStats {
  const TriPeaksStats({
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.bestScore = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.longestRunEver = 0,
  });

  final int gamesStarted;
  final int gamesWon;
  final int bestScore;
  final int currentStreak;
  final int bestStreak;
  final int longestRunEver;

  double get winRate => gamesStarted == 0 ? 0 : gamesWon / gamesStarted;

  TriPeaksStats recordGameStarted() {
    return copyWith(gamesStarted: gamesStarted + 1);
  }

  TriPeaksStats recordWin({required int score, required int longestRun}) {
    final nextCurrentStreak = currentStreak + 1;
    return copyWith(
      gamesWon: gamesWon + 1,
      currentStreak: nextCurrentStreak,
      bestStreak: nextCurrentStreak > bestStreak ? nextCurrentStreak : bestStreak,
      bestScore: score > bestScore ? score : bestScore,
      longestRunEver: longestRun > longestRunEver ? longestRun : longestRunEver,
    );
  }

  TriPeaksStats recordLoss({required int longestRun}) {
    return copyWith(
      currentStreak: 0,
      longestRunEver: longestRun > longestRunEver ? longestRun : longestRunEver,
    );
  }

  TriPeaksStats copyWith({
    int? gamesStarted,
    int? gamesWon,
    int? bestScore,
    int? currentStreak,
    int? bestStreak,
    int? longestRunEver,
  }) {
    return TriPeaksStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      bestScore: bestScore ?? this.bestScore,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      longestRunEver: longestRunEver ?? this.longestRunEver,
    );
  }
}
