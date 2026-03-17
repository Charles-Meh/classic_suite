import 'package:classic_suite/games/tripeaks/tripeaks_game.dart';
import 'package:classic_suite/games/tripeaks/tripeaks_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

TriPeaksCard _card(CardValue value, [Suit suit = Suit.spades]) {
  return TriPeaksCard(card: PlayingCard(suit, value));
}

Widget _buildHarness({TriPeaksGameState? state}) {
  return MaterialApp(home: TriPeaksGame(initialState: state));
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

TriPeaksGameState _wonState() {
  return TriPeaksGameState.debug(
    tableau: List<TriPeaksCard?>.filled(28, null),
    stock: const [],
    waste: [_card(CardValue.jack)],
    clearedCount: 28,
    score: 9200,
    currentRun: 5,
    longestRun: 5,
    status: TriPeaksStatus.won,
    message: 'Peaks cleared. You win.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows TriPeaks and navigates to the game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(const ClassicSuiteApp());

    await tester.scrollUntilVisible(
      find.text('TriPeaks Solitaire'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TriPeaks Solitaire'), findsOneWidget);

    await tester.tap(find.text('TriPeaks Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byType(TriPeaksGame), findsOneWidget);
    expect(find.byKey(const Key('tripeaks_stock')), findsOneWidget);
    expect(find.byKey(const Key('tripeaks_waste')), findsOneWidget);
    expect(find.byKey(const Key('tripeaks_undo')), findsOneWidget);
  });

  testWidgets('tapping a valid exposed card moves it to waste and enables undo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(_buildHarness(state: _interactiveState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripeaks_tableau_18')));
    await tester.pumpAndSettle();

    expect(find.text('Run x1 • +100 points'), findsOneWidget);
    final undoButton = tester.widget<FilledButton>(find.byKey(const Key('tripeaks_undo')));
    expect(undoButton.onPressed, isNotNull);
  });

  testWidgets('undo and redo restore the deal state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(_buildHarness(state: _interactiveState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripeaks_tableau_18')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tripeaks_undo')));
    await tester.pumpAndSettle();

    expect(find.text('Debug deal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tripeaks_redo')));
    await tester.pumpAndSettle();

    expect(find.text('Run x1 • +100 points'), findsOneWidget);
  });

  testWidgets('pause overlay appears and resume clears it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(_buildHarness(state: _interactiveState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripeaks_pause')));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('saved state restores paused deal with elapsed time', (tester) async {
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

  testWidgets('won state shows the victory overlay', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(_buildHarness(state: _wonState()));
    await tester.pumpAndSettle();

    expect(find.text('You won'), findsOneWidget);
    expect(find.textContaining('Score: 9200'), findsOneWidget);
  });

  testWidgets('statistics dialog shows persisted numbers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues({
      'tripeaks_stats_games_started': 8,
      'tripeaks_stats_games_won': 3,
      'tripeaks_stats_best_score': 9100,
      'tripeaks_stats_current_streak': 2,
      'tripeaks_stats_best_streak': 4,
      'tripeaks_stats_longest_run': 7,
    });

    await tester.pumpWidget(_buildHarness(state: _wonState()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const Key('tripeaks_overlay_stats')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('TriPeaks statistics'), findsOneWidget);
    expect(find.text('9100'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
  });
}
