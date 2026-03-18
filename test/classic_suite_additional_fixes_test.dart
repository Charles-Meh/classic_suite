import 'package:classic_suite/core/game_list_page.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/klondike/game_state.dart';
import 'package:classic_suite/games/klondike/klondike_advisor.dart';
import 'package:classic_suite/games/klondike/klondike_game.dart';
import 'package:classic_suite/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

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

Widget _buildKlondikeHarness(GameState state) {
  return MaterialApp(home: KlondikeGame(initialState: state));
}

void main() {
  testWidgets('launcher keeps only title and search, without subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildLauncherHarness());

    expect(find.text('Classic Suite'), findsOneWidget);
    expect(find.text('Choose a game'), findsNothing);
    expect(find.textContaining('Search once, tap once'), findsNothing);
    expect(find.byKey(const Key('game_search_field')), findsOneWidget);
  });

  testWidgets(
    'launching a game clears search focus so it will not reopen focused',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildLauncherHarness());
      await tester.pump();

      await tester.tap(find.byKey(const Key('game_search_field')));
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await tester.tap(find.text('Klondike Solitaire'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.testTextInput.hasAnyClients, isFalse);
    },
  );

  testWidgets('klondike hint uses only visual markers with no text banner', (
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
    await tester.pump();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('hint_banner')), findsNothing);
    expect(find.textContaining('Move 6♥'), findsNothing);
  });

  testWidgets('klondike top bar and settings layout match requested controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildKlondikeHarness(GameState()));
    await tester.pump();

    expect(find.text('Draw 1'), findsNothing);
    expect(find.text('Draw 3'), findsNothing);
    expect(find.text('Winning deal'), findsNothing);
    expect(find.text('Restart deal'), findsNothing);
    expect(find.byTooltip('Statistics'), findsOneWidget);

    await tester.tap(find.byTooltip('Game menu'));
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Statistics'), findsNothing);
  });

  test('advisor skips redundant move from an already valid tableau run', () {
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
