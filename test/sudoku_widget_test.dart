import 'package:classic_suite/games/sudoku/sudoku_game.dart';
import 'package:classic_suite/games/sudoku/sudoku_game_state.dart';
import 'package:classic_suite/games/sudoku/sudoku_stats.dart';
import 'package:classic_suite/games/sudoku/sudoku_stats_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildSudokuHarness({SudokuGameState? state}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SudokuGame(initialState: state),
  );
}

Future<void> _settleSudoku(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpSudoku(
  WidgetTester tester, {
  SudokuGameState? state,
  Size size = const Size(1000, 1200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildSudokuHarness(state: state));
  await _settleSudoku(tester);
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
    final settingsButton = tester.widgetList<IconButton>(find.byType(IconButton)).firstWhere(
      (button) => button.tooltip == 'Settings',
    );

    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_cell_0_0')), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
    expect(find.byKey(const Key('sudoku_difficulty_button')), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
    expect(settingsButton.onPressed, isNull);
    expect(find.byKey(const Key('sudoku_status_message')), findsNothing);
    expect(find.text('Filled'), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('All notes'), findsNothing);
    expect(find.text('Notes'), findsOneWidget);
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

    expect(find.text('Grid Complete!'), findsOneWidget);
  });

  testWidgets('notes mode restores pencil marks on the board', (
    WidgetTester tester,
  ) async {
    await _pumpSudoku(tester);

    await tester.tap(find.byKey(const Key('sudoku_cell_0_2')));
    await _settleSudoku(tester);

    await tester.tap(find.byKey(const Key('sudoku_notes_mode')));
    await _settleSudoku(tester);

    await tester.tap(find.byKey(const Key('sudoku_digit_1')));
    await tester.tap(find.byKey(const Key('sudoku_digit_2')));
    await _settleSudoku(tester);

    final cell = find.byKey(const Key('sudoku_cell_0_2'));
    expect(find.descendant(of: cell, matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('difficulty selector starts a puzzle at the chosen level', (
    WidgetTester tester,
  ) async {
    await _pumpSudoku(tester);

    await tester.tap(find.byKey(const Key('sudoku_difficulty_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sudoku_difficulty_hard')).last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sudoku_difficulty_button')),
        matching: find.text('Hard'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('statistics show current timer and best times per difficulty', (
    WidgetTester tester,
  ) async {
    await SudokuStatsStore().save(
      const SudokuStats(
        bestEasyTimeSeconds: 65,
        bestMediumTimeSeconds: 125,
        bestHardTimeSeconds: 245,
      ),
    );

    final state = SudokuGameState()..elapsedSeconds = 83;
    await _pumpSudoku(tester, state: state);

    await tester.tap(find.byTooltip('Statistics'));
    await _settleSudoku(tester);

    expect(find.text('Current time'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('01:23'),
      ),
      findsOneWidget,
    );
    expect(find.text('Best easy'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Best medium'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('Best hard'), findsOneWidget);
    expect(find.text('04:05'), findsOneWidget);
  });
}
