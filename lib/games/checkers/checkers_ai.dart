import 'dart:math';

import 'checkers_game_state.dart';

class CheckersAi {
  const CheckersAi();

  CheckersMove? bestMove(CheckersGameState state, {int? depth}) {
    final legal = state.legalMoves;
    if (legal.isEmpty) return null;
    final searchDepth = depth ?? state.difficulty.searchDepth;
    final ordered = List<CheckersMove>.from(legal)
      ..sort((a, b) => _moveScore(state, b).compareTo(_moveScore(state, a)));

    CheckersMove? best;
    var bestScore = -1 << 30;
    var alpha = -1 << 30;
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

  int _search(CheckersGameState state, int depth, int alpha, int beta) {
    if (depth <= 0 || state.isFinished) {
      return _evaluate(state);
    }

    final legal = state.legalMoves;
    if (legal.isEmpty) {
      return _evaluate(state);
    }

    final ordered = List<CheckersMove>.from(legal)
      ..sort((a, b) => _moveScore(state, b).compareTo(_moveScore(state, a)));

    var best = -1 << 30;
    for (final move in ordered) {
      final next = state.applyMove(move, fromAi: true);
      final score = -_search(next, depth - 1, -beta, -alpha);
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _moveScore(CheckersGameState state, CheckersMove move) {
    final piece = state.board[move.fromRow][move.fromCol];
    return (move.capturedSquares.length * 120) +
        (move.promotes ? 90 : 0) +
        ((piece?.isKing ?? false) ? 10 : 0) +
        (move.toRow == 0 || move.toRow == 7 ? 8 : 0);
  }

  int _evaluate(CheckersGameState state) {
    if (state.status == CheckersGameStatus.blackWon) return 1000000;
    if (state.status == CheckersGameStatus.redWon) return -1000000;
    if (state.status == CheckersGameStatus.draw) return 0;

    var score = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = state.board[row][col];
        if (piece == null) continue;
        final value = _pieceValue(piece) + _positionalBonus(piece, row, col);
        score += piece.side == CheckersSide.black ? value : -value;
      }
    }

    final mobility =
        state.legalMoves.length * (state.turn == CheckersSide.black ? 3 : -3);
    score += mobility;
    if (state.mandatoryCaptureExists) {
      score += state.turn == CheckersSide.black ? 12 : -12;
    }
    return score;
  }

  int _pieceValue(CheckersPiece piece) => piece.isKing ? 180 : 100;

  int _positionalBonus(CheckersPiece piece, int row, int col) {
    final centerDistance = (row - 3.5).abs() + (col - 3.5).abs();
    final centerBonus = (8 - centerDistance).round() * 2;
    if (piece.isKing) return centerBonus + 16;
    final advancement = piece.side == CheckersSide.black ? row : (7 - row);
    return advancement * 7 + centerBonus;
  }
}
