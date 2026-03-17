import 'dart:convert';
import 'dart:math';

import 'hearts_ai.dart';

enum HeartsSuit { clubs, diamonds, spades, hearts }

enum HeartsPassDirection { left, right, across, hold }

enum HeartsSpeed { instant, normal, relaxed }

enum HeartsPhase { passing, playing, roundComplete, matchComplete }

class HeartsCard {
  const HeartsCard(this.suit, this.rank);

  final HeartsSuit suit;
  final int rank;

  static const suitSymbols = {
    HeartsSuit.clubs: '♣',
    HeartsSuit.diamonds: '♦',
    HeartsSuit.spades: '♠',
    HeartsSuit.hearts: '♥',
  };

  static const suitNames = {
    HeartsSuit.clubs: 'clubs',
    HeartsSuit.diamonds: 'diamonds',
    HeartsSuit.spades: 'spades',
    HeartsSuit.hearts: 'hearts',
  };

  String get rankLabel => switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    _ => '$rank',
  };

  String get key => '$rank-${suit.name}';

  String get shortLabel => '$rankLabel${suitSymbols[suit]!}';

  bool get isHeart => suit == HeartsSuit.hearts;
  bool get isQueenOfSpades => suit == HeartsSuit.spades && rank == 12;
  bool get isPointCard => isHeart || isQueenOfSpades;
  int get pointValue => isHeart ? 1 : (isQueenOfSpades ? 13 : 0);

  Map<String, Object?> toJson() => {'suit': suit.name, 'rank': rank};

  factory HeartsCard.fromJson(Map<String, dynamic> json) {
    return HeartsCard(
      HeartsSuit.values.firstWhere(
        (value) => value.name == (json['suit'] as String? ?? 'clubs'),
        orElse: () => HeartsSuit.clubs,
      ),
      (json['rank'] as num?)?.toInt() ?? 2,
    );
  }
}

class HeartsTrickPlay {
  const HeartsTrickPlay({required this.player, required this.card});

  final int player;
  final HeartsCard card;

  Map<String, Object?> toJson() => {'player': player, 'card': card.toJson()};

  factory HeartsTrickPlay.fromJson(Map<String, dynamic> json) {
    return HeartsTrickPlay(
      player: (json['player'] as num?)?.toInt() ?? 0,
      card: HeartsCard.fromJson(json['card'] as Map<String, dynamic>),
    );
  }
}

class HeartsTrick {
  const HeartsTrick({
    required this.plays,
    required this.winner,
    required this.points,
  });

  final List<HeartsTrickPlay> plays;
  final int winner;
  final int points;

  Map<String, Object?> toJson() => {
    'plays': plays.map((play) => play.toJson()).toList(),
    'winner': winner,
    'points': points,
  };

  factory HeartsTrick.fromJson(Map<String, dynamic> json) {
    return HeartsTrick(
      plays: (json['plays'] as List<dynamic>? ?? const [])
          .map((item) => HeartsTrickPlay.fromJson(item as Map<String, dynamic>))
          .toList(),
      winner: (json['winner'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class HeartsGameState {
  HeartsGameState._({
    required this.hands,
    required this.matchScores,
    required this.handPoints,
    required this.tricksWon,
    required this.currentTrick,
    required this.completedTricks,
    required this.currentPlayer,
    required this.trickLeader,
    required this.passDirection,
    required this.selectedPassCards,
    required this.heartsBroken,
    required this.phase,
    required this.handNumber,
    required this.isPaused,
    required this.speed,
    required this.message,
    required this.lastRoundAppliedScores,
    required this.lastRoundMoonShooter,
  });

  static const String storageKey = 'classic_suite.hearts.saved_state';
  static const int humanPlayer = 0;
  static const int targetScore = 100;

  final List<List<HeartsCard>> hands;
  final List<int> matchScores;
  final List<int> handPoints;
  final List<int> tricksWon;
  final List<HeartsTrickPlay> currentTrick;
  final List<HeartsTrick> completedTricks;
  final int currentPlayer;
  final int trickLeader;
  final HeartsPassDirection passDirection;
  final Set<String> selectedPassCards;
  final bool heartsBroken;
  final HeartsPhase phase;
  final int handNumber;
  final bool isPaused;
  final HeartsSpeed speed;
  final String message;
  final List<int>? lastRoundAppliedScores;
  final int? lastRoundMoonShooter;

  factory HeartsGameState.newMatch({int? seed}) {
    return _dealHand(
      handNumber: 0,
      matchScores: const [0, 0, 0, 0],
      speed: HeartsSpeed.normal,
      seed: seed,
    );
  }

  factory HeartsGameState.debug({
    required List<List<HeartsCard>> hands,
    List<int>? matchScores,
    List<int>? handPoints,
    List<int>? tricksWon,
    List<HeartsTrickPlay>? currentTrick,
    List<HeartsTrick>? completedTricks,
    int currentPlayer = 0,
    int trickLeader = 0,
    HeartsPassDirection passDirection = HeartsPassDirection.hold,
    Set<String>? selectedPassCards,
    bool heartsBroken = false,
    HeartsPhase phase = HeartsPhase.playing,
    int handNumber = 0,
    bool isPaused = false,
    HeartsSpeed speed = HeartsSpeed.instant,
    String message = 'Debug hand',
    List<int>? lastRoundAppliedScores,
    int? lastRoundMoonShooter,
  }) {
    return HeartsGameState._(
      hands: hands.map((hand) => _sortHand([...hand])).toList(),
      matchScores: [
        ...(matchScores ?? const [0, 0, 0, 0]),
      ],
      handPoints: [
        ...(handPoints ?? const [0, 0, 0, 0]),
      ],
      tricksWon: [
        ...(tricksWon ?? const [0, 0, 0, 0]),
      ],
      currentTrick: [...(currentTrick ?? const [])],
      completedTricks: [...(completedTricks ?? const [])],
      currentPlayer: currentPlayer,
      trickLeader: trickLeader,
      passDirection: passDirection,
      selectedPassCards: {...(selectedPassCards ?? <String>{})},
      heartsBroken: heartsBroken,
      phase: phase,
      handNumber: handNumber,
      isPaused: isPaused,
      speed: speed,
      message: message,
      lastRoundAppliedScores: lastRoundAppliedScores == null
          ? null
          : [...lastRoundAppliedScores],
      lastRoundMoonShooter: lastRoundMoonShooter,
    );
  }

  factory HeartsGameState.fromJson(Map<String, dynamic> json) {
    return HeartsGameState._(
      hands: (json['hands'] as List<dynamic>? ?? const [])
          .map(
            (hand) => (hand as List<dynamic>)
                .map(
                  (card) => HeartsCard.fromJson(card as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList(),
      matchScores: _intList(json['matchScores'], fallbackLength: 4),
      handPoints: _intList(json['handPoints'], fallbackLength: 4),
      tricksWon: _intList(json['tricksWon'], fallbackLength: 4),
      currentTrick: (json['currentTrick'] as List<dynamic>? ?? const [])
          .map((item) => HeartsTrickPlay.fromJson(item as Map<String, dynamic>))
          .toList(),
      completedTricks: (json['completedTricks'] as List<dynamic>? ?? const [])
          .map((item) => HeartsTrick.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPlayer: (json['currentPlayer'] as num?)?.toInt() ?? 0,
      trickLeader: (json['trickLeader'] as num?)?.toInt() ?? 0,
      passDirection: HeartsPassDirection.values.firstWhere(
        (value) => value.name == (json['passDirection'] as String? ?? 'left'),
        orElse: () => HeartsPassDirection.left,
      ),
      selectedPassCards: {
        for (final item
            in (json['selectedPassCards'] as List<dynamic>? ?? const []))
          '$item',
      },
      heartsBroken: json['heartsBroken'] as bool? ?? false,
      phase: HeartsPhase.values.firstWhere(
        (value) => value.name == (json['phase'] as String? ?? 'passing'),
        orElse: () => HeartsPhase.passing,
      ),
      handNumber: (json['handNumber'] as num?)?.toInt() ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      speed: HeartsSpeed.values.firstWhere(
        (value) => value.name == (json['speed'] as String? ?? 'normal'),
        orElse: () => HeartsSpeed.normal,
      ),
      message: json['message'] as String? ?? 'Welcome to Hearts.',
      lastRoundAppliedScores: json['lastRoundAppliedScores'] == null
          ? null
          : _intList(json['lastRoundAppliedScores'], fallbackLength: 4),
      lastRoundMoonShooter: (json['lastRoundMoonShooter'] as num?)?.toInt(),
    );
  }

  static HeartsGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return HeartsGameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'hands': hands
        .map((hand) => hand.map((card) => card.toJson()).toList())
        .toList(),
    'matchScores': matchScores,
    'handPoints': handPoints,
    'tricksWon': tricksWon,
    'currentTrick': currentTrick.map((play) => play.toJson()).toList(),
    'completedTricks': completedTricks.map((trick) => trick.toJson()).toList(),
    'currentPlayer': currentPlayer,
    'trickLeader': trickLeader,
    'passDirection': passDirection.name,
    'selectedPassCards': selectedPassCards.toList(),
    'heartsBroken': heartsBroken,
    'phase': phase.name,
    'handNumber': handNumber,
    'isPaused': isPaused,
    'speed': speed.name,
    'message': message,
    'lastRoundAppliedScores': lastRoundAppliedScores,
    'lastRoundMoonShooter': lastRoundMoonShooter,
  };

  static List<int> _intList(Object? value, {required int fallbackLength}) {
    final list = (value as List<dynamic>? ?? const [])
        .map((item) => (item as num).toInt())
        .toList();
    if (list.length == fallbackLength) {
      return list;
    }
    return List<int>.filled(fallbackLength, 0);
  }

  HeartsGameState copyWith({
    List<List<HeartsCard>>? hands,
    List<int>? matchScores,
    List<int>? handPoints,
    List<int>? tricksWon,
    List<HeartsTrickPlay>? currentTrick,
    List<HeartsTrick>? completedTricks,
    int? currentPlayer,
    int? trickLeader,
    HeartsPassDirection? passDirection,
    Set<String>? selectedPassCards,
    bool? heartsBroken,
    HeartsPhase? phase,
    int? handNumber,
    bool? isPaused,
    HeartsSpeed? speed,
    String? message,
    List<int>? lastRoundAppliedScores,
    Object? lastRoundMoonShooter = _sentinel,
  }) {
    return HeartsGameState._(
      hands: hands == null
          ? this.hands.map((hand) => [...hand]).toList()
          : hands.map((hand) => [...hand]).toList(),
      matchScores: [...(matchScores ?? this.matchScores)],
      handPoints: [...(handPoints ?? this.handPoints)],
      tricksWon: [...(tricksWon ?? this.tricksWon)],
      currentTrick: [...(currentTrick ?? this.currentTrick)],
      completedTricks: [...(completedTricks ?? this.completedTricks)],
      currentPlayer: currentPlayer ?? this.currentPlayer,
      trickLeader: trickLeader ?? this.trickLeader,
      passDirection: passDirection ?? this.passDirection,
      selectedPassCards: {...(selectedPassCards ?? this.selectedPassCards)},
      heartsBroken: heartsBroken ?? this.heartsBroken,
      phase: phase ?? this.phase,
      handNumber: handNumber ?? this.handNumber,
      isPaused: isPaused ?? this.isPaused,
      speed: speed ?? this.speed,
      message: message ?? this.message,
      lastRoundAppliedScores: lastRoundAppliedScores == null
          ? (this.lastRoundAppliedScores == null
                ? null
                : [...this.lastRoundAppliedScores!])
          : [...lastRoundAppliedScores],
      lastRoundMoonShooter: identical(lastRoundMoonShooter, _sentinel)
          ? this.lastRoundMoonShooter
          : lastRoundMoonShooter as int?,
    );
  }

  static const _sentinel = Object();

  bool get isPassing => phase == HeartsPhase.passing;
  bool get isPlaying => phase == HeartsPhase.playing;
  bool get isRoundComplete => phase == HeartsPhase.roundComplete;
  bool get isMatchComplete => phase == HeartsPhase.matchComplete;
  bool get isHumanTurn => isPlaying && currentPlayer == humanPlayer;
  bool get isFirstTrick => completedTricks.isEmpty;
  int get cardsRemainingInHand => hands[humanPlayer].length;

  String get passDirectionLabel => switch (passDirection) {
    HeartsPassDirection.left => 'Pass left',
    HeartsPassDirection.right => 'Pass right',
    HeartsPassDirection.across => 'Pass across',
    HeartsPassDirection.hold => 'Hold hand',
  };

  String playerLabel(int player) => switch (player) {
    0 => 'You',
    1 => 'West',
    2 => 'North',
    3 => 'East',
    _ => 'P${player + 1}',
  };

  List<HeartsCard> legalPlaysFor(int player) {
    final hand = hands[player];
    if (!isPlaying || player != currentPlayer || hand.isEmpty) {
      return const [];
    }

    if (currentTrick.isEmpty) {
      if (isFirstTrick) {
        return hand
            .where((card) => card.suit == HeartsSuit.clubs && card.rank == 2)
            .toList();
      }
      if (!heartsBroken) {
        final nonHearts = hand.where((card) => !card.isHeart).toList();
        if (nonHearts.isNotEmpty) {
          return nonHearts;
        }
      }
      return [...hand];
    }

    final leadSuit = currentTrick.first.card.suit;
    final followSuit = hand.where((card) => card.suit == leadSuit).toList();
    if (followSuit.isNotEmpty) {
      return followSuit;
    }

    if (isFirstTrick) {
      final nonPointCards = hand.where((card) => !card.isPointCard).toList();
      if (nonPointCards.isNotEmpty) {
        return nonPointCards;
      }
    }
    return [...hand];
  }

  bool canHumanPlayCard(HeartsCard card) {
    return legalPlaysFor(
      humanPlayer,
    ).any((candidate) => candidate.key == card.key);
  }

  HeartsGameState togglePause() {
    return copyWith(
      isPaused: !isPaused,
      message: !isPaused ? 'Game paused.' : 'Game resumed.',
    );
  }

  HeartsGameState setSpeed(HeartsSpeed nextSpeed) {
    return copyWith(speed: nextSpeed);
  }

  HeartsGameState togglePassSelection(String cardKey) {
    if (!isPassing || passDirection == HeartsPassDirection.hold) {
      return this;
    }

    final selected = {...selectedPassCards};
    if (selected.contains(cardKey)) {
      selected.remove(cardKey);
      return copyWith(
        selectedPassCards: selected,
        message: 'Pass ${selected.length}/3 cards.',
      );
    }

    if (selected.length >= 3) {
      return copyWith(message: 'Pick exactly three cards to pass.');
    }

    selected.add(cardKey);
    return copyWith(
      selectedPassCards: selected,
      message: 'Pass ${selected.length}/3 cards.',
    );
  }

  HeartsGameState confirmHumanPass() {
    if (!isPassing) {
      return this;
    }
    if (passDirection == HeartsPassDirection.hold) {
      return copyWith(
        phase: HeartsPhase.playing,
        message: '${playerLabel(currentPlayer)} leads the hold hand.',
      );
    }
    if (selectedPassCards.length != 3) {
      return copyWith(message: 'Pick exactly three cards to pass.');
    }

    final nextHands = hands.map((hand) => [...hand]).toList();
    final outgoing = List<List<HeartsCard>>.generate(4, (_) => <HeartsCard>[]);

    outgoing[humanPlayer] = nextHands[humanPlayer]
        .where((card) => selectedPassCards.contains(card.key))
        .toList();
    if (outgoing[humanPlayer].length != 3) {
      return copyWith(message: 'Those pass cards are no longer available.');
    }

    for (int player = 1; player < 4; player++) {
      outgoing[player] = HeartsAi.choosePassCards(this, player);
    }

    for (int player = 0; player < 4; player++) {
      for (final card in outgoing[player]) {
        nextHands[player].removeWhere((item) => item.key == card.key);
      }
    }

    for (int player = 0; player < 4; player++) {
      final receiver = _passTarget(player, passDirection);
      nextHands[receiver].addAll(outgoing[player]);
      nextHands[receiver] = _sortHand(nextHands[receiver]);
    }

    return copyWith(
      hands: nextHands,
      phase: HeartsPhase.playing,
      selectedPassCards: <String>{},
      message:
          '$passDirectionLabel. ${playerLabel(currentPlayer)} leads with 2♣.',
    );
  }

  HeartsGameState playHumanCard(String cardKey) {
    if (!isHumanTurn || isPaused) {
      return this;
    }
    final card = hands[humanPlayer].firstWhere(
      (item) => item.key == cardKey,
      orElse: () => const HeartsCard(HeartsSuit.clubs, -1),
    );
    if (card.rank == -1 || !canHumanPlayCard(card)) {
      return copyWith(message: 'That card is not legal right now.');
    }
    return _playCard(humanPlayer, card);
  }

  HeartsGameState autoPlayCurrentPlayer() {
    if (!isPlaying || isPaused || currentPlayer == humanPlayer) {
      return this;
    }
    final choice = HeartsAi.chooseCard(this, currentPlayer);
    return _playCard(currentPlayer, choice);
  }

  HeartsGameState startNextHand({int? seed}) {
    if (!isRoundComplete || isMatchComplete) {
      return this;
    }
    return _dealHand(
      handNumber: handNumber + 1,
      matchScores: matchScores,
      speed: speed,
      seed: seed,
    );
  }

  HeartsGameState newMatch({int? seed}) {
    return HeartsGameState.newMatch(seed: seed).setSpeed(speed);
  }

  HeartsGameState _playCard(int player, HeartsCard card) {
    final legal = legalPlaysFor(player);
    if (!legal.any((candidate) => candidate.key == card.key)) {
      return this;
    }

    final nextHands = hands.map((hand) => [...hand]).toList();
    nextHands[player].removeWhere((item) => item.key == card.key);
    final nextTrick = [
      ...currentTrick,
      HeartsTrickPlay(player: player, card: card),
    ];
    final brokeHearts = heartsBroken || card.isHeart;

    if (nextTrick.length < 4) {
      return copyWith(
        hands: nextHands,
        currentTrick: nextTrick,
        currentPlayer: (player + 1) % 4,
        heartsBroken: brokeHearts,
        message: '${playerLabel(player)} played ${card.shortLabel}.',
      );
    }

    final resolved = _resolveTrick(
      nextHands: nextHands,
      finishedTrick: nextTrick,
      brokeHearts: brokeHearts,
    );
    return resolved;
  }

  HeartsGameState _resolveTrick({
    required List<List<HeartsCard>> nextHands,
    required List<HeartsTrickPlay> finishedTrick,
    required bool brokeHearts,
  }) {
    final leadSuit = finishedTrick.first.card.suit;
    HeartsTrickPlay winningPlay = finishedTrick.first;
    for (final play in finishedTrick.skip(1)) {
      if (play.card.suit == leadSuit &&
          play.card.rank > winningPlay.card.rank) {
        winningPlay = play;
      }
    }

    final points = finishedTrick.fold<int>(
      0,
      (sum, play) => sum + play.card.pointValue,
    );
    final nextHandPoints = [...handPoints];
    nextHandPoints[winningPlay.player] += points;
    final nextTricksWon = [...tricksWon];
    nextTricksWon[winningPlay.player] += 1;
    final nextCompleted = [
      ...completedTricks,
      HeartsTrick(
        plays: finishedTrick,
        winner: winningPlay.player,
        points: points,
      ),
    ];

    if (nextHands.every((hand) => hand.isEmpty)) {
      final appliedScores = _applyRoundScores(nextHandPoints);
      final nextMatchScores = [
        for (int index = 0; index < 4; index++)
          matchScores[index] + appliedScores.$1[index],
      ];
      final matchComplete = nextMatchScores.any(
        (score) => score >= targetScore,
      );
      final humanLowScore =
          nextMatchScores[humanPlayer] == nextMatchScores.reduce(min);

      return copyWith(
        hands: nextHands,
        currentTrick: const [],
        completedTricks: nextCompleted,
        currentPlayer: winningPlay.player,
        trickLeader: winningPlay.player,
        heartsBroken: brokeHearts,
        handPoints: nextHandPoints,
        tricksWon: nextTricksWon,
        matchScores: nextMatchScores,
        phase: matchComplete
            ? HeartsPhase.matchComplete
            : HeartsPhase.roundComplete,
        message: matchComplete
            ? (humanLowScore
                  ? 'Match complete. You won the table.'
                  : 'Match complete. Start a rematch?')
            : 'Hand complete. ${playerLabel(winningPlay.player)} took the last trick.',
        lastRoundAppliedScores: appliedScores.$1,
        lastRoundMoonShooter: appliedScores.$2,
      );
    }

    return copyWith(
      hands: nextHands,
      currentTrick: const [],
      completedTricks: nextCompleted,
      currentPlayer: winningPlay.player,
      trickLeader: winningPlay.player,
      heartsBroken: brokeHearts,
      handPoints: nextHandPoints,
      tricksWon: nextTricksWon,
      message:
          '${playerLabel(winningPlay.player)} took the trick${points > 0 ? ' for $points point${points == 1 ? '' : 's'}' : ''}.',
    );
  }

  (List<int>, int?) _applyRoundScores(List<int> roundPoints) {
    final shooter = roundPoints.indexWhere((value) => value == 26);
    if (shooter != -1) {
      return ([for (int i = 0; i < 4; i++) i == shooter ? 0 : 26], shooter);
    }
    return ([...roundPoints], null);
  }

  static HeartsGameState _dealHand({
    required int handNumber,
    required List<int> matchScores,
    required HeartsSpeed speed,
    int? seed,
  }) {
    final deck = <HeartsCard>[
      for (final suit in HeartsSuit.values)
        for (int rank = 2; rank <= 14; rank++) HeartsCard(suit, rank),
    ];
    deck.shuffle(seed == null ? Random() : Random(seed));

    final hands = List<List<HeartsCard>>.generate(4, (_) => <HeartsCard>[]);
    for (int index = 0; index < deck.length; index++) {
      hands[index % 4].add(deck[index]);
    }
    for (int player = 0; player < 4; player++) {
      hands[player] = _sortHand(hands[player]);
    }

    final leader = hands.indexWhere(
      (hand) =>
          hand.any((card) => card.suit == HeartsSuit.clubs && card.rank == 2),
    );
    final passDirection = switch (handNumber % 4) {
      0 => HeartsPassDirection.left,
      1 => HeartsPassDirection.right,
      2 => HeartsPassDirection.across,
      _ => HeartsPassDirection.hold,
    };

    return HeartsGameState._(
      hands: hands,
      matchScores: [...matchScores],
      handPoints: const [0, 0, 0, 0],
      tricksWon: const [0, 0, 0, 0],
      currentTrick: const [],
      completedTricks: const [],
      currentPlayer: leader,
      trickLeader: leader,
      passDirection: passDirection,
      selectedPassCards: const <String>{},
      heartsBroken: false,
      phase: passDirection == HeartsPassDirection.hold
          ? HeartsPhase.playing
          : HeartsPhase.passing,
      handNumber: handNumber,
      isPaused: false,
      speed: speed,
      message: passDirection == HeartsPassDirection.hold
          ? 'Hold hand. ${leader == 0 ? 'You lead 2♣.' : 'Waiting for ${switch (leader) {
                    1 => 'West',
                    2 => 'North',
                    3 => 'East',
                    _ => 'West',
                  }} to lead 2♣.'}'
          : 'Select three cards to ${switch (passDirection) {
              HeartsPassDirection.left => 'pass left',
              HeartsPassDirection.right => 'pass right',
              HeartsPassDirection.across => 'pass across',
              HeartsPassDirection.hold => 'hold',
            }}.',
      lastRoundAppliedScores: null,
      lastRoundMoonShooter: null,
    );
  }

  static List<HeartsCard> _sortHand(List<HeartsCard> hand) {
    hand.sort((a, b) {
      final suitCompare = a.suit.index.compareTo(b.suit.index);
      if (suitCompare != 0) {
        return suitCompare;
      }
      return a.rank.compareTo(b.rank);
    });
    return hand;
  }

  static int _passTarget(int player, HeartsPassDirection direction) {
    return switch (direction) {
      HeartsPassDirection.left => (player + 1) % 4,
      HeartsPassDirection.right => (player + 3) % 4,
      HeartsPassDirection.across => (player + 2) % 4,
      HeartsPassDirection.hold => player,
    };
  }
}
