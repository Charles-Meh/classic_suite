import 'dart:convert';
import 'dart:math';

import 'package:playing_cards/playing_cards.dart';

const List<CardValue> _tripeaksValues = [
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

class TriPeaksCard {
  const TriPeaksCard({required this.card, this.faceUp = true});

  final PlayingCard card;
  final bool faceUp;

  TriPeaksCard copyWith({PlayingCard? card, bool? faceUp}) {
    return TriPeaksCard(
      card: card ?? this.card,
      faceUp: faceUp ?? this.faceUp,
    );
  }

  int get rank => switch (card.value) {
    CardValue.ace => 1,
    CardValue.two => 2,
    CardValue.three => 3,
    CardValue.four => 4,
    CardValue.five => 5,
    CardValue.six => 6,
    CardValue.seven => 7,
    CardValue.eight => 8,
    CardValue.nine => 9,
    CardValue.ten => 10,
    CardValue.jack => 11,
    CardValue.queen => 12,
    CardValue.king => 13,
    _ => throw ArgumentError('Unsupported card value: ${card.value}'),
  };

  Map<String, Object?> toJson() => {
    'suit': card.suit.name,
    'value': card.value.name,
    'faceUp': faceUp,
  };

  factory TriPeaksCard.fromJson(Map<String, dynamic> json) {
    final suit = Suit.values.firstWhere((value) => value.name == json['suit']);
    final cardValue = CardValue.values.firstWhere(
      (value) => value.name == json['value'],
    );
    return TriPeaksCard(
      card: PlayingCard(suit, cardValue),
      faceUp: json['faceUp'] as bool? ?? true,
    );
  }
}

class TriPeaksPosition {
  const TriPeaksPosition({
    required this.index,
    required this.row,
    required this.column,
    this.children = const [],
  });

  final int index;
  final int row;
  final double column;
  final List<int> children;
}

enum TriPeaksStatus { active, won, lost }

class TriPeaksGameState {
  TriPeaksGameState._({
    required this.tableau,
    required this.stock,
    required this.waste,
    required this.clearedCount,
    required this.score,
    required this.currentRun,
    required this.longestRun,
    required this.drawCount,
    required this.elapsedSeconds,
    required this.paused,
    required this.status,
    required this.message,
    required this.seed,
  });

  static const String storageKey = 'classic_suite.tripeaks.saved_state';
  static const List<TriPeaksPosition> layout = [
    TriPeaksPosition(index: 0, row: 0, column: 1.0, children: [3, 4]),
    TriPeaksPosition(index: 1, row: 0, column: 5.0, children: [5, 6]),
    TriPeaksPosition(index: 2, row: 0, column: 9.0, children: [7, 8]),
    TriPeaksPosition(index: 3, row: 1, column: 0.5, children: [9, 10]),
    TriPeaksPosition(index: 4, row: 1, column: 1.5, children: [10, 11]),
    TriPeaksPosition(index: 5, row: 1, column: 4.5, children: [12, 13]),
    TriPeaksPosition(index: 6, row: 1, column: 5.5, children: [13, 14]),
    TriPeaksPosition(index: 7, row: 1, column: 8.5, children: [15, 16]),
    TriPeaksPosition(index: 8, row: 1, column: 9.5, children: [16, 17]),
    TriPeaksPosition(index: 9, row: 2, column: 0.0, children: [18, 19]),
    TriPeaksPosition(index: 10, row: 2, column: 1.0, children: [19, 20]),
    TriPeaksPosition(index: 11, row: 2, column: 2.0, children: [20, 21]),
    TriPeaksPosition(index: 12, row: 2, column: 4.0, children: [21, 22]),
    TriPeaksPosition(index: 13, row: 2, column: 5.0, children: [22, 23]),
    TriPeaksPosition(index: 14, row: 2, column: 6.0, children: [23, 24]),
    TriPeaksPosition(index: 15, row: 2, column: 8.0, children: [24, 25]),
    TriPeaksPosition(index: 16, row: 2, column: 9.0, children: [25, 26]),
    TriPeaksPosition(index: 17, row: 2, column: 10.0, children: [26, 27]),
    TriPeaksPosition(index: 18, row: 3, column: 0.0),
    TriPeaksPosition(index: 19, row: 3, column: 1.0),
    TriPeaksPosition(index: 20, row: 3, column: 2.0),
    TriPeaksPosition(index: 21, row: 3, column: 3.0),
    TriPeaksPosition(index: 22, row: 3, column: 4.0),
    TriPeaksPosition(index: 23, row: 3, column: 5.0),
    TriPeaksPosition(index: 24, row: 3, column: 6.0),
    TriPeaksPosition(index: 25, row: 3, column: 7.0),
    TriPeaksPosition(index: 26, row: 3, column: 8.0),
    TriPeaksPosition(index: 27, row: 3, column: 9.0),
  ];

  final List<TriPeaksCard?> tableau;
  final List<TriPeaksCard> stock;
  final List<TriPeaksCard> waste;
  final int clearedCount;
  final int score;
  final int currentRun;
  final int longestRun;
  final int drawCount;
  final int elapsedSeconds;
  final bool paused;
  final TriPeaksStatus status;
  final String message;
  final int seed;

  factory TriPeaksGameState.newGame({int? seed}) {
    final actualSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final deck = _buildDeck()..shuffle(Random(actualSeed));
    final tableau = List<TriPeaksCard?>.generate(
      28,
      (index) => TriPeaksCard(card: deck[index]),
    );
    final waste = [TriPeaksCard(card: deck[28])];
    final stock = [
      for (int index = 29; index < deck.length; index++)
        TriPeaksCard(card: deck[index]),
    ];

    return TriPeaksGameState._(
      tableau: tableau,
      stock: stock,
      waste: waste,
      clearedCount: 0,
      score: 0,
      currentRun: 0,
      longestRun: 0,
      drawCount: 0,
      elapsedSeconds: 0,
      paused: false,
      status: TriPeaksStatus.active,
      message: 'Clear the peaks by matching one rank up or down.',
      seed: actualSeed,
    );
  }

  factory TriPeaksGameState.debug({
    required List<TriPeaksCard?> tableau,
    required List<TriPeaksCard> stock,
    required List<TriPeaksCard> waste,
    int clearedCount = 0,
    int score = 0,
    int currentRun = 0,
    int longestRun = 0,
    int drawCount = 0,
    int elapsedSeconds = 0,
    bool paused = false,
    TriPeaksStatus status = TriPeaksStatus.active,
    String message = 'Debug state',
    int seed = 0,
  }) {
    return TriPeaksGameState._(
      tableau: List<TriPeaksCard?>.from(tableau),
      stock: List<TriPeaksCard>.from(stock),
      waste: List<TriPeaksCard>.from(waste),
      clearedCount: clearedCount,
      score: score,
      currentRun: currentRun,
      longestRun: longestRun,
      drawCount: drawCount,
      elapsedSeconds: elapsedSeconds,
      paused: paused,
      status: status,
      message: message,
      seed: seed,
    );
  }

  factory TriPeaksGameState.fromJson(Map<String, dynamic> json) {
    return TriPeaksGameState._(
      tableau: (json['tableau'] as List<dynamic>)
          .map(
            (entry) => entry == null
                ? null
                : TriPeaksCard.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      stock: (json['stock'] as List<dynamic>)
          .map((entry) => TriPeaksCard.fromJson(entry as Map<String, dynamic>))
          .toList(),
      waste: (json['waste'] as List<dynamic>)
          .map((entry) => TriPeaksCard.fromJson(entry as Map<String, dynamic>))
          .toList(),
      clearedCount: (json['clearedCount'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      currentRun: (json['currentRun'] as num?)?.toInt() ?? 0,
      longestRun: (json['longestRun'] as num?)?.toInt() ?? 0,
      drawCount: (json['drawCount'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      paused: json['paused'] as bool? ?? false,
      status: TriPeaksStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? 'active'),
        orElse: () => TriPeaksStatus.active,
      ),
      message: json['message'] as String? ??
          'Clear the peaks by matching one rank up or down.',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
    );
  }

  TriPeaksGameState copyWith({
    List<TriPeaksCard?>? tableau,
    List<TriPeaksCard>? stock,
    List<TriPeaksCard>? waste,
    int? clearedCount,
    int? score,
    int? currentRun,
    int? longestRun,
    int? drawCount,
    int? elapsedSeconds,
    bool? paused,
    TriPeaksStatus? status,
    String? message,
    int? seed,
  }) {
    return TriPeaksGameState._(
      tableau: tableau ?? List<TriPeaksCard?>.from(this.tableau),
      stock: stock ?? List<TriPeaksCard>.from(this.stock),
      waste: waste ?? List<TriPeaksCard>.from(this.waste),
      clearedCount: clearedCount ?? this.clearedCount,
      score: score ?? this.score,
      currentRun: currentRun ?? this.currentRun,
      longestRun: longestRun ?? this.longestRun,
      drawCount: drawCount ?? this.drawCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      paused: paused ?? this.paused,
      status: status ?? this.status,
      message: message ?? this.message,
      seed: seed ?? this.seed,
    );
  }

  static List<PlayingCard> _buildDeck() {
    const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    final deck = <PlayingCard>[];
    for (final suit in suits) {
      for (final value in _tripeaksValues) {
        deck.add(PlayingCard(suit, value));
      }
    }
    return deck;
  }

  bool get isWon => status == TriPeaksStatus.won;
  bool get isLost => status == TriPeaksStatus.lost;
  bool get isActive => status == TriPeaksStatus.active && !paused;
  int get cardsRemainingInPeaks => 28 - clearedCount;
  TriPeaksCard get wasteTop => waste.last;

  List<int> get exposedIndexes => [
    for (final position in layout)
      if (tableau[position.index] != null && isExposed(position.index)) position.index,
  ];

  bool isExposed(int index) {
    final position = layout[index];
    if (tableau[index] == null) {
      return false;
    }
    for (final child in position.children) {
      if (tableau[child] != null) {
        return false;
      }
    }
    return true;
  }

  bool isValidMove(int index) {
    final card = tableau[index];
    if (card == null || !isExposed(index) || status != TriPeaksStatus.active || paused) {
      return false;
    }
    return ranksAreAdjacent(card.rank, wasteTop.rank);
  }

  bool get hasAnyValidMove => exposedIndexes.any(isValidMove);

  static bool ranksAreAdjacent(int a, int b) {
    if ((a == 1 && b == 13) || (a == 13 && b == 1)) {
      return true;
    }
    return (a - b).abs() == 1;
  }

  TriPeaksGameState removeCard(int index) {
    if (!isValidMove(index)) {
      return this;
    }

    final nextTableau = List<TriPeaksCard?>.from(tableau);
    final removed = nextTableau[index]!;
    nextTableau[index] = null;
    final nextWaste = List<TriPeaksCard>.from(waste)..add(removed);
    final nextRun = currentRun + 1;
    final nextLongestRun = max(longestRun, nextRun);
    final nextScore = score + (nextRun * 100);
    final nextCleared = clearedCount + 1;

    var next = copyWith(
      tableau: nextTableau,
      waste: nextWaste,
      clearedCount: nextCleared,
      score: nextScore,
      currentRun: nextRun,
      longestRun: nextLongestRun,
      message: 'Run x$nextRun • +${nextRun * 100} points',
    );

    if (nextCleared == 28) {
      next = next.copyWith(
        status: TriPeaksStatus.won,
        score: next.score + 5000,
        message: 'Peaks cleared. You win.',
      );
    } else if (!next.hasAnyValidMove && next.stock.isEmpty) {
      next = next.copyWith(
        status: TriPeaksStatus.lost,
        message: 'No moves left. Deal a new game.',
      );
    }

    return next;
  }

  TriPeaksGameState drawFromStock() {
    if (stock.isEmpty || status != TriPeaksStatus.active || paused) {
      return this;
    }

    final nextStock = List<TriPeaksCard>.from(stock);
    final drawn = nextStock.removeLast();
    final nextWaste = List<TriPeaksCard>.from(waste)..add(drawn);
    var next = copyWith(
      stock: nextStock,
      waste: nextWaste,
      drawCount: drawCount + 1,
      currentRun: 0,
      message: nextStock.isEmpty
          ? 'Last stock card drawn.'
          : 'Stock drawn. Build another run.',
    );

    if (!next.hasAnyValidMove && next.stock.isEmpty) {
      next = next.copyWith(
        status: TriPeaksStatus.lost,
        message: 'No moves left. Deal a new game.',
      );
    }
    return next;
  }

  TriPeaksGameState incrementElapsed() {
    if (!isActive) {
      return this;
    }
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  TriPeaksGameState togglePaused() {
    if (isWon || isLost) {
      return this;
    }
    return copyWith(
      paused: !paused,
      message: !paused ? 'Game paused.' : 'Back in play.',
    );
  }

  TriPeaksGameState withElapsedSeconds(int value) {
    return copyWith(elapsedSeconds: value < 0 ? 0 : value);
  }

  Map<String, Object?> toJson() => {
    'tableau': tableau.map((entry) => entry?.toJson()).toList(),
    'stock': stock.map((entry) => entry.toJson()).toList(),
    'waste': waste.map((entry) => entry.toJson()).toList(),
    'clearedCount': clearedCount,
    'score': score,
    'currentRun': currentRun,
    'longestRun': longestRun,
    'drawCount': drawCount,
    'elapsedSeconds': elapsedSeconds,
    'paused': paused,
    'status': status.name,
    'message': message,
    'seed': seed,
  };

  String encode() => jsonEncode(toJson());

  static TriPeaksGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return TriPeaksGameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
