import 'package:shared_preferences/shared_preferences.dart';

import 'freecell_stats.dart';

class FreeCellStatsStore {
  static const _dealsStartedKey = 'freecell_stats_deals_started';
  static const _winsKey = 'freecell_stats_wins';
  static const _currentStreakKey = 'freecell_stats_current_streak';
  static const _bestStreakKey = 'freecell_stats_best_streak';
  static const _bestTimeSecondsKey = 'freecell_stats_best_time_seconds';

  Future<FreeCellStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return FreeCellStats(
      dealsStarted: prefs.getInt(_dealsStartedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      bestTimeSeconds: prefs.getInt(_bestTimeSecondsKey),
    );
  }

  Future<void> save(FreeCellStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dealsStartedKey, stats.dealsStarted);
    await prefs.setInt(_winsKey, stats.wins);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
    if (stats.bestTimeSeconds == null) {
      await prefs.remove(_bestTimeSecondsKey);
    } else {
      await prefs.setInt(_bestTimeSecondsKey, stats.bestTimeSeconds!);
    }
  }
}
