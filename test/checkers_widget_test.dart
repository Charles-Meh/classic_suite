import 'package:classic_suite/games/checkers/checkers_game.dart';
import 'package:classic_suite/games/checkers/checkers_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({CheckersGameState? state}) {
  return MaterialApp(home: CheckersGame(initialState: state));
}

List<List<CheckersPiece?>> _emptyBoard() =>
    List.generate(8, (_) => List<CheckersPiece?>.filled(8, null));

CheckersGameState _buildNearlyWonState() {
  final board = _emptyBoard();
  board[1][2] = const CheckersPiece(side: CheckersSide.red);
  return CheckersGameState.debug(
    board: board,
    turn: CheckersSide.red,
    elapsedSeconds: 12,
    status: CheckersGameStatus.active,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Checkers and navigates', (tester) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Checkers'), findsOneWidget);

    await tester.tap(find.text('Checkers'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckersGame), findsOneWidget);
    expect(find.byKey(const Key('checkers_title')), findsOneWidget);
    expect(find.byKey(const Key('checkers_undo')), findsOneWidget);
    expect(find.byKey(const Key('checkers_pause')), findsOneWidget);
  });

  testWidgets('difficulty chips update the title', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Checkers • Medium AI'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkers_difficulty_hard')),
    );
    await tester.tap(find.byKey(const Key('checkers_difficulty_hard')));
    await tester.pumpAndSettle();

    expect(find.text('Checkers • Hard AI'), findsOneWidget);
  });

  testWidgets('mode chip switches to pass and play', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('checkers_mode_local')));
    await tester.tap(find.byKey(const Key('checkers_mode_local')));
    await tester.pumpAndSettle();

    expect(find.text('Checkers • Pass & play'), findsOneWidget);
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

    expect(find.text('00:33'), findsOneWidget);
    expect(find.text('Red piece selected.'), findsOneWidget);
  });

  testWidgets('winning a board updates statistics dialog', (tester) async {
    await tester.pumpWidget(_buildHarness(state: _buildNearlyWonState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkers_square_1_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkers_square_0_1')));
    await tester.pumpAndSettle();

    expect(find.text('Red wins.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Game menu').first);
    await tester.tap(find.byTooltip('Game menu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Checkers statistics'), findsOneWidget);
    expect(find.text('Best Easy'), findsOneWidget);
    expect(find.text('00:12'), findsWidgets);
  });

  testWidgets('pause toggles to resume', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('checkers_pause')));
    await tester.tap(find.byKey(const Key('checkers_pause')));
    await tester.pumpAndSettle();

    expect(find.text('Game paused.'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
