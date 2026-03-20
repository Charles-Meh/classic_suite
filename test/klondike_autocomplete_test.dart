import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_autocomplete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

void main() {
  test('autocomplete finishes an obviously won position', () {
    final state = _buildAlmostWonState();

    expect(KlondikeAutocomplete.canAutocomplete(state), isTrue);
    expect(KlondikeAutocomplete.finish(state), isTrue);
    expect(state.isWon, isTrue);
  });

  test('autocomplete stays available once tableau is fully revealed', () {
    final state = _buildStockDrawState();

    expect(KlondikeAutocomplete.canAutocomplete(state), isTrue);
    expect(KlondikeAutocomplete.finish(state), isTrue);
  });

  test('autocomplete stays hidden when a face-down tableau card remains', () {
    final state = _buildAlmostWonState();
    state.tableau[0].insert(
      0,
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.ace), faceUp: false),
    );

    expect(KlondikeAutocomplete.canAutocomplete(state), isFalse);
  });

  test('autocomplete finishes revealed endgames that require recycling waste', () {
    final state = _buildWasteRecycleState();

    expect(KlondikeAutocomplete.canAutocomplete(state), isTrue);
    expect(KlondikeAutocomplete.finish(state), isTrue);
    expect(state.isWon, isTrue);
  });

  test('applyNextMove cycles stock and waste during autocomplete', () {
    final state = _buildWasteRecycleState();

    var steps = 0;
    while (steps < 20 && KlondikeAutocomplete.applyNextMove(state)) {
      steps += 1;
    }

    expect(state.isWon, isTrue);
    expect(steps, greaterThan(0));
  });
}

GameState _buildAlmostWonState() {
  final state = GameState();
  _clearState(state);

  for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
    _addFoundationRange(state, suit, _allValues);
  }
  _addFoundationRange(state, Suit.spades, _allValuesWithoutKing);

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
  );
  return state;
}

GameState _buildStockDrawState() {
  final state = GameState();
  _clearState(state);

  for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
    _addFoundationRange(state, suit, _allValues);
  }
  _addFoundationRange(state, Suit.spades, _allValuesWithoutKing);
  state.stock.add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: false),
  );
  return state;
}

GameState _buildWasteRecycleState() {
  final state = GameState();
  _clearState(state);

  _addFoundationRange(state, Suit.clubs, _valuesThroughJack);
  _addFoundationRange(state, Suit.diamonds, _allValuesWithoutKing);
  _addFoundationRange(state, Suit.hearts, _allValuesWithoutKing);
  _addFoundationRange(state, Suit.spades, _allValuesWithoutKing);

  state.waste.addAll([
    KlondikeCard(PlayingCard(Suit.clubs, CardValue.queen), faceUp: true),
    KlondikeCard(PlayingCard(Suit.hearts, CardValue.king), faceUp: true),
  ]);
  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.clubs, CardValue.king), faceUp: true),
  );
  state.tableau[1].add(
    KlondikeCard(PlayingCard(Suit.diamonds, CardValue.king), faceUp: true),
  );
  state.tableau[2].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
  );
  return state;
}

void _clearState(GameState state) {
  state.stock.clear();
  state.waste.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  for (final pile in state.foundations) {
    pile.clear();
  }
}

void _addFoundationRange(
  GameState state,
  Suit suit,
  Iterable<CardValue> values,
) {
  for (final value in values) {
    state
        .foundationForSuit(suit)
        .add(KlondikeCard(PlayingCard(suit, value), faceUp: true));
  }
}

const List<CardValue> _allValues = [
  CardValue.ace,
  CardValue.two,
  CardValue.three,
  CardValue.four,
  CardValue.five,
  CardValue.six,
  CardValue.seven,
  CardValue.eight,
  CardValue.nine,
  CardValue.ten,
  CardValue.jack,
  CardValue.queen,
  CardValue.king,
];

const List<CardValue> _allValuesWithoutKing = [
  CardValue.ace,
  CardValue.two,
  CardValue.three,
  CardValue.four,
  CardValue.five,
  CardValue.six,
  CardValue.seven,
  CardValue.eight,
  CardValue.nine,
  CardValue.ten,
  CardValue.jack,
  CardValue.queen,
];

const List<CardValue> _valuesThroughJack = [
  CardValue.ace,
  CardValue.two,
  CardValue.three,
  CardValue.four,
  CardValue.five,
  CardValue.six,
  CardValue.seven,
  CardValue.eight,
  CardValue.nine,
  CardValue.ten,
  CardValue.jack,
];
