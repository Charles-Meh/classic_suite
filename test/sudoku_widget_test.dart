import 'package:classic_suite/games/sudoku/sudoku_game.dart';
import 'package:classic_suite/games/sudoku/sudoku_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildSudokuHarness({SudokuGameState? state}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SudokuGame(initialState: state),
  );
}

Future<void> _pumpSudoku(
  WidgetTester tester, {
  SudokuGameState? state,
  Size size = const Size(1000, 1200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildSudokuHarness(state: state));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('screen uses the simplified Sudoku layout', (
    WidgetTester tester,
  ) async {
    await _pumpSudoku(tester);

    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_cell_0_0')), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
    expect(find.text('Starter puzzle'), findsNothing);
    expect(find.text('All notes'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Load'), findsNothing);
  });

  testWidgets('compact height still renders board and controls', (
    WidgetTester tester,
  ) async {
    await _pumpSudoku(tester, size: const Size(390, 700));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sudoku_cell_0_0')), findsOneWidget);
    expect(find.byKey(const Key('sudoku_digit_1')), findsOneWidget);
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

    await _pumpSudoku(tester, state: solved);

    expect(find.text('Solved. Nicely done.'), findsOneWidget);
  });
}
