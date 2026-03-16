import 'package:playing_cards/playing_cards.dart';

import 'card_model.dart';
import 'game_state.dart';
import 'klondike_autocomplete.dart';

class KlondikeSolver {
  KlondikeSolver({this.maxVisitedStates = 150000, this.maxDepth = 350});

  final int maxVisitedStates;
  final int maxDepth;

  final Map<String, int> _visitedDepths = <String, int>{};
  int _visitedStates = 0;

  bool isGreedySolvable(GameState initialState, {int maxSteps = 1200}) {
    final seenStates = <String>{};
    var state = initialState.copy();
    KlondikeAutocomplete.autoPromote(state);

    for (int step = 0; step < maxSteps; step++) {
      if (state.isWon) {
        return true;
      }

      final signature = _signatureFor(state);
      if (!seenStates.add(signature)) {
        return false;
      }

      final next = _chooseGreedyNextState(state, seenStates);
      if (next == null) {
        return false;
      }
      state = next;
    }

    return state.isWon;
  }

  bool isSolvable(GameState initialState) {
    _visitedDepths.clear();
    _visitedStates = 0;

    final startingState = initialState.copy();
    KlondikeAutocomplete.autoPromote(startingState);
    return _search(startingState, 0);
  }

  bool _search(GameState state, int depth) {
    if (state.isWon) {
      return true;
    }
    if (depth >= maxDepth || _visitedStates >= maxVisitedStates) {
      return false;
    }

    final signature = _signatureFor(state);
    final previousDepth = _visitedDepths[signature];
    if (previousDepth != null && previousDepth <= depth) {
      return false;
    }

    _visitedDepths[signature] = depth;
    _visitedStates++;

    final moves = _orderedMoves(state);
    for (final move in moves) {
      final next = state.copy();
      if (!move.apply(next)) {
        continue;
      }
      KlondikeAutocomplete.autoPromote(next);
      if (_search(next, depth + 1)) {
        return true;
      }
    }

    return false;
  }

  List<_SolverMove> _orderedMoves(GameState state) {
    final moves = <_SolverMove>[];

    if (state.waste.isNotEmpty) {
      final wasteCard = state.waste.last;
      if (state.canMoveToFoundation(wasteCard)) {
        moves.add(_WasteToFoundationMove(priority: 120));
      }
      for (int target = 0; target < state.tableau.length; target++) {
        if (state.canMoveCardsToTableau([wasteCard], state.tableau[target])) {
          var priority = 80;
          if (state.tableau[target].isEmpty) {
            priority += 10;
          }
          moves.add(_WasteToTableauMove(target, priority: priority));
        }
      }
    }

    for (
      int foundationIndex = 0;
      foundationIndex < state.foundations.length;
      foundationIndex++
    ) {
      final foundation = state.foundations[foundationIndex];
      if (foundation.isEmpty) {
        continue;
      }

      final card = foundation.last;
      for (int target = 0; target < state.tableau.length; target++) {
        if (state.canMoveCardsToTableau([card], state.tableau[target])) {
          moves.add(
            _FoundationToTableauMove(
              foundationIndex,
              target,
              priority: state.tableau[target].isEmpty ? 15 : 20,
            ),
          );
        }
      }
    }

    for (int pileIndex = 0; pileIndex < state.tableau.length; pileIndex++) {
      final pile = state.tableau[pileIndex];
      if (pile.isEmpty) {
        continue;
      }

      final topCard = pile.last;
      if (state.canMoveToFoundation(topCard)) {
        var priority = 110;
        if (pile.length > 1 && !pile[pile.length - 2].faceUp) {
          priority += 15;
        }
        moves.add(_TableauToFoundationMove(pileIndex, priority: priority));
      }

      final firstFaceUpIndex = _firstFaceUpIndex(pile);
      for (
        int startIndex = firstFaceUpIndex;
        startIndex < pile.length;
        startIndex++
      ) {
        final cards = pile.sublist(startIndex);
        for (int target = 0; target < state.tableau.length; target++) {
          if (target == pileIndex) {
            continue;
          }
          if (!state.canMoveCardsToTableau(cards, state.tableau[target])) {
            continue;
          }

          var priority = 60;
          if (startIndex == firstFaceUpIndex && startIndex > 0) {
            priority += 30;
          }
          if (state.tableau[target].isEmpty) {
            priority += 12;
          }
          if (cards.length > 1) {
            priority += 5;
          }

          moves.add(
            _TableauToTableauMove(
              pileIndex,
              startIndex,
              target,
              priority: priority,
            ),
          );
        }
      }
    }

    if (state.stock.isNotEmpty) {
      moves.add(_DrawFromStockMove(priority: 30));
    } else if (state.waste.isNotEmpty) {
      moves.add(_RecycleWasteMove(priority: 5));
    }

    moves.sort((left, right) => right.priority.compareTo(left.priority));
    return moves;
  }

  GameState? _chooseGreedyNextState(GameState state, Set<String> seenStates) {
    for (final move in _orderedMoves(state)) {
      final next = state.copy();
      if (!move.apply(next)) {
        continue;
      }
      KlondikeAutocomplete.autoPromote(next);
      final signature = _signatureFor(next);
      if (seenStates.contains(signature)) {
        continue;
      }
      return next;
    }
    return null;
  }

  int _firstFaceUpIndex(List<KlondikeCard> pile) {
    for (int index = 0; index < pile.length; index++) {
      if (pile[index].faceUp) {
        return index;
      }
    }
    return pile.length;
  }

  String _signatureFor(GameState state) {
    final buffer = StringBuffer()..write(state.drawCount);
    _writePileSignature(buffer, state.stock);
    _writePileSignature(buffer, state.waste);
    for (final pile in state.foundations) {
      _writePileSignature(buffer, pile);
    }
    for (final pile in state.tableau) {
      _writePileSignature(buffer, pile);
    }
    return buffer.toString();
  }

  void _writePileSignature(StringBuffer buffer, List<KlondikeCard> pile) {
    buffer.write('|');
    for (final card in pile) {
      buffer
        ..write(_cardCode(card.card))
        ..write(card.faceUp ? 'u' : 'd')
        ..write(',');
    }
  }

  String _cardCode(PlayingCard card) {
    final suitCode = switch (card.suit) {
      Suit.clubs => 'C',
      Suit.diamonds => 'D',
      Suit.hearts => 'H',
      Suit.spades => 'S',
      _ => throw ArgumentError('Unsupported suit: ${card.suit}'),
    };
    final valueCode = switch (card.value) {
      CardValue.ace => 'A',
      CardValue.two => '2',
      CardValue.three => '3',
      CardValue.four => '4',
      CardValue.five => '5',
      CardValue.six => '6',
      CardValue.seven => '7',
      CardValue.eight => '8',
      CardValue.nine => '9',
      CardValue.ten => 'T',
      CardValue.jack => 'J',
      CardValue.queen => 'Q',
      CardValue.king => 'K',
      _ => throw ArgumentError('Unsupported card value: ${card.value}'),
    };
    return '$suitCode$valueCode';
  }
}

abstract class _SolverMove {
  const _SolverMove({required this.priority});

  final int priority;

  bool apply(GameState state);
}

class _DrawFromStockMove extends _SolverMove {
  const _DrawFromStockMove({required super.priority});

  @override
  bool apply(GameState state) {
    return state.drawFromStock() > 0;
  }
}

class _RecycleWasteMove extends _SolverMove {
  const _RecycleWasteMove({required super.priority});

  @override
  bool apply(GameState state) {
    if (state.stock.isNotEmpty || state.waste.isEmpty) {
      return false;
    }
    state.recycleWaste();
    return true;
  }
}

class _WasteToFoundationMove extends _SolverMove {
  const _WasteToFoundationMove({required super.priority});

  @override
  bool apply(GameState state) {
    if (state.waste.isEmpty) {
      return false;
    }
    return state.moveToFoundation(state.waste.last);
  }
}

class _TableauToFoundationMove extends _SolverMove {
  const _TableauToFoundationMove(this.pileIndex, {required super.priority});

  final int pileIndex;

  @override
  bool apply(GameState state) {
    final pile = state.tableau[pileIndex];
    if (pile.isEmpty) {
      return false;
    }
    return state.moveToFoundation(pile.last);
  }
}

class _WasteToTableauMove extends _SolverMove {
  const _WasteToTableauMove(this.targetPileIndex, {required super.priority});

  final int targetPileIndex;

  @override
  bool apply(GameState state) {
    if (state.waste.isEmpty) {
      return false;
    }
    return state.moveCardsToTableau([
      state.waste.last,
    ], state.tableau[targetPileIndex]);
  }
}

class _FoundationToTableauMove extends _SolverMove {
  const _FoundationToTableauMove(
    this.foundationIndex,
    this.targetPileIndex, {
    required super.priority,
  });

  final int foundationIndex;
  final int targetPileIndex;

  @override
  bool apply(GameState state) {
    final foundation = state.foundations[foundationIndex];
    if (foundation.isEmpty) {
      return false;
    }
    return state.moveCardsToTableau([
      foundation.last,
    ], state.tableau[targetPileIndex]);
  }
}

class _TableauToTableauMove extends _SolverMove {
  const _TableauToTableauMove(
    this.originPileIndex,
    this.startIndex,
    this.targetPileIndex, {
    required super.priority,
  });

  final int originPileIndex;
  final int startIndex;
  final int targetPileIndex;

  @override
  bool apply(GameState state) {
    final origin = state.tableau[originPileIndex];
    if (startIndex >= origin.length) {
      return false;
    }
    return state.moveCardsToTableau(
      origin.sublist(startIndex),
      state.tableau[targetPileIndex],
    );
  }
}
