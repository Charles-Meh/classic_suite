import 'package:shared_preferences/shared_preferences.dart';

import 'checkers_stats.dart';

class CheckersStatsStore {
  static const _gamesStartedKey = 'checkers_stats_games_started';
  static const _winsKey = 'checkers_stats_wins';
  static const _lossesKey = 'checkers_stats_losses';
  static const _drawsKey = 'checkers_stats_draws';
  static const _bestEasyKey = 'checkers_stats_best_easy';
  static const _bestMediumKey = 'checkers_stats_best_medium';
  static const _bestHardKey = 'checkers_stats_best_hard';
  static const _bestLocalKey = 'checkers_stats_best_local';

  Future<CheckersStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CheckersStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      losses: prefs.getInt(_lossesKey) ?? 0,
      draws: prefs.getInt(_drawsKey) ?? 0,
      bestEasySeconds: prefs.getInt(_bestEasyKey),
      bestMediumSeconds: prefs.getInt(_bestMediumKey),
      bestHardSeconds: prefs.getInt(_bestHardKey),
      bestLocalSeconds: prefs.getInt(_bestLocalKey),
    );
  }

  Future<void> save(CheckersStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesStartedKey, stats.gamesStarted);
    await prefs.setInt(_winsKey, stats.wins);
    await prefs.setInt(_lossesKey, stats.losses);
    await prefs.setInt(_drawsKey, stats.draws);
    if (stats.bestEasySeconds != null) {
      await prefs.setInt(_bestEasyKey, stats.bestEasySeconds!);
    }
    if (stats.bestMediumSeconds != null) {
      await prefs.setInt(_bestMediumKey, stats.bestMediumSeconds!);
    }
    if (stats.bestHardSeconds != null) {
      await prefs.setInt(_bestHardKey, stats.bestHardSeconds!);
    }
    if (stats.bestLocalSeconds != null) {
      await prefs.setInt(_bestLocalKey, stats.bestLocalSeconds!);
    }
  }
}
