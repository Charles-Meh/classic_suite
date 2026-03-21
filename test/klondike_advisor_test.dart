import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_advisor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

KlondikeCard _card(Suit suit, CardValue value) {
  return KlondikeCard(PlayingCard(suit, value), faceUp: true);
}

GameState _emptyState() {
  final state = GameState();
  state.stock.clear();
  state.waste.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  for (final pile in state.foundations) {
    pile.clear();
  }
  return state;
}

void main() {
  test('best hint skips lone king move to an empty tableau', () {
    final state = _emptyState();

    state.tableau[0].add(_card(Suit.spades, CardValue.king));

    final hint = KlondikeAdvisor.bestHint(state);

    expect(hint.kind, KlondikeSuggestionKind.noMoves);
  });

  test(
    'best hint still allows moving a king-led stack to an empty tableau',
    () {
      final state = _emptyState();

      state.tableau[0].addAll([
        _card(Suit.spades, CardValue.king),
        _card(Suit.hearts, CardValue.queen),
      ]);

      final hint = KlondikeAdvisor.bestHint(state);

      expect(hint.kind, KlondikeSuggestionKind.moveToTableau);
      expect(hint.source?.zone, KlondikeLocationZone.tableau);
      expect(hint.source?.pileIndex, 0);
      expect(hint.source?.cardIndex, 0);
      expect(hint.targetTableauIndex, 1);
      expect(hint.cards, hasLength(2));
      expect(hint.cards.first.card.value, CardValue.king);
    },
  );

  test('best hint still prefers moving an ace to foundation', () {
    final state = _emptyState();

    state.waste.add(_card(Suit.hearts, CardValue.ace));
    state.tableau[0].addAll([
      _card(Suit.spades, CardValue.king),
      _card(Suit.hearts, CardValue.queen),
    ]);

    final hint = KlondikeAdvisor.bestHint(state);

    expect(hint.kind, KlondikeSuggestionKind.moveToFoundation);
    expect(hint.source?.zone, KlondikeLocationZone.waste);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.ace);
  });
}
