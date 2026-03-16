import 'package:playing_cards/playing_cards.dart';

/// A card used internally by the klondike game, combining a playing_cards
/// object with visibility state.
class KlondikeCard {
  final PlayingCard card;
  bool faceUp;

  KlondikeCard(this.card, {this.faceUp = false});

  /// Create a face-down card with the given rank and suit.
  KlondikeCard.faceDown(this.card) : faceUp = false;

  /// Helper to copy card with a new faceUp state.
  KlondikeCard copyWith({bool? faceUp}) {
    return KlondikeCard(card, faceUp: faceUp ?? this.faceUp);
  }

  /// A simple numeric rank used for ordering. Ace is low (1) and King is 13.
  int get valueIndex {
    switch (card.value) {
      case CardValue.ace:
        return 1;
      case CardValue.two:
        return 2;
      case CardValue.three:
        return 3;
      case CardValue.four:
        return 4;
      case CardValue.five:
        return 5;
      case CardValue.six:
        return 6;
      case CardValue.seven:
        return 7;
      case CardValue.eight:
        return 8;
      case CardValue.nine:
        return 9;
      case CardValue.ten:
        return 10;
      case CardValue.jack:
        return 11;
      case CardValue.queen:
        return 12;
      case CardValue.king:
        return 13;
      default:
        throw ArgumentError('Unsupported card value: ${card.value}');
    }
  }
}
