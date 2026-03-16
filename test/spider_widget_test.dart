import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/spider/spider_game.dart';
import 'package:classic_suite/games/spider/spider_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

Widget _buildSpiderHarness(SpiderGameState state) {
  return MaterialApp(home: SpiderGame(initialState: state));
}

SpiderGameState _buildSimpleSpiderMoveState() {
  final state = SpiderGameState();
  state.stock.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  state.completedRuns.clear();

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.clubs, CardValue.seven), faceUp: true),
  );
  state.tableau[1].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.six), faceUp: true),
  );
  for (int index = 2; index < state.tableau.length; index++) {
    state.tableau[index].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
    );
  }
  return state;
}

void main() {
  testWidgets('launcher shows Spider Klondike and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Spider Klondike'), findsOneWidget);

    await tester.tap(find.text('Spider Klondike'));
    await tester.pumpAndSettle();

    expect(find.byType(SpiderGame), findsOneWidget);
    expect(find.text('Spider Klondike'), findsWidgets);
  });

  testWidgets('spider hint shows visual source and target', (
    WidgetTester tester,
  ) async {
    final state = _buildSimpleSpiderMoveState();

    await tester.pumpWidget(_buildSpiderHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spider_hint_banner')), findsOneWidget);
    expect(find.text('Move 6♠ from tableau 2 to tableau 1.'), findsOneWidget);
    expect(find.byKey(const Key('spider_hint_stock')), findsNothing);
    expect(find.byKey(const Key('spider_tableau_0_drop_hint')), findsOneWidget);
  });

  testWidgets(
    'tapping a movable spider card performs the move and undo restores it',
    (WidgetTester tester) async {
      final state = _buildSimpleSpiderMoveState();
      final movedCard = state.tableau[1].single;

      await tester.pumpWidget(_buildSpiderHarness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('spider_tableau_1_card_0')));
      await tester.pumpAndSettle();

      expect(state.tableau[1], isEmpty);
      expect(state.tableau[0].last, movedCard);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(state.tableau[0], hasLength(1));
      expect(state.tableau[1], hasLength(1));
      expect(state.tableau[1].single.card.value, CardValue.six);
    },
  );

  testWidgets('dealing from stock is blocked while a tableau pile is empty', (
    WidgetTester tester,
  ) async {
    final state = _buildSimpleSpiderMoveState();
    state.stock
      ..clear()
      ..addAll(
        List.generate(
          10,
          (_) => KlondikeCard(
            PlayingCard(Suit.spades, CardValue.ace),
            faceUp: false,
          ),
        ),
      );
    state.tableau[4].clear();

    await tester.pumpWidget(_buildSpiderHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('spider_stock')));
    await tester.pumpAndSettle();

    expect(
      find.text('Fill every tableau column before dealing a new row.'),
      findsOneWidget,
    );
    expect(state.stock, hasLength(10));
  });
}
