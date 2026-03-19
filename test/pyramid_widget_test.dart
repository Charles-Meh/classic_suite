import 'package:classic_suite/games/pyramid/pyramid_game.dart';
import 'package:classic_suite/games/pyramid/pyramid_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PyramidCard _card(PyramidSuit suit, PyramidRank rank, {bool removed = false}) {
  return PyramidCard(suit: suit, rank: rank, removed: removed);
}

PyramidGameState _buildPairReadyState() {
  return PyramidGameState.debug(
    pyramid: [
      [_card(PyramidSuit.hearts, PyramidRank.five)],
      [
        _card(PyramidSuit.spades, PyramidRank.ace, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.two, removed: true),
      ],
      [
        _card(PyramidSuit.clubs, PyramidRank.three, removed: true),
        _card(PyramidSuit.diamonds, PyramidRank.four, removed: true),
        _card(PyramidSuit.spades, PyramidRank.five, removed: true),
      ],
      [
        _card(PyramidSuit.clubs, PyramidRank.six, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.seven, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.eight, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.nine, removed: true),
      ],
      [
        _card(PyramidSuit.clubs, PyramidRank.ten, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.jack, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.queen, removed: true),
        _card(PyramidSuit.clubs, PyramidRank.king, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.ace, removed: true),
      ],
      [
        _card(PyramidSuit.hearts, PyramidRank.two, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.three, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.four, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.six, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.seven, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.eight, removed: true),
      ],
      [
        _card(PyramidSuit.hearts, PyramidRank.nine, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.ten, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.jack, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.queen, removed: true),
        _card(PyramidSuit.hearts, PyramidRank.king, removed: true),
        _card(PyramidSuit.spades, PyramidRank.ace, removed: true),
        _card(PyramidSuit.spades, PyramidRank.two, removed: true),
      ],
    ],
    waste: [_card(PyramidSuit.spades, PyramidRank.eight)],
    elapsedSeconds: 12,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state is restored on launch', (tester) async {
    final saved = PyramidGameState.debug(
      pyramid: _buildPairReadyState().pyramid,
      waste: [_card(PyramidSuit.spades, PyramidRank.eight)],
      elapsedSeconds: 33,
      selectedCard: const PyramidCardRef.waste(0),
      paused: true,
    );
    SharedPreferences.setMockInitialValues({
      PyramidGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: PyramidGame()));
    await tester.pumpAndSettle();

    expect(find.text('00:33'), findsOneWidget);
    expect(find.byKey(const Key('pyramid_pause_overlay')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_waste_card')), findsOneWidget);
  });
}
