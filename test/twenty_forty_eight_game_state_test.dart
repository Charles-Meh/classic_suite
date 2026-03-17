import 'package:classic_suite/games/twenty_forty_eight/twenty_forty_eight_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<TwentyFortyEightTile> boardFromValues(List<List<int>> grid) {
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

  test('new game starts with two tiles', () {
    final state = TwentyFortyEightGameState.newGame(seed: 7);

    expect(state.tiles.length, 2);
    expect(state.score, 0);
    expect(state.highestTile, anyOf(2, 4));
  });

  test('move left merges once per pair and updates score', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [2, 2, 2, 2],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      nextTileId: 10,
    );

    final result = state.move(MoveDirection.left, seed: 1);
    final grid = result.state.valueGrid;

    expect(result.changed, isTrue);
    expect(grid[0][0], 4);
    expect(grid[0][1], 4);
    expect(result.state.score, 8);
    expect(result.state.moveCount, 1);
    expect(result.state.canUndo, isTrue);
  });

  test('move with no change does not add undo state', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [2, 4, 8, 16],
        [32, 64, 128, 256],
        [512, 1024, 2, 4],
        [8, 16, 32, 64],
      ]),
      status: TwentyFortyEightStatus.lost,
    );

    final result = state.move(MoveDirection.left);

    expect(result.changed, isFalse);
    expect(result.state.undoStack, isEmpty);
  });

  test('reaching 2048 sets won state and continue can resume play', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [1024, 1024, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      nextTileId: 20,
    );

    final won = state.move(MoveDirection.left, seed: 2).state;
    final continued = won.continuePast2048();

    expect(won.hasWon, isTrue);
    expect(won.status, TwentyFortyEightStatus.won);
    expect(continued.keepGoing, isTrue);
    expect(continued.status, TwentyFortyEightStatus.playing);
  });

  test('undo restores prior board and score', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [2, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      nextTileId: 10,
    );

    final moved = state.move(MoveDirection.left, seed: 3).state;
    final undone = moved.undo();

    expect(undone.valueGrid[0][0], 2);
    expect(undone.valueGrid[0][1], 2);
    expect(undone.score, 0);
    expect(undone.moveCount, 0);
  });

  test('encoding preserves state and undo stack', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [2, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      score: 12,
      moveCount: 5,
      hasWon: true,
      keepGoing: true,
      status: TwentyFortyEightStatus.playing,
      elapsedSeconds: 44,
      undoStack: [
        const TwentyFortyEightSnapshot(
          tiles: [TwentyFortyEightTile(id: 1, value: 2, row: 0, column: 0)],
          score: 0,
          moveCount: 0,
          hasWon: false,
          keepGoing: false,
          status: TwentyFortyEightStatus.ready,
          message: 'Swipe anywhere to begin.',
          nextTileId: 2,
          startedAt: null,
          elapsedSeconds: 0,
        ),
      ],
    );

    final restored = TwentyFortyEightGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.score, 12);
    expect(restored.moveCount, 5);
    expect(restored.hasWon, isTrue);
    expect(restored.keepGoing, isTrue);
    expect(restored.elapsedSeconds, 44);
    expect(restored.undoStack.length, 1);
  });

  test('full board with no matches is lost', () {
    final state = TwentyFortyEightGameState.debug(
      tiles: boardFromValues([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 2],
      ]),
      status: TwentyFortyEightStatus.playing,
    );

    expect(state.canMove, isFalse);
  });
}
