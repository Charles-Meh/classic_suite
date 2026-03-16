import 'package:classic_suite/games/sudoku/sudoku_game.dart';
import 'package:classic_suite/games/sudoku/sudoku_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Sudoku and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Sudoku'), findsOneWidget);

    await tester.tap(find.text('Sudoku'));
    await tester.pumpAndSettle();

    expect(find.byType(SudokuGame), findsOneWidget);
    expect(find.text('Starter puzzle'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_cell_0_0')), findsOneWidget);
    expect(find.byKey(const Key('sudoku_new_puzzle')), findsOneWidget);
  });

  testWidgets('entering a duplicate shows conflict feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sudoku_digit_5')));
    await tester.pumpAndSettle();

    expect(
      find.text('That creates a duplicate in the row, column, or box.'),
      findsOneWidget,
    );
    expect(find.text('Conflicts found'), findsOneWidget);
  });

  testWidgets('save and load restores entered progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SudokuGame()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sudoku_digit_4')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('sudoku_save_game')));
    await tester.tap(find.byKey(const Key('sudoku_save_game')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('sudoku_new_puzzle')));
    await tester.tap(find.byKey(const Key('sudoku_new_puzzle')));
    await tester.pumpAndSettle();
    expect(find.text('Cascade puzzle'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('sudoku_load_game')));
    await tester.tap(find.byKey(const Key('sudoku_load_game')));
    await tester.pumpAndSettle();

    expect(find.text('Starter puzzle'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_cell_0_2')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
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
