import 'sudoku_game_state.dart';

class SudokuStats {
  const SudokuStats({
    this.bestEasyTimeSeconds,
    this.bestMediumTimeSeconds,
    this.bestHardTimeSeconds,
  });

  final int? bestEasyTimeSeconds;
  final int? bestMediumTimeSeconds;
  final int? bestHardTimeSeconds;

  SudokuStats copyWith({
    int? bestEasyTimeSeconds,
    int? bestMediumTimeSeconds,
    int? bestHardTimeSeconds,
  }) {
    return SudokuStats(
      bestEasyTimeSeconds: bestEasyTimeSeconds ?? this.bestEasyTimeSeconds,
      bestMediumTimeSeconds:
          bestMediumTimeSeconds ?? this.bestMediumTimeSeconds,
      bestHardTimeSeconds: bestHardTimeSeconds ?? this.bestHardTimeSeconds,
    );
  }

  int? bestTimeFor(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return bestEasyTimeSeconds;
      case SudokuDifficulty.medium:
        return bestMediumTimeSeconds;
      case SudokuDifficulty.hard:
        return bestHardTimeSeconds;
    }
  }

  SudokuStats recordWin(SudokuDifficulty difficulty, int elapsedSeconds) {
    final clampedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
    final best = bestTimeFor(difficulty);
    final nextBest = best == null || clampedSeconds < best
        ? clampedSeconds
        : best;

    switch (difficulty) {
      case SudokuDifficulty.easy:
        return copyWith(bestEasyTimeSeconds: nextBest);
      case SudokuDifficulty.medium:
        return copyWith(bestMediumTimeSeconds: nextBest);
      case SudokuDifficulty.hard:
        return copyWith(bestHardTimeSeconds: nextBest);
    }
  }
}
