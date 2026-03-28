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
    'best hint skips a king-led stack that only shuffles between empty columns',
    () {
      final state = _emptyState();

      state.tableau[0].addAll([
        _card(Suit.spades, CardValue.king),
        _card(Suit.hearts, CardValue.queen),
      ]);

      final hint = KlondikeAdvisor.bestHint(state);

      expect(hint.kind, KlondikeSuggestionKind.noMoves);
    },
  );

  test('best hint allows a king to empty when it reveals a hidden card', () {
    final state = _emptyState();

    state.tableau[0].addAll([
      KlondikeCard(PlayingCard(Suit.spades, CardValue.two), faceUp: false),
      _card(Suit.spades, CardValue.king),
    ]);

    final hint = KlondikeAdvisor.bestHint(state);

    expect(hint.kind, KlondikeSuggestionKind.moveToTableau);
    expect(hint.source?.zone, KlondikeLocationZone.tableau);
    expect(hint.source?.pileIndex, 0);
    expect(hint.source?.cardIndex, 1);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.first.card.value, CardValue.king);
    expect(hint.targetTableauIndex, isNotNull);
  });

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
