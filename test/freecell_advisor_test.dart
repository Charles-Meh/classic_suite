import 'package:classic_suite/games/freecell/freecell_advisor.dart';
import 'package:classic_suite/games/freecell/freecell_game_state.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

KlondikeCard _card(Suit suit, CardValue value) {
  return KlondikeCard(PlayingCard(suit, value), faceUp: true);
}

FreeCellGameState _emptyState() {
  final state = FreeCellGameState();
  for (final cascade in state.cascades) {
    cascade.clear();
  }
  for (int index = 0; index < state.freecells.length; index++) {
    state.freecells[index] = null;
  }
  for (final foundation in state.foundations) {
    foundation.clear();
  }
  return state;
}

void main() {
  test('best hint skips equivalent jack-to-jack cascade shuffle', () {
    final state = _emptyState();

    state.cascades[0].addAll([
      _card(Suit.clubs, CardValue.jack),
      _card(Suit.hearts, CardValue.ten),
    ]);
    state.cascades[1].add(_card(Suit.spades, CardValue.jack));
    state.cascades[2].add(_card(Suit.diamonds, CardValue.queen));

    for (int index = 3; index < state.cascades.length; index++) {
      state.cascades[index].add(_card(Suit.clubs, CardValue.king));
    }

    final hint = FreeCellAdvisor.bestHint(state);

    expect(hint.kind, FreeCellHintKind.moveToCascade);
    expect(hint.sourceZone, FreeCellHintSourceZone.cascade);
    expect(hint.sourceIndex, 0);
    expect(hint.sourceCardIndex, 0);
    expect(hint.targetCascadeIndex, 2);
    expect(hint.cards, hasLength(2));
    expect(hint.cards.first.card.value, CardValue.jack);
    expect(hint.cards.last.card.value, CardValue.ten);
  });

  test(
    'best hint falls back to a freecell instead of a noisy cascade move',
    () {
      final state = _emptyState();

      state.cascades[0].addAll([
        _card(Suit.clubs, CardValue.jack),
        _card(Suit.hearts, CardValue.ten),
      ]);
      state.cascades[1].add(_card(Suit.spades, CardValue.jack));

      for (int index = 2; index < state.cascades.length; index++) {
        state.cascades[index].add(_card(Suit.clubs, CardValue.king));
      }

      final hint = FreeCellAdvisor.bestHint(state);

      expect(hint.kind, FreeCellHintKind.moveToFreecell);
      expect(hint.sourceZone, FreeCellHintSourceZone.cascade);
      expect(hint.sourceIndex, 0);
      expect(hint.cards, hasLength(1));
      expect(hint.cards.single.card.value, CardValue.ten);
    },
  );

  test('best hint still prefers moves to foundation', () {
    final state = _emptyState();

    state.cascades[0].add(_card(Suit.spades, CardValue.ace));
    state.cascades[1].addAll([
      _card(Suit.clubs, CardValue.jack),
      _card(Suit.hearts, CardValue.ten),
    ]);
    state.cascades[2].add(_card(Suit.spades, CardValue.jack));

    for (int index = 3; index < state.cascades.length; index++) {
      state.cascades[index].add(_card(Suit.clubs, CardValue.king));
    }

    final hint = FreeCellAdvisor.bestHint(state);

    expect(hint.kind, FreeCellHintKind.moveToFoundation);
    expect(hint.sourceZone, FreeCellHintSourceZone.cascade);
    expect(hint.sourceIndex, 0);
    expect(hint.cards, hasLength(1));
    expect(hint.cards.single.card.value, CardValue.ace);
  });
}
