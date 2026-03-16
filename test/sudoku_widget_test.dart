import 'package:classic_suite/games/sudoku/sudoku_game.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
