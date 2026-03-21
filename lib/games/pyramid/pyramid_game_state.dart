import 'dart:convert';
import 'dart:math';

enum PyramidSuit { clubs, diamonds, hearts, spades }

enum PyramidRank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

enum PyramidGameStatus { running, won }

enum PyramidCardZone { pyramid, waste }

class PyramidCardRef {
  const PyramidCardRef.pyramid(this.row, this.column)
    : zone = PyramidCardZone.pyramid,
      wasteIndex = null;

  const PyramidCardRef.waste(this.wasteIndex)
    : zone = PyramidCardZone.waste,
      row = null,
      column = null;

  final PyramidCardZone zone;
  final int? row;
  final int? column;
  final int? wasteIndex;

  Map<String, Object?> toJson() => {
    'zone': zone.name,
    'row': row,
    'column': column,
    'wasteIndex': wasteIndex,
  };

  factory PyramidCardRef.fromJson(Map<String, dynamic> json) {
    final zoneName = json['zone'] as String? ?? PyramidCardZone.pyramid.name;
    final zone = PyramidCardZone.values.firstWhere(
      (value) => value.name == zoneName,
      orElse: () => PyramidCardZone.pyramid,
    );
    return switch (zone) {
      PyramidCardZone.pyramid => PyramidCardRef.pyramid(
        (json['row'] as num?)?.toInt() ?? 0,
        (json['column'] as num?)?.toInt() ?? 0,
      ),
      PyramidCardZone.waste => PyramidCardRef.waste(
        (json['wasteIndex'] as num?)?.toInt() ?? 0,
      ),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PyramidCardRef &&
        other.zone == zone &&
        other.row == row &&
        other.column == column &&
        other.wasteIndex == wasteIndex;
  }

  @override
  int get hashCode => Object.hash(zone, row, column, wasteIndex);
}

class PyramidCard {
  const PyramidCard({
    required this.suit,
    required this.rank,
    this.removed = false,
  });

  final PyramidSuit suit;
  final PyramidRank rank;
  final bool removed;

  static const List<PyramidSuit> allSuits = PyramidSuit.values;
  static const List<PyramidRank> allRanks = PyramidRank.values;

  int get value => rank.index + 1;

  String get rankLabel => switch (rank) {
    PyramidRank.ace => 'A',
    PyramidRank.jack => 'J',
    PyramidRank.queen => 'Q',
    PyramidRank.king => 'K',
    _ => '${rank.index + 1}',
  };

  String get suitSymbol => switch (suit) {
    PyramidSuit.clubs => '♣',
    PyramidSuit.diamonds => '♦',
    PyramidSuit.hearts => '♥',
    PyramidSuit.spades => '♠',
  };

  bool get isRed => suit == PyramidSuit.hearts || suit == PyramidSuit.diamonds;

  PyramidCard copyWith({PyramidSuit? suit, PyramidRank? rank, bool? removed}) {
    return PyramidCard(
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
      removed: removed ?? this.removed,
    );
  }

  Map<String, Object?> toJson() => {
    'suit': suit.name,
    'rank': rank.name,
    'removed': removed,
  };

  factory PyramidCard.fromJson(Map<String, dynamic> json) {
    return PyramidCard(
      suit: PyramidSuit.values.firstWhere(
        (value) =>
            value.name == (json['suit'] as String? ?? PyramidSuit.clubs.name),
        orElse: () => PyramidSuit.clubs,
      ),
      rank: PyramidRank.values.firstWhere(
        (value) =>
            value.name == (json['rank'] as String? ?? PyramidRank.ace.name),
        orElse: () => PyramidRank.ace,
      ),
      removed: json['removed'] as bool? ?? false,
    );
  }
}

class PyramidGameState {
  PyramidGameState._({
    required this.seed,
    required this.pyramid,
    required this.stock,
    required this.waste,
    required this.status,
    required this.message,
    required this.elapsedSeconds,
    required this.selectedCard,
    required this.paused,
    required this.cycleCount,
  });

  static const String storageKey = 'classic_suite.pyramid.saved_state';

  final int seed;
  final List<List<PyramidCard>> pyramid;
  final List<PyramidCard> stock;
  final List<PyramidCard> waste;
  final PyramidGameStatus status;
  final String message;
  final int elapsedSeconds;
  final PyramidCardRef? selectedCard;
  final bool paused;
  final int cycleCount;

  factory PyramidGameState.newGame({int? seed}) {
    final resolvedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final shuffledDeck = _shuffledDeck(resolvedSeed);
    var deckIndex = 0;
    final pyramid = List<List<PyramidCard>>.generate(7, (row) {
      return List<PyramidCard>.generate(row + 1, (column) {
        final card = shuffledDeck[deckIndex++];
        return card;
      });
    });
    final stock = shuffledDeck.sublist(deckIndex);

    return PyramidGameState._(
      seed: resolvedSeed,
      pyramid: pyramid,
      stock: stock,
      waste: const [],
      status: PyramidGameStatus.running,
      message: 'Clear the pyramid by matching exposed cards to 13.',
      elapsedSeconds: 0,
      selectedCard: null,
      paused: false,
      cycleCount: 0,
    );
  }

  factory PyramidGameState.debug({
    int seed = 1,
    required List<List<PyramidCard>> pyramid,
    List<PyramidCard> stock = const [],
    List<PyramidCard> waste = const [],
    PyramidGameStatus status = PyramidGameStatus.running,
    String message = 'Debug state',
    int elapsedSeconds = 0,
    PyramidCardRef? selectedCard,
    bool paused = false,
    int cycleCount = 0,
  }) {
    return PyramidGameState._(
      seed: seed,
      pyramid: pyramid
          .map((row) => row.map((card) => card.copyWith()).toList())
          .toList(),
      stock: stock.map((card) => card.copyWith()).toList(),
      waste: waste.map((card) => card.copyWith()).toList(),
      status: status,
      message: message,
      elapsedSeconds: elapsedSeconds,
      selectedCard: selectedCard,
      paused: paused,
      cycleCount: cycleCount,
    );
  }

  factory PyramidGameState.fromJson(Map<String, dynamic> json) {
    return PyramidGameState._(
      seed: (json['seed'] as num?)?.toInt() ?? 1,
      pyramid: ((json['pyramid'] as List<dynamic>?) ?? const [])
          .map(
            (row) => (row as List<dynamic>)
                .map(
                  (card) => PyramidCard.fromJson(card as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList(),
      stock: ((json['stock'] as List<dynamic>?) ?? const [])
          .map((card) => PyramidCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      waste: ((json['waste'] as List<dynamic>?) ?? const [])
          .map((card) => PyramidCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      status: PyramidGameStatus.values.firstWhere(
        (value) =>
            value.name ==
            (json['status'] as String? ?? PyramidGameStatus.running.name),
        orElse: () => PyramidGameStatus.running,
      ),
      message:
          json['message'] as String? ??
          'Clear the pyramid by matching exposed cards to 13.',
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      selectedCard: json['selectedCard'] == null
          ? null
          : PyramidCardRef.fromJson(
              json['selectedCard'] as Map<String, dynamic>,
            ),
      paused: json['paused'] as bool? ?? false,
      cycleCount: (json['cycleCount'] as num?)?.toInt() ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  static PyramidGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return PyramidGameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'seed': seed,
    'pyramid': pyramid
        .map((row) => row.map((card) => card.toJson()).toList())
        .toList(),
    'stock': stock.map((card) => card.toJson()).toList(),
    'waste': waste.map((card) => card.toJson()).toList(),
    'status': status.name,
    'message': message,
    'elapsedSeconds': elapsedSeconds,
    'selectedCard': selectedCard?.toJson(),
    'paused': paused,
    'cycleCount': cycleCount,
  };

  PyramidGameState copyWith({
    int? seed,
    List<List<PyramidCard>>? pyramid,
    List<PyramidCard>? stock,
    List<PyramidCard>? waste,
    PyramidGameStatus? status,
    String? message,
    int? elapsedSeconds,
    PyramidCardRef? selectedCard,
    bool clearSelection = false,
    bool? paused,
    int? cycleCount,
  }) {
    return PyramidGameState._(
      seed: seed ?? this.seed,
      pyramid: pyramid ?? copyPyramid(),
      stock: stock ?? copyCards(this.stock),
      waste: waste ?? copyCards(this.waste),
      status: status ?? this.status,
      message: message ?? this.message,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      selectedCard: clearSelection ? null : (selectedCard ?? this.selectedCard),
      paused: paused ?? this.paused,
      cycleCount: cycleCount ?? this.cycleCount,
    );
  }

  List<List<PyramidCard>> copyPyramid() {
    return pyramid
        .map((row) => row.map((card) => card.copyWith()).toList())
        .toList();
  }

  List<PyramidCard> copyCards(List<PyramidCard> cards) {
    return cards.map((card) => card.copyWith()).toList();
  }

  PyramidCard? get wasteTop => waste.isEmpty ? null : waste.last;
  int get cardsRemainingInPyramid =>
      pyramid.expand((row) => row).where((card) => !card.removed).length;
  int get removedCount => 28 - cardsRemainingInPyramid;
  bool get isWon => status == PyramidGameStatus.won;
  bool get isActive => !isWon && !paused;

  PyramidGameState incrementElapsed() {
    if (!isActive) {
      return this;
    }
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  PyramidGameState togglePause() {
    return copyWith(
      paused: !paused,
      message: paused
          ? 'Game resumed.'
          : 'Game paused. Your progress is saved.',
    );
  }

  bool isExposed(int row, int column) {
    final card = pyramid[row][column];
    if (card.removed) {
      return false;
    }
    if (row == pyramid.length - 1) {
      return true;
    }
    return pyramid[row + 1][column].removed &&
        pyramid[row + 1][column + 1].removed;
  }

  PyramidCard? cardAt(PyramidCardRef ref) {
    return switch (ref.zone) {
      PyramidCardZone.pyramid => pyramid[ref.row!][ref.column!],
      PyramidCardZone.waste =>
        ref.wasteIndex == waste.length - 1 ? wasteTop : null,
    };
  }

  bool isPlayableRef(PyramidCardRef ref) {
    return switch (ref.zone) {
      PyramidCardZone.pyramid => isExposed(ref.row!, ref.column!),
      PyramidCardZone.waste =>
        ref.wasteIndex == waste.length - 1 && waste.isNotEmpty,
    };
  }

  bool canRemoveSingle(PyramidCardRef ref) {
    if (!isPlayableRef(ref)) {
      return false;
    }
    final card = cardAt(ref);
    return card != null && !card.removed && card.value == 13;
  }

  bool canPair(PyramidCardRef a, PyramidCardRef b) {
    if (a == b || !isPlayableRef(a) || !isPlayableRef(b)) {
      return false;
    }
    final first = cardAt(a);
    final second = cardAt(b);
    if (first == null || second == null || first.removed || second.removed) {
      return false;
    }
    return first.value + second.value == 13;
  }

  PyramidGameState tapCard(PyramidCardRef ref) {
    if (paused || isWon || !isPlayableRef(ref)) {
      return this;
    }

    if (canRemoveSingle(ref)) {
      return _removeCards([ref], message: 'King cleared.');
    }

    if (selectedCard == null) {
      return copyWith(
        selectedCard: ref,
        message: 'Select another exposed card that totals 13.',
      );
    }

    if (selectedCard == ref) {
      return copyWith(clearSelection: true, message: 'Selection cleared.');
    }

    if (canPair(selectedCard!, ref)) {
      return _removeCards([selectedCard!, ref], message: 'Match cleared.');
    }

    return copyWith(
      selectedCard: ref,
      message: 'That pair does not total 13. Pick another card.',
    );
  }

  PyramidGameState drawFromStock() {
    if (paused || isWon) {
      return this;
    }

    if (stock.isNotEmpty) {
      final nextStock = copyCards(stock);
      final nextWaste = copyCards(waste);
      nextWaste.add(nextStock.removeLast());
      return copyWith(
        stock: nextStock,
        waste: nextWaste,
        clearSelection: true,
        message: 'Drew a card from the stock.',
      );
    }

    if (waste.isEmpty) {
      return copyWith(message: 'No more stock to cycle.');
    }

    final nextStock = copyCards(waste.reversed.toList());
    final nextWaste = <PyramidCard>[];
    return copyWith(
      stock: nextStock,
      waste: nextWaste,
      cycleCount: cycleCount + 1,
      clearSelection: true,
      message: 'Waste recycled back into the stock.',
    );
  }

  PyramidGameState _removeCards(
    List<PyramidCardRef> refs, {
    required String message,
  }) {
    final nextPyramid = copyPyramid();
    final nextWaste = copyCards(waste);

    for (final ref in refs) {
      switch (ref.zone) {
        case PyramidCardZone.pyramid:
          final card = nextPyramid[ref.row!][ref.column!];
          nextPyramid[ref.row!][ref.column!] = card.copyWith(removed: true);
        case PyramidCardZone.waste:
          if (ref.wasteIndex == nextWaste.length - 1) {
            nextWaste.removeLast();
          }
      }
    }

    final next = copyWith(
      pyramid: nextPyramid,
      waste: nextWaste,
      clearSelection: true,
      message: message,
    );
    return next._finishIfWon();
  }

  PyramidGameState _finishIfWon() {
    if (cardsRemainingInPyramid != 0) {
      return this;
    }
    return copyWith(
      status: PyramidGameStatus.won,
      clearSelection: true,
      message: 'Pyramid cleared. You win.',
    );
  }

  static List<PyramidCard> _shuffledDeck(int seed) {
    final cards = <PyramidCard>[];
    for (final suit in PyramidCard.allSuits) {
      for (final rank in PyramidCard.allRanks) {
        cards.add(PyramidCard(suit: suit, rank: rank));
      }
    }
    final random = Random(seed);
    cards.shuffle(random);
    return cards;
  }
}
