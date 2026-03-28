import 'package:classic_suite/games/hearts/hearts_game.dart';
import 'package:classic_suite/games/hearts/hearts_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state restores on launch', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

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

    // Status chip shows the saved message
    expect(find.text('Saved hand restored.'), findsOneWidget);
    // Score strip shows the match score for player 0
    expect(find.text('12'), findsOneWidget);
    // Undo button is present in the bottom bar
    expect(find.byKey(const Key('hearts_undo')), findsOneWidget);
  });

  testWidgets('passing flow selects 3 cards and enables confirm', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

    final state = HeartsGameState.debug(
      hands: [
        const [
          HeartsCard(HeartsSuit.clubs, 2),
          HeartsCard(HeartsSuit.clubs, 3),
          HeartsCard(HeartsSuit.clubs, 4),
          HeartsCard(HeartsSuit.clubs, 5),
          HeartsCard(HeartsSuit.hearts, 6),
          HeartsCard(HeartsSuit.hearts, 7),
          HeartsCard(HeartsSuit.hearts, 8),
          HeartsCard(HeartsSuit.hearts, 9),
          HeartsCard(HeartsSuit.diamonds, 10),
          HeartsCard(HeartsSuit.diamonds, 11),
          HeartsCard(HeartsSuit.diamonds, 12),
          HeartsCard(HeartsSuit.diamonds, 13),
          HeartsCard(HeartsSuit.diamonds, 14),
        ],
        const [
          HeartsCard(HeartsSuit.spades, 3),
          HeartsCard(HeartsSuit.spades, 4),
          HeartsCard(HeartsSuit.spades, 5),
          HeartsCard(HeartsSuit.spades, 6),
          HeartsCard(HeartsSuit.spades, 7),
          HeartsCard(HeartsSuit.spades, 8),
          HeartsCard(HeartsSuit.spades, 9),
          HeartsCard(HeartsSuit.spades, 10),
          HeartsCard(HeartsSuit.spades, 11),
          HeartsCard(HeartsSuit.spades, 12),
          HeartsCard(HeartsSuit.spades, 13),
          HeartsCard(HeartsSuit.spades, 14),
          HeartsCard(HeartsSuit.clubs, 14),
        ],
        const [
          HeartsCard(HeartsSuit.clubs, 6),
          HeartsCard(HeartsSuit.clubs, 7),
          HeartsCard(HeartsSuit.clubs, 8),
          HeartsCard(HeartsSuit.clubs, 9),
          HeartsCard(HeartsSuit.clubs, 10),
          HeartsCard(HeartsSuit.clubs, 11),
          HeartsCard(HeartsSuit.clubs, 12),
          HeartsCard(HeartsSuit.clubs, 13),
          HeartsCard(HeartsSuit.diamonds, 2),
          HeartsCard(HeartsSuit.diamonds, 3),
          HeartsCard(HeartsSuit.diamonds, 4),
          HeartsCard(HeartsSuit.diamonds, 5),
          HeartsCard(HeartsSuit.diamonds, 6),
        ],
        const [
          HeartsCard(HeartsSuit.hearts, 2),
          HeartsCard(HeartsSuit.hearts, 3),
          HeartsCard(HeartsSuit.hearts, 4),
          HeartsCard(HeartsSuit.hearts, 5),
          HeartsCard(HeartsSuit.hearts, 10),
          HeartsCard(HeartsSuit.hearts, 11),
          HeartsCard(HeartsSuit.hearts, 12),
          HeartsCard(HeartsSuit.hearts, 13),
          HeartsCard(HeartsSuit.hearts, 14),
          HeartsCard(HeartsSuit.diamonds, 7),
          HeartsCard(HeartsSuit.diamonds, 8),
          HeartsCard(HeartsSuit.diamonds, 9),
          HeartsCard(HeartsSuit.spades, 2),
        ],
      ],
      currentPlayer: 0,
      trickLeader: 0,
      phase: HeartsPhase.passing,
      passDirection: HeartsPassDirection.left,
      speed: HeartsSpeed.instant,
    );

    await tester.pumpWidget(MaterialApp(home: HeartsGame(initialState: state)));
    await tester.pumpAndSettle();

    // Confirm button should be disabled (0/3 selected)
    final confirmBtn = find.byKey(const Key('hearts_confirm_pass'));
    expect(confirmBtn, findsOneWidget);
    expect(tester.widget<FilledButton>(confirmBtn).enabled, isFalse);

    // Select 3 cards
    await tester.tap(find.byKey(const Key('hearts_human_card_2-clubs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hearts_human_card_3-clubs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hearts_human_card_4-clubs')));
    await tester.pumpAndSettle();

    // Confirm button should now be enabled (3/3 selected)
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('hearts_confirm_pass')))
          .enabled,
      isTrue,
    );

    // Tap confirm — should transition to playing without crash
    await tester.tap(find.byKey(const Key('hearts_confirm_pass')));
    await tester.pumpAndSettle();

    // Should no longer be in passing phase (confirm button gone)
    expect(find.byKey(const Key('hearts_confirm_pass')), findsNothing);
  });
}
