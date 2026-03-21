import 'package:classic_suite/games/pyramid/pyramid_advisor.dart';
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

List<List<PyramidCard>> _clearedPyramid() {
  return _filledPyramid().map((row) {
    return row.map((card) => card.copyWith(removed: true)).toList();
  }).toList();
}

void main() {
  test('best hint prefers removing an exposed king', () {
    final pyramid = _clearedPyramid();
    pyramid[6][2] = _card(PyramidSuit.hearts, PyramidRank.king);
    pyramid[6][3] = _card(PyramidSuit.spades, PyramidRank.five);
    final state = PyramidGameState.debug(
      pyramid: pyramid,
      waste: [_card(PyramidSuit.clubs, PyramidRank.eight)],
    );

    final hint = PyramidAdvisor.bestHint(state);

    expect(hint, isNotNull);
    expect(hint!.cardRef, const PyramidCardRef.pyramid(6, 2));
  });

  test('best hint prefers a waste pair before a pyramid-only pair', () {
    final pyramid = _clearedPyramid();
    pyramid[6][0] = _card(PyramidSuit.hearts, PyramidRank.five);
    pyramid[6][1] = _card(PyramidSuit.spades, PyramidRank.six);
    pyramid[6][2] = _card(PyramidSuit.clubs, PyramidRank.seven);
    final state = PyramidGameState.debug(
      pyramid: pyramid,
      waste: [_card(PyramidSuit.diamonds, PyramidRank.eight)],
    );

    final hint = PyramidAdvisor.bestHint(state);

    expect(hint, isNotNull);
    expect(hint!.cardRef, const PyramidCardRef.pyramid(6, 0));
  });

  test('best hint returns null when no playable move exists', () {
    final pyramid = _clearedPyramid();
    pyramid[6][0] = _card(PyramidSuit.hearts, PyramidRank.ace);
    pyramid[6][1] = _card(PyramidSuit.spades, PyramidRank.three);
    final state = PyramidGameState.debug(pyramid: pyramid);

    final hint = PyramidAdvisor.bestHint(state);

    expect(hint, isNull);
  });
}
