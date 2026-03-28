import 'dart:convert';
import 'dart:math';

import 'package:playing_cards/playing_cards.dart';

import '../klondike/card_model.dart';

const List<CardValue> _spiderValues = [
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

class SpiderGameState {
  static const String storageKey = 'classic_suite.spider.saved_state';

  SpiderGameState({
    this.suitMode = 1,
    this.currentSeed,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 500,
  }) {
    dealNewGame(seed: currentSeed);
  }

  SpiderGameState._fromSnapshot({
    required this.suitMode,
    this.currentSeed,
    this.elapsedSeconds = 0,
    this.moveCount = 0,
    this.score = 500,
  });

  int suitMode;
  int? currentSeed;
  int elapsedSeconds;
  int moveCount;
  int score;
  final List<KlondikeCard> stock = [];
  final List<List<KlondikeCard>> tableau = List.generate(10, (_) => []);
  final List<List<KlondikeCard>> completedRuns = [];

  Map<String, dynamic> toJson() {
    return {
      'suitMode': suitMode,
      'currentSeed': currentSeed,
      'elapsedSeconds': elapsedSeconds,
      'moveCount': moveCount,
      'score': score,
      'stock': stock.map(encodeKlondikeCard).toList(),
      'tableau': tableau
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
      'completedRuns': completedRuns
          .map((pile) => pile.map(encodeKlondikeCard).toList())
          .toList(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory SpiderGameState.fromJson(Map<String, dynamic> json) {
    final state = SpiderGameState._fromSnapshot(
      suitMode: (json['suitMode'] as num).toInt(),
      currentSeed: (json['currentSeed'] as num?)?.toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
      moveCount: (json['moveCount'] as num).toInt(),
      score: (json['score'] as num).toInt(),
    );
    state._replaceFromJsonPile(state.stock, json['stock'] as List<dynamic>);
    state._replacePileListFromJson(
      state.tableau,
      json['tableau'] as List<dynamic>,
    );
    state.completedRuns
      ..clear()
      ..addAll(
        (json['completedRuns'] as List<dynamic>)
            .map((pile) => state._decodePile(pile))
            .toList(),
      );
    return state;
  }

  static SpiderGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SpiderGameState.fromJson(decoded);
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
    currentSeed = seed;
    elapsedSeconds = 0;
    moveCount = 0;
    score = 500;
    _populateStock(seed: seed);
    _dealOpeningTableau();
    completedRuns.clear();
  }

  void dealSeededGame(int seed) {
    dealNewGame(seed: seed);
  }

  SpiderGameState copy() {
    final snapshot = SpiderGameState._fromSnapshot(
      suitMode: suitMode,
      currentSeed: currentSeed,
      elapsedSeconds: elapsedSeconds,
      moveCount: moveCount,
      score: score,
    );
    snapshot.stock.addAll(stock.map(_copyCard));
    for (int i = 0; i < tableau.length; i++) {
      snapshot.tableau[i].addAll(tableau[i].map(_copyCard));
    }
    for (int i = 0; i < completedRuns.length; i++) {
      snapshot.completedRuns.add(completedRuns[i].map(_copyCard).toList());
    }
    return snapshot;
  }

  void restoreFrom(SpiderGameState snapshot) {
    suitMode = snapshot.suitMode;
    currentSeed = snapshot.currentSeed;
    elapsedSeconds = snapshot.elapsedSeconds;
    moveCount = snapshot.moveCount;
    score = snapshot.score;
    _replaceCards(stock, snapshot.stock);
    for (int i = 0; i < tableau.length; i++) {
      _replaceCards(tableau[i], snapshot.tableau[i]);
    }
    completedRuns
      ..clear()
      ..addAll(
        snapshot.completedRuns.map((pile) => pile.map(_copyCard).toList()),
      );
  }

  bool canPickUpRun(int pileIndex, int startIndex) {
    final pile = tableau[pileIndex];
    if (startIndex < 0 || startIndex >= pile.length) {
      return false;
    }
    if (!pile[startIndex].faceUp) {
      return false;
    }
    return _isMovableRun(pile.sublist(startIndex));
  }

  List<KlondikeCard> runAt(int pileIndex, int startIndex) {
    if (!canPickUpRun(pileIndex, startIndex)) {
      return const [];
    }
    return tableau[pileIndex].sublist(startIndex);
  }

  bool canMoveCardsToTableau(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (cards.isEmpty || cards.any((card) => !card.faceUp)) {
      return false;
    }

    final origin = _findTableauPileContaining(cards.first);
    if (origin == null) {
      return false;
    }
    final startIndex = origin.indexOf(cards.first);
    if (!_matchesTrailingRun(origin, startIndex, cards)) {
      return false;
    }
    if (!_isMovableRun(cards)) {
      return false;
    }

    if (targetPile.isEmpty) {
      return true;
    }

    final destinationTop = targetPile.last;
    return cards.first.valueIndex == destinationTop.valueIndex - 1;
  }

  bool moveCardsToTableau(
    List<KlondikeCard> cards,
    List<KlondikeCard> targetPile,
  ) {
    if (!canMoveCardsToTableau(cards, targetPile)) {
      return false;
    }
    if (!_removeCards(cards)) {
      return false;
    }
    targetPile.addAll(cards);
    _removeCompletedRunIfPresent(targetPile);
    moveCount += 1;
    score = max(0, score - 1);
    return true;
  }

  bool get canDealFromStock {
    return stock.length >= tableau.length &&
        tableau.every((pile) => pile.isNotEmpty);
  }

  bool dealFromStock() {
    if (!canDealFromStock) {
      return false;
    }

    for (final pile in tableau) {
      final card = stock.removeLast();
      card.faceUp = true;
      pile.add(card);
      _removeCompletedRunIfPresent(pile);
    }
    moveCount += 1;
    score = max(0, score - 1);
    return true;
  }

  bool get isWon => completedRuns.length == 8;

  int get dealsRemaining => stock.length ~/ tableau.length;

  void _populateStock({int? seed}) {
    stock.clear();
    final deck = _spiderDeck();
    if (seed == null) {
      deck.shuffle(Random());
    } else {
      _shuffleDeterministically(deck, seed);
    }
    stock.addAll(deck.map((card) => KlondikeCard(card, faceUp: false)));
  }

  List<PlayingCard> _spiderDeck() {
    final deck = <PlayingCard>[];
    final suits = switch (suitMode) {
      1 => List.filled(8, Suit.spades),
      2 => [
        Suit.spades,
        Suit.spades,
        Suit.spades,
        Suit.spades,
        Suit.hearts,
        Suit.hearts,
        Suit.hearts,
        Suit.hearts,
      ],
      4 => [
        Suit.clubs,
        Suit.clubs,
        Suit.diamonds,
        Suit.diamonds,
        Suit.hearts,
        Suit.hearts,
        Suit.spades,
        Suit.spades,
      ],
      _ => throw ArgumentError.value(
        suitMode,
        'suitMode',
        'Must be 1, 2, or 4.',
      ),
    };

    for (final suit in suits) {
      for (final value in _spiderValues) {
        deck.add(PlayingCard(suit, value));
      }
    }
    return deck;
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

  void _dealOpeningTableau() {
    final pileLengths = [6, 6, 6, 6, 5, 5, 5, 5, 5, 5];
    for (int pileIndex = 0; pileIndex < tableau.length; pileIndex++) {
      tableau[pileIndex].clear();
      final pileLength = pileLengths[pileIndex];
      for (int cardIndex = 0; cardIndex < pileLength; cardIndex++) {
        final card = stock.removeLast();
        tableau[pileIndex].add(
          KlondikeCard(card.card, faceUp: cardIndex == pileLength - 1),
        );
      }
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

  List<KlondikeCard> _decodePile(dynamic pile) {
    return (pile as List<dynamic>)
        .map(
          (card) => decodeKlondikeCard((card as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  void _replaceFromJsonPile(List<KlondikeCard> target, List<dynamic> source) {
    target
      ..clear()
      ..addAll(_decodePile(source));
  }

  void _replacePileListFromJson(
    List<List<KlondikeCard>> target,
    List<dynamic> source,
  ) {
    if (source.length != target.length) {
      throw const FormatException('Invalid Spider pile list payload.');
    }
    for (int i = 0; i < target.length; i++) {
      _replaceFromJsonPile(target[i], source[i] as List<dynamic>);
    }
  }

  List<KlondikeCard>? _findTableauPileContaining(KlondikeCard card) {
    for (final pile in tableau) {
      if (pile.contains(card)) {
        return pile;
      }
    }
    return null;
  }

  bool _removeCards(List<KlondikeCard> cards) {
    final origin = _findTableauPileContaining(cards.first);
    if (origin == null) {
      return false;
    }
    final startIndex = origin.indexOf(cards.first);
    if (!_matchesTrailingRun(origin, startIndex, cards)) {
      return false;
    }

    origin.removeRange(startIndex, origin.length);
    _flipExposedCard(origin);
    return true;
  }

  bool _matchesTrailingRun(
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

  bool _isMovableRun(List<KlondikeCard> cards) {
    if (cards.isEmpty) {
      return false;
    }
    for (int i = 0; i < cards.length; i++) {
      if (!cards[i].faceUp) {
        return false;
      }
    }
    for (int i = 0; i < cards.length - 1; i++) {
      final current = cards[i];
      final next = cards[i + 1];
      final sameSuit = current.card.suit == next.card.suit;
      final descendsByOne = current.valueIndex == next.valueIndex + 1;
      if (!sameSuit || !descendsByOne) {
        return false;
      }
    }
    return true;
  }

  void _removeCompletedRunIfPresent(List<KlondikeCard> pile) {
    if (pile.length < 13) {
      return;
    }

    final candidate = pile.sublist(pile.length - 13);
    if (candidate.any((card) => !card.faceUp)) {
      return;
    }
    final suit = candidate.first.card.suit;
    if (candidate.first.card.value != CardValue.king ||
        candidate.last.card.value != CardValue.ace) {
      return;
    }

    for (int i = 0; i < candidate.length - 1; i++) {
      final current = candidate[i];
      final next = candidate[i + 1];
      if (current.card.suit != suit || next.card.suit != suit) {
        return;
      }
      if (current.valueIndex != next.valueIndex + 1) {
        return;
      }
    }

    completedRuns.add(candidate.map(_copyCard).toList());
    pile.removeRange(pile.length - 13, pile.length);
    _flipExposedCard(pile);
    score += 100;
  }

  void _flipExposedCard(List<KlondikeCard> pile) {
    if (pile.isNotEmpty && !pile.last.faceUp) {
      pile.last.faceUp = true;
    }
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
