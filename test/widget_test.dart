import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classic_suite/core/game_list_page.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_advisor.dart';
import 'package:classic_suite/games/klondike/klondike_autocomplete.dart';
import 'package:classic_suite/games/klondike/klondike_game.dart';
import 'package:classic_suite/games/klondike/solver.dart';
import 'package:classic_suite/games/klondike/winnable_seed_data.dart';
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

Future<void> _launchKlondikeFromApp(WidgetTester tester) async {
  await tester.pumpWidget(const ClassicSuiteApp());
  await tester.tap(find.text('Klondike Solitaire'));
  await tester.pumpAndSettle();
}

Future<void> _applyKlondikeSettings(
  WidgetTester tester, {
  required String drawMode,
  required String dealType,
}) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();

  await tester.tap(find.text(drawMode));
  await tester.pumpAndSettle();
  await tester.tap(find.text(dealType));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Apply and deal'));
  await tester.pumpAndSettle();
}

Future<GameState> _readSavedKlondikeState() async {
  final prefs = await SharedPreferences.getInstance();
  final savedState = GameState.tryDecode(prefs.getString(GameState.storageKey));
  expect(savedState, isNotNull);
  return savedState!;
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

  testWidgets(
    'default Klondike launch persists a solvable draw-one winning deal',
    (WidgetTester tester) async {
      await _launchKlondikeFromApp(tester);

      final savedState = await _readSavedKlondikeState();

      expect(savedState.drawCount, 1);
      expect(savedState.currentSeed, isNotNull);
      expect(kWinnableDrawOneSeeds, contains(savedState.currentSeed));
      expect(KlondikeSolver().isSolvable(savedState), isTrue);
    },
  );

  testWidgets('Klondike settings can deal a solvable draw-three winning game', (
    WidgetTester tester,
  ) async {
    await _launchKlondikeFromApp(tester);
    await _applyKlondikeSettings(
      tester,
      drawMode: '3-card draw',
      dealType: 'Winning deal',
    );

    final savedState = await _readSavedKlondikeState();

    expect(savedState.drawCount, 3);
    expect(savedState.currentSeed, isNotNull);
    expect(kWinnableDrawThreeSeeds, contains(savedState.currentSeed));
    expect(KlondikeSolver().isSolvable(savedState), isTrue);
  });

  testWidgets('Klondike settings can deal a fresh random game', (
    WidgetTester tester,
  ) async {
    await _launchKlondikeFromApp(tester);
    await _applyKlondikeSettings(
      tester,
      drawMode: '1-card draw',
      dealType: 'Random deal',
    );

    final savedState = await _readSavedKlondikeState();

    expect(savedState.currentSeed, isNull);
    expect(savedState.stock, hasLength(24));
    expect(savedState.waste, isEmpty);
    expect(savedState.foundations.every((pile) => pile.isEmpty), isTrue);
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
    final state = _emptyKlondikeState();

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

  testWidgets('autocomplete button stays hidden with covered tableau cards', (
    WidgetTester tester,
  ) async {
    final hiddenState = _emptyKlondikeState();
    hiddenState.tableau[0].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: false),
    );

    await tester.pumpWidget(_buildKlondikeHarness(hiddenState));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('autocomplete_prompt')), findsNothing);
    expect(find.byKey(const Key('autocomplete_button')), findsNothing);
  });

  testWidgets('autocomplete prompt can be dismissed without running', (
    WidgetTester tester,
  ) async {
    final state = _buildAutocompleteReadyState();

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('autocomplete_prompt')), findsOneWidget);
    expect(find.byKey(const Key('autocomplete_button')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('autocomplete_prompt')), findsNothing);
    expect(find.byKey(const Key('autocomplete_button')), findsNothing);
    expect(find.byKey(const Key('win_overlay')), findsNothing);
  });

  testWidgets('autocomplete prompt appears and runs for revealed endgames', (
    WidgetTester tester,
  ) async {
    final state = _buildAutocompleteReadyState();

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    expect(KlondikeAutocomplete.canAutocomplete(state), isTrue);
    expect(find.byKey(const Key('autocomplete_prompt')), findsOneWidget);
    expect(find.byKey(const Key('autocomplete_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('autocomplete_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('win_overlay')), findsOneWidget);
    expect(find.byKey(const Key('autocomplete_button')), findsNothing);
  });

  test('advisor tap prefers foundation over tableau when both are valid', () {
    final state = _emptyKlondikeState();

    state.foundationForSuit(Suit.hearts).addAll([
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.ace), faceUp: true),
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.two), faceUp: true),
    ]);

    final threeHearts = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.three),
      faceUp: true,
    );
    state.tableau[0].add(threeHearts);
    state.tableau[1].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.four), faceUp: true),
    );

    final move = KlondikeAdvisor.bestTapMove(state, threeHearts);

    expect(move, isNotNull);
    expect(move!.kind, KlondikeSuggestionKind.moveToFoundation);
    expect(move.cards, [threeHearts]);
  });

  test('advisor tap ignores tableau-only moves', () {
    final state = _emptyKlondikeState();

    final sixHearts = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.six),
      faceUp: true,
    );
    state.tableau[0].add(sixHearts);
    state.tableau[1].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.seven), faceUp: true),
    );

    final move = KlondikeAdvisor.bestTapMove(state, sixHearts);

    expect(move, isNull);
  });

  test('advisor skips redundant tableau tap moves on already valid runs', () {
    final state = _emptyKlondikeState();

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

GameState _emptyKlondikeState() {
  final state = GameState();
  state.stock.clear();
  state.waste.clear();
  for (final pile in state.foundations) {
    pile.clear();
  }
  for (final pile in state.tableau) {
    pile.clear();
  }
  return state;
}

GameState _buildAutocompleteReadyState() {
  final state = _emptyKlondikeState();

  for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
    _addFoundationRange(state, suit, _allKlondikeValues);
  }
  _addFoundationRange(state, Suit.spades, _allKlondikeValuesWithoutKing);

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
  );

  return state;
}

void _addFoundationRange(
  GameState state,
  Suit suit,
  Iterable<CardValue> values,
) {
  for (final value in values) {
    state
        .foundationForSuit(suit)
        .add(KlondikeCard(PlayingCard(suit, value), faceUp: true));
  }
}

const List<CardValue> _allKlondikeValues = [
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

const List<CardValue> _allKlondikeValuesWithoutKing = [
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
];
