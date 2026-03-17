import 'package:classic_suite/games/pyramid/pyramid_game.dart';
import 'package:classic_suite/games/pyramid/pyramid_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PyramidCard _card(PyramidSuit suit, PyramidRank rank, {bool removed = false}) {
  return PyramidCard(suit: suit, rank: rank, removed: removed);
}

Widget _buildHarness({PyramidGameState? state}) {
  return MaterialApp(home: PyramidGame(initialState: state));
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

  testWidgets('launcher shows Pyramid Solitaire and navigates', (tester) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Pyramid Solitaire'), findsOneWidget);

    await tester.tap(find.text('Pyramid Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byType(PyramidGame), findsOneWidget);
    expect(find.byKey(const Key('pyramid_status_message')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_stock')), findsOneWidget);
  });

  testWidgets('tapping a valid pair clears both cards', (tester) async {
    await tester.pumpWidget(_buildHarness(state: _buildPairReadyState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_card_0_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pyramid_waste_card')));
    await tester.pumpAndSettle();

    expect(find.text('You won'), findsOneWidget);
  });

  testWidgets('stock tap draws a waste card and undo restores it', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_stock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pyramid_waste_card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pyramid_undo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pyramid_waste_card')), findsNothing);
  });

  testWidgets('pause overlay appears and can resume', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_pause')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pyramid_pause_overlay')), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pyramid_pause_overlay')), findsNothing);
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

  testWidgets('statistics dialog shows updated best time after a win', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(state: _buildPairReadyState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_card_0_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pyramid_waste_card')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Game menu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistics').last);
    await tester.pumpAndSettle();

    expect(find.text('Pyramid Solitaire statistics'), findsOneWidget);
    expect(find.text('Best time'), findsOneWidget);
    expect(find.text('00:12'), findsWidgets);
  });
}
