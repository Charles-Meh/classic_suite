import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_stats.dart';

class SudokuStatsStore {
  static const _easyBestTimeKey = 'sudoku_stats_best_time_easy';
  static const _mediumBestTimeKey = 'sudoku_stats_best_time_medium';
  static const _hardBestTimeKey = 'sudoku_stats_best_time_hard';

  Future<SudokuStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SudokuStats(
      bestEasyTimeSeconds: prefs.getInt(_easyBestTimeKey),
      bestMediumTimeSeconds: prefs.getInt(_mediumBestTimeKey),
      bestHardTimeSeconds: prefs.getInt(_hardBestTimeKey),
    );
  }

  Future<void> save(SudokuStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveNullableInt(prefs, _easyBestTimeKey, stats.bestEasyTimeSeconds);
    await _saveNullableInt(
      prefs,
      _mediumBestTimeKey,
      stats.bestMediumTimeSeconds,
    );
    await _saveNullableInt(prefs, _hardBestTimeKey, stats.bestHardTimeSeconds);
  }

  Future<void> _saveNullableInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setInt(key, value);
  }
}
