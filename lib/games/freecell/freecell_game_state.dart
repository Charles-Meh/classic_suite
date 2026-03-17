import 'dart:convert';
import 'dart:math';

import 'package:playing_cards/playing_cards.dart';

import '../klondike/card_model.dart';

class FreeCellGameState {
  static const String storageKey = 'classic_suite.freecell.saved_state';

  final List<List<KlondikeCard>> cascades = List.generate(8, (_) => []);
  final List<KlondikeCard?> freecells = List.generate(4, (_) => null);
  final List<List<KlondikeCard>> foundations = List.generate(4, (_) => []);

  int? gameNumber;
  int elapsedSeconds;
  int moveCount;
  int score;

  FreeCellGameState({
    this.gameNumber,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 0,
  }) {
    dealNewGame(seed: gameNumber);
  }

  FreeCellGameState._fromSnapshot({
    this.gameNumber,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 0,
  });

  bool get isWon => foundations.every((pile) => pile.length == 13);

  int get emptyFreecellCount => freecells.where((card) => card == null).length;

  int get emptyCascadeCount => cascades.where((pile) => pile.isEmpty).length;

  Map<String, dynamic> toJson() {
    return {
      'gameNumber': gameNumber,
      'elapsedSeconds': elapsedSeconds,
      'moveCount': moveCount,
      'score': score,
      'cascades': cascades
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
      'freecells': freecells
          .map((card) => card == null ? null : encodeKlondikeCard(card))
          .toList(),
      'foundations': foundations
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory FreeCellGameState.fromJson(Map<String, dynamic> json) {
    final state = FreeCellGameState._fromSnapshot(
      gameNumber: (json['gameNumber'] as num?)?.toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      moveCount: (json['moveCount'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
    );

    final cascades = json['cascades'] as List<dynamic>? ?? const [];
    for (int i = 0; i < state.cascades.length; i++) {
      _replaceCards(
        state.cascades[i],
        i < cascades.length ? _decodePile(cascades[i]) : const [],
      );
    }

    final freecells = json['freecells'] as List<dynamic>? ?? const [];
    for (int i = 0; i < state.freecells.length; i++) {
      if (i >= freecells.length || freecells[i] == null) {
        state.freecells[i] = null;
      } else {
        state.freecells[i] = decodeKlondikeCard(
          (freecells[i] as Map).cast<String, dynamic>(),
        );
      }
    }

    final foundations = json['foundations'] as List<dynamic>? ?? const [];
    for (int i = 0; i < state.foundations.length; i++) {
      _replaceCards(
        state.foundations[i],
        i < foundations.length ? _decodePile(foundations[i]) : const [],
      );
    }

    return state;
  }

  static FreeCellGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return FreeCellGameState.fromJson(decoded);
      }
      if (decoded is Map) {
        return FreeCellGameState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void incrementElapsed() {
    if (!isWon) {
      elapsedSeconds += 1;
    }
  }

  void dealNewGame({int? seed}) {
    gameNumber = seed ?? Random().nextInt(1 << 31);
    elapsedSeconds = 0;
    moveCount = 0;
    score = 0;
    final deck = _standardDeck();
    deck.shuffle(Random(gameNumber));
    for (final cascade in cascades) {
      cascade.clear();
    }
    for (var i = 0; i < 52; i++) {
      cascades[i % 8].add(deck[i]);
    }
    for (var i = 0; i < freecells.length; i++) {
      freecells[i] = null;
    }
    for (final foundation in foundations) {
      foundation.clear();
    }
  }

  FreeCellGameState copy() {
    final snap = FreeCellGameState._fromSnapshot(
      gameNumber: gameNumber,
      elapsedSeconds: elapsedSeconds,
      moveCount: moveCount,
      score: score,
    );
    for (int i = 0; i < 8; i++) {
      snap.cascades[i].addAll(cascades[i].map(_copyCard));
    }
    for (int i = 0; i < 4; i++) {
      snap.freecells[i] = freecells[i] == null
          ? null
          : _copyCard(freecells[i]!);
      snap.foundations[i].addAll(foundations[i].map(_copyCard));
    }
    return snap;
  }

  void restoreFrom(FreeCellGameState snapshot) {
    gameNumber = snapshot.gameNumber;
    elapsedSeconds = snapshot.elapsedSeconds;
    moveCount = snapshot.moveCount;
    score = snapshot.score;
    for (int i = 0; i < 8; i++) {
      _replaceCards(cascades[i], snapshot.cascades[i]);
    }
    for (int i = 0; i < 4; i++) {
      freecells[i] = snapshot.freecells[i] == null
          ? null
          : _copyCard(snapshot.freecells[i]!);
      _replaceCards(foundations[i], snapshot.foundations[i]);
    }
  }

  bool canMoveToFoundation(KlondikeCard card) {
    final foundation = foundations[_foundationIndexForSuit(card.card.suit)];
    if (foundation.isEmpty) {
      return card.valueIndex == 1;
    }
    final top = foundation.last;
    return top.card.suit == card.card.suit &&
        card.valueIndex == top.valueIndex + 1;
  }

  bool moveToFoundation(KlondikeCard card) {
    if (!canMoveToFoundation(card)) {
      return false;
    }
    final location = _findCard(card);
    if (location == null || !_isAccessibleSingleCard(location)) {
      return false;
    }
    _removeCardAt(location);
    foundations[_foundationIndexForSuit(card.card.suit)].add(card);
    moveCount += 1;
    score += 10;
    return true;
  }

  bool canMoveToFreecell(KlondikeCard card, {int? freecellIndex}) {
    final location = _findCard(card);
    if (location == null || !_isAccessibleSingleCard(location)) {
      return false;
    }
    if (freecellIndex != null) {
      return freecells[freecellIndex] == null;
    }
    return freecells.any((slot) => slot == null);
  }

  bool moveToFreecell(KlondikeCard card, {int? freecellIndex}) {
    if (!canMoveToFreecell(card, freecellIndex: freecellIndex)) {
      return false;
    }
    final location = _findCard(card);
    if (location == null) {
      return false;
    }
    final targetIndex =
        freecellIndex ?? freecells.indexWhere((slot) => slot == null);
    if (targetIndex < 0) {
      return false;
    }
    _removeCardAt(location);
    freecells[targetIndex] = card;
    moveCount += 1;
    return true;
  }

  bool canMoveCardsToCascade(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (cards.isEmpty || !_isValidSequence(cards)) {
      return false;
    }
    final location = _findRun(cards);
    if (location == null) {
      return false;
    }
    if (location.zone == _FreeCellZone.cascade &&
        identical(cascades[location.index], targetPile)) {
      return false;
    }
    final movableLimit = maxMovableCards(targetCascade: targetPile);
    if (cards.length > movableLimit) {
      return false;
    }
    if (targetPile.isNotEmpty) {
      final targetTop = targetPile.last;
      return _isAlternatingColor(targetTop, cards.first) &&
          targetTop.valueIndex == cards.first.valueIndex + 1;
    }
    return true;
  }

  bool moveCardsToCascade(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (!canMoveCardsToCascade(cards, targetPile)) {
      return false;
    }
    final location = _findRun(cards);
    if (location == null) {
      return false;
    }
    _removeRun(location, cards.length);
    targetPile.addAll(cards);
    moveCount += 1;
    return true;
  }

  int maxMovableCards({required List<KlondikeCard> targetCascade}) {
    var emptyCascades = emptyCascadeCount;
    final targetIsEmpty = targetCascade.isEmpty;
    if (targetIsEmpty) {
      emptyCascades -= 1;
    }
    if (emptyCascades < 0) {
      emptyCascades = 0;
    }
    return (emptyFreecellCount + 1) * (1 << emptyCascades);
  }

  bool autoMoveSafeToFoundation() {
    var movedAny = false;
    var movedThisPass = true;
    while (movedThisPass) {
      movedThisPass = false;
      for (final cascade in cascades) {
        if (cascade.isEmpty) {
          continue;
        }
        final top = cascade.last;
        if (_canAutoSendHome(top) && moveToFoundation(top)) {
          movedAny = true;
          movedThisPass = true;
          break;
        }
      }
      if (movedThisPass) {
        continue;
      }
      for (final card in freecells) {
        if (card == null) {
          continue;
        }
        if (_canAutoSendHome(card) && moveToFoundation(card)) {
          movedAny = true;
          movedThisPass = true;
          break;
        }
      }
    }
    return movedAny;
  }

  bool _canAutoSendHome(KlondikeCard card) {
    if (!canMoveToFoundation(card)) {
      return false;
    }
    if (card.valueIndex <= 2) {
      return true;
    }
    final oppositeFoundationsReady = switch (card.card.suit) {
      Suit.clubs || Suit.spades => min(
        _foundationHeight(Suit.hearts),
        _foundationHeight(Suit.diamonds),
      ),
      Suit.hearts || Suit.diamonds => min(
        _foundationHeight(Suit.clubs),
        _foundationHeight(Suit.spades),
      ),
      _ => 0,
    };
    return oppositeFoundationsReady >= card.valueIndex - 1;
  }

  int _foundationHeight(Suit suit) =>
      foundations[_foundationIndexForSuit(suit)].length;

  static List<KlondikeCard> _standardDeck() {
    const suits = [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades];
    const values = [
      CardValue.ace,
      CardValue.two,
      CardValue.three,
      CardValue.four,
      CardValue.five,
      CardValue.six,
      CardValue.seven,
      CardValue.eight,
      CardValue.nine,
      CardValue.ten,
      CardValue.jack,
      CardValue.queen,
      CardValue.king,
    ];

    return [
      for (final suit in suits)
        for (final value in values)
          KlondikeCard(PlayingCard(suit, value), faceUp: true),
    ];
  }

  bool _isValidSequence(List<KlondikeCard> cards) {
    if (cards.isEmpty) {
      return false;
    }
    for (int i = 0; i < cards.length - 1; i++) {
      final upper = cards[i];
      final lower = cards[i + 1];
      if (!_isAlternatingColor(upper, lower) ||
          upper.valueIndex != lower.valueIndex + 1) {
        return false;
      }
    }
    return true;
  }

  bool _isAlternatingColor(KlondikeCard a, KlondikeCard b) =>
      _isRed(a.card.suit) != _isRed(b.card.suit);

  bool _isRed(Suit suit) => suit == Suit.hearts || suit == Suit.diamonds;

  _FreeCellLocation? _findCard(KlondikeCard card) {
    for (int i = 0; i < cascades.length; i++) {
      final cardIndex = cascades[i].indexWhere(
        (candidate) => identical(candidate, card),
      );
      if (cardIndex != -1) {
        return _FreeCellLocation(_FreeCellZone.cascade, i, cardIndex);
      }
    }
    for (int i = 0; i < freecells.length; i++) {
      if (identical(freecells[i], card)) {
        return _FreeCellLocation(_FreeCellZone.freecell, i, 0);
      }
    }
    for (int i = 0; i < foundations.length; i++) {
      final pile = foundations[i];
      if (pile.isNotEmpty && identical(pile.last, card)) {
        return _FreeCellLocation(_FreeCellZone.foundation, i, pile.length - 1);
      }
    }
    return null;
  }

  _FreeCellLocation? _findRun(List<KlondikeCard> cards) {
    if (cards.isEmpty) {
      return null;
    }
    if (cards.length == 1) {
      final location = _findCard(cards.first);
      if (location == null || !_isAccessibleSingleCard(location)) {
        return null;
      }
      return location;
    }
    for (int pileIndex = 0; pileIndex < cascades.length; pileIndex++) {
      final pile = cascades[pileIndex];
      for (int start = 0; start <= pile.length - cards.length; start++) {
        var matches = true;
        for (int offset = 0; offset < cards.length; offset++) {
          if (!identical(pile[start + offset], cards[offset])) {
            matches = false;
            break;
          }
        }
        if (matches && start + cards.length == pile.length) {
          return _FreeCellLocation(_FreeCellZone.cascade, pileIndex, start);
        }
      }
    }
    if (cards.length == 1) {
      return _findCard(cards.first);
    }
    return null;
  }

  void _removeCardAt(_FreeCellLocation location) {
    switch (location.zone) {
      case _FreeCellZone.cascade:
        cascades[location.index].removeAt(location.cardIndex);
      case _FreeCellZone.freecell:
        freecells[location.index] = null;
      case _FreeCellZone.foundation:
        foundations[location.index].removeLast();
    }
  }

  void _removeRun(_FreeCellLocation location, int length) {
    switch (location.zone) {
      case _FreeCellZone.cascade:
        cascades[location.index].removeRange(
          location.cardIndex,
          location.cardIndex + length,
        );
      case _FreeCellZone.freecell:
        if (length != 1) {
          throw StateError('Freecells can only hold one card.');
        }
        freecells[location.index] = null;
      case _FreeCellZone.foundation:
        if (length != 1) {
          throw StateError('Foundations can only move one card at a time.');
        }
        foundations[location.index].removeLast();
    }
  }

  bool _isAccessibleSingleCard(_FreeCellLocation location) {
    return switch (location.zone) {
      _FreeCellZone.cascade =>
        location.cardIndex == cascades[location.index].length - 1,
      _FreeCellZone.freecell => freecells[location.index] != null,
      _FreeCellZone.foundation =>
        foundations[location.index].isNotEmpty &&
            location.cardIndex == foundations[location.index].length - 1,
    };
  }

  int _foundationIndexForSuit(Suit suit) {
    return switch (suit) {
      Suit.clubs => 0,
      Suit.diamonds => 1,
      Suit.hearts => 2,
      Suit.spades => 3,
      _ => throw ArgumentError('Unsupported suit: $suit'),
    };
  }
}

class _FreeCellLocation {
  const _FreeCellLocation(this.zone, this.index, this.cardIndex);

  final _FreeCellZone zone;
  final int index;
  final int cardIndex;
}

enum _FreeCellZone { cascade, freecell, foundation }

KlondikeCard _copyCard(KlondikeCard card) =>
    KlondikeCard(card.card, faceUp: card.faceUp);

List<KlondikeCard> _decodePile(dynamic pile) {
  return ((pile as List<dynamic>?) ?? const [])
      .whereType<Map>()
      .map((card) => decodeKlondikeCard(card.cast<String, dynamic>()))
      .toList();
}

void _replaceCards(List<KlondikeCard> dst, List<KlondikeCard> src) {
  dst.clear();
  dst.addAll(src.map(_copyCard));
}
