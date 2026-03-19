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
}
