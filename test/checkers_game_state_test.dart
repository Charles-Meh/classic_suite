import 'package:classic_suite/games/checkers/checkers_ai.dart';
import 'package:classic_suite/games/checkers/checkers_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<CheckersPiece?>> _emptyBoard() =>
    List.generate(8, (_) => List<CheckersPiece?>.filled(8, null));

void main() {
  test('starting position has 12 pieces per side', () {
    final state = CheckersGameState.newGame();
    var red = 0;
    var black = 0;
    for (final row in state.board) {
      for (final piece in row) {
        if (piece?.side == CheckersSide.red) red++;
        if (piece?.side == CheckersSide.black) black++;
      }
    }
    expect(red, 12);
    expect(black, 12);
    expect(state.turn, CheckersSide.red);
  });

  test('mandatory captures suppress simple moves', () {
    final board = _emptyBoard();
    board[5][0] = const CheckersPiece(side: CheckersSide.red);
    board[5][2] = const CheckersPiece(side: CheckersSide.red);
    board[4][3] = const CheckersPiece(side: CheckersSide.black);
    final state = CheckersGameState.debug(board: board, turn: CheckersSide.red);

    final legal = state.legalMoves;

    expect(legal, hasLength(1));
    expect(legal.single.fromRow, 5);
    expect(legal.single.fromCol, 2);
    expect(legal.single.toRow, 3);
    expect(legal.single.toCol, 4);
    expect(legal.single.isCapture, isTrue);
  });

  test('multi-jump captures are generated as one move', () {
    final board = _emptyBoard();
    board[5][0] = const CheckersPiece(side: CheckersSide.red);
    board[4][1] = const CheckersPiece(side: CheckersSide.black);
    board[2][3] = const CheckersPiece(side: CheckersSide.black);
    final state = CheckersGameState.debug(board: board, turn: CheckersSide.red);

    final move = state.legalMoves.single;
    final next = state.applyMove(move);

    expect(move.path, equals([(5, 0), (3, 2), (1, 4)]));
    expect(move.capturedSquares, equals([(4, 1), (2, 3)]));
    expect(next.board[1][4]?.side, CheckersSide.red);
    expect(next.board[4][1], isNull);
    expect(next.board[2][3], isNull);
  });

  test('kings can move backward', () {
    final board = _emptyBoard();
    board[4][3] = const CheckersPiece(side: CheckersSide.red, isKing: true);
    final state = CheckersGameState.debug(board: board, turn: CheckersSide.red);

    final moves = state.legalMovesForSquare(4, 3);
    final targets = moves.map((move) => (move.toRow, move.toCol)).toSet();

    expect(targets.contains((3, 2)), isTrue);
    expect(targets.contains((3, 4)), isTrue);
    expect(targets.contains((5, 2)), isTrue);
    expect(targets.contains((5, 4)), isTrue);
  });

  test('promotion crowns a piece reaching the back rank', () {
    final board = _emptyBoard();
    board[1][2] = const CheckersPiece(side: CheckersSide.red);
    final state = CheckersGameState.debug(board: board, turn: CheckersSide.red);

    final move = state.legalMoves.firstWhere(
      (move) => move.toRow == 0 && move.toCol == 1,
    );
    final next = state.applyMove(move);

    expect(next.board[0][1]?.isKing, isTrue);
  });

  test('encoding preserves board, selection, and history', () {
    final board = _emptyBoard();
    board[5][0] = const CheckersPiece(side: CheckersSide.red);
    final state = CheckersGameState.debug(
      board: board,
      selectedSquare: (5, 0),
      elapsedSeconds: 21,
      moveHistory: const [
        CheckersHistoryEntry(
          move: CheckersMove(path: [(5, 0), (4, 1)]),
          notation: 'a3-b4',
          position: 'pos',
        ),
      ],
    );

    final restored = CheckersGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.selectedSquare, equals((5, 0)));
    expect(restored.elapsedSeconds, 21);
    expect(restored.moveHistory.single.notation, 'a3-b4');
  });

  test('ai respects forced capture rules', () {
    final board = _emptyBoard();
    board[2][3] = const CheckersPiece(side: CheckersSide.black);
    board[3][4] = const CheckersPiece(side: CheckersSide.red);
    board[2][7] = const CheckersPiece(side: CheckersSide.black);
    final state = CheckersGameState.debug(
      board: board,
      turn: CheckersSide.black,
    );

    final move = const CheckersAi().bestMove(state, depth: 2);

    expect(move, isNotNull);
    expect(move!.isCapture, isTrue);
    expect(move.toRow, 4);
    expect(move.toCol, 5);
  });
}
