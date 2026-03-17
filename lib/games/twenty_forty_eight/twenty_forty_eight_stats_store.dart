import 'package:shared_preferences/shared_preferences.dart';

import 'twenty_forty_eight_stats.dart';

class TwentyFortyEightStatsStore {
  static const _gamesStartedKey = '2048_stats_games_started';
  static const _gamesWonKey = '2048_stats_games_won';
  static const _bestScoreKey = '2048_stats_best_score';
  static const _bestTileKey = '2048_stats_best_tile';
  static const _totalScoreKey = '2048_stats_total_score';
  static const _longestRunMovesKey = '2048_stats_longest_run_moves';

  Future<TwentyFortyEightStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TwentyFortyEightStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      gamesWon: prefs.getInt(_gamesWonKey) ?? 0,
      bestScore: prefs.getInt(_bestScoreKey) ?? 0,
      bestTile: prefs.getInt(_bestTileKey) ?? 0,
      totalScore: prefs.getInt(_totalScoreKey) ?? 0,
      longestRunMoves: prefs.getInt(_longestRunMovesKey) ?? 0,
    );
  }

  Future<void> save(TwentyFortyEightStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesStartedKey, stats.gamesStarted);
    await prefs.setInt(_gamesWonKey, stats.gamesWon);
    await prefs.setInt(_bestScoreKey, stats.bestScore);
    await prefs.setInt(_bestTileKey, stats.bestTile);
    await prefs.setInt(_totalScoreKey, stats.totalScore);
    await prefs.setInt(_longestRunMovesKey, stats.longestRunMoves);
  }
}
