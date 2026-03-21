import 'package:playing_cards/playing_cards.dart';

import 'card_model.dart';
import 'game_state.dart';
import 'klondike_autocomplete.dart';

enum KlondikeSuggestionKind {
  moveToFoundation,
  moveToTableau,
  drawFromStock,
  recycleWaste,
  noMoves,
}

enum KlondikeLocationZone { stock, waste, foundation, tableau }

class KlondikeLocation {
  const KlondikeLocation._({
    required this.zone,
    this.pileIndex,
    this.cardIndex,
  });

  const KlondikeLocation.stock()
    : this._(zone: KlondikeLocationZone.stock, pileIndex: 0, cardIndex: 0);

  const KlondikeLocation.waste()
    : this._(zone: KlondikeLocationZone.waste, pileIndex: 0, cardIndex: 0);

  const KlondikeLocation.foundation(int foundationIndex)
    : this._(
        zone: KlondikeLocationZone.foundation,
        pileIndex: foundationIndex,
        cardIndex: 0,
      );

  const KlondikeLocation.tableau({
    required int pileIndex,
    required int cardIndex,
  }) : this._(
         zone: KlondikeLocationZone.tableau,
         pileIndex: pileIndex,
         cardIndex: cardIndex,
       );

  final KlondikeLocationZone zone;
  final int? pileIndex;
  final int? cardIndex;

  List<KlondikeCard>? sourcePile(GameState state) {
    return switch (zone) {
      KlondikeLocationZone.stock => state.stock,
      KlondikeLocationZone.waste => state.waste,
      KlondikeLocationZone.foundation => state.foundations[pileIndex!],
      KlondikeLocationZone.tableau => state.tableau[pileIndex!],
    };
  }

  List<KlondikeCard> cards(GameState state) {
    final pile = sourcePile(state);
    if (pile == null || pile.isEmpty) {
      return const [];
    }
    return switch (zone) {
      KlondikeLocationZone.stock => [pile.last],
      KlondikeLocationZone.waste => [pile.last],
      KlondikeLocationZone.foundation => [pile.last],
      KlondikeLocationZone.tableau => pile.sublist(cardIndex!),
    };
  }
}

class KlondikeSuggestion {
  const KlondikeSuggestion({
    required this.kind,
    this.cards = const [],
    this.targetTableauIndex,
    this.source,
  });

  final KlondikeSuggestionKind kind;
  final List<KlondikeCard> cards;
  final int? targetTableauIndex;
  final KlondikeLocation? source;
}

class KlondikeAdvisor {
  const KlondikeAdvisor._();

  static KlondikeSuggestion? bestTapMove(GameState state, KlondikeCard card) {
    final location = locateCard(state, card);
    if (location == null || !card.faceUp) {
      return null;
    }

    final canMoveToFoundation =
        location.cards(state).length == 1 && state.canMoveToFoundation(card);

    if (canMoveToFoundation) {
      return KlondikeSuggestion(
        kind: KlondikeSuggestionKind.moveToFoundation,
        cards: [card],
        source: location,
      );
    }

    return null;
  }

  static KlondikeSuggestion bestHint(GameState state) {
    if (state.isWon) {
      return const KlondikeSuggestion(kind: KlondikeSuggestionKind.noMoves);
    }

    if (state.waste.isNotEmpty) {
      final wasteCard = state.waste.last;
      if (KlondikeAutocomplete.shouldAutoPromote(state, wasteCard) &&
          state.canMoveToFoundation(wasteCard)) {
        return KlondikeSuggestion(
          kind: KlondikeSuggestionKind.moveToFoundation,
          cards: [wasteCard],
          source: const KlondikeLocation.waste(),
        );
      }

      final wasteMove = _bestTableauMoveForLocation(
        state,
        const KlondikeLocation.waste(),
      );
      if (wasteMove != null) {
        return wasteMove;
      }
    }

    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      if (pile.isEmpty) {
        continue;
      }

      final topCard = pile.last;
      if (KlondikeAutocomplete.shouldAutoPromote(state, topCard) &&
          state.canMoveToFoundation(topCard)) {
        return KlondikeSuggestion(
          kind: KlondikeSuggestionKind.moveToFoundation,
          cards: [topCard],
          source: KlondikeLocation.tableau(
            pileIndex: pileIndex,
            cardIndex: pile.length - 1,
          ),
        );
      }
    }

    KlondikeSuggestion? bestTableauHint;
    var bestScore = -1;
    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      for (int cardIndex = 0; cardIndex < pile.length; cardIndex++) {
        final card = pile[cardIndex];
        if (!card.faceUp) {
          continue;
        }
        final location = KlondikeLocation.tableau(
          pileIndex: pileIndex,
          cardIndex: cardIndex,
        );
        final move = _bestTableauMoveForLocation(state, location);
        if (move == null) {
          continue;
        }
        final score = _tableauHintScore(
          state,
          source: location,
          targetPileIndex: move.targetTableauIndex!,
          cards: move.cards,
        );
        if (score > bestScore) {
          bestScore = score;
          bestTableauHint = move;
        }
      }
    }
    if (bestTableauHint != null) {
      return bestTableauHint;
    }

    if (state.stock.isNotEmpty) {
      return const KlondikeSuggestion(
        kind: KlondikeSuggestionKind.drawFromStock,
        source: KlondikeLocation.stock(),
      );
    }

    if (state.waste.isNotEmpty) {
      return const KlondikeSuggestion(
        kind: KlondikeSuggestionKind.recycleWaste,
        source: KlondikeLocation.waste(),
      );
    }

    return const KlondikeSuggestion(kind: KlondikeSuggestionKind.noMoves);
  }

  static KlondikeSuggestion? _bestTableauMoveForLocation(
    GameState state,
    KlondikeLocation location,
  ) {
    if (location.zone == KlondikeLocationZone.foundation) {
      return null;
    }

    final sourcePile = location.sourcePile(state);
    if (sourcePile == null) {
      return null;
    }

    final cards = location.cards(state);
    if (cards.isEmpty) {
      return null;
    }

    var bestTargetIndex = -1;
    var bestScore = -1;
    for (
      int targetIndex = 0;
      targetIndex < state.tableau.length;
      targetIndex++
    ) {
      if (location.zone == KlondikeLocationZone.tableau &&
          targetIndex == location.pileIndex) {
        continue;
      }
      final targetPile = state.tableau[targetIndex];
      if (!state.canMoveCardsToTableau(cards, targetPile) ||
          _isRedundantTableauMove(
            state,
            source: location,
            targetPileIndex: targetIndex,
            cards: cards,
          )) {
        continue;
      }
      final score = _tableauHintScore(
        state,
        source: location,
        targetPileIndex: targetIndex,
        cards: cards,
      );
      if (score > bestScore) {
        bestScore = score;
        bestTargetIndex = targetIndex;
      }
    }

    if (bestTargetIndex < 0) {
      return null;
    }

    return KlondikeSuggestion(
      kind: KlondikeSuggestionKind.moveToTableau,
      cards: cards,
      targetTableauIndex: bestTargetIndex,
      source: location,
    );
  }

  static bool _isRedundantTableauMove(
    GameState state, {
    required KlondikeLocation source,
    required int targetPileIndex,
    required List<KlondikeCard> cards,
  }) {
    final targetPile = state.tableau[targetPileIndex];
    if (targetPile.isEmpty &&
        cards.length == 1 &&
        cards.first.card.value == CardValue.king) {
      return true;
    }

    if (source.zone != KlondikeLocationZone.tableau || source.cardIndex == 0) {
      return false;
    }

    final sourcePile = state.tableau[source.pileIndex!];
    final previousCard = sourcePile[source.cardIndex! - 1];
    if (!previousCard.faceUp) {
      return false;
    }

    final movingCard = cards.first;
    final hasOppositeColor =
        _isRed(previousCard.card.suit) != _isRed(movingCard.card.suit);
    final isOneRankLower = movingCard.valueIndex == previousCard.valueIndex - 1;
    if (!hasOppositeColor || !isOneRankLower) {
      return false;
    }

    return targetPile.isNotEmpty;
  }

  static bool _isRed(Suit suit) {
    return suit == Suit.hearts || suit == Suit.diamonds;
  }

  static int _tableauHintScore(
    GameState state, {
    required KlondikeLocation source,
    required int targetPileIndex,
    required List<KlondikeCard> cards,
  }) {
    var score = 0;
    final targetPile = state.tableau[targetPileIndex];

    if (source.zone == KlondikeLocationZone.tableau) {
      final sourcePile = state.tableau[source.pileIndex!];
      final revealsHidden =
          source.cardIndex! > 0 && !sourcePile[source.cardIndex! - 1].faceUp;
      if (revealsHidden) {
        score += 200;
      }
      if (cards.length > 1) {
        score += 30;
      }
    }

    if (source.zone == KlondikeLocationZone.waste) {
      score += 120;
    }

    if (targetPile.isNotEmpty) {
      score += 40;
    } else {
      score += 60;
    }

    if (cards.first.card.value == CardValue.king && targetPile.isEmpty) {
      score += 25;
    }

    return score;
  }

  static KlondikeLocation? locateCard(GameState state, KlondikeCard card) {
    if (state.waste.isNotEmpty && identical(state.waste.last, card)) {
      return const KlondikeLocation.waste();
    }

    for (
      int foundationIndex = 0;
      foundationIndex < state.foundations.length;
      foundationIndex++
    ) {
      final pile = state.foundations[foundationIndex];
      if (pile.isNotEmpty && identical(pile.last, card)) {
        return KlondikeLocation.foundation(foundationIndex);
      }
    }

    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      final cardIndex = pile.indexOf(card);
      if (cardIndex >= 0) {
        return KlondikeLocation.tableau(
          pileIndex: pileIndex,
          cardIndex: cardIndex,
        );
      }
    }

    return null;
  }

  static String cardLabel(KlondikeCard card) => _cardLabel(card);

  static String _cardLabel(KlondikeCard card) {
    return '${_valueLabel(card.card.value)}${_suitSymbol(card.card.suit)}';
  }

  static String _valueLabel(CardValue value) {
    return switch (value) {
      CardValue.ace => 'A',
      CardValue.two => '2',
      CardValue.three => '3',
      CardValue.four => '4',
      CardValue.five => '5',
      CardValue.six => '6',
      CardValue.seven => '7',
      CardValue.eight => '8',
      CardValue.nine => '9',
      CardValue.ten => '10',
      CardValue.jack => 'J',
      CardValue.queen => 'Q',
      CardValue.king => 'K',
      _ => throw ArgumentError('Unsupported value: $value'),
    };
  }

  static String _suitSymbol(Suit suit) {
    return switch (suit) {
      Suit.clubs => '♣',
      Suit.diamonds => '♦',
      Suit.hearts => '♥',
      Suit.spades => '♠',
      _ => throw ArgumentError('Unsupported suit: $suit'),
    };
  }
}
