import 'package:playing_cards/playing_cards.dart';

import 'card_model.dart';
import 'game_state.dart';

class KlondikeAutocomplete {
  const KlondikeAutocomplete._();

  static bool canAutocomplete(GameState state) {
    if (state.isWon || state.stock.isNotEmpty) {
      return false;
    }
    if (state.tableau.any((pile) => pile.any((card) => !card.faceUp))) {
      return false;
    }

    final probe = state.copy();
    return finish(probe);
  }

  static bool finish(GameState state, {int maxMoves = 200}) {
    for (int step = 0; step < maxMoves && !state.isWon; step++) {
      if (!applyNextMove(state)) {
        break;
      }
    }
    return state.isWon;
  }

  static void autoPromote(GameState state) {
    while (applyNextMove(state)) {}
  }

  static bool applyNextMove(GameState state) {
    if (state.waste.isNotEmpty) {
      final wasteCard = state.waste.last;
      if (shouldAutoPromote(state, wasteCard) &&
          state.moveToFoundation(wasteCard)) {
        return true;
      }
    }

    for (final pile in state.tableau) {
      if (pile.isEmpty) {
        continue;
      }
      final card = pile.last;
      if (shouldAutoPromote(state, card) && state.moveToFoundation(card)) {
        return true;
      }
    }

    return false;
  }

  static bool shouldAutoPromote(GameState state, KlondikeCard card) {
    if (!state.canMoveToFoundation(card)) {
      return false;
    }
    if (card.valueIndex <= 2) {
      return true;
    }

    final blackMinimum = _minimumFoundationValue(state, const [
      Suit.clubs,
      Suit.spades,
    ]);
    final redMinimum = _minimumFoundationValue(state, const [
      Suit.hearts,
      Suit.diamonds,
    ]);

    if (_isRed(card.card.suit)) {
      return blackMinimum >= card.valueIndex - 1;
    }
    return redMinimum >= card.valueIndex - 1;
  }

  static int _minimumFoundationValue(GameState state, List<Suit> suits) {
    var minimum = 13;
    for (final suit in suits) {
      final pile = state.foundationForSuit(suit);
      final topValue = pile.isEmpty ? 0 : pile.last.valueIndex;
      if (topValue < minimum) {
        minimum = topValue;
      }
    }
    return minimum;
  }

  static bool _isRed(Suit suit) {
    return suit == Suit.hearts || suit == Suit.diamonds;
  }
}
