import 'package:classic_suite/games/chess/chess_game.dart';
import 'package:classic_suite/games/chess/chess_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({ChessGameState? state}) {
  return MaterialApp(home: ChessGame(initialState: state));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Chess and navigates', (tester) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Chess'), findsOneWidget);
    await tester.tap(find.text('Chess'));
    await tester.pumpAndSettle();

    expect(find.byType(ChessGame), findsOneWidget);
    expect(find.byKey(const Key('chess_title')), findsOneWidget);
    expect(find.byKey(const Key('chess_undo')), findsOneWidget);
    expect(find.byKey(const Key('chess_hint')), findsOneWidget);
  });

  testWidgets('tap piece highlights legal moves and executes move', (
    tester,
  ) async {
    final state = ChessGameState.newGame(mode: ChessGameMode.passAndPlay);
    await tester.pumpWidget(_buildHarness(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chess_square_6_4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chess_square_4_4')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chess_square_4_4')));
    await tester.pumpAndSettle();

    final widget = tester.widget(find.byKey(const Key('chess_square_4_4')));
    expect(widget, isNotNull);
    expect(find.textContaining('Black to move'), findsOneWidget);
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

    expect(find.text('Saved game restored.'), findsOneWidget);
    expect(find.text('00:31'), findsOneWidget);
  });
}
