import '../klondike/card_model.dart';
import 'freecell_game_state.dart';

class FreeCellAdvisor {
  static FreeCellSuggestion? bestTapMove(
    FreeCellGameState state,
    List<KlondikeCard> cards,
  ) {
    if (cards.isEmpty) {
      return null;
    }

    if (cards.length == 1 && state.canMoveToFoundation(cards.first)) {
      return const FreeCellSuggestion.toFoundation();
    }

    for (int index = 0; index < state.cascades.length; index++) {
      final target = state.cascades[index];
      if (state.canMoveCardsToCascade(cards, target)) {
        return FreeCellSuggestion.toCascade(index);
      }
    }

    if (cards.length == 1 && state.canMoveToFreecell(cards.first)) {
      return const FreeCellSuggestion.toFreecell();
    }

    return null;
  }
}

class FreeCellSuggestion {
  const FreeCellSuggestion._({
    this.targetCascadeIndex,
    this.toFoundation = false,
    this.toFreecell = false,
  });

  const FreeCellSuggestion.toCascade(int cascadeIndex)
    : this._(targetCascadeIndex: cascadeIndex);

  const FreeCellSuggestion.toFoundation() : this._(toFoundation: true);

  const FreeCellSuggestion.toFreecell() : this._(toFreecell: true);

  final int? targetCascadeIndex;
  final bool toFoundation;
  final bool toFreecell;
}
