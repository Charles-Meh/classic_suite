import 'dart:math';

import 'chess_game_state.dart';

class ChessAi {
  const ChessAi();

  ChessMove? bestMove(ChessGameState state, {int? depth}) {
    final legal = state.legalMoves;
    if (legal.isEmpty) return null;
    final searchDepth = depth ?? state.difficulty.searchDepth;
    final ordered = List<ChessMove>.from(legal)
      ..sort((a, b) => _moveScore(state, b).compareTo(_moveScore(state, a)));

    ChessMove? best;
    int bestScore = -1 << 30;
    int alpha = -1 << 30;
    const beta = 1 << 30;

    for (final move in ordered) {
      final next = state.applyMove(move, fromAi: true);
      final score = -_search(next, searchDepth - 1, -beta, -alpha);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
      alpha = max(alpha, bestScore);
    }
    return best ?? legal.first;
  }

  int _search(ChessGameState state, int depth, int alpha, int beta) {
    if (depth <= 0 || state.isFinished || state.isPaused) {
      return _evaluate(state);
    }
    final legal = state.legalMoves;
    if (legal.isEmpty) {
      return _evaluate(state);
    }
    final ordered = List<ChessMove>.from(legal)
      ..sort((a, b) => _moveScore(state, b).compareTo(_moveScore(state, a)));
    int best = -1 << 30;
    for (final move in ordered) {
      final next = state.applyMove(move, fromAi: true);
      final score = -_search(next, depth - 1, -beta, -alpha);
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _moveScore(ChessGameState state, ChessMove move) {
    final target = state.board[move.toRow][move.toCol];
    final piece = state.board[move.fromRow][move.fromCol];
    return (target == null ? 0 : _pieceValue(target.type) * 10) +
        (move.promotion == null ? 0 : _pieceValue(move.promotion!)) +
        (piece?.type == ChessPieceType.pawn &&
                (move.toRow == 0 || move.toRow == 7)
            ? 800
            : 0) +
        (move.isCastleKingSide || move.isCastleQueenSide ? 100 : 0);
  }

  int _evaluate(ChessGameState state) {
    if (state.status == ChessGameStatus.blackWon) return 1000000;
    if (state.status == ChessGameStatus.whiteWon) return -1000000;
    if (state.status == ChessGameStatus.draw) return 0;

    int score = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = state.board[row][col];
        if (piece == null) continue;
        final value =
            _pieceValue(piece.type) + _positionalBonus(piece, row, col);
        score += piece.side == ChessSide.black ? value : -value;
      }
    }

    final mobility =
        state.legalMoves.length * (state.turn == ChessSide.black ? 2 : -2);
    score += mobility;
    if (state.isKingInCheck(ChessSide.white)) score += 25;
    if (state.isKingInCheck(ChessSide.black)) score -= 25;
    return score;
  }

  int _pieceValue(ChessPieceType type) => switch (type) {
    ChessPieceType.pawn => 100,
    ChessPieceType.knight => 320,
    ChessPieceType.bishop => 330,
    ChessPieceType.rook => 500,
    ChessPieceType.queen => 900,
    ChessPieceType.king => 20000,
  };

  int _positionalBonus(ChessPiece piece, int row, int col) {
    final rankFromWhite = 7 - row;
    final centerDistance = (col - 3.5).abs() + (row - 3.5).abs();
    final centrality = (10 - centerDistance * 2).round();
    return switch (piece.type) {
      ChessPieceType.pawn =>
        (piece.side == ChessSide.white ? rankFromWhite : row) * 8,
      ChessPieceType.knight => centrality * 3,
      ChessPieceType.bishop => centrality * 2,
      ChessPieceType.rook =>
        (piece.side == ChessSide.white ? rankFromWhite : row) * 2,
      ChessPieceType.queen => centrality,
      ChessPieceType.king =>
        piece.side == ChessSide.black
            ? ((row <= 1 ? 16 : 0) + ((col == 6 || col == 2) ? 10 : 0))
            : -((row >= 6 ? 16 : 0) + ((col == 6 || col == 2) ? 10 : 0)),
    };
  }
}
