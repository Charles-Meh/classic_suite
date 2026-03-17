import 'package:shared_preferences/shared_preferences.dart';

import 'tripeaks_stats.dart';

class TriPeaksStatsStore {
  static const _gamesStartedKey = 'tripeaks_stats_games_started';
  static const _gamesWonKey = 'tripeaks_stats_games_won';
  static const _bestScoreKey = 'tripeaks_stats_best_score';
  static const _currentStreakKey = 'tripeaks_stats_current_streak';
  static const _bestStreakKey = 'tripeaks_stats_best_streak';
  static const _longestRunKey = 'tripeaks_stats_longest_run';

  Future<TriPeaksStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TriPeaksStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      gamesWon: prefs.getInt(_gamesWonKey) ?? 0,
      bestScore: prefs.getInt(_bestScoreKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      longestRunEver: prefs.getInt(_longestRunKey) ?? 0,
    );
  }

  Future<void> save(TriPeaksStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesStartedKey, stats.gamesStarted);
    await prefs.setInt(_gamesWonKey, stats.gamesWon);
    await prefs.setInt(_bestScoreKey, stats.bestScore);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
    await prefs.setInt(_longestRunKey, stats.longestRunEver);
  }
}
