import 'dart:convert';
import 'dart:math';

import 'package:playing_cards/playing_cards.dart';

import 'card_model.dart';

const List<Suit> _klondikeSuits = [
  Suit.clubs,
  Suit.diamonds,
  Suit.hearts,
  Suit.spades,
];

const List<CardValue> _klondikeValues = [
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

/// Represents the mutable state of a single Klondike (Klondike) game.
class GameState {
  static const String storageKey = 'classic_suite.klondike.saved_state';

  /// Number of cards drawn from the stock at a time (1 or 3).
  int drawCount;
  int? currentSeed;
  int elapsedSeconds;
  int moveCount;
  int score;

  /// All cards still in the stock, face-down.
  final List<KlondikeCard> stock = [];

  /// Cards that have been drawn from the stock, face-up.
  final List<KlondikeCard> waste = [];

  /// Four foundation piles indexed by suit order Clubs, Diamonds, Hearts, Spades.
  final List<List<KlondikeCard>> foundations = List.generate(4, (_) => []);

  /// Seven tableau piles.
  final List<List<KlondikeCard>> tableau = List.generate(7, (_) => []);

  GameState({
    this.drawCount = 1,
    this.currentSeed,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 0,
  }) {
    dealNewGame(seed: currentSeed);
  }

  GameState._fromSnapshot(
    this.drawCount, {
    this.currentSeed,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 0,
  });

  /// Starts a new shuffled game.
  void dealNewGame({int? seed}) {
    currentSeed = seed;
    elapsedSeconds = 0;
    moveCount = 0;
    score = 0;
    _populateStock(seed: seed);
    _dealTableau();
    waste.clear();
    for (final f in foundations) {
      f.clear();
    }
  }

  /// Starts a deterministic deal from a fixed seed.
  void dealSeededGame(int seed) {
    dealNewGame(seed: seed);
  }

  /// Starts a curated, guaranteed-winnable deal from a validated seed.
  void dealWinnableGame(int seed) {
    dealSeededGame(seed);
  }

  Map<String, dynamic> toJson() {
    return {
      'drawCount': drawCount,
      'currentSeed': currentSeed,
      'elapsedSeconds': elapsedSeconds,
      'moveCount': moveCount,
      'score': score,
      'stock': stock.map(encodeKlondikeCard).toList(),
      'waste': waste.map(encodeKlondikeCard).toList(),
      'foundations': foundations
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
      'tableau': tableau
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory GameState.fromJson(Map<String, dynamic> json) {
    final state = GameState._fromSnapshot(
      (json['drawCount'] as num).toInt(),
      currentSeed: (json['currentSeed'] as num?)?.toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
      moveCount: (json['moveCount'] as num).toInt(),
      score: (json['score'] as num).toInt(),
    );
    state._replaceFromJsonPile(state.stock, json['stock'] as List<dynamic>);
    state._replaceFromJsonPile(state.waste, json['waste'] as List<dynamic>);
    state._replacePileListFromJson(
      state.foundations,
      json['foundations'] as List<dynamic>,
    );
    state._replacePileListFromJson(
      state.tableau,
      json['tableau'] as List<dynamic>,
    );
    return state;
  }

  static GameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GameState.fromJson(decoded);
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

  void _populateStock({int? seed}) {
    stock.clear();
    final all = _standardDeck();
    if (seed == null) {
      all.shuffle(Random());
    } else {
      _shuffleDeterministically(all, seed);
    }
    stock.addAll(all.map((c) => KlondikeCard(c, faceUp: false)));
  }

  List<PlayingCard> _standardDeck() {
    final all = <PlayingCard>[];
    for (final suit in _klondikeSuits) {
      for (final value in _klondikeValues) {
        all.add(PlayingCard(suit, value));
      }
    }
    return all;
  }

  void _shuffleDeterministically(List<PlayingCard> cards, int seed) {
    final random = _SplitMix64(seed);
    for (int index = cards.length - 1; index > 0; index--) {
      final swapIndex = random.nextIndex(index + 1);
      final current = cards[index];
      cards[index] = cards[swapIndex];
      cards[swapIndex] = current;
    }
  }

  void _dealTableau() {
    for (int pile = 0; pile < 7; pile++) {
      tableau[pile].clear();
      for (int i = 0; i <= pile; i++) {
        final card = stock.removeLast();
        tableau[pile].add(KlondikeCard(card.card, faceUp: i == pile));
      }
    }
  }

  int drawFromStock() {
    if (stock.isEmpty) return 0;
    int moved = 0;
    for (int i = 0; i < drawCount && stock.isNotEmpty; i++) {
      final c = stock.removeLast();
      c.faceUp = true;
      waste.add(c);
      moved++;
    }
    if (moved > 0) {
      moveCount += 1;
    }
    return moved;
  }

  void recycleWaste() {
    if (waste.isEmpty) {
      return;
    }
    while (waste.isNotEmpty) {
      final c = waste.removeLast();
      c.faceUp = false;
      stock.add(c);
    }
    moveCount += 1;
  }

  List<KlondikeCard> foundationForSuit(Suit suit) {
    return foundations[_foundationIndexForSuit(suit)];
  }

  GameState copy() {
    final snapshot = GameState._fromSnapshot(
      drawCount,
      currentSeed: currentSeed,
      elapsedSeconds: elapsedSeconds,
      moveCount: moveCount,
      score: score,
    );
    snapshot.stock.addAll(stock.map(_copyCard));
    snapshot.waste.addAll(waste.map(_copyCard));
    for (int i = 0; i < foundations.length; i++) {
      snapshot.foundations[i].addAll(foundations[i].map(_copyCard));
    }
    for (int i = 0; i < tableau.length; i++) {
      snapshot.tableau[i].addAll(tableau[i].map(_copyCard));
    }
    return snapshot;
  }

  void restoreFrom(GameState snapshot) {
    drawCount = snapshot.drawCount;
    currentSeed = snapshot.currentSeed;
    elapsedSeconds = snapshot.elapsedSeconds;
    moveCount = snapshot.moveCount;
    score = snapshot.score;
    _replaceCards(stock, snapshot.stock);
    _replaceCards(waste, snapshot.waste);
    for (int i = 0; i < foundations.length; i++) {
      _replaceCards(foundations[i], snapshot.foundations[i]);
    }
    for (int i = 0; i < tableau.length; i++) {
      _replaceCards(tableau[i], snapshot.tableau[i]);
    }
  }

  bool canMoveToFoundation(KlondikeCard card) {
    if (!_canMoveSingleCard(card)) return false;
    final suitPile = foundationForSuit(card.card.suit);
    if (suitPile.isEmpty) {
      return card.card.value == CardValue.ace;
    }
    final top = suitPile.last;
    return card.valueIndex == top.valueIndex + 1;
  }

  bool moveToFoundation(KlondikeCard card) {
    if (!canMoveToFoundation(card)) return false;
    if (!_removeSingleCard(card)) return false;
    final suitPile = foundationForSuit(card.card.suit);
    suitPile.add(card);
    moveCount += 1;
    score += 10;
    return true;
  }

  bool canMoveCardsToTableau(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (cards.isEmpty) return false;
    if (cards.any((card) => !card.faceUp)) return false;

    if (cards.length == 1) {
      if (!_canMoveSingleCard(cards.first)) return false;
    } else {
      final origin = _findTableauPileContaining(cards.first);
      if (origin == null) return false;
      final startIndex = origin.indexOf(cards.first);
      if (!_matchesTrailingTableauStack(origin, startIndex, cards)) {
        return false;
      }
      if (!_isValidTableauRun(cards)) return false;
    }

    if (targetPile.isEmpty) {
      return cards.first.card.value == CardValue.king;
    }

    final destinationTop = targetPile.last;
    final hasOppositeColor =
        _isRed(cards.first.card.suit) != _isRed(destinationTop.card.suit);
    final isOneRankLower =
        cards.first.valueIndex == destinationTop.valueIndex - 1;
    return hasOppositeColor && isOneRankLower;
  }

  bool moveCardsToTableau(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (!canMoveCardsToTableau(cards, targetPile)) return false;
    if (!_removeCards(cards)) return false;
    targetPile.addAll(cards);
    moveCount += 1;
    return true;
  }

  bool canMoveStackToTableau(KlondikeCard card, List<KlondikeCard> targetPile) {
    final origin = _findTableauPileContaining(card);
    if (origin == null) return false;
    final index = origin.indexOf(card);
    return canMoveCardsToTableau(origin.sublist(index), targetPile);
  }

  bool moveStackToTableau(KlondikeCard card, List<KlondikeCard> targetPile) {
    final origin = _findTableauPileContaining(card)!;
    final idx = origin.indexOf(card);
    return moveCardsToTableau(origin.sublist(idx), targetPile);
  }

  List<KlondikeCard>? _findTableauPileContaining(KlondikeCard card) {
    for (var pile in tableau) {
      if (pile.contains(card)) return pile;
    }
    return null;
  }

  bool _isRed(Suit suit) {
    return suit == Suit.hearts || suit == Suit.diamonds;
  }

  int _foundationIndexForSuit(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return 0;
      case Suit.diamonds:
        return 1;
      case Suit.hearts:
        return 2;
      case Suit.spades:
        return 3;
      default:
        throw ArgumentError('Unsupported suit: $suit');
    }
  }

  KlondikeCard _copyCard(KlondikeCard card) {
    return KlondikeCard(card.card, faceUp: card.faceUp);
  }

  void _replaceCards(List<KlondikeCard> target, List<KlondikeCard> source) {
    target
      ..clear()
      ..addAll(source.map(_copyCard));
  }

  void _replaceFromJsonPile(List<KlondikeCard> target, List<dynamic> source) {
    target
      ..clear()
      ..addAll(
        source.map(
          (card) => decodeKlondikeCard((card as Map).cast<String, dynamic>()),
        ),
      );
  }

  void _replacePileListFromJson(
    List<List<KlondikeCard>> target,
    List<dynamic> source,
  ) {
    if (source.length != target.length) {
      throw const FormatException('Invalid Klondike pile list payload.');
    }
    for (int i = 0; i < target.length; i++) {
      _replaceFromJsonPile(target[i], source[i] as List<dynamic>);
    }
  }

  bool _canMoveSingleCard(KlondikeCard card) {
    if (!card.faceUp) return false;
    if (waste.isNotEmpty && identical(waste.last, card)) return true;
    for (final pile in tableau) {
      if (pile.isNotEmpty && identical(pile.last, card)) return true;
    }
    for (final pile in foundations) {
      if (pile.isNotEmpty && identical(pile.last, card)) return true;
    }
    return false;
  }

  bool _removeSingleCard(KlondikeCard card) {
    if (waste.isNotEmpty && identical(waste.last, card)) {
      waste.removeLast();
      return true;
    }

    for (final pile in tableau) {
      if (pile.isNotEmpty && identical(pile.last, card)) {
        pile.removeLast();
        if (pile.isNotEmpty && !pile.last.faceUp) {
          pile.last.faceUp = true;
          score += 5;
        }
        return true;
      }
    }

    for (final pile in foundations) {
      if (pile.isNotEmpty && identical(pile.last, card)) {
        pile.removeLast();
        score = max(0, score - 15);
        return true;
      }
    }

    return false;
  }

  bool _removeCards(List<KlondikeCard> cards) {
    if (cards.length == 1) {
      return _removeSingleCard(cards.first);
    }

    final origin = _findTableauPileContaining(cards.first);
    if (origin == null) return false;
    final startIndex = origin.indexOf(cards.first);
    if (!_matchesTrailingTableauStack(origin, startIndex, cards)) {
      return false;
    }

    origin.removeRange(startIndex, origin.length);
    if (origin.isNotEmpty && !origin.last.faceUp) {
      origin.last.faceUp = true;
      score += 5;
    }
    return true;
  }

  bool _matchesTrailingTableauStack(
    List<KlondikeCard> origin,
    int startIndex,
    List<KlondikeCard> cards,
  ) {
    if (startIndex < 0 || origin.length - startIndex != cards.length) {
      return false;
    }

    for (int i = 0; i < cards.length; i++) {
      if (!identical(origin[startIndex + i], cards[i])) {
        return false;
      }
    }
    return true;
  }

  bool _isValidTableauRun(List<KlondikeCard> cards) {
    for (int i = 0; i < cards.length - 1; i++) {
      final current = cards[i];
      final next = cards[i + 1];
      final alternatesColor =
          _isRed(current.card.suit) != _isRed(next.card.suit);
      final descendsByOne = current.valueIndex == next.valueIndex + 1;
      if (!alternatesColor || !descendsByOne) {
        return false;
      }
    }
    return true;
  }

  bool get isWon {
    return foundations.every((pile) => pile.length == 13);
  }
}

class _SplitMix64 {
  _SplitMix64(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFFFFFFFFFF;
  static const int _increment = 0x9E3779B97F4A7C15;
  static const int _multiplierOne = 0xBF58476D1CE4E5B9;
  static const int _multiplierTwo = 0x94D049BB133111EB;

  int _state;

  int nextIndex(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'Must be greater than zero.');
    }
    return nextUint64() % max;
  }

  int nextUint64() {
    _state = (_state + _increment) & _mask;
    var z = _state;
    z = ((z ^ (z >>> 30)) * _multiplierOne) & _mask;
    z = ((z ^ (z >>> 27)) * _multiplierTwo) & _mask;
    return (z ^ (z >>> 31)) & _mask;
  }
}
