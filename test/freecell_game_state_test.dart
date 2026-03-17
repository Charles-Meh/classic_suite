import 'package:classic_suite/games/freecell/freecell_game.dart';
import 'package:classic_suite/games/freecell/freecell_game_state.dart';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';

void main() {
  group('FreeCellGameState', () {
    test('top card can move to freecell and foundation', () {
      final state = FreeCellGameState();
      for (final pile in state.cascades) {
        pile.clear();
      }
      for (int i = 0; i < state.freecells.length; i++) {
        state.freecells[i] = null;
      }
      for (final pile in state.foundations) {
        pile.clear();
      }

      final aceClubs = _card(Suit.clubs, CardValue.ace);
      state.cascades[0].add(aceClubs);

      expect(state.canMoveToFreecell(aceClubs), isTrue);
      expect(state.moveToFreecell(aceClubs), isTrue);
      expect(
        state.freecells.where((card) => identical(card, aceClubs)).length,
        1,
      );
      expect(state.moveToFoundation(aceClubs), isTrue);
      expect(state.foundations[0].last.card.suit, Suit.clubs);
      expect(state.foundations[0].last.card.value, CardValue.ace);
    });

    test('supermove limit is enforced for empty cascades', () {
      final state = FreeCellGameState();
      for (final pile in state.cascades) {
        pile.clear();
      }
      for (final pile in state.foundations) {
        pile.clear();
      }

      state.freecells[0] = _card(Suit.spades, CardValue.king);
      state.freecells[1] = _card(Suit.hearts, CardValue.king);
      state.freecells[2] = _card(Suit.clubs, CardValue.king);
      state.freecells[3] = null;

      state.cascades[0].addAll([
        _card(Suit.hearts, CardValue.five),
        _card(Suit.clubs, CardValue.four),
        _card(Suit.diamonds, CardValue.three),
      ]);
      state.cascades[1].clear();
      for (int i = 2; i < 8; i++) {
        state.cascades[i].add(_card(Suit.spades, CardValue.two));
      }

      expect(
        state.canMoveCardsToCascade(
          state.cascades[0].sublist(0),
          state.cascades[1],
        ),
        isFalse,
      );
      expect(
        state.canMoveCardsToCascade(
          state.cascades[0].sublist(1),
          state.cascades[1],
        ),
        isTrue,
      );
    });

    test('auto move sends safe aces home', () {
      final state = FreeCellGameState();
      for (final pile in state.cascades) {
        pile.clear();
      }
      for (int i = 0; i < state.freecells.length; i++) {
        state.freecells[i] = null;
      }
      for (final pile in state.foundations) {
        pile.clear();
      }

      final aceSpades = _card(Suit.spades, CardValue.ace);
      final aceHearts = _card(Suit.hearts, CardValue.ace);
      state.cascades[0].add(aceSpades);
      state.freecells[0] = aceHearts;

      expect(state.autoMoveSafeToFoundation(), isTrue);
      expect(state.foundations[2].last.card.value, CardValue.ace);
      expect(state.foundations[3].last.card.value, CardValue.ace);
    });
  });

  testWidgets('FreeCell widget renders controls on a narrow layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FreeCellGame()));
    await tester.pumpAndSettle();

    expect(find.text('FreeCell'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

KlondikeCard _card(Suit suit, CardValue value) =>
    KlondikeCard(PlayingCard(suit, value), faceUp: true);
