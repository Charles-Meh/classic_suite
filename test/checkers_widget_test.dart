import 'package:classic_suite/games/checkers/checkers_game.dart';
import 'package:classic_suite/games/checkers/checkers_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved state is restored on launch', (tester) async {
    final saved = CheckersGameState.newGame()
        .copyWith(elapsedSeconds: 33)
        .selectSquare(5, 0);
    SharedPreferences.setMockInitialValues({
      CheckersGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: CheckersGame()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkers_title')), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('00:33'), findsOneWidget);
    expect(find.text('Red piece selected.'), findsOneWidget);
    expect(find.byKey(const Key('checkers_pause')), findsNothing);
  });
}
