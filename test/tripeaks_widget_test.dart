import 'package:classic_suite/games/tripeaks/tripeaks_game.dart';
import 'package:classic_suite/games/tripeaks/tripeaks_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

TriPeaksCard _card(CardValue value, [Suit suit = Suit.spades]) {
  return TriPeaksCard(card: PlayingCard(suit, value));
}

TriPeaksGameState _interactiveState() {
  final tableau = List<TriPeaksCard?>.filled(28, null);
  tableau[18] = _card(CardValue.eight);
  tableau[19] = _card(CardValue.seven);
  return TriPeaksGameState.debug(
    tableau: tableau,
    stock: [_card(CardValue.queen), _card(CardValue.six)],
    waste: [_card(CardValue.nine)],
    message: 'Debug deal',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state restores paused deal with elapsed time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    final saved = _interactiveState().withElapsedSeconds(44).togglePaused();
    SharedPreferences.setMockInitialValues({
      TriPeaksGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: TriPeaksGame()));
    await tester.pumpAndSettle();

    expect(find.text('00:44'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });
}
