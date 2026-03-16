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

  test('encoding and decoding preserve board state and notes', () {
    final state = SudokuGameState();
    state.selectCell(0, 2);
    state.setSelectedValue(4);
    state.selectCell(0, 3);
    state.toggleNoteForSelection(6);
    state.toggleNoteForSelection(8);

    final restored = SudokuGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.board[0][2], 4);
    expect(restored.notesForCell(0, 3), containsAll(<int>{6, 8}));
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

  test('undo and redo restore previous board state', () {
    final state = SudokuGameState();
    state.selectCell(0, 2);

    expect(state.setSelectedValue(4), isTrue);
    expect(state.canUndo, isTrue);

    expect(state.undo(), isTrue);
    expect(state.board[0][2], 0);
    expect(state.canRedo, isTrue);

    expect(state.redo(), isTrue);
    expect(state.board[0][2], 4);
  });

  test('pencil marks can be toggled and auto-filled', () {
    final state = SudokuGameState();
    state.selectCell(0, 2);

    expect(state.toggleNoteForSelection(1), isTrue);
    expect(state.toggleNoteForSelection(2), isTrue);
    expect(state.notesForCell(0, 2), containsAll(<int>{1, 2}));

    state.selectCell(0, 3);
    expect(state.fillPencilMarksForSelection(), isTrue);
    expect(state.notesForCell(0, 3), isNotEmpty);

    expect(state.autoFillAllPencilMarks(), isTrue);
    expect(state.notesForCell(8, 6), isNotEmpty);
  });

  test('hint finds a valid single and applies it', () {
    final state = SudokuGameState();

    final hint = state.nextHint();

    expect(hint, isNotNull);
    expect(hint!.value, 5);
    expect(state.applyHint(), isTrue);
    expect(state.board[4][4], 5);
    expect(state.message, contains('single'));
  });

  test('difficulty selection filters puzzle pool', () {
    final hard = SudokuGameState(difficulty: SudokuDifficulty.hard);

    expect(hard.difficulty, SudokuDifficulty.hard);
    expect(hard.puzzleId, 'crosswind');
  });
}
