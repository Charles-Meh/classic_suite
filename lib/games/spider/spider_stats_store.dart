import 'package:shared_preferences/shared_preferences.dart';

import 'spider_stats.dart';

class SpiderStatsStore {
  static const _dealsStartedKey = 'spider_stats_deals_started';
  static const _winsKey = 'spider_stats_wins';
  static const _currentStreakKey = 'spider_stats_current_streak';
  static const _bestStreakKey = 'spider_stats_best_streak';

  Future<SpiderStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SpiderStats(
      dealsStarted: prefs.getInt(_dealsStartedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
    );
  }

  Future<void> save(SpiderStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dealsStartedKey, stats.dealsStarted);
    await prefs.setInt(_winsKey, stats.wins);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
  }
}
