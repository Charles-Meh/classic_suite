import 'package:classic_suite/games/sudoku/sudoku_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('givens are locked and editable cells accept values', () {
    final state = SudokuGameState();

    state.selectCell(0, 0);
    expect(state.setSelectedValue(1), isFalse);
    expect(state.message, 'Starter clues cannot be changed.');

    state.selectCell(0, 2);
    expect(state.setSelectedValue(4), isTrue);
    expect(state.board[0][2], 4);
  });

  test('encoding and decoding preserve board state', () {
    final state = SudokuGameState();
    state.selectCell(0, 2);
    state.setSelectedValue(4);

    final restored = SudokuGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.board[0][2], 4);
    expect(restored.puzzleId, state.puzzleId);
  });

  test('solved board marks completion', () {
    final state = SudokuGameState.fromPuzzle(SudokuGameState.puzzles.first);

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        state.board[row][col] = state.solution[row][col];
      }
    }

    state.selectCell(0, 2);
    final result = state.setSelectedValue(state.solution[0][2]);

    expect(result, isTrue);
    expect(state.completed, isTrue);
    expect(state.message, 'Solved. Nicely done.');
  });
}
