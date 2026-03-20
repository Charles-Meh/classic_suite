import 'package:classic_suite/games/tripeaks/tripeaks_advisor.dart';
import 'package:classic_suite/games/tripeaks/tripeaks_game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

TriPeaksCard _card(CardValue value, [Suit suit = Suit.spades]) {
  return TriPeaksCard(card: PlayingCard(suit, value));
}

void main() {
  test('new game deals 28 tableau cards, 23 stock cards, and 1 waste card', () {
    final state = TriPeaksGameState.newGame(seed: 7);

    expect(state.tableau, hasLength(28));
    expect(state.tableau.whereType<TriPeaksCard>(), hasLength(28));
    expect(state.stock, hasLength(23));
    expect(state.waste, hasLength(1));
    expect(state.exposedIndexes, hasLength(10));
    expect(
      state.exposedIndexes,
      equals([18, 19, 20, 21, 22, 23, 24, 25, 26, 27]),
    );
  });

  test('top cards stay blocked until both children are removed', () {
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[0] = _card(CardValue.queen);
    tableau[3] = _card(CardValue.jack);
    tableau[4] = _card(CardValue.ten);

    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: const [],
      waste: [_card(CardValue.king)],
    );

    expect(state.isExposed(0), isFalse);

    final afterOne = state.copyWith(tableau: [...tableau]..[3] = null);
    expect(afterOne.isExposed(0), isFalse);

    final afterTwo = state.copyWith(
      tableau: [...tableau]
        ..[3] = null
        ..[4] = null,
    );
    expect(afterTwo.isExposed(0), isTrue);
  });

  test('adjacent rank check supports ace and king wrap', () {
    expect(TriPeaksGameState.ranksAreAdjacent(1, 13), isTrue);
    expect(TriPeaksGameState.ranksAreAdjacent(13, 1), isTrue);
    expect(TriPeaksGameState.ranksAreAdjacent(1, 2), isTrue);
    expect(TriPeaksGameState.ranksAreAdjacent(1, 12), isFalse);
  });

  test('removing a valid card scores based on current run', () {
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[18] = _card(CardValue.eight);
    tableau[19] = _card(CardValue.seven);

    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: const [],
      waste: [_card(CardValue.nine)],
    );

    final next = state.removeCard(18);
    expect(next.tableau[18], isNull);
    expect(next.wasteTop.card.value, CardValue.eight);
    expect(next.score, 100);
    expect(next.currentRun, 1);

    final third = next.removeCard(19);
    expect(third.score, 300);
    expect(third.currentRun, 2);
    expect(third.longestRun, 2);
  });

  test('drawing from stock resets the current run and can end a dead game', () {
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[18] = _card(CardValue.five);

    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: [_card(CardValue.king)],
      waste: [_card(CardValue.nine)],
      currentRun: 3,
      score: 600,
    );

    final next = state.drawFromStock();
    expect(next.stock, isEmpty);
    expect(next.currentRun, 0);
    expect(next.wasteTop.card.value, CardValue.king);
    expect(next.status, TriPeaksStatus.lost);
  });

  test('advisor prefers the first playable exposed card', () {
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[18] = _card(CardValue.eight);
    tableau[19] = _card(CardValue.seven);

    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: [_card(CardValue.queen)],
      waste: [_card(CardValue.nine)],
    );

    final hint = TriPeaksAdvisor.bestHint(state);

    expect(hint.kind, TriPeaksHintKind.removeCard);
    expect(hint.tableauIndex, 18);
  });

  test('advisor falls back to the stock when no tableau move is available', () {
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[18] = _card(CardValue.five);

    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: [_card(CardValue.king)],
      waste: [_card(CardValue.nine)],
    );

    final hint = TriPeaksAdvisor.bestHint(state);

    expect(hint.kind, TriPeaksHintKind.drawStock);
    expect(hint.tableauIndex, isNull);
  });

  test('encode and decode round-trip preserves state', () {
    final original = TriPeaksGameState.newGame(
      seed: 42,
    ).withElapsedSeconds(31).togglePaused();

    final decoded = TriPeaksGameState.tryDecode(original.encode());

    expect(decoded, isNotNull);
    expect(decoded!.elapsedSeconds, 31);
    expect(decoded.paused, isTrue);
    expect(decoded.seed, original.seed);
    expect(decoded.stock.length, original.stock.length);
    expect(decoded.tableau.whereType<TriPeaksCard>().length, 28);
  });
}
