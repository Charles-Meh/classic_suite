import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/spider/spider_game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

void main() {
  test('new spider deal has 10 tableau piles and 50 stock cards', () {
    final state = SpiderGameState();

    expect(state.tableau, hasLength(10));
    expect(state.stock, hasLength(50));
    expect(state.completedRuns, isEmpty);

    final expectedPileLengths = [6, 6, 6, 6, 5, 5, 5, 5, 5, 5];
    for (int index = 0; index < state.tableau.length; index++) {
      final pile = state.tableau[index];
      expect(pile, hasLength(expectedPileLengths[index]));
      for (int cardIndex = 0; cardIndex < pile.length - 1; cardIndex++) {
        expect(pile[cardIndex].faceUp, isFalse);
      }
      expect(pile.last.faceUp, isTrue);
    }
  });

  test('only same-suit descending runs can move together', () {
    final state = SpiderGameState();
    state.stock.clear();
    for (final pile in state.tableau) {
      pile.clear();
    }

    final seven = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.seven),
      faceUp: true,
    );
    final six = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.six),
      faceUp: true,
    );
    final mixedFive = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.five),
      faceUp: true,
    );
    final target = KlondikeCard(
      PlayingCard(Suit.clubs, CardValue.eight),
      faceUp: true,
    );

    state.tableau[0].addAll([seven, six]);
    state.tableau[1].add(target);
    state.tableau[2].addAll([seven.copyWith(), mixedFive]);

    expect(state.canPickUpRun(0, 0), isTrue);
    expect(state.canMoveCardsToTableau([seven, six], state.tableau[1]), isTrue);
    expect(state.moveCardsToTableau([seven, six], state.tableau[1]), isTrue);

    final mixedRun = state.tableau[2].sublist(0);
    expect(state.canPickUpRun(2, 0), isFalse);
    expect(state.canMoveCardsToTableau(mixedRun, state.tableau[1]), isFalse);
  });

  test('completed king-to-ace run is removed automatically', () {
    final state = SpiderGameState();
    state.stock.clear();
    for (final pile in state.tableau) {
      pile.clear();
    }

    final destinationPile = <KlondikeCard>[];
    for (final value in [
      CardValue.king,
      CardValue.queen,
      CardValue.jack,
      CardValue.ten,
      CardValue.nine,
      CardValue.eight,
      CardValue.seven,
      CardValue.six,
      CardValue.five,
      CardValue.four,
      CardValue.three,
    ]) {
      destinationPile.add(
        KlondikeCard(PlayingCard(Suit.spades, value), faceUp: true),
      );
    }
    state.tableau[0].addAll(destinationPile);

    final two = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.two),
      faceUp: true,
    );
    final ace = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.ace),
      faceUp: true,
    );
    state.tableau[1].addAll([two, ace]);

    expect(state.moveCardsToTableau([two, ace], state.tableau[0]), isTrue);
    expect(state.tableau[0], isEmpty);
    expect(state.completedRuns, hasLength(1));
    expect(state.completedRuns.single.first.card.value, CardValue.king);
    expect(state.completedRuns.single.last.card.value, CardValue.ace);
  });

  test('cannot deal from stock while any tableau pile is empty', () {
    final state = SpiderGameState();
    state.tableau[0].clear();

    expect(state.canDealFromStock, isFalse);
    expect(state.dealFromStock(), isFalse);
  });

  test('won state requires eight completed runs', () {
    final state = SpiderGameState();
    state.stock.clear();
    for (final pile in state.tableau) {
      pile.clear();
    }
    state.completedRuns
      ..clear()
      ..addAll(
        List.generate(
          8,
          (_) => [
            KlondikeCard(
              PlayingCard(Suit.spades, CardValue.king),
              faceUp: true,
            ),
          ],
        ),
      );

    expect(state.isWon, isTrue);
  });
}
