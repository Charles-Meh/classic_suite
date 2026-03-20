import 'package:playing_cards/playing_cards.dart';

import 'tripeaks_game_state.dart';

enum TriPeaksHintKind { removeCard, drawStock, noMoves }

class TriPeaksSuggestion {
  const TriPeaksSuggestion({
    required this.kind,
    required this.message,
    this.tableauIndex,
  });

  final TriPeaksHintKind kind;
  final String message;
  final int? tableauIndex;
}

class TriPeaksAdvisor {
  const TriPeaksAdvisor._();

  static TriPeaksSuggestion bestHint(TriPeaksGameState state) {
    if (state.isWon) {
      return const TriPeaksSuggestion(
        kind: TriPeaksHintKind.noMoves,
        message: 'The peaks are already cleared.',
      );
    }

    if (state.isLost) {
      return const TriPeaksSuggestion(
        kind: TriPeaksHintKind.noMoves,
        message: 'No moves remain in this deal.',
      );
    }

    for (final index in state.exposedIndexes) {
      if (!state.isValidMove(index)) {
        continue;
      }
      final card = state.tableau[index]!;
      return TriPeaksSuggestion(
        kind: TriPeaksHintKind.removeCard,
        tableauIndex: index,
        message:
            'Remove ${_cardLabel(card)} from the peaks to keep the run going.',
      );
    }

    if (state.stock.isNotEmpty) {
      return const TriPeaksSuggestion(
        kind: TriPeaksHintKind.drawStock,
        message: 'Draw from the stock to open a new rank.',
      );
    }

    return const TriPeaksSuggestion(
      kind: TriPeaksHintKind.noMoves,
      message: 'No moves are available from this position.',
    );
  }

  static String _cardLabel(TriPeaksCard card) {
    final rank = switch (card.card.value) {
      CardValue.ace => 'A',
      CardValue.two => '2',
      CardValue.three => '3',
      CardValue.four => '4',
      CardValue.five => '5',
      CardValue.six => '6',
      CardValue.seven => '7',
      CardValue.eight => '8',
      CardValue.nine => '9',
      CardValue.ten => '10',
      CardValue.jack => 'J',
      CardValue.queen => 'Q',
      CardValue.king => 'K',
      _ => '?',
    };
    final suit = switch (card.card.suit) {
      Suit.clubs => 'C',
      Suit.diamonds => 'D',
      Suit.hearts => 'H',
      Suit.spades => 'S',
      _ => '?',
    };
    return '$rank$suit';
  }
}
