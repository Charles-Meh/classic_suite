import 'package:classic_suite/games/minesweeper/minesweeper_game.dart';
import 'package:classic_suite/games/minesweeper/minesweeper_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({MinesweeperGameState? state}) {
  return MaterialApp(home: MinesweeperGame(initialState: state));
}

MinesweeperGameState _buildNearlySolvedEasyState() {
  const config = MinesweeperConfig(
    id: 'easy',
    label: 'Easy',
    rows: 5,
    columns: 5,
    mines: 1,
    isPreset: true,
  );
  final board = List<List<MinesweeperCell>>.generate(
    config.rows,
    (_) => List<MinesweeperCell>.filled(
      config.columns,
      const MinesweeperCell(revealed: true),
    ),
  );

  board[0][0] = const MinesweeperCell(hasMine: true, adjacentMines: 0);
  board[0][1] = const MinesweeperCell(revealed: false, adjacentMines: 1);
  board[1][0] = const MinesweeperCell(revealed: true, adjacentMines: 1);
  board[1][1] = const MinesweeperCell(revealed: true, adjacentMines: 1);

  return MinesweeperGameState.debug(
    config: config,
    board: board,
    status: MinesweeperGameStatus.running,
    elapsedSeconds: 12,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Minesweeper and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Minesweeper'), findsOneWidget);

    await tester.tap(find.text('Minesweeper'));
    await tester.pumpAndSettle();

    expect(find.byType(MinesweeperGame), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_board_label')), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_flag_mode')), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_restart')), findsOneWidget);
  });

  testWidgets('flag mode places a flag on tap', (WidgetTester tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minesweeper_flag_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('minesweeper_cell_0_0')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag), findsAtLeastNWidgets(2));
    expect(find.text('Flag mode on'), findsOneWidget);
  });

  testWidgets('long press toggles a flag without flag mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('minesweeper_cell_0_1')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag), findsOneWidget);
  });

  testWidgets('difficulty chips start a different board size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Easy • 9×9 • 10 mines'), findsOneWidget);

    await tester.tap(find.byKey(const Key('minesweeper_difficulty_medium')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Medium • 16×16 • 40 mines'), findsOneWidget);
  });

  testWidgets('saved state is restored on launch', (WidgetTester tester) async {
    final saved = MinesweeperGameState.newGame(MinesweeperConfig.easy())
        .toggleFlag(2, 2)
        .withElapsedSeconds(33);
    SharedPreferences.setMockInitialValues({
      MinesweeperGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: MinesweeperGame()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.text('00:33'), findsOneWidget);
  });

  testWidgets('winning a board updates statistics dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(state: _buildNearlySolvedEasyState()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minesweeper_cell_0_1')));
    await tester.pumpAndSettle();

    expect(find.text('Board cleared. Nice work.'), findsOneWidget);

    await tester.tap(find.byTooltip('Game menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Minesweeper statistics'), findsOneWidget);
    expect(find.text('Wins'), findsOneWidget);
    expect(find.text('Best Easy'), findsOneWidget);
    expect(find.text('00:12'), findsWidgets);
  });

  testWidgets('restart button quickly resets the board', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minesweeper_cell_0_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clear run going.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('minesweeper_restart')));
    await tester.pumpAndSettle();

    expect(
      find.text('Clear every safe tile. First tap is always safe.'),
      findsOneWidget,
    );
  });
}
