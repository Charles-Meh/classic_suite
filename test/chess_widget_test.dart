import 'package:classic_suite/games/chess/chess_game.dart';
import 'package:classic_suite/games/chess/chess_game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saved game restores on launch', (tester) async {
    final saved = ChessGameState.newGame(
      mode: ChessGameMode.passAndPlay,
    ).copyWith(elapsedSeconds: 31, message: 'Saved game restored.');
    SharedPreferences.setMockInitialValues({
      ChessGameState.storageKey: saved.encode(),
    });

    await tester.pumpWidget(const MaterialApp(home: ChessGame()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chess_title')), findsOneWidget);
    expect(find.text('Pass & play'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('Saved game restored.'), findsOneWidget);
    expect(find.text('00:31'), findsOneWidget);
    expect(find.byKey(const Key('chess_pause')), findsNothing);
  });
}
