import 'dart:math';
import 'package:playing_cards/playing_cards.dart';
import '../klondike/card_model.dart';

class FreeCellGameState {
  final List<List<KlondikeCard>> cascades = List.generate(8, (_) => []);
  final List<KlondikeCard?> freecells = List.generate(4, (_) => null);
  final List<List<KlondikeCard>> foundations = List.generate(4, (_) => []); // By suit order

  FreeCellGameState() {
    dealNewGame();
  }

  FreeCellGameState._fromSnapshot();

  void dealNewGame({int? seed}) {
    final deck = _standardDeck();
    if (seed != null) {
      deck.shuffle(Random(seed));
    } else {
      deck.shuffle();
    }
    for (final cascade in cascades) {
      cascade.clear();
    }
    for (var i = 0; i < 52; i++) {
      cascades[i % 8].add(deck[i]);
    }
    for (var i = 0; i < freecells.length; i++) {
      freecells[i] = null;
    }
    for (final f in foundations) {
      f.clear();
    }
  }

  FreeCellGameState copy() {
    final snap = FreeCellGameState._fromSnapshot();
    for (int i = 0; i < 8; i++) {
      snap.cascades[i].addAll(cascades[i].map(_copyCard));
    }
    for (int i = 0; i < 4; i++) {
      snap.freecells[i] = freecells[i] == null ? null : _copyCard(freecells[i]!);
      snap.foundations[i].addAll(foundations[i].map(_copyCard));
    }
    return snap;
  }

  void restoreFrom(FreeCellGameState snapshot) {
    for (int i = 0; i < 8; i++) {
      _replaceCards(cascades[i], snapshot.cascades[i]);
    }
    for (int i = 0; i < 4; i++) {
      freecells[i] = snapshot.freecells[i] == null ? null : _copyCard(snapshot.freecells[i]!);
      _replaceCards(foundations[i], snapshot.foundations[i]);
    }
  }

  static List<KlondikeCard> _standardDeck() {
    return [
      for (final suit in Suit.values)
        for (final value in CardValue.values)
          KlondikeCard(PlayingCard(suit, value), faceUp: true),
    ];
  }
}

KlondikeCard _copyCard(KlondikeCard card) => KlondikeCard(card.card, faceUp: card.faceUp);
void _replaceCards(List<KlondikeCard> dst, List<KlondikeCard> src) {
  dst.clear();
  dst.addAll(src.map(_copyCard));
}
