import 'package:shared_preferences/shared_preferences.dart';

import 'klondike_stats.dart';

class KlondikeStatsStore {
  static const _dealsStartedKey = 'klondike_stats_deals_started';
  static const _winsKey = 'klondike_stats_wins';
  static const _currentStreakKey = 'klondike_stats_current_streak';
  static const _bestStreakKey = 'klondike_stats_best_streak';

  Future<KlondikeStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KlondikeStats(
      dealsStarted: prefs.getInt(_dealsStartedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
    );
  }

  Future<void> save(KlondikeStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dealsStartedKey, stats.dealsStarted);
    await prefs.setInt(_winsKey, stats.wins);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
  }
}
