import 'package:shared_preferences/shared_preferences.dart';

import 'pyramid_stats.dart';

class PyramidStatsStore {
  static const _gamesStartedKey = 'pyramid_stats_games_started';
  static const _gamesWonKey = 'pyramid_stats_games_won';
  static const _currentStreakKey = 'pyramid_stats_current_streak';
  static const _bestStreakKey = 'pyramid_stats_best_streak';
  static const _bestTimeKey = 'pyramid_stats_best_time';

  Future<PyramidStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PyramidStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      gamesWon: prefs.getInt(_gamesWonKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      bestTimeSeconds: prefs.getInt(_bestTimeKey),
    );
  }

  Future<void> save(PyramidStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesStartedKey, stats.gamesStarted);
    await prefs.setInt(_gamesWonKey, stats.gamesWon);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
    if (stats.bestTimeSeconds != null) {
      await prefs.setInt(_bestTimeKey, stats.bestTimeSeconds!);
    }
  }
}
