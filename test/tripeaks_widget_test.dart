import 'dart:convert';

import 'package:classic_suite/games/tripeaks/tripeaks_game.dart';
import 'package:classic_suite/games/tripeaks/tripeaks_game_state.dart';
import 'package:classic_suite/shared/classic_game_ui.dart';
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

TriPeaksCard _card(CardValue value, [Suit suit = Suit.spades]) {
  return TriPeaksCard(card: PlayingCard(suit, value));
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

  testWidgets('saved state restores paused deal with elapsed time', (
    tester,
  ) async {
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

  testWidgets(
    'tripeaks uses the shared shelf layout without redundant header stats',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(home: TriPeaksGame(initialState: _interactiveState())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripeaks_top_shelf')), findsOneWidget);
      expect(find.text('TriPeaks Solitaire'), findsOneWidget);
      expect(find.text('Run'), findsNothing);
      expect(find.text('Best run'), findsNothing);
      expect(find.text('Stock'), findsNothing);
      expect(find.text('Cleared'), findsOneWidget);
      expect(find.byKey(const Key('tripeaks_stock_count')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    },
  );

  testWidgets('hint highlights a playable tableau card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

    await tester.pumpWidget(
      MaterialApp(home: TriPeaksGame(initialState: _interactiveState())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('tripeaks_tableau_18_hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tripeaks_stock_hint')),
      findsNothing,
    );
  });

  testWidgets('hint highlights the stock when no tableau move is available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    final tableau = List<TriPeaksCard?>.filled(28, null);
    tableau[18] = _card(CardValue.five);
    final state = TriPeaksGameState.debug(
      tableau: tableau,
      stock: [_card(CardValue.king)],
      waste: [_card(CardValue.nine)],
      message: 'Debug deal',
    );

    await tester.pumpWidget(
      MaterialApp(home: TriPeaksGame(initialState: state)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('tripeaks_stock_hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tripeaks_tableau_18_hint')),
      findsNothing,
    );
  });

  testWidgets(
    'cleared tableau slots are transparent while empty stock stays visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      final tableau = List<TriPeaksCard?>.filled(28, null);
      tableau[18] = _card(CardValue.eight);
      final state = TriPeaksGameState.debug(
        tableau: tableau,
        stock: const [],
        waste: [_card(CardValue.nine)],
        message: 'Debug deal',
      );

      await tester.pumpWidget(
        MaterialApp(home: TriPeaksGame(initialState: state)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('tripeaks_tableau_0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tripeaks_tableau_0')),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tripeaks_stock_idle')),
          matching: find.byWidgetPredicate((widget) {
            if (widget is! DecoratedBox) {
              return false;
            }

            final decoration = widget.decoration;
            if (decoration is! BoxDecoration) {
              return false;
            }

            return decoration.color == Colors.white.withValues(alpha: 0.12);
          }),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tripeaks_stock_idle')),
          matching: find.byType(ClassicPlayingCard),
        ),
        findsNothing,
      );
    },
  );
}
