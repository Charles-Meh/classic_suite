import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/spider/spider_advisor.dart';
import 'package:classic_suite/games/spider/spider_game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

KlondikeCard _faceUpCard(Suit suit, CardValue value) {
  return KlondikeCard(PlayingCard(suit, value), faceUp: true);
}

void main() {
  SpiderGameState buildEmptySpiderState() {
    final state = SpiderGameState();
    state.stock.clear();
    state.completedRuns.clear();
    for (final pile in state.tableau) {
      pile.clear();
    }
    return state;
  }

  test('best hint skips equivalent jack-to-jack sideways move', () {
    final state = buildEmptySpiderState();

    state.tableau[0].addAll([
      _faceUpCard(Suit.hearts, CardValue.jack),
      _faceUpCard(Suit.spades, CardValue.ten),
    ]);
    state.tableau[1].add(_faceUpCard(Suit.clubs, CardValue.jack));
    state.tableau[2].add(_faceUpCard(Suit.spades, CardValue.queen));

    for (int index = 3; index < state.tableau.length; index++) {
      state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.king));
    }

    final hint = SpiderAdvisor.bestHint(state);

    expect(hint.kind, SpiderSuggestionKind.moveRun);
    expect(hint.sourcePileIndex, 1);
    expect(hint.targetPileIndex, 2);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.jack);
  });

  test('best hint still prefers revealing a facedown card', () {
    final state = buildEmptySpiderState();

    state.tableau[0].addAll([
      KlondikeCard.faceDown(PlayingCard(Suit.hearts, CardValue.jack)),
      _faceUpCard(Suit.spades, CardValue.ten),
    ]);
    state.tableau[1].add(_faceUpCard(Suit.clubs, CardValue.jack));

    for (int index = 2; index < state.tableau.length; index++) {
      state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.king));
    }

    final hint = SpiderAdvisor.bestHint(state);

    expect(hint.kind, SpiderSuggestionKind.moveRun);
    expect(hint.sourcePileIndex, 0);
    expect(hint.targetPileIndex, 1);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.ten);
  });

  test('best hint allows moving onto a better same-suit support', () {
    final state = buildEmptySpiderState();

    state.tableau[0].addAll([
      _faceUpCard(Suit.hearts, CardValue.jack),
      _faceUpCard(Suit.spades, CardValue.ten),
    ]);
    state.tableau[1].add(_faceUpCard(Suit.spades, CardValue.jack));

    for (int index = 2; index < state.tableau.length; index++) {
      state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.king));
    }

    final hint = SpiderAdvisor.bestHint(state);

    expect(hint.kind, SpiderSuggestionKind.moveRun);
    expect(hint.sourcePileIndex, 0);
    expect(hint.targetPileIndex, 1);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.ten);
  });
}
