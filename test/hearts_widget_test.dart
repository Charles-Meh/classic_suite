import 'package:classic_suite/games/hearts/hearts_game.dart';
import 'package:classic_suite/games/hearts/hearts_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({HeartsGameState? state}) {
  return MaterialApp(home: HeartsGame(initialState: state));
}

HeartsGameState _buildPassingState() {
  return HeartsGameState.debug(
    hands: [
      const [
        HeartsCard(HeartsSuit.clubs, 2),
        HeartsCard(HeartsSuit.spades, 12),
        HeartsCard(HeartsSuit.hearts, 14),
        HeartsCard(HeartsSuit.diamonds, 13),
        HeartsCard(HeartsSuit.clubs, 3),
      ],
      const [
        HeartsCard(HeartsSuit.clubs, 4),
        HeartsCard(HeartsSuit.clubs, 5),
        HeartsCard(HeartsSuit.clubs, 6),
        HeartsCard(HeartsSuit.hearts, 2),
        HeartsCard(HeartsSuit.hearts, 3),
      ],
      const [
        HeartsCard(HeartsSuit.clubs, 7),
        HeartsCard(HeartsSuit.clubs, 8),
        HeartsCard(HeartsSuit.clubs, 9),
        HeartsCard(HeartsSuit.hearts, 4),
        HeartsCard(HeartsSuit.hearts, 5),
      ],
      const [
        HeartsCard(HeartsSuit.clubs, 10),
        HeartsCard(HeartsSuit.clubs, 11),
        HeartsCard(HeartsSuit.clubs, 12),
        HeartsCard(HeartsSuit.hearts, 6),
        HeartsCard(HeartsSuit.hearts, 7),
      ],
    ],
    phase: HeartsPhase.passing,
    passDirection: HeartsPassDirection.left,
    currentPlayer: 0,
    trickLeader: 0,
    message: 'Select three cards to pass left.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Hearts and navigates', (tester) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Hearts'), findsOneWidget);

    await tester.tap(find.text('Hearts'));
    await tester.pumpAndSettle();

    expect(find.byType(HeartsGame), findsOneWidget);
    expect(find.byKey(const Key('hearts_status_title')), findsOneWidget);
    expect(find.byKey(const Key('hearts_pause')), findsOneWidget);
    expect(find.byKey(const Key('hearts_undo')), findsOneWidget);
  });

  testWidgets('passing flow selects three cards and starts play', (tester) async {
    await tester.pumpWidget(_buildHarness(state: _buildPassingState()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('hearts_human_card_12-spades')));
    await tester.tap(find.byKey(const Key('hearts_human_card_12-spades')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hearts_human_card_14-hearts')));
    await tester.tap(find.byKey(const Key('hearts_human_card_14-hearts')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hearts_human_card_13-diamonds')));
    await tester.tap(find.byKey(const Key('hearts_human_card_13-diamonds')));
    await tester.pumpAndSettle();

    expect(find.text('Pass 3/3'), findsOneWidget);

    final confirm = find.byKey(const Key('hearts_confirm_pass'));
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.textContaining('leads with 2♣'), findsOneWidget);
    expect(find.text('Your hand'), findsOneWidget);
  });

  testWidgets('saved state restores on launch', (tester) async {
    final saved = HeartsGameState.debug(
      hands: [
        const [HeartsCard(HeartsSuit.clubs, 2)],
        const [HeartsCard(HeartsSuit.clubs, 3)],
        const [HeartsCard(HeartsSuit.clubs, 4)],
        const [HeartsCard(HeartsSuit.clubs, 5)],
      ],
      currentPlayer: 0,
      trickLeader: 0,
      phase: HeartsPhase.playing,
      speed: HeartsSpeed.relaxed,
      message: 'Saved hand restored.',
      matchScores: const [12, 22, 32, 42],
      handPoints: const [1, 2, 3, 4],
    );
    SharedPreferences.setMockInitialValues({
      HeartsGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: HeartsGame()));
    await tester.pumpAndSettle();

    expect(find.text('Saved hand restored.'), findsOneWidget);
    expect(find.text('Match: 12'), findsOneWidget);
    expect(find.byKey(const Key('hearts_speed_relaxed')), findsOneWidget);
  });

  testWidgets('pause toggles to resume', (tester) async {
    await tester.pumpWidget(_buildHarness(state: _buildPassingState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hearts_pause')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.text('Game paused.'), findsOneWidget);
  });
}
