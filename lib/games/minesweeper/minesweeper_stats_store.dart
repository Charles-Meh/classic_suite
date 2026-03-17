import 'package:shared_preferences/shared_preferences.dart';

import 'minesweeper_stats.dart';

class MinesweeperStatsStore {
  static const _gamesStartedKey = 'minesweeper_stats_games_started';
  static const _gamesWonKey = 'minesweeper_stats_games_won';
  static const _currentStreakKey = 'minesweeper_stats_current_streak';
  static const _bestStreakKey = 'minesweeper_stats_best_streak';
  static const _bestEasyKey = 'minesweeper_stats_best_easy';
  static const _bestMediumKey = 'minesweeper_stats_best_medium';
  static const _bestHardKey = 'minesweeper_stats_best_hard';

  Future<MinesweeperStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MinesweeperStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      gamesWon: prefs.getInt(_gamesWonKey) ?? 0,
      currentStreak: prefs.getInt(_currentStreakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      bestEasySeconds: prefs.getInt(_bestEasyKey),
      bestMediumSeconds: prefs.getInt(_bestMediumKey),
      bestHardSeconds: prefs.getInt(_bestHardKey),
    );
  }

  Future<void> save(MinesweeperStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesStartedKey, stats.gamesStarted);
    await prefs.setInt(_gamesWonKey, stats.gamesWon);
    await prefs.setInt(_currentStreakKey, stats.currentStreak);
    await prefs.setInt(_bestStreakKey, stats.bestStreak);
    if (stats.bestEasySeconds != null) {
      await prefs.setInt(_bestEasyKey, stats.bestEasySeconds!);
    }
    if (stats.bestMediumSeconds != null) {
      await prefs.setInt(_bestMediumKey, stats.bestMediumSeconds!);
    }
    if (stats.bestHardSeconds != null) {
      await prefs.setInt(_bestHardKey, stats.bestHardSeconds!);
    }
  }
}
