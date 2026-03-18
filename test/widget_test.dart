import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classic_suite/core/game_list_page.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_advisor.dart';
import 'package:classic_suite/games/klondike/klondike_game.dart';
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

Future<void> _openGameMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Game menu'));
  await tester.pumpAndSettle();
}

GameState _buildAlmostWonState() {
  final state = GameState();
  state.stock.clear();
  state.waste.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  for (final pile in state.foundations) {
    pile.clear();
  }

  final fullFoundationValues = [
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
  final nearCompleteFoundationValues = fullFoundationValues
      .where((value) => value != CardValue.king)
      .toList();

  for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
    for (final value in fullFoundationValues) {
      state
          .foundationForSuit(suit)
          .add(KlondikeCard(PlayingCard(suit, value), faceUp: true));
    }
  }
  for (final value in nearCompleteFoundationValues) {
    state
        .foundationForSuit(Suit.spades)
        .add(KlondikeCard(PlayingCard(Suit.spades, value), faceUp: true));
  }

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
  );
  return state;
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

  testWidgets('settings switch draw count to three-card draw', (
    WidgetTester tester,
  ) async {
    final state = GameState();
    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    await _openGameMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3-card draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply and deal'));
    await tester.pumpAndSettle();

    expect(state.drawCount, 3);

    await tester.tap(find.byKey(const Key('stock')));
    await tester.pumpAndSettle();

    expect(state.waste.length, 3);
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
    expect(find.byKey(const Key('hint_waste')), findsOneWidget);
    expect(find.byKey(const Key('tableau_0_drop_hint')), findsOneWidget);
  });

  testWidgets('tapping waste card can auto-move it to tableau', (
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

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('waste_draggable')));
    await tester.pumpAndSettle();

    expect(state.waste, isEmpty);
    expect(state.tableau[0].last, wasteCard);
  });

  testWidgets('dragging waste immediately reveals the next card below', (
    WidgetTester tester,
  ) async {
    final state = GameState(drawCount: 1);
    state.stock.clear();
    state.waste.clear();
    for (final pile in state.foundations) {
      pile.clear();
    }
    for (final pile in state.tableau) {
      pile.clear();
    }

    final lowerCard = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.five),
      faceUp: true,
    );
    final topCard = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.four),
      faceUp: true,
    );
    state.waste.addAll([lowerCard, topCard]);

    await tester.pumpWidget(_buildKlondikeHarness(state));

    expect(find.byKey(const Key('waste_card_0')), findsNothing);
    expect(find.byKey(const Key('waste_card_1')), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('waste_draggable'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();

    expect(find.byKey(const Key('waste_card_0')), findsOneWidget);
    expect(find.byKey(const Key('waste_card_1')), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('drag waste card to tableau moves the card', (
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

    await tester.pumpWidget(_buildKlondikeHarness(state));

    final waste = find.byKey(const Key('waste_draggable'));
    final target = find.byKey(const Key('tableau_0'));
    expect(waste, findsOneWidget);
    expect(target, findsOneWidget);

    final start = tester.getCenter(waste);
    final end = tester.getCenter(target);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(state.waste, isEmpty);
    expect(state.tableau[0].last, wasteCard);
  });

  testWidgets('dragging an upper tableau card moves the whole run', (
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

    final hidden = KlondikeCard(
      PlayingCard(Suit.clubs, CardValue.nine),
      faceUp: false,
    );
    final seven = KlondikeCard(
      PlayingCard(Suit.hearts, CardValue.seven),
      faceUp: true,
    );
    final six = KlondikeCard(
      PlayingCard(Suit.clubs, CardValue.six),
      faceUp: true,
    );
    final destination = KlondikeCard(
      PlayingCard(Suit.spades, CardValue.eight),
      faceUp: true,
    );

    state.tableau[0].addAll([hidden, seven, six]);
    state.tableau[1].add(destination);

    await tester.pumpWidget(_buildKlondikeHarness(state));

    final source = find.byKey(const Key('tableau_0_card_1'));
    final trailingCard = find.byKey(const Key('tableau_0_card_2'));
    final target = find.byKey(const Key('tableau_1'));
    expect(source, findsOneWidget);
    expect(trailingCard, findsOneWidget);
    expect(target, findsOneWidget);

    final sourceTopLeft = tester.getTopLeft(source);
    final sourceSize = tester.getSize(source);
    final start = sourceTopLeft + Offset(sourceSize.width / 2, 10);
    final end = tester.getCenter(target);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();

    expect(find.byKey(const Key('tableau_0_card_2')), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(state.tableau[0].length, 1);
    expect(state.tableau[0].single, hidden);
    expect(hidden.faceUp, isTrue);
    expect(state.tableau[1], [destination, seven, six]);
  });

  testWidgets('tableau drop hint stays near the actual snap point', (
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

    state.tableau[0].addAll([
      KlondikeCard(PlayingCard(Suit.clubs, CardValue.king), faceUp: false),
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.queen), faceUp: false),
      KlondikeCard(PlayingCard(Suit.clubs, CardValue.jack), faceUp: true),
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.ten), faceUp: true),
      KlondikeCard(PlayingCard(Suit.clubs, CardValue.nine), faceUp: true),
    ]);
    state.tableau[1].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.seven), faceUp: true),
    );
    state.waste.add(
      KlondikeCard(PlayingCard(Suit.hearts, CardValue.six), faceUp: true),
    );

    await tester.pumpWidget(_buildKlondikeHarness(state));

    final waste = find.byKey(const Key('waste_draggable'));
    final target = find.byKey(const Key('tableau_1'));
    final targetCard = find.byKey(const Key('tableau_1_card_0'));

    final gesture = await tester.startGesture(tester.getCenter(waste));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();

    final dropHint = find.byKey(const Key('tableau_1_drop_hint'));
    expect(dropHint, findsOneWidget);

    final hintTop = tester.getTopLeft(dropHint).dy;
    final targetTop = tester.getTopLeft(targetCard).dy;
    final targetHeight = tester.getSize(targetCard).height;

    expect(hintTop, greaterThan(targetTop));
    expect(hintTop, lessThan(targetTop + targetHeight));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('undo restores the previous move', (WidgetTester tester) async {
    final state = GameState();
    state.stock.clear();
    state.waste.clear();
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

    await tester.pumpWidget(_buildKlondikeHarness(state));

    await tester.dragFrom(
      tester.getCenter(find.byKey(const Key('waste_draggable'))),
      tester.getCenter(find.byKey(const Key('tableau_0'))) -
          tester.getCenter(find.byKey(const Key('waste_draggable'))),
    );
    await tester.pumpAndSettle();

    expect(state.waste, isEmpty);
    expect(state.tableau[0].last, wasteCard);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();

    expect(state.waste, hasLength(1));
    expect(state.waste.last.card, wasteCard.card);
    expect(state.tableau[0], hasLength(1));
    expect(state.tableau[0].single.card, destination.card);
  });

  testWidgets('autocomplete button appears for trivially finishable games', (
    WidgetTester tester,
  ) async {
    final state = _buildAlmostWonState();

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('autocomplete_button')), findsOneWidget);
    expect(find.text('Autocomplete'), findsOneWidget);
  });

  testWidgets(
    'autocomplete finishes the game and shows the normal win overlay',
    (WidgetTester tester) async {
      final state = _buildAlmostWonState();

      await tester.pumpWidget(_buildKlondikeHarness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('autocomplete_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('win_overlay')), findsOneWidget);
      expect(find.text('You won'), findsOneWidget);
      expect(find.text('Wins 1 • Streak 1'), findsOneWidget);
    },
  );

  testWidgets('statistics dialog opens from the top bar after a win', (
    WidgetTester tester,
  ) async {
    final state = _buildAlmostWonState();

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('autocomplete_button')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Klondike Solitaire statistics'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
  });

  testWidgets('win state shows celebratory overlay', (
    WidgetTester tester,
  ) async {
    final state = GameState();
    state.stock.clear();
    state.waste.clear();
    for (final pile in state.tableau) {
      pile.clear();
    }
    for (final pile in state.foundations) {
      pile.clear();
    }

    for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades]) {
      for (final value in [
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
      ]) {
        state
            .foundationForSuit(suit)
            .add(KlondikeCard(PlayingCard(suit, value), faceUp: true));
      }
    }

    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('win_overlay')), findsOneWidget);
    expect(find.text('You won'), findsOneWidget);
    expect(find.text('New Deal'), findsOneWidget);
  });

  testWidgets('settings can start a curated winning deal', (
    WidgetTester tester,
  ) async {
    expect(kWinnableDrawOneSeeds, isNotEmpty);

    final state = GameState();
    await tester.pumpWidget(_buildKlondikeHarness(state));
    await tester.pumpAndSettle();

    await _openGameMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('1-card draw'), findsOneWidget);
    expect(find.text('3-card draw'), findsOneWidget);
    expect(find.text('Winning deal'), findsOneWidget);
    await tester.tap(find.text('Winning deal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply and deal'));
    await tester.pumpAndSettle();

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
