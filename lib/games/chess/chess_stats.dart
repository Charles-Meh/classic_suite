class ChessStats {
  const ChessStats({
    this.gamesStarted = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.bestEasySeconds,
    this.bestMediumSeconds,
    this.bestHardSeconds,
  });

  final int gamesStarted;
  final int wins;
  final int losses;
  final int draws;
  final int? bestEasySeconds;
  final int? bestMediumSeconds;
  final int? bestHardSeconds;

  double get winRate => gamesStarted == 0 ? 0 : wins / gamesStarted;

  ChessStats copyWith({
    int? gamesStarted,
    int? wins,
    int? losses,
    int? draws,
    int? bestEasySeconds,
    int? bestMediumSeconds,
    int? bestHardSeconds,
  }) {
    return ChessStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      bestEasySeconds: bestEasySeconds ?? this.bestEasySeconds,
      bestMediumSeconds: bestMediumSeconds ?? this.bestMediumSeconds,
      bestHardSeconds: bestHardSeconds ?? this.bestHardSeconds,
    );
  }

  ChessStats recordGameStarted() => copyWith(gamesStarted: gamesStarted + 1);

  ChessStats recordWin({required String difficultyId, required int seconds}) {
    return copyWith(
      wins: wins + 1,
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

  ChessStats recordLoss() => copyWith(losses: losses + 1);

  ChessStats recordDraw() => copyWith(draws: draws + 1);

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
