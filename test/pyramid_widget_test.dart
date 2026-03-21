import 'package:classic_suite/games/pyramid/pyramid_game.dart';
import 'package:classic_suite/games/pyramid/pyramid_game_state.dart';
import 'package:classic_suite/shared/classic_game_ui.dart';
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

PyramidGameState _buildHintReadyState() {
  return _buildPairReadyState().copyWith(
    stock: [
      _card(PyramidSuit.hearts, PyramidRank.ace),
      _card(PyramidSuit.clubs, PyramidRank.two),
      _card(PyramidSuit.spades, PyramidRank.three),
    ],
  );
}

ClassicPlayingCard _cardWidget(WidgetTester tester, Key key) {
  return tester.widget<ClassicPlayingCard>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(ClassicPlayingCard),
    ),
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
      cycleCount: 2,
    );
    SharedPreferences.setMockInitialValues({
      PyramidGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: PyramidGame()));
    await tester.pumpAndSettle();

    expect(find.text('00:33'), findsOneWidget);
    expect(find.byKey(const Key('pyramid_top_shelf')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_help_action')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_settings_action')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_pause_overlay')), findsNothing);
    expect(find.byKey(const Key('pyramid_pause')), findsNothing);
    expect(find.byKey(const Key('pyramid_status_message')), findsNothing);
    expect(find.text('Cycles'), findsNothing);
    expect(find.text('Waste'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    expect(find.text('Pyramid Solitaire'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Hint'), findsOneWidget);
    expect(find.byTooltip('Statistics'), findsOneWidget);
    expect(find.byKey(const Key('pyramid_waste_card')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_stock_count')), findsOneWidget);
  });

  testWidgets('settings action opens pyramid settings dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PyramidGame(initialState: _buildPairReadyState())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_settings_action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pyramid_settings_dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('pyramid_restart_deal_action')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pyramid_new_deal_action')), findsOneWidget);
  });

  testWidgets('selecting a card does not auto-highlight its matching partner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PyramidGame(initialState: _buildPairReadyState())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pyramid_waste_card')));
    await tester.pump();

    final pyramidCard = _cardWidget(tester, const Key('pyramid_card_0_0'));
    final wasteCard = _cardWidget(tester, const Key('pyramid_waste_card'));

    expect(pyramidCard.highlightColor, isNull);
    expect(wasteCard.highlightColor, isNotNull);
  });

  testWidgets('removed pyramid cards do not leave visible placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PyramidGame(initialState: _buildPairReadyState())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClassicCardPlaceholder), findsNothing);
    expect(find.byKey(const Key('pyramid_card_0_0')), findsOneWidget);
    expect(find.byKey(const Key('pyramid_waste_card')), findsOneWidget);
  });

  testWidgets('hint highlights one card without drawing from stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PyramidGame(initialState: _buildHintReadyState())),
    );
    await tester.pumpAndSettle();

    final stockCountBefore = tester.widget<Text>(
      find.byKey(const Key('pyramid_stock_count')),
    );
    expect(stockCountBefore.data, '3');

    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();

    final stockCountAfter = tester.widget<Text>(
      find.byKey(const Key('pyramid_stock_count')),
    );
    final pyramidCard = _cardWidget(tester, const Key('pyramid_card_0_0'));
    final wasteCard = _cardWidget(tester, const Key('pyramid_waste_card'));

    expect(stockCountAfter.data, '3');
    expect(pyramidCard.highlightColor, isNotNull);
    expect(wasteCard.highlightColor, isNull);
  });
}
