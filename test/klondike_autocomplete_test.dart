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

  test('autocomplete stays hidden while stock cards remain', () {
    final state = _buildAlmostWonState();
    state.stock.add(
      KlondikeCard(PlayingCard(Suit.clubs, CardValue.ace), faceUp: false),
    );

    expect(KlondikeAutocomplete.canAutocomplete(state), isFalse);
  });

  test('autocomplete stays hidden when a face-down tableau card remains', () {
    final state = _buildAlmostWonState();
    state.tableau[0].insert(
      0,
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.ace), faceUp: false),
    );

    expect(KlondikeAutocomplete.canAutocomplete(state), isFalse);
  });
}

GameState _buildAlmostWonState() {
  final state = GameState();
  state.stock.clear();
  state.waste.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  for (final pile in state.foundations) {
    pile.clear();
  }

  final fullFoundationValues = [
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
  final nearCompleteFoundationValues = fullFoundationValues
      .where((value) => value != CardValue.king)
      .toList();

  for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
    for (final value in fullFoundationValues) {
      state
          .foundationForSuit(suit)
          .add(KlondikeCard(PlayingCard(suit, value), faceUp: true));
    }
  }
  for (final value in nearCompleteFoundationValues) {
    state
        .foundationForSuit(Suit.spades)
        .add(KlondikeCard(PlayingCard(Suit.spades, value), faceUp: true));
  }

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
  );
  return state;
}
