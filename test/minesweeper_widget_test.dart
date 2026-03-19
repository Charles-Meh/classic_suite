import 'package:classic_suite/games/minesweeper/minesweeper_game.dart';
import 'package:classic_suite/games/minesweeper/minesweeper_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({MinesweeperGameState? state}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MinesweeperGame(initialState: state),
  );
}

Future<void> _pumpMinesweeper(
  WidgetTester tester, {
  MinesweeperGameState? state,
  Size size = const Size(1000, 1200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildHarness(state: state));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher search finds Minesweeper and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Classic Suite'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mine');
    await tester.pumpAndSettle();

    expect(find.text('Minesweeper'), findsOneWidget);

    await tester.tap(find.text('Minesweeper'));
    await tester.pumpAndSettle();

    expect(find.byType(MinesweeperGame), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_board_label')), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_flag_mode')), findsOneWidget);
    expect(find.text('New Board'), findsOneWidget);
  });

  testWidgets('board layout adapts on compact screens without overflow', (
    WidgetTester tester,
  ) async {
    await _pumpMinesweeper(tester, size: const Size(390, 700));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('minesweeper_cell_0_0')), findsOneWidget);
  });

  testWidgets('launcher navigation renders Minesweeper on short screens', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ClassicSuiteApp());
    await tester.enterText(find.byType(TextField), 'mine');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minesweeper'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MinesweeperGame), findsOneWidget);
    expect(find.byKey(const Key('minesweeper_cell_0_0')), findsOneWidget);
  });

  testWidgets('saved state is restored on launch', (WidgetTester tester) async {
    final saved = MinesweeperGameState.newGame(
      MinesweeperConfig.easy(),
    ).toggleFlag(2, 2).withElapsedSeconds(33);
    SharedPreferences.setMockInitialValues({
      MinesweeperGameState.storageKey: saved.encode(),
    });

    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MinesweeperGame(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.text('00:33'), findsOneWidget);
  });
}
