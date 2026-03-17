import 'package:shared_preferences/shared_preferences.dart';

import 'chess_stats.dart';

class ChessStatsStore {
  static const _gamesStartedKey = 'chess_stats_games_started';
  static const _winsKey = 'chess_stats_wins';
  static const _lossesKey = 'chess_stats_losses';
  static const _drawsKey = 'chess_stats_draws';
  static const _bestEasyKey = 'chess_stats_best_easy';
  static const _bestMediumKey = 'chess_stats_best_medium';
  static const _bestHardKey = 'chess_stats_best_hard';

  Future<ChessStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ChessStats(
      gamesStarted: prefs.getInt(_gamesStartedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      losses: prefs.getInt(_lossesKey) ?? 0,
      draws: prefs.getInt(_drawsKey) ?? 0,
      bestEasySeconds: prefs.getInt(_bestEasyKey),
      bestMediumSeconds: prefs.getInt(_bestMediumKey),
      bestHardSeconds: prefs.getInt(_bestHardKey),
    );
  }

  Future<void> save(ChessStats stats) async {
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
  }
}
