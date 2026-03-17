class CheckersStats {
  const CheckersStats({
    this.gamesStarted = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.bestEasySeconds,
    this.bestMediumSeconds,
    this.bestHardSeconds,
    this.bestLocalSeconds,
  });

  final int gamesStarted;
  final int wins;
  final int losses;
  final int draws;
  final int? bestEasySeconds;
  final int? bestMediumSeconds;
  final int? bestHardSeconds;
  final int? bestLocalSeconds;

  double get winRate => gamesStarted == 0 ? 0 : wins / gamesStarted;

  CheckersStats copyWith({
    int? gamesStarted,
    int? wins,
    int? losses,
    int? draws,
    int? bestEasySeconds,
    int? bestMediumSeconds,
    int? bestHardSeconds,
    int? bestLocalSeconds,
  }) {
    return CheckersStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      bestEasySeconds: bestEasySeconds ?? this.bestEasySeconds,
      bestMediumSeconds: bestMediumSeconds ?? this.bestMediumSeconds,
      bestHardSeconds: bestHardSeconds ?? this.bestHardSeconds,
      bestLocalSeconds: bestLocalSeconds ?? this.bestLocalSeconds,
    );
  }

  CheckersStats recordGameStarted() => copyWith(gamesStarted: gamesStarted + 1);

  CheckersStats recordWin({required String bucket, required int seconds}) {
    return copyWith(
      wins: wins + 1,
      bestEasySeconds: bucket == 'easy'
          ? _bestOf(bestEasySeconds, seconds)
          : bestEasySeconds,
      bestMediumSeconds: bucket == 'medium'
          ? _bestOf(bestMediumSeconds, seconds)
          : bestMediumSeconds,
      bestHardSeconds: bucket == 'hard'
          ? _bestOf(bestHardSeconds, seconds)
          : bestHardSeconds,
      bestLocalSeconds: bucket == 'local'
          ? _bestOf(bestLocalSeconds, seconds)
          : bestLocalSeconds,
    );
  }

  CheckersStats recordLoss() => copyWith(losses: losses + 1);

  CheckersStats recordDraw() => copyWith(draws: draws + 1);

  static int _bestOf(int? currentBest, int seconds) {
    if (currentBest == null || seconds < currentBest) {
      return seconds;
    }
    return currentBest;
  }
}
