import 'package:classic_suite/games/pyramid/pyramid_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

PyramidCard _card(PyramidSuit suit, PyramidRank rank, {bool removed = false}) {
  return PyramidCard(suit: suit, rank: rank, removed: removed);
}

List<List<PyramidCard>> _filledPyramid() {
  final values = PyramidRank.values;
  return List<List<PyramidCard>>.generate(
    7,
    (row) => List<PyramidCard>.generate(
      row + 1,
      (column) => _card(
        PyramidSuit.values[(row + column) % PyramidSuit.values.length],
        values[(row + column) % values.length],
      ),
    ),
  );
}

void main() {
  test('new game deals a 28-card pyramid and 24-card stock', () {
    final state = PyramidGameState.newGame(seed: 123);

    expect(state.pyramid.length, 7);
    expect(state.pyramid[0], hasLength(1));
    expect(state.pyramid[6], hasLength(7));
    expect(state.pyramid.expand((row) => row), hasLength(28));
    expect(state.stock, hasLength(24));
    expect(state.waste, isEmpty);
  });

  test('only uncovered cards are exposed', () {
    final pyramid = _filledPyramid();
    pyramid[2][0] = pyramid[2][0].copyWith(removed: true);
    pyramid[2][1] = pyramid[2][1].copyWith(removed: true);

    final state = PyramidGameState.debug(pyramid: pyramid);

    expect(state.isExposed(0, 0), isFalse);
    expect(state.isExposed(1, 0), isTrue);
    expect(state.isExposed(1, 1), isFalse);
    expect(state.isExposed(6, 4), isTrue);
  });

  test('kings can be removed by themselves', () {
    final pyramid = _filledPyramid();
    pyramid[6][6] = _card(PyramidSuit.hearts, PyramidRank.king);
    final state = PyramidGameState.debug(pyramid: pyramid);

    final next = state.tapCard(const PyramidCardRef.pyramid(6, 6));

    expect(next.pyramid[6][6].removed, isTrue);
    expect(next.message, 'King cleared.');
  });

  test('matching exposed cards that total 13 removes both', () {
    final pyramid = _filledPyramid();
    pyramid[6][0] = _card(PyramidSuit.hearts, PyramidRank.five);
    final state = PyramidGameState.debug(
      pyramid: pyramid,
      waste: [_card(PyramidSuit.spades, PyramidRank.eight)],
    );

    final selected = state.tapCard(const PyramidCardRef.pyramid(6, 0));
    final cleared = selected.tapCard(const PyramidCardRef.waste(0));

    expect(cleared.pyramid[6][0].removed, isTrue);
    expect(cleared.waste, isEmpty);
    expect(cleared.message, 'Match cleared.');
  });

  test('drawing cycles stock into waste and recycles waste back to stock', () {
    final pyramid = _filledPyramid().map((row) {
      return row.map((card) => card.copyWith(removed: true)).toList();
    }).toList();
    final state = PyramidGameState.debug(
      pyramid: pyramid,
      stock: [
        _card(PyramidSuit.hearts, PyramidRank.ace),
        _card(PyramidSuit.spades, PyramidRank.king),
      ],
    );

    final afterFirstDraw = state.drawFromStock();
    final afterSecondDraw = afterFirstDraw.drawFromStock();
    final afterRecycle = afterSecondDraw.drawFromStock();

    expect(afterFirstDraw.stock, hasLength(1));
    expect(afterFirstDraw.wasteTop!.rank, PyramidRank.king);
    expect(afterSecondDraw.stock, isEmpty);
    expect(afterSecondDraw.waste, hasLength(2));
    expect(afterRecycle.stock, hasLength(2));
    expect(afterRecycle.waste, isEmpty);
    expect(afterRecycle.cycleCount, 1);
  });

  test('winning clears the pyramid and marks the game complete', () {
    final pyramid = _filledPyramid().map((row) {
      return row.map((card) => card.copyWith(removed: true)).toList();
    }).toList();
    pyramid[6][0] = _card(PyramidSuit.hearts, PyramidRank.five);
    final state = PyramidGameState.debug(
      pyramid: pyramid,
      waste: [_card(PyramidSuit.spades, PyramidRank.eight)],
    );

    final next = state
        .tapCard(const PyramidCardRef.pyramid(6, 0))
        .tapCard(const PyramidCardRef.waste(0));

    expect(next.isWon, isTrue);
    expect(next.message, 'Pyramid cleared. You win.');
  });

  test('encoding and decoding preserve selection and pause state', () {
    final state = PyramidGameState.debug(
      pyramid: _filledPyramid(),
      waste: [_card(PyramidSuit.hearts, PyramidRank.queen)],
      elapsedSeconds: 37,
      selectedCard: const PyramidCardRef.waste(0),
      paused: true,
      cycleCount: 2,
    );

    final restored = PyramidGameState.tryDecode(state.encode());

    expect(restored, isNotNull);
    expect(restored!.elapsedSeconds, 37);
    expect(restored.selectedCard, const PyramidCardRef.waste(0));
    expect(restored.paused, isTrue);
    expect(restored.cycleCount, 2);
  });
}
