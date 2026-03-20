import 'package:classic_suite/games/twenty_forty_eight/twenty_forty_eight_game.dart';
import 'package:classic_suite/games/twenty_forty_eight/twenty_forty_eight_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({TwentyFortyEightGameState? state}) {
  return MaterialApp(home: TwentyFortyEightGame(initialState: state));
}

List<TwentyFortyEightTile> _boardFromValues(List<List<int>> grid) {
  var nextId = 1;
  final tiles = <TwentyFortyEightTile>[];
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      final value = grid[row][col];
      if (value != 0) {
        tiles.add(
          TwentyFortyEightTile(
            id: nextId++,
            value: value,
            row: row,
            column: col,
          ),
        );
      }
    }
  }
  return tiles;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state is restored on launch', (tester) async {
    final saved = TwentyFortyEightGameState.debug(
      tiles: _boardFromValues([
        [2, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      score: 12,
      moveCount: 3,
      elapsedSeconds: 22,
    );
    SharedPreferences.setMockInitialValues({
      TwentyFortyEightGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: TwentyFortyEightGame()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Score 12'), findsOneWidget);
    expect(find.text('00:22'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('undo button restores the previous position', (tester) async {
    final state = TwentyFortyEightGameState.debug(
      tiles: _boardFromValues([
        [4, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      score: 4,
      moveCount: 1,
      undoStack: [
        const TwentyFortyEightSnapshot(
          tiles: [
            TwentyFortyEightTile(id: 1, value: 2, row: 0, column: 0),
            TwentyFortyEightTile(id: 2, value: 2, row: 0, column: 1),
          ],
          score: 0,
          moveCount: 0,
          hasWon: false,
          keepGoing: false,
          status: TwentyFortyEightStatus.ready,
          message: 'Swipe anywhere to begin.',
          nextTileId: 3,
          startedAt: null,
          elapsedSeconds: 0,
        ),
      ],
    );

    await tester.pumpWidget(_buildHarness(state: state));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsWidgets);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byKey(const Key('2048_pause')), findsNothing);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Move undone.'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('Score 0'), findsOneWidget);
  });

  testWidgets('app bar keeps help and disabled settings only', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Help'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Game menu'), findsNothing);
    expect(find.byKey(const Key('2048_pause')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('2048_settings_action'))),
      isA<IconButton>().having((button) => button.onPressed, 'onPressed', null),
    );
  });

  testWidgets('won board offers keep going and statistics dialog', (
    tester,
  ) async {
    final won = TwentyFortyEightGameState.debug(
      tiles: _boardFromValues([
        [2048, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      score: 4000,
      moveCount: 120,
      hasWon: true,
      status: TwentyFortyEightStatus.won,
    );

    await tester.pumpWidget(_buildHarness(state: won));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('2048_continue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('2048_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('2048_continue')), findsNothing);

    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('2048 statistics'), findsOneWidget);
    expect(find.text('Best score'), findsOneWidget);
  });

  testWidgets('new game resets the board quickly', (tester) async {
    final state = TwentyFortyEightGameState.debug(
      tiles: _boardFromValues([
        [128, 64, 32, 16],
        [8, 4, 2, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      score: 999,
      moveCount: 20,
    );

    await tester.pumpWidget(_buildHarness(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Game'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Score 0'), findsOneWidget);
    expect(find.text('Swipe anywhere to begin.'), findsOneWidget);
  });
}
