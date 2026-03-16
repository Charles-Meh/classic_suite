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
    required this.message,
    this.cards = const [],
    this.targetTableauIndex,
    this.source,
  });

  final KlondikeSuggestionKind kind;
  final String message;
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

    final tableauMove = _bestTableauMoveForLocation(state, location);
    final canMoveToFoundation =
        location.cards(state).length == 1 && state.canMoveToFoundation(card);
    final safeFoundationMove =
        canMoveToFoundation &&
        KlondikeAutocomplete.shouldAutoPromote(state, card);

    if (safeFoundationMove || (canMoveToFoundation && tableauMove == null)) {
      return KlondikeSuggestion(
        kind: KlondikeSuggestionKind.moveToFoundation,
        cards: [card],
        source: location,
        message: 'Move ${_cardLabel(card)} to its foundation.',
      );
    }

    if (tableauMove != null) {
      return tableauMove;
    }

    if (canMoveToFoundation) {
      return KlondikeSuggestion(
        kind: KlondikeSuggestionKind.moveToFoundation,
        cards: [card],
        source: location,
        message: 'Move ${_cardLabel(card)} to its foundation.',
      );
    }

    return null;
  }

  static KlondikeSuggestion bestHint(GameState state) {
    if (state.isWon) {
      return const KlondikeSuggestion(
        kind: KlondikeSuggestionKind.noMoves,
        message: 'You already won this deal.',
      );
    }

    if (state.waste.isNotEmpty) {
      final wasteCard = state.waste.last;
      if (KlondikeAutocomplete.shouldAutoPromote(state, wasteCard) &&
          state.canMoveToFoundation(wasteCard)) {
        return KlondikeSuggestion(
          kind: KlondikeSuggestionKind.moveToFoundation,
          cards: [wasteCard],
          source: const KlondikeLocation.waste(),
          message: 'Move ${_cardLabel(wasteCard)} from waste to foundation.',
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
          message:
              'Move ${_cardLabel(topCard)} from tableau ${pileIndex + 1} to foundation.',
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

    for (
      int foundationIndex = 0;
      foundationIndex < state.foundations.length;
      foundationIndex++
    ) {
      final pile = state.foundations[foundationIndex];
      if (pile.isEmpty) {
        continue;
      }
      final move = _bestTableauMoveForLocation(
        state,
        KlondikeLocation.foundation(foundationIndex),
      );
      if (move != null) {
        return move;
      }
    }

    if (state.stock.isNotEmpty) {
      return const KlondikeSuggestion(
        kind: KlondikeSuggestionKind.drawFromStock,
        source: KlondikeLocation.stock(),
        message: 'Draw from the stock for more options.',
      );
    }

    if (state.waste.isNotEmpty) {
      return const KlondikeSuggestion(
        kind: KlondikeSuggestionKind.recycleWaste,
        source: KlondikeLocation.waste(),
        message: 'Recycle the waste back into the stock.',
      );
    }

    return const KlondikeSuggestion(
      kind: KlondikeSuggestionKind.noMoves,
      message: 'No moves are available from this position.',
    );
  }

  static KlondikeSuggestion? _bestTableauMoveForLocation(
    GameState state,
    KlondikeLocation location,
  ) {
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
      if (!state.canMoveCardsToTableau(cards, targetPile)) {
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

    final cardsLabel = cards.length == 1
        ? _cardLabel(cards.first)
        : '${_cardLabel(cards.first)} stack';
    final sourceLabel = switch (location.zone) {
      KlondikeLocationZone.stock => 'stock',
      KlondikeLocationZone.waste => 'waste',
      KlondikeLocationZone.foundation => 'foundation',
      KlondikeLocationZone.tableau => 'tableau ${location.pileIndex! + 1}',
    };
    return KlondikeSuggestion(
      kind: KlondikeSuggestionKind.moveToTableau,
      cards: cards,
      targetTableauIndex: bestTargetIndex,
      source: location,
      message:
          'Move $cardsLabel from $sourceLabel to tableau ${bestTargetIndex + 1}.',
    );
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

    if (source.zone == KlondikeLocationZone.foundation) {
      score += 20;
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
