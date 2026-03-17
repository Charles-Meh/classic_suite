import 'package:shared_preferences/shared_preferences.dart';

import 'hearts_stats.dart';

class HeartsStatsStore {
  static const _matchesStartedKey = 'hearts_stats_matches_started';
  static const _matchesWonKey = 'hearts_stats_matches_won';
  static const _handsPlayedKey = 'hearts_stats_hands_played';
  static const _handsWonKey = 'hearts_stats_hands_won';
  static const _shootMoonKey = 'hearts_stats_shoot_moon_count';
  static const _bestMatchScoreKey = 'hearts_stats_best_match_score';

  Future<HeartsStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HeartsStats(
      matchesStarted: prefs.getInt(_matchesStartedKey) ?? 0,
      matchesWon: prefs.getInt(_matchesWonKey) ?? 0,
      handsPlayed: prefs.getInt(_handsPlayedKey) ?? 0,
      handsWon: prefs.getInt(_handsWonKey) ?? 0,
      shootTheMoonCount: prefs.getInt(_shootMoonKey) ?? 0,
      bestMatchScore: prefs.getInt(_bestMatchScoreKey),
    );
  }

  Future<void> save(HeartsStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_matchesStartedKey, stats.matchesStarted);
    await prefs.setInt(_matchesWonKey, stats.matchesWon);
    await prefs.setInt(_handsPlayedKey, stats.handsPlayed);
    await prefs.setInt(_handsWonKey, stats.handsWon);
    await prefs.setInt(_shootMoonKey, stats.shootTheMoonCount);
    if (stats.bestMatchScore != null) {
      await prefs.setInt(_bestMatchScoreKey, stats.bestMatchScore!);
    }
  }
}
