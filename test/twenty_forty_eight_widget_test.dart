import 'dart:convert';

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

void _expectHeaderStats({
  required int score,
  required int best,
  required int moves,
  String? time,
}) {
  final zeroValueCount = [
    score,
    best,
    moves,
  ].where((value) => value == 0).length;

  expect(find.text('Score'), findsOneWidget);
  expect(find.text('Best'), findsOneWidget);
  expect(find.text('Moves'), findsOneWidget);
  expect(find.text('Time'), findsOneWidget);
  if (score != 0) {
    expect(find.text('$score'), findsOneWidget);
  }
  if (best != 0) {
    expect(find.text('$best'), findsOneWidget);
  }
  if (moves != 0) {
    expect(find.text('$moves'), findsOneWidget);
  }
  if (zeroValueCount > 0) {
    expect(find.text('0'), findsAtLeastNWidgets(zeroValueCount));
  }
  if (time != null) {
    expect(find.text(time), findsOneWidget);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state with legacy message keys is restored on launch', (
    tester,
  ) async {
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
    final legacyJson = saved.toJson();
    legacyJson['message'] = 'Swipe anywhere to begin.';
    legacyJson['undoStack'] = [
      {
        'tiles': [
          {
            'id': 1,
            'value': 2,
            'row': 0,
            'column': 0,
            'isNew': false,
            'isMerged': false,
          },
        ],
        'score': 0,
        'moveCount': 0,
        'hasWon': false,
        'keepGoing': false,
        'status': TwentyFortyEightStatus.ready.name,
        'message': 'Legacy undo message',
        'nextTileId': 2,
        'startedAt': null,
        'elapsedSeconds': 0,
      },
    ];
    SharedPreferences.setMockInitialValues({
      TwentyFortyEightGameState.storageKey: jsonEncode(legacyJson),
    });

    await tester.pumpWidget(const MaterialApp(home: TwentyFortyEightGame()));
    await tester.pumpAndSettle();

    _expectHeaderStats(score: 12, best: 0, moves: 3, time: '00:22');
    expect(find.text('Swipe anywhere to begin.'), findsNothing);
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

    expect(find.text('2'), findsWidgets);
    _expectHeaderStats(score: 0, best: 0, moves: 0, time: '00:00');
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

  testWidgets('new game asks for confirmation before resetting', (
    tester,
  ) async {
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

    expect(find.text('Start new game?'), findsOneWidget);
    expect(find.text('Current progress will be lost.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    _expectHeaderStats(score: 999, best: 0, moves: 20);
    expect(find.text('128'), findsWidgets);

    await tester.tap(find.text('New Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Game').last);
    await tester.pumpAndSettle();

    _expectHeaderStats(score: 0, best: 0, moves: 0, time: '00:00');
    expect(find.text('999'), findsNothing);
    expect(find.text('128'), findsNothing);
  });

  testWidgets('overlay restart uses the same confirmation dialog', (
    tester,
  ) async {
    final lost = TwentyFortyEightGameState.debug(
      tiles: _boardFromValues([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 2],
      ]),
      score: 240,
      moveCount: 40,
      status: TwentyFortyEightStatus.lost,
    );

    await tester.pumpWidget(_buildHarness(state: lost));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Restart'));
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(find.text('Start new game?'), findsOneWidget);
    expect(find.text('Current progress will be lost.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    _expectHeaderStats(score: 240, best: 0, moves: 40, time: '00:00');
  });
}
