import 'package:classic_suite/games/sudoku/sudoku_game.dart';
import 'package:classic_suite/games/sudoku/sudoku_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('screen uses the simplified Sudoku layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_cell_0_0')), findsOneWidget);
    expect(find.byKey(const Key('sudoku_new_puzzle')), findsOneWidget);
    expect(find.byKey(const Key('sudoku_hint')), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
    expect(find.text('Starter puzzle'), findsNothing);
    expect(find.text('All notes'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Load'), findsNothing);
  });

  testWidgets('entering a duplicate shows conflict feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sudoku_digit_5')));
    await tester.tap(find.byKey(const Key('sudoku_digit_5')));
    await tester.pumpAndSettle();

    expect(
      find.text('That creates a duplicate in the row, column, or box.'),
      findsOneWidget,
    );
    expect(find.text('Board valid'), findsNothing);
    expect(find.text('Conflicts found'), findsNothing);
  });

  testWidgets('autosave restores entered progress on reopen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('sudoku_digit_4')));
    await tester.tap(find.byKey(const Key('sudoku_digit_4')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('undo restores previous board state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sudoku_digit_4')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('sudoku_undo')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsNothing,
    );
  });

  testWidgets('difficulty settings switch puzzles in the no-hints layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Difficulty'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sudoku_difficulty_hard')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Hard game started.'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_hint')), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Difficulty'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sudoku_difficulty_easy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Easy game started.'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_hint')), findsNothing);
    expect(find.textContaining('Hint:'), findsNothing);

    await tester.tap(find.byKey(const Key('sudoku_new_puzzle')));
    await tester.pumpAndSettle();

    expect(find.text('New easy game started.'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_hint')), findsNothing);
  });

  testWidgets('completed board shows solved message', (
    WidgetTester tester,
  ) async {
    final solved = SudokuGameState.fromPuzzle(SudokuGameState.puzzles.first);
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        solved.board[row][col] = solved.solution[row][col];
      }
    }
    solved.selectCell(0, 2);
    solved.setSelectedValue(4);

    await tester.pumpWidget(
      MaterialApp(home: SudokuGame(initialState: solved)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solved. Nicely done.'), findsOneWidget);
  });
}
