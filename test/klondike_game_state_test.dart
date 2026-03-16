import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/solver.dart';
import 'package:classic_suite/games/klondike/winnable_seed_data.dart';

void main() {
  test('new game has 7 tableau piles with increasing face-up cards', () {
    final state = GameState();
    expect(state.tableau.length, 7);
    for (var i = 0; i < 7; i++) {
      // pile size should be i+1
      expect(state.tableau[i].length, i + 1);
      // top card of each pile should be face-up
      expect(state.tableau[i].last.faceUp, isTrue);
      // all others should be face-down
      for (var j = 0; j < state.tableau[i].length - 1; j++) {
        expect(state.tableau[i][j].faceUp, isFalse);
      }
    }
    // stock should have remaining cards
    expect(state.stock.isNotEmpty, isTrue);
    // waste should be empty at start
    expect(state.waste, isEmpty);
  });

  test('drawing from stock moves card to waste', () {
    final state = GameState();
    final initialStock = List.of(state.stock);
    final moved = state.drawFromStock();
    expect(moved, greaterThan(0));
    expect(state.waste.length, moved);
    expect(state.stock.length, initialStock.length - moved);
    expect(state.waste.every((c) => c.faceUp), isTrue);
  });

  test('drawing three cards moves up to three cards into waste', () {
    final state = GameState(drawCount: 3);
    final moved = state.drawFromStock();

    expect(moved, 3);
    expect(state.waste.length, 3);
    expect(state.waste.every((c) => c.faceUp), isTrue);
  });

  test('winnable seed deal keeps a standard Klondike opening layout', () {
    expect(kWinnableDrawOneSeeds, isNotEmpty);

    final state = GameState(drawCount: 1);
    state.dealWinnableGame(kWinnableDrawOneSeeds.first);

    expect(state.stock, hasLength(24));
    expect(state.waste, isEmpty);
    expect(state.foundations.every((pile) => pile.isEmpty), isTrue);

    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      expect(pile, hasLength(pileIndex + 1));
      for (int cardIndex = 0; cardIndex < pile.length - 1; cardIndex++) {
        expect(pile[cardIndex].faceUp, isFalse);
      }
      expect(pile.last.faceUp, isTrue);
    }
  });

  test(
    'every bundled winnable seed is unique and confirmed by the full solver',
    () {
      final solver = KlondikeSolver();

      expect(
        kWinnableDrawOneSeeds.toSet(),
        hasLength(kWinnableDrawOneSeeds.length),
      );
      expect(
        kWinnableDrawThreeSeeds.toSet(),
        hasLength(kWinnableDrawThreeSeeds.length),
      );

      for (final seed in kWinnableDrawOneSeeds) {
        final state = GameState(drawCount: 1)..dealWinnableGame(seed);
        expect(solver.isSolvable(state), isTrue, reason: 'draw 1 seed $seed');
      }

      for (final seed in kWinnableDrawThreeSeeds) {
        final state = GameState(drawCount: 3)..dealWinnableGame(seed);
        expect(solver.isSolvable(state), isTrue, reason: 'draw 3 seed $seed');
      }
    },
  );

  test('can move ace to empty foundation', () {
    final state = GameState();
    // create an ace and try moving
    final aceCard = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.ace),
      faceUp: true,
    );
    state.waste.add(aceCard);
    expect(state.canMoveToFoundation(aceCard), isTrue);
    expect(state.moveToFoundation(aceCard), isTrue);
    expect(state.foundationForSuit(Suit.hearts).last, aceCard);
    expect(state.waste, isEmpty);
  });

  test('can stack two of hearts onto ace of hearts foundation', () {
    final state = GameState();
    state.waste.clear();
    state.stock.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final ace = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.ace),
      faceUp: true,
    );
    final two = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.two),
      faceUp: true,
    );

    state.waste.add(ace);
    expect(state.moveToFoundation(ace), isTrue);

    state.waste.add(two);
    expect(state.canMoveToFoundation(two), isTrue);
    expect(state.moveToFoundation(two), isTrue);
    expect(
      state.foundationForSuit(Suit.hearts).map((card) => card.card.value),
      [CardValue.ace, CardValue.two],
    );
  });

  test('cannot move non-ace to empty foundation', () {
    final state = GameState();
    final card = KlondikeCard(
      PlayingCard(Suit.clubs, CardValue.king),
      faceUp: true,
    );
    state.waste.add(card);
    expect(state.canMoveToFoundation(card), isFalse);
  });

  test('tableau stacking and legal move', () {
    final state = GameState();
    // clear piles and set up custom scenario: king on pile0, queen of opposite color on pile1
    for (final pile in state.tableau) {
      pile.clear();
    }
    final king = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.king),
      faceUp: true,
    );
    final queenRed = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.queen),
      faceUp: true,
    );
    state.tableau[0].add(king);
    state.tableau[1].add(queenRed);
    expect(state.canMoveStackToTableau(queenRed, state.tableau[0]), isTrue);
    expect(state.moveStackToTableau(queenRed, state.tableau[0]), isTrue);
    expect(state.tableau[0].last, queenRed);
    expect(state.tableau[1], isEmpty);
  });

  test('moving tableau card to foundation flips exposed card', () {
    final state = GameState();
    state.waste.clear();
    state.stock.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final hiddenTwo = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.two),
      faceUp: false,
    );
    final ace = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.ace),
      faceUp: true,
    );

    state.tableau[0].addAll([hiddenTwo, ace]);

    expect(state.moveToFoundation(ace), isTrue);
    expect(state.foundationForSuit(Suit.hearts), contains(ace));
    expect(state.tableau[0].single, hiddenTwo);
    expect(hiddenTwo.faceUp, isTrue);
  });

  test('waste top card can move to tableau', () {
    final state = GameState();
    state.waste.clear();
    state.stock.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final wasteCard = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.six),
      faceUp: true,
    );
    final destination = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.seven),
      faceUp: true,
    );

    state.waste.add(wasteCard);
    state.tableau[0].add(destination);

    expect(state.canMoveCardsToTableau([wasteCard], state.tableau[0]), isTrue);
    expect(state.moveCardsToTableau([wasteCard], state.tableau[0]), isTrue);
    expect(state.waste, isEmpty);
    expect(state.tableau[0].last, wasteCard);
  });

  test('non-top tableau card cannot move to foundation', () {
    final state = GameState();
    state.waste.clear();
    state.stock.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final ace = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.ace),
      faceUp: true,
    );
    final two = KlondikeCard(
      PlayingCard(Suit.clubs, CardValue.two),
      faceUp: true,
    );

    state.tableau[0].addAll([ace, two]);

    expect(state.canMoveToFoundation(ace), isFalse);
    expect(state.moveToFoundation(ace), isFalse);
    expect(state.tableau[0], [ace, two]);
  });

  test('foundation top card can move back to tableau', () {
    final state = GameState();
    state.waste.clear();
    state.stock.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final foundationCard = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.six),
      faceUp: true,
    );
    final destination = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.seven),
      faceUp: true,
    );

    state.foundations[Suit.hearts.index].add(foundationCard);
    state.tableau[0].add(destination);

    expect(
      state.canMoveCardsToTableau([foundationCard], state.tableau[0]),
      isTrue,
    );
    expect(
      state.moveCardsToTableau([foundationCard], state.tableau[0]),
      isTrue,
    );
    expect(state.foundationForSuit(Suit.hearts), isEmpty);
    expect(state.tableau[0].last, foundationCard);
  });
}
