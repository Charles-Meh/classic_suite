class HeartsStats {
  const HeartsStats({
    this.matchesStarted = 0,
    this.matchesWon = 0,
    this.handsPlayed = 0,
    this.handsWon = 0,
    this.shootTheMoonCount = 0,
    this.bestMatchScore,
  });

  final int matchesStarted;
  final int matchesWon;
  final int handsPlayed;
  final int handsWon;
  final int shootTheMoonCount;
  final int? bestMatchScore;

  double get matchWinRate => matchesStarted == 0 ? 0 : matchesWon / matchesStarted;

  HeartsStats copyWith({
    int? matchesStarted,
    int? matchesWon,
    int? handsPlayed,
    int? handsWon,
    int? shootTheMoonCount,
    int? bestMatchScore,
  }) {
    return HeartsStats(
      matchesStarted: matchesStarted ?? this.matchesStarted,
      matchesWon: matchesWon ?? this.matchesWon,
      handsPlayed: handsPlayed ?? this.handsPlayed,
      handsWon: handsWon ?? this.handsWon,
      shootTheMoonCount: shootTheMoonCount ?? this.shootTheMoonCount,
      bestMatchScore: bestMatchScore ?? this.bestMatchScore,
    );
  }

  HeartsStats recordMatchStarted() => copyWith(matchesStarted: matchesStarted + 1);

  HeartsStats recordHand({required bool humanWonHand, required bool humanShotMoon}) {
    return copyWith(
      handsPlayed: handsPlayed + 1,
      handsWon: handsWon + (humanWonHand ? 1 : 0),
      shootTheMoonCount: shootTheMoonCount + (humanShotMoon ? 1 : 0),
    );
  }

  HeartsStats recordMatchFinished({required bool humanWonMatch, required int finalScore}) {
    return copyWith(
      matchesWon: matchesWon + (humanWonMatch ? 1 : 0),
      bestMatchScore: bestMatchScore == null || finalScore < bestMatchScore!
          ? finalScore
          : bestMatchScore,
    );
  }
}
