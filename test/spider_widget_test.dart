import 'dart:convert';
import 'package:classic_suite/games/klondike/card_model.dart';
import 'package:classic_suite/games/spider/spider_game.dart';
import 'package:classic_suite/games/spider/spider_game_state.dart';
import 'package:classic_suite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> _playingCardAssets = [
  'package/playing_cards/assets/card_imagery/back_001.png',
  'package/playing_cards/assets/card_imagery/bw_joker.png',
  'package/playing_cards/assets/card_imagery/club.png',
  'package/playing_cards/assets/card_imagery/color_joker.png',
  'package/playing_cards/assets/card_imagery/diamond.png',
  'package/playing_cards/assets/card_imagery/heart.png',
  'package/playing_cards/assets/card_imagery/jc.png',
  'package/playing_cards/assets/card_imagery/jd.png',
  'package/playing_cards/assets/card_imagery/jh.png',
  'package/playing_cards/assets/card_imagery/js.png',
  'package/playing_cards/assets/card_imagery/kc.png',
  'package/playing_cards/assets/card_imagery/kd.png',
  'package/playing_cards/assets/card_imagery/kh.png',
  'package/playing_cards/assets/card_imagery/ks.png',
  'package/playing_cards/assets/card_imagery/qc.png',
  'package/playing_cards/assets/card_imagery/qd.png',
  'package/playing_cards/assets/card_imagery/qh.png',
  'package/playing_cards/assets/card_imagery/qs.png',
  'package/playing_cards/assets/card_imagery/spade.png',
];

final Uint8List _transparentPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

final ByteData _assetManifestBytes = () {
  final manifest = <String, List<String>>{
    for (final asset in _playingCardAssets) asset: [asset],
  };
  return const StandardMessageCodec().encodeMessage(manifest)!;
}();

ByteData _bytesToData(Uint8List bytes) => ByteData.view(bytes.buffer);

Future<ByteData?> _mockAssetHandler(ByteData? message) async {
  if (message == null) {
    return null;
  }

  final key = utf8.decode(message.buffer.asUint8List());
  if (key == 'AssetManifest.bin') {
    return _assetManifestBytes;
  }
  if (key.endsWith('.png')) {
    return _bytesToData(_transparentPng);
  }
  return null;
}

Widget _buildSpiderHarness(SpiderGameState state) {
  return MaterialApp(home: SpiderGame(initialState: state));
}

SpiderGameState _buildSimpleSpiderMoveState() {
  final state = SpiderGameState();
  state.stock.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  state.completedRuns.clear();

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.clubs, CardValue.seven), faceUp: true),
  );
  state.tableau[1].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.six), faceUp: true),
  );
  for (int index = 2; index < state.tableau.length; index++) {
    state.tableau[index].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.king), faceUp: true),
    );
  }
  return state;
}

SpiderGameState _buildSpiderEmptyTableauFallbackState() {
  final state = SpiderGameState();
  state.stock.clear();
  for (final pile in state.tableau) {
    pile.clear();
  }
  state.completedRuns.clear();

  state.tableau[0].add(
    KlondikeCard(PlayingCard(Suit.clubs, CardValue.queen), faceUp: true),
  );
  state.tableau[1].add(
    KlondikeCard(PlayingCard(Suit.spades, CardValue.eight), faceUp: true),
  );
  for (int index = 3; index < state.tableau.length; index++) {
    state.tableau[index].add(
      KlondikeCard(PlayingCard(Suit.spades, CardValue.four), faceUp: true),
    );
  }
  return state;
}

SpiderGameState _buildSpiderDealHintState() {
  final state = _buildSpiderEmptyTableauFallbackState();
  state.tableau[2].add(
    KlondikeCard(PlayingCard(Suit.hearts, CardValue.ace), faceUp: true),
  );
  state.stock.addAll(
    List.generate(
      10,
      (index) => KlondikeCard(
        PlayingCard(Suit.hearts, CardValue.values[index]),
        faceUp: false,
      ),
    ),
  );
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1.0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', _mockAssetHandler);
  });

  tearDownAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launcher shows Spider Solitaire and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClassicSuiteApp());

    expect(find.text('Spider Solitaire'), findsOneWidget);

    await tester.tap(find.text('Spider Solitaire'));
    await tester.pumpAndSettle();

    expect(find.byType(SpiderGame), findsOneWidget);
    expect(find.text('Spider Solitaire'), findsWidgets);
  });

  testWidgets('spider hint shows visual source and target', (
    WidgetTester tester,
  ) async {
    final state = _buildSimpleSpiderMoveState();

    await tester.pumpWidget(_buildSpiderHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spider_hint_banner')), findsNothing);
    expect(find.text('Move 6♠ from tableau 2 to tableau 1.'), findsNothing);
    expect(find.byKey(const Key('spider_hint_stock')), findsNothing);
    expect(find.byKey(const Key('spider_tableau_0_drop_hint')), findsOneWidget);
  });

  testWidgets('dealing from stock is blocked while a tableau pile is empty', (
    WidgetTester tester,
  ) async {
    final state = _buildSimpleSpiderMoveState();
    state.stock
      ..clear()
      ..addAll(
        List.generate(
          10,
          (_) => KlondikeCard(
            PlayingCard(Suit.spades, CardValue.ace),
            faceUp: false,
          ),
        ),
      );
    state.tableau[4].clear();

    await tester.pumpWidget(_buildSpiderHarness(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('spider_stock')));
    await tester.pumpAndSettle();

    expect(
      find.text('Fill every tableau column before dealing a new row.'),
      findsOneWidget,
    );
    expect(state.stock, hasLength(10));
  });

  testWidgets(
    'spider hint highlights an open tableau when no normal move exists',
    (WidgetTester tester) async {
      final state = _buildSpiderEmptyTableauFallbackState();

      await tester.pumpWidget(_buildSpiderHarness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hint'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('spider_tableau_2_empty_hint')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('spider_hint_stock')), findsNothing);
      expect(find.byKey(const Key('spider_tableau_0_drop_hint')), findsNothing);
    },
  );

  testWidgets(
    'spider hint points to stock when no move exists and no tableau is open',
    (WidgetTester tester) async {
      final state = _buildSpiderDealHintState();

      await tester.pumpWidget(_buildSpiderHarness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hint'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('spider_hint_stock')), findsOneWidget);
      expect(
        find.byKey(const Key('spider_tableau_2_empty_hint')),
        findsNothing,
      );
    },
  );
}
