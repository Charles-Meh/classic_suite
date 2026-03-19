import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classic_suite/core/game_list_page.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_advisor.dart';
import 'package:classic_suite/games/klondike/klondike_game.dart';
import 'package:classic_suite/main.dart';
import 'package:classic_suite/shared/game_definition.dart';
import 'package:playing_cards/playing_cards.dart';

Widget _buildKlondikeHarness(GameState state) {
  return MaterialApp(home: KlondikeGame(initialState: state));
}

Widget _buildLauncherHarness() {
  return MaterialApp(
    home: GameListPage(
      games: [
        GameDefinition(
          title: 'Klondike Solitaire',
          builder: (_) => const KlondikeGame(),
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Klondike Solitaire and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Klondike Solitaire'), findsOneWidget);

    await tester.tap(find.text('Klondike Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byType(KlondikeGame), findsOneWidget);
    expect(find.text('Klondike Solitaire'), findsWidgets);
  });

  testWidgets('launcher keeps only the title and search without subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildLauncherHarness());

    expect(find.text('Classic Suite'), findsOneWidget);
    expect(find.text('Choose a game'), findsNothing);
    expect(find.textContaining('Search once, tap once'), findsNothing);
    expect(find.byKey(const Key('game_search_field')), findsOneWidget);
  });

  testWidgets(
    'search field does not stay focused after returning from a game',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildLauncherHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('game_search_field')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await tester.tap(find.text('Klondike Solitaire'));
      await tester.pumpAndSettle();

      expect(find.byType(KlondikeGame), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(GameListPage), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    },
  );

  testWidgets('initial deal shows non-empty tableau and stock', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());
    await tester.tap(find.text('Klondike Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stock')), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('tap stock draws a card into waste', (WidgetTester tester) async {
    await tester.pumpWidget(const ClassicSuiteApp());
    await tester.tap(find.text('Klondike Solitaire'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pump();

    expect(find.byKey(const Key('waste_draggable')), findsOneWidget);
  });

  testWidgets('foundations show visible placeholders on first load', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());
    await tester.tap(find.text('Klondike Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundation_0')), findsOneWidget);
    expect(find.byKey(const Key('foundation_1')), findsOneWidget);
    expect(find.byKey(const Key('foundation_2')), findsOneWidget);
    expect(find.byKey(const Key('foundation_3')), findsOneWidget);
  });

  testWidgets('hint button shows only visual suggestion markers', (
    WidgetTester tester,
  ) async {
    final state = GameState();
    state.stock.clear();
    state.waste.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    state.waste.add(
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.six), faceUp: true),
    );
    state.tableau[0].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.seven), faceUp: true),
    );

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hint_banner')), findsNothing);
    expect(find.textContaining('Move 6♥'), findsNothing);
    expect(find.byKey(const Key('hint_waste')), findsNothing);
    expect(find.byKey(const Key('tableau_0_drop_hint')), findsOneWidget);
  });

  test('advisor skips redundant tableau tap moves on already valid runs', () {
    final state = GameState();
    state.stock.clear();
    state.waste.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    state.tableau[0].addAll([
      KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.queen), faceUp: true),
      KlondikeCard(PlayingCard(Suit.spades, CardValue.jack), faceUp: true),
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.ten), faceUp: true),
      KlondikeCard(PlayingCard(Suit.spades, CardValue.nine), faceUp: true),
    ]);
    state.tableau[1].addAll([
      KlondikeCard(PlayingCard(Suit.clubs, CardValue.queen), faceUp: true),
      KlondikeCard(PlayingCard(Suit.diamonds, CardValue.jack), faceUp: true),
    ]);

    final move = KlondikeAdvisor.bestTapMove(state, state.tableau[0][3]);

    expect(move, isNull);
  });
}
