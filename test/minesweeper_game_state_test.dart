import 'package:classic_suite/games/minesweeper/minesweeper_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first reveal is always safe and starts the board', () {
    final state = MinesweeperGameState.newGame(MinesweeperConfig.easy());

    final revealed = state.revealCell(0, 0, seed: 7);

    expect(revealed.generated, isTrue);
    expect(revealed.status, isNot(MinesweeperGameStatus.ready));
    expect(revealed.cellAt(0, 0).hasMine, isFalse);
    expect(revealed.cellAt(0, 0).revealed, isTrue);
  });

  test('flagging updates remaining mine counter', () {
    final state = MinesweeperGameState.newGame(MinesweeperConfig.easy());

    final flagged = state.toggleFlag(2, 3);
    final unflagged = flagged.toggleFlag(2, 3);

    expect(flagged.cellAt(2, 3).flagged, isTrue);
    expect(flagged.remainingMines, state.mineCount - 1);
    expect(unflagged.cellAt(2, 3).flagged, isFalse);
    expect(unflagged.remainingMines, state.mineCount);
  });

  test('reveal floods through zero-value area', () {
    const config = MinesweeperConfig(
      id: 'custom',
      label: 'Custom',
      rows: 5,
      columns: 5,
      mines: 3,
      isPreset: false,
    );
    final state = MinesweeperGameState.debug(
      config: config,
      board: [
        const [
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(hasMine: true),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(hasMine: true),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(hasMine: true),
        ],
        const [
          MinesweeperCell(hasMine: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 2),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
      ],
    );

    final next = state.revealCell(0, 0);

    expect(next.cellAt(0, 0).revealed, isTrue);
    expect(next.cellAt(1, 1).revealed, isTrue);
    expect(next.cellAt(2, 2).revealed, isTrue);
    expect(next.cellAt(1, 3).revealed, isFalse);
  });

  test('chording opens surrounding tiles when flags match', () {
    const config = MinesweeperConfig(
      id: 'custom',
      label: 'Custom',
      rows: 5,
      columns: 5,
      mines: 2,
      isPreset: false,
    );
    final state = MinesweeperGameState.debug(
      config: config,
      board: [
        const [
          MinesweeperCell(revealed: true, adjacentMines: 1),
          MinesweeperCell(hasMine: true, flagged: true),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(hasMine: true),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
        const [
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 0),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: false, adjacentMines: 1),
        ],
      ],
    );

    final next = state.chordCell(0, 0);

    expect(next.cellAt(1, 0).revealed, isTrue);
    expect(next.cellAt(1, 1).revealed, isTrue);
    expect(next.cellAt(0, 2).revealed, isFalse);
  });

  test('encoding and decoding preserve elapsed time and board state', () {
    final state = MinesweeperGameState.newGame(
      MinesweeperConfig.easy(),
    ).toggleFlag(1, 1).withElapsedSeconds(42).copyWith(message: 'Saved');

    final restored = MinesweeperGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.cellAt(1, 1).flagged, isTrue);
    expect(restored.elapsedSeconds, 42);
    expect(restored.message, 'Saved');
  });

  test('solved board is marked as won and auto-flags mines', () {
    const config = MinesweeperConfig(
      id: 'custom',
      label: 'Custom',
      rows: 5,
      columns: 5,
      mines: 1,
      isPreset: false,
    );
    final state = MinesweeperGameState.debug(
      config: config,
      status: MinesweeperGameStatus.running,
      board: [
        const [
          MinesweeperCell(revealed: true, adjacentMines: 1),
          MinesweeperCell(hasMine: true),
          MinesweeperCell(revealed: false, adjacentMines: 1),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: true, adjacentMines: 1),
          MinesweeperCell(revealed: true, adjacentMines: 1),
          MinesweeperCell(revealed: true, adjacentMines: 1),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
        ],
        const [
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
          MinesweeperCell(revealed: true, adjacentMines: 0),
        ],
      ],
    );

    final next = state.revealCell(0, 2);

    expect(next.isComplete, isTrue);
    expect(next.cellAt(0, 1).flagged, isTrue);
    expect(next.message, 'Board cleared. Nice work.');
  });

  test('custom config validates bounds and mine counts', () {
    expect(
      MinesweeperConfig.custom(rows: 4, columns: 9, mines: 10).validate(),
      'Rows must be between 5 and 40.',
    );
    expect(
      MinesweeperConfig.custom(rows: 9, columns: 9, mines: 81).validate(),
      'Mine count must leave at least one safe cell.',
    );
    expect(
      MinesweeperConfig.custom(rows: 12, columns: 20, mines: 50).validate(),
      isNull,
    );
  });
}
