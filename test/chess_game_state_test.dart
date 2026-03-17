import 'package:classic_suite/games/chess/chess_ai.dart';
import 'package:classic_suite/games/chess/chess_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening position has 20 legal moves for white', () {
    final state = ChessGameState.newGame();

    expect(state.legalMoves, hasLength(20));
    expect(
      state.fen.startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w'),
      isTrue,
    );
  });

  test('castling appears when path is clear and king is safe', () {
    final state = ChessGameState.debug(
      board: [
        [
          const ChessPiece(ChessSide.black, ChessPieceType.rook),
          null,
          null,
          null,
          const ChessPiece(ChessSide.black, ChessPieceType.king),
          null,
          null,
          const ChessPiece(ChessSide.black, ChessPieceType.rook),
        ],
        List<ChessPiece?>.filled(8, null),
        List<ChessPiece?>.filled(8, null),
        List<ChessPiece?>.filled(8, null),
        List<ChessPiece?>.filled(8, null),
        List<ChessPiece?>.filled(8, null),
        List<ChessPiece?>.filled(8, null),
        [
          const ChessPiece(ChessSide.white, ChessPieceType.rook),
          null,
          null,
          null,
          const ChessPiece(ChessSide.white, ChessPieceType.king),
          null,
          null,
          const ChessPiece(ChessSide.white, ChessPieceType.rook),
        ],
      ],
    );

    final moves = state.legalMovesForSquare(7, 4);

    expect(moves.any((m) => m.isCastleKingSide), isTrue);
    expect(moves.any((m) => m.isCastleQueenSide), isTrue);
  });

  test('ai prefers winning material when available', () {
    final state = ChessGameState.debug(
      board: [
        [
          null,
          null,
          null,
          null,
          const ChessPiece(ChessSide.black, ChessPieceType.king),
          null,
          null,
          null,
        ],
        [null, null, null, null, null, null, null, null],
        [null, null, null, null, null, null, null, null],
        [
          null,
          null,
          null,
          const ChessPiece(ChessSide.black, ChessPieceType.queen),
          null,
          null,
          null,
          null,
        ],
        [
          null,
          null,
          null,
          null,
          const ChessPiece(ChessSide.white, ChessPieceType.queen),
          null,
          null,
          null,
        ],
        [null, null, null, null, null, null, null, null],
        [null, null, null, null, null, null, null, null],
        [
          null,
          null,
          null,
          null,
          const ChessPiece(ChessSide.white, ChessPieceType.king),
          null,
          null,
          null,
        ],
      ],
      turn: ChessSide.black,
    );

    final move = const ChessAi().bestMove(state, depth: 2);

    expect(move, isNotNull);
    expect(move!.toRow, 4);
    expect(move.toCol, 4);
  });

  test('encoded state restores last move and history', () {
    final state = ChessGameState.newGame();
    final move = state.legalMoves.firstWhere((m) => m.uci == 'e2e4');
    final next = state.applyMove(move);
    final restored = ChessGameState.tryDecode(next.encode());

    expect(restored, isNotNull);
    expect(restored!.lastMove?.uci, 'e2e4');
    expect(restored.moveHistory, hasLength(1));
  });
}
