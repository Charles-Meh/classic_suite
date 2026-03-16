import 'freecell_game_state.dart';

/// Suggests the best move on card tap, or possible moves for hints/autocomplete.
class FreeCellAdvisor {
  // For MVP: Returns null (no hints yet)
  static FreeCellSuggestion? bestTapMove(FreeCellGameState state, int cascadeIndex, int cardIndex) {
    return null;
  }
}

class FreeCellSuggestion {
  // Placeholder for different suggestion kinds (e.g., moveToCascade, moveToFoundation, moveToFreecell)
  const FreeCellSuggestion();
}
