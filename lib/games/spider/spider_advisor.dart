import 'package:playing_cards/playing_cards.dart';

import '../klondike/card_model.dart';
import '../klondike/klondike_advisor.dart';
import 'spider_game_state.dart';

enum SpiderSuggestionKind { moveRun, dealFromStock, noMoves }

class SpiderSuggestion {
  const SpiderSuggestion({
    required this.kind,
    required this.message,
    this.cards = const [],
    this.sourcePileIndex,
    this.sourceCardIndex,
    this.targetPileIndex,
  });

  final SpiderSuggestionKind kind;
  final String message;
  final List<KlondikeCard> cards;
  final int? sourcePileIndex;
  final int? sourceCardIndex;
  final int? targetPileIndex;
}

class SpiderAdvisor {
  const SpiderAdvisor._();

  static SpiderSuggestion? bestTapMove(
    SpiderGameState state,
    int pileIndex,
    int cardIndex,
  ) {
    if (!state.canPickUpRun(pileIndex, cardIndex)) {
      return null;
    }
    return _bestMoveForRun(state, pileIndex, cardIndex);
  }

  static SpiderSuggestion bestHint(SpiderGameState state) {
    if (state.isWon) {
      return const SpiderSuggestion(
        kind: SpiderSuggestionKind.noMoves,
        message: 'You already cleared every run.',
      );
    }

    SpiderSuggestion? bestMove;
    var bestScore = -1;
    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      for (int cardIndex = 0; cardIndex < pile.length; cardIndex++) {
        if (!state.canPickUpRun(pileIndex, cardIndex)) {
          continue;
        }
        final suggestion = _bestMoveForRun(state, pileIndex, cardIndex);
        if (suggestion == null) {
          continue;
        }
        final score = _moveScore(state, suggestion);
        if (score > bestScore) {
          bestScore = score;
          bestMove = suggestion;
        }
      }
    }

    if (bestMove != null) {
      return bestMove;
    }

    if (state.canDealFromStock) {
      return const SpiderSuggestion(
        kind: SpiderSuggestionKind.dealFromStock,
        message: 'Deal a fresh row from the stock.',
      );
    }

    if (state.stock.isNotEmpty) {
      return const SpiderSuggestion(
        kind: SpiderSuggestionKind.noMoves,
        message: 'Fill every tableau column before dealing a fresh row.',
      );
    }

    return const SpiderSuggestion(
      kind: SpiderSuggestionKind.noMoves,
      message: 'No moves are available from this position.',
    );
  }

  static SpiderSuggestion? _bestMoveForRun(
    SpiderGameState state,
    int sourcePileIndex,
    int sourceCardIndex,
  ) {
    final cards = state.runAt(sourcePileIndex, sourceCardIndex);
    if (cards.isEmpty) {
      return null;
    }

    SpiderSuggestion? bestMove;
    var bestScore = -1;
    for (
      int targetPileIndex = 0;
      targetPileIndex < state.tableau.length;
      targetPileIndex++
    ) {
      if (targetPileIndex == sourcePileIndex) {
        continue;
      }
      final targetPile = state.tableau[targetPileIndex];
      if (!state.canMoveCardsToTableau(cards, targetPile)) {
        continue;
      }

      final suggestion = SpiderSuggestion(
        kind: SpiderSuggestionKind.moveRun,
        cards: cards,
        sourcePileIndex: sourcePileIndex,
        sourceCardIndex: sourceCardIndex,
        targetPileIndex: targetPileIndex,
        message:
            'Move ${_runLabel(cards)} from tableau ${sourcePileIndex + 1} to tableau ${targetPileIndex + 1}.',
      );
      final score = _moveScore(state, suggestion);
      if (score > bestScore) {
        bestScore = score;
        bestMove = suggestion;
      }
    }

    return bestMove;
  }

  static int _moveScore(SpiderGameState state, SpiderSuggestion suggestion) {
    var score = 0;
    final sourcePile = state.tableau[suggestion.sourcePileIndex!];
    final targetPile = state.tableau[suggestion.targetPileIndex!];
    final firstMovedCard = suggestion.cards.first;

    final revealsHidden =
        suggestion.sourceCardIndex! > 0 &&
        !sourcePile[suggestion.sourceCardIndex! - 1].faceUp;
    if (revealsHidden) {
      score += 220;
    }

    if (suggestion.cards.length > 1) {
      score += 35;
    }

    if (targetPile.isEmpty) {
      score += 70;
    } else {
      score += 45;
      if (targetPile.last.card.suit == firstMovedCard.card.suit) {
        score += 25;
      }
    }

    if (firstMovedCard.card.value == CardValue.king && targetPile.isEmpty) {
      score += 15;
    }

    return score;
  }

  static String _runLabel(List<KlondikeCard> cards) {
    if (cards.length == 1) {
      return KlondikeAdvisor.cardLabel(cards.first);
    }
    return '${KlondikeAdvisor.cardLabel(cards.first)} stack';
  }
}
