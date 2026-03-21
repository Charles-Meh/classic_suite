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

  test('best hint prefers a normal move over an open tableau column', () {
    final state = buildEmptySpiderState();

    state.tableau[0].add(_faceUpCard(Suit.clubs, CardValue.seven));
    state.tableau[1].add(_faceUpCard(Suit.spades, CardValue.six));
    state.tableau[2].clear();

    for (int index = 3; index < state.tableau.length; index++) {
      state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.king));
    }

    final hint = SpiderAdvisor.bestHint(state);

    expect(hint.kind, SpiderSuggestionKind.moveRun);
    expect(hint.sourcePileIndex, 1);
    expect(hint.targetPileIndex, 0);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.six);
  });

  test('best hint highlights an open tableau when no normal move exists', () {
    final state = buildEmptySpiderState();

    state.tableau[0].add(_faceUpCard(Suit.clubs, CardValue.queen));
    state.tableau[1].add(_faceUpCard(Suit.spades, CardValue.eight));
    state.tableau[2].clear();

    for (int index = 3; index < state.tableau.length; index++) {
      state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.four));
    }

    final hint = SpiderAdvisor.bestHint(state);

    expect(hint.kind, SpiderSuggestionKind.useEmptyTableau);
    expect(hint.targetPileIndex, 2);
    expect(hint.sourcePileIndex, isNull);
    expect(hint.cards, isEmpty);
  });

  test(
    'best hint suggests dealing when no move exists and no tableau is open',
    () {
      final state = buildEmptySpiderState();

      state.tableau[0].add(_faceUpCard(Suit.clubs, CardValue.queen));
      state.tableau[1].add(_faceUpCard(Suit.spades, CardValue.eight));
      for (int index = 2; index < state.tableau.length; index++) {
        state.tableau[index].add(_faceUpCard(Suit.diamonds, CardValue.four));
      }
      state.stock.addAll([
        _faceUpCard(Suit.hearts, CardValue.ace),
        _faceUpCard(Suit.hearts, CardValue.two),
        _faceUpCard(Suit.hearts, CardValue.three),
        _faceUpCard(Suit.hearts, CardValue.four),
        _faceUpCard(Suit.hearts, CardValue.five),
        _faceUpCard(Suit.hearts, CardValue.six),
        _faceUpCard(Suit.hearts, CardValue.seven),
        _faceUpCard(Suit.hearts, CardValue.eight),
        _faceUpCard(Suit.hearts, CardValue.nine),
        _faceUpCard(Suit.hearts, CardValue.ten),
      ]);

      final hint = SpiderAdvisor.bestHint(state);

      expect(hint.kind, SpiderSuggestionKind.dealFromStock);
      expect(hint.targetPileIndex, isNull);
    },
  );
}
