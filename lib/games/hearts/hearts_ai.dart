import 'hearts_game_state.dart';

class HeartsAi {
  static List<HeartsCard> choosePassCards(HeartsGameState state, int player) {
    final hand = [...state.hands[player]];
    final shootMoon = _shouldShootMoon(state, player);
    hand.sort(
      (a, b) => _passPriority(
        state,
        player,
        b,
        shootMoon,
      ).compareTo(_passPriority(state, player, a, shootMoon)),
    );
    return hand.take(3).toList();
  }

  static HeartsCard chooseCard(HeartsGameState state, int player) {
    final legal = state.legalPlaysFor(player);
    if (legal.isEmpty) {
      return state.hands[player].first;
    }
    final shootMoon = _shouldShootMoon(state, player);
    if (legal.length == 1) {
      return legal.single;
    }

    if (state.currentTrick.isEmpty) {
      if (state.isFirstTrick) {
        return legal.single;
      }
      return shootMoon
          ? _leadForMoon(legal)
          : _leadDefensively(state, player, legal);
    }

    final leadSuit = state.currentTrick.first.card.suit;
    final followingSuit = legal.every((card) => card.suit == leadSuit);
    if (followingSuit) {
      return shootMoon
          ? _followSuitForMoon(state, legal)
          : _followSuitDefensively(state, legal);
    }

    return shootMoon
        ? _discardForMoon(legal)
        : _discardDefensively(state, legal);
  }

  static HeartsCard _leadForMoon(List<HeartsCard> legal) {
    final sorted = [...legal]..sort((a, b) => b.rank.compareTo(a.rank));
    final hearts = sorted.where((card) => card.isHeart).toList();
    if (hearts.isNotEmpty) {
      return hearts.first;
    }
    return sorted.first;
  }

  static HeartsCard _leadDefensively(
    HeartsGameState state,
    int player,
    List<HeartsCard> legal,
  ) {
    final bySuit = <HeartsSuit, List<HeartsCard>>{};
    for (final card in legal) {
      bySuit.putIfAbsent(card.suit, () => <HeartsCard>[]).add(card);
    }
    for (final cards in bySuit.values) {
      cards.sort((a, b) => a.rank.compareTo(b.rank));
    }

    final safeSuits =
        bySuit.entries.where((entry) {
          if (entry.key != HeartsSuit.spades) {
            return true;
          }
          return !state.hands[player].any((card) => card.isQueenOfSpades);
        }).toList()..sort((a, b) {
          final lengthCompare = b.value.length.compareTo(a.value.length);
          if (lengthCompare != 0) {
            return lengthCompare;
          }
          return a.value.first.rank.compareTo(b.value.first.rank);
        });

    if (safeSuits.isNotEmpty) {
      return safeSuits.first.value.first;
    }

    final sorted = [...legal]..sort((a, b) => a.rank.compareTo(b.rank));
    return sorted.first;
  }

  static HeartsCard _followSuitForMoon(
    HeartsGameState state,
    List<HeartsCard> legal,
  ) {
    final winningRank = _currentWinningRank(state);
    final winningCards = legal.where((card) => card.rank > winningRank).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (winningCards.isNotEmpty) {
      return winningCards.first;
    }
    final sorted = [...legal]..sort((a, b) => b.rank.compareTo(a.rank));
    return sorted.first;
  }

  static HeartsCard _followSuitDefensively(
    HeartsGameState state,
    List<HeartsCard> legal,
  ) {
    final sorted = [...legal]..sort((a, b) => a.rank.compareTo(b.rank));
    final winningRank = _currentWinningRank(state);
    final losing = sorted.where((card) => card.rank < winningRank).toList();
    final trickPoints = state.currentTrick.fold<int>(
      0,
      (sum, play) => sum + play.card.pointValue,
    );

    if (losing.isNotEmpty) {
      return losing.last;
    }

    if (trickPoints > 0 ||
        state.currentTrick.first.card.suit == HeartsSuit.spades) {
      return sorted.first;
    }
    return sorted.last;
  }

  static HeartsCard _discardForMoon(List<HeartsCard> legal) {
    final sorted = [...legal]..sort((a, b) => a.rank.compareTo(b.rank));
    return sorted.first;
  }

  static HeartsCard _discardDefensively(
    HeartsGameState state,
    List<HeartsCard> legal,
  ) {
    final queen = legal.where((card) => card.isQueenOfSpades).toList();
    if (queen.isNotEmpty) {
      return queen.first;
    }

    final hearts = legal.where((card) => card.isHeart).toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));
    if (hearts.isNotEmpty) {
      return hearts.first;
    }

    final highSpades =
        legal.where((card) => card.suit == HeartsSuit.spades).toList()
          ..sort((a, b) => b.rank.compareTo(a.rank));
    if (highSpades.isNotEmpty) {
      return highSpades.first;
    }

    final sorted = [...legal]..sort((a, b) => b.rank.compareTo(a.rank));
    return sorted.first;
  }

  static int _currentWinningRank(HeartsGameState state) {
    final leadSuit = state.currentTrick.first.card.suit;
    var rank = state.currentTrick.first.card.rank;
    for (final play in state.currentTrick.skip(1)) {
      if (play.card.suit == leadSuit && play.card.rank > rank) {
        rank = play.card.rank;
      }
    }
    return rank;
  }

  static bool _shouldShootMoon(HeartsGameState state, int player) {
    if (state.handPoints[player] >= 10 &&
        state.handPoints
            .asMap()
            .entries
            .where((entry) => entry.key != player)
            .every((entry) => entry.value == 0)) {
      return true;
    }

    if (state.handPoints
        .asMap()
        .entries
        .where((entry) => entry.key != player)
        .any((entry) => entry.value > 0)) {
      return false;
    }

    final hand = state.hands[player];
    var strength = 0;
    for (final card in hand) {
      if (card.rank >= 11) {
        strength += (card.rank - 10) * (card.isHeart ? 3 : 2);
      }
      if (card.isHeart && card.rank >= 10) {
        strength += 3;
      }
      if (card.isQueenOfSpades) {
        strength += 5;
      }
    }
    return strength >= 38;
  }

  static int _passPriority(
    HeartsGameState state,
    int player,
    HeartsCard card,
    bool shootMoon,
  ) {
    if (shootMoon) {
      var value = 0;
      value += (15 - card.rank) * 8;
      if (card.suit != HeartsSuit.hearts) {
        value += 10;
      }
      if (card.isQueenOfSpades) {
        value -= 60;
      }
      return value;
    }

    var value = card.rank;
    if (card.isQueenOfSpades) {
      value += 300;
    }
    if (card.suit == HeartsSuit.spades && card.rank == 14) {
      value += 180;
    }
    if (card.suit == HeartsSuit.spades && card.rank == 13) {
      value += 170;
    }
    if (card.isHeart) {
      value += 90 + (card.rank * 10);
    }
    final suitCount = state.hands[player]
        .where((item) => item.suit == card.suit)
        .length;
    if (suitCount == 1) {
      value += 35;
    } else if (suitCount == 2) {
      value += 20;
    }
    if (card.rank >= 12) {
      value += 25;
    }
    return value;
  }
}
