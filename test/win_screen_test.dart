import 'package:classic_suite/shared/win_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness(WinScreenTheme theme, String title) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(),
          GameWinScreen(
            theme: theme,
            title: title,
            subtitle: 'A polished solitaire finish animation is visible.',
            stats: const [WinScreenStat(label: 'Wins', value: '3')],
            onNewGame: _noop,
            onBackToMenu: _noop,
          ),
        ],
      ),
    ),
  );
}

void _noop() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'solitaire-family themes render the shared celebration animation',
    (tester) async {
      const cases = <(WinScreenTheme, String)>[
        (WinScreenTheme.klondike, 'You Win!'),
        (WinScreenTheme.spider, 'Spider Solved!'),
        (WinScreenTheme.pyramid, 'Pyramid Cleared!'),
      ];

      for (final (theme, title) in cases) {
        await tester.pumpWidget(_buildHarness(theme, title));
        await tester.pump();

        expect(find.text(title), findsOneWidget);
        expect(
          find.byKey(ValueKey<String>('solitaire_win_animation_${theme.name}')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('solitaire_win_glow')), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
