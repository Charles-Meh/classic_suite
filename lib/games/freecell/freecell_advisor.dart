import 'package:playing_cards/playing_cards.dart';

import '../klondike/card_model.dart';
import 'freecell_game_state.dart';

enum FreeCellHintKind {
  moveToFoundation,
  moveToCascade,
  moveToFreecell,
  noMoves,
}

enum FreeCellHintSourceZone { cascade, freecell, foundation }

class FreeCellAdvisor {
  static FreeCellSuggestion? bestTapMove(
    FreeCellGameState state,
    List<KlondikeCard> cards,
  ) {
    if (cards.isEmpty) {
      return null;
    }

    if (cards.length == 1 && state.canMoveToFoundation(cards.first)) {
      return const FreeCellSuggestion.toFoundation();
    }

    for (int index = 0; index < state.cascades.length; index++) {
      final target = state.cascades[index];
      if (state.canMoveCardsToCascade(cards, target)) {
        return FreeCellSuggestion.toCascade(index);
      }
    }

    if (cards.length == 1 && state.canMoveToFreecell(cards.first)) {
      return const FreeCellSuggestion.toFreecell();
    }

    return null;
  }

  static FreeCellHint bestHint(FreeCellGameState state) {
    for (
      int cascadeIndex = 0;
      cascadeIndex < state.cascades.length;
      cascadeIndex++
    ) {
      final pile = state.cascades[cascadeIndex];
      if (pile.isEmpty) {
        continue;
      }
      final card = pile.last;
      if (state.canMoveToFoundation(card)) {
        return FreeCellHint(
          kind: FreeCellHintKind.moveToFoundation,
          cards: [card],
          sourceZone: FreeCellHintSourceZone.cascade,
          sourceIndex: cascadeIndex,
          sourceCardIndex: pile.length - 1,
          targetFoundationIndex: _foundationIndexForSuit(card),
          message: 'Move ${_cardLabel(card)} to the foundation.',
        );
      }
    }

    for (
      int freecellIndex = 0;
      freecellIndex < state.freecells.length;
      freecellIndex++
    ) {
      final card = state.freecells[freecellIndex];
      if (card == null) {
        continue;
      }
      if (state.canMoveToFoundation(card)) {
        return FreeCellHint(
          kind: FreeCellHintKind.moveToFoundation,
          cards: [card],
          sourceZone: FreeCellHintSourceZone.freecell,
          sourceIndex: freecellIndex,
          sourceCardIndex: 0,
          targetFoundationIndex: _foundationIndexForSuit(card),
          message:
              'Move ${_cardLabel(card)} from the free cell to the foundation.',
        );
      }
    }

    for (
      int cascadeIndex = 0;
      cascadeIndex < state.cascades.length;
      cascadeIndex++
    ) {
      final pile = state.cascades[cascadeIndex];
      for (int start = 0; start < pile.length; start++) {
        final run = pile.sublist(start);
        if (!_isOrderedStack(run)) {
          continue;
        }
        for (
          int targetIndex = 0;
          targetIndex < state.cascades.length;
          targetIndex++
        ) {
          if (targetIndex == cascadeIndex) {
            continue;
          }
          if (!state.canMoveCardsToCascade(run, state.cascades[targetIndex])) {
            continue;
          }
          final hint = FreeCellHint(
            kind: FreeCellHintKind.moveToCascade,
            cards: run,
            sourceZone: FreeCellHintSourceZone.cascade,
            sourceIndex: cascadeIndex,
            sourceCardIndex: start,
            targetCascadeIndex: targetIndex,
            message: 'Move ${_runLabel(run)} to cascade ${targetIndex + 1}.',
          );
          if (_isEquivalentOrWorseCascadeMove(state, hint)) {
            continue;
          }
          return hint;
        }
      }
    }

    for (
      int freecellIndex = 0;
      freecellIndex < state.freecells.length;
      freecellIndex++
    ) {
      final card = state.freecells[freecellIndex];
      if (card == null) {
        continue;
      }
      for (
        int targetIndex = 0;
        targetIndex < state.cascades.length;
        targetIndex++
      ) {
        if (state.canMoveCardsToCascade([card], state.cascades[targetIndex])) {
          return FreeCellHint(
            kind: FreeCellHintKind.moveToCascade,
            cards: [card],
            sourceZone: FreeCellHintSourceZone.freecell,
            sourceIndex: freecellIndex,
            sourceCardIndex: 0,
            targetCascadeIndex: targetIndex,
            message:
                'Move ${_cardLabel(card)} from the free cell to cascade ${targetIndex + 1}.',
          );
        }
      }
    }

    for (
      int cascadeIndex = 0;
      cascadeIndex < state.cascades.length;
      cascadeIndex++
    ) {
      final pile = state.cascades[cascadeIndex];
      if (pile.isEmpty) {
        continue;
      }
      final card = pile.last;
      if (state.canMoveToFreecell(card)) {
        final targetFreecellIndex = state.freecells.indexWhere(
          (slot) => slot == null,
        );
        return FreeCellHint(
          kind: FreeCellHintKind.moveToFreecell,
          cards: [card],
          sourceZone: FreeCellHintSourceZone.cascade,
          sourceIndex: cascadeIndex,
          sourceCardIndex: pile.length - 1,
          targetFreecellIndex: targetFreecellIndex < 0
              ? null
              : targetFreecellIndex,
          message: 'Park ${_cardLabel(card)} in an open free cell.',
        );
      }
    }

    return const FreeCellHint(
      kind: FreeCellHintKind.noMoves,
      cards: [],
      message:
          'No clear hint right now. Try freeing a cascade or opening a free cell.',
    );
  }

  static bool _isOrderedStack(List<KlondikeCard> cards) {
    if (cards.isEmpty) {
      return false;
    }
    for (int i = 0; i < cards.length - 1; i++) {
      final upper = cards[i];
      final lower = cards[i + 1];
      final upperRed =
          upper.card.suit == Suit.hearts || upper.card.suit == Suit.diamonds;
      final lowerRed =
          lower.card.suit == Suit.hearts || lower.card.suit == Suit.diamonds;
      if (upperRed == lowerRed || upper.valueIndex != lower.valueIndex + 1) {
        return false;
      }
    }
    return true;
  }

  static int _foundationIndexForSuit(KlondikeCard card) {
    return switch (card.card.suit) {
      Suit.clubs => 0,
      Suit.diamonds => 1,
      Suit.hearts => 2,
      Suit.spades => 3,
      _ => 0,
    };
  }

  static bool _isEquivalentOrWorseCascadeMove(
    FreeCellGameState state,
    FreeCellHint hint,
  ) {
    if (hint.kind != FreeCellHintKind.moveToCascade ||
        hint.sourceZone != FreeCellHintSourceZone.cascade ||
        hint.sourceCardIndex == null ||
        hint.sourceCardIndex == 0 ||
        hint.targetCascadeIndex == null) {
      return false;
    }

    final sourcePile = state.cascades[hint.sourceIndex!];
    final targetPile = state.cascades[hint.targetCascadeIndex!];
    if (targetPile.isEmpty) {
      return false;
    }

    final sourceSupport = sourcePile[hint.sourceCardIndex! - 1];
    final targetSupport = targetPile.last;
    return sourceSupport.valueIndex == targetSupport.valueIndex &&
        _isSameColor(sourceSupport, targetSupport);
  }

  static bool _isSameColor(KlondikeCard a, KlondikeCard b) {
    final aRed = a.card.suit == Suit.hearts || a.card.suit == Suit.diamonds;
    final bRed = b.card.suit == Suit.hearts || b.card.suit == Suit.diamonds;
    return aRed == bRed;
  }

  static String _runLabel(List<KlondikeCard> cards) {
    if (cards.length == 1) {
      return _cardLabel(cards.first);
    }
    return '${_cardLabel(cards.first)} down to ${_cardLabel(cards.last)}';
  }

  static String _cardLabel(KlondikeCard card) {
    final rank = switch (card.card.value) {
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
      _ => '?',
    };
    final suit = switch (card.card.suit) {
      Suit.clubs => '♣',
      Suit.diamonds => '♦',
      Suit.hearts => '♥',
      Suit.spades => '♠',
      _ => '?',
    };
    return '$rank$suit';
  }
}

class FreeCellSuggestion {
  const FreeCellSuggestion._({
    this.targetCascadeIndex,
    this.toFoundation = false,
    this.toFreecell = false,
  });

  const FreeCellSuggestion.toCascade(int cascadeIndex)
    : this._(targetCascadeIndex: cascadeIndex);

  const FreeCellSuggestion.toFoundation() : this._(toFoundation: true);

  const FreeCellSuggestion.toFreecell() : this._(toFreecell: true);

  final int? targetCascadeIndex;
  final bool toFoundation;
  final bool toFreecell;
}

class FreeCellHint {
  const FreeCellHint({
    required this.kind,
    required this.cards,
    required this.message,
    this.sourceZone,
    this.sourceIndex,
    this.sourceCardIndex,
    this.targetCascadeIndex,
    this.targetFreecellIndex,
    this.targetFoundationIndex,
  });

  final FreeCellHintKind kind;
  final List<KlondikeCard> cards;
  final String message;
  final FreeCellHintSourceZone? sourceZone;
  final int? sourceIndex;
  final int? sourceCardIndex;
  final int? targetCascadeIndex;
  final int? targetFreecellIndex;
  final int? targetFoundationIndex;
}
