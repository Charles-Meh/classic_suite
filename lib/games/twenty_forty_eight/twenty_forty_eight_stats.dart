class TwentyFortyEightStats {
  const TwentyFortyEightStats({
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.bestScore = 0,
    this.bestTile = 0,
    this.totalScore = 0,
    this.longestRunMoves = 0,
  });

  final int gamesStarted;
  final int gamesWon;
  final int bestScore;
  final int bestTile;
  final int totalScore;
  final int longestRunMoves;

  double get winRate => gamesStarted == 0 ? 0 : gamesWon / gamesStarted;

  TwentyFortyEightStats copyWith({
    int? gamesStarted,
    int? gamesWon,
    int? bestScore,
    int? bestTile,
    int? totalScore,
    int? longestRunMoves,
  }) {
    return TwentyFortyEightStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      bestScore: bestScore ?? this.bestScore,
      bestTile: bestTile ?? this.bestTile,
      totalScore: totalScore ?? this.totalScore,
      longestRunMoves: longestRunMoves ?? this.longestRunMoves,
    );
  }

  TwentyFortyEightStats recordGameStarted() {
    return copyWith(gamesStarted: gamesStarted + 1);
  }

  TwentyFortyEightStats recordFinishedGame({
    required bool won,
    required int score,
    required int highestTile,
    required int moveCount,
  }) {
    return copyWith(
      gamesWon: won ? gamesWon + 1 : gamesWon,
      bestScore: score > bestScore ? score : bestScore,
      bestTile: highestTile > bestTile ? highestTile : bestTile,
      totalScore: totalScore + score,
      longestRunMoves: moveCount > longestRunMoves
          ? moveCount
          : longestRunMoves,
    );
  }
}
