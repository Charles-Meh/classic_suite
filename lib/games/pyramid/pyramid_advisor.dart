import 'pyramid_game_state.dart';

class PyramidHint {
  const PyramidHint({required this.cardRef});

  final PyramidCardRef cardRef;
}

class PyramidAdvisor {
  const PyramidAdvisor._();

  static PyramidHint? bestHint(PyramidGameState state) {
    if (state.paused || state.isWon) {
      return null;
    }

    final playableRefs = _playableRefs(state);
    for (final ref in playableRefs) {
      if (state.canRemoveSingle(ref)) {
        return PyramidHint(cardRef: ref);
      }
    }

    final wasteRef = state.waste.isEmpty
        ? null
        : PyramidCardRef.waste(state.waste.length - 1);
    if (wasteRef != null) {
      for (final ref in playableRefs) {
        if (ref.zone == PyramidCardZone.waste) {
          continue;
        }
        if (state.canPair(wasteRef, ref)) {
          return PyramidHint(cardRef: ref);
        }
      }
    }

    for (int index = 0; index < playableRefs.length; index++) {
      final first = playableRefs[index];
      if (first.zone == PyramidCardZone.waste) {
        continue;
      }
      for (
        int otherIndex = index + 1;
        otherIndex < playableRefs.length;
        otherIndex++
      ) {
        final second = playableRefs[otherIndex];
        if (second.zone == PyramidCardZone.waste) {
          continue;
        }
        if (state.canPair(first, second)) {
          return PyramidHint(cardRef: first);
        }
      }
    }

    return null;
  }

  static List<PyramidCardRef> _playableRefs(PyramidGameState state) {
    final refs = <PyramidCardRef>[];
    for (int row = state.pyramid.length - 1; row >= 0; row--) {
      for (int column = 0; column < state.pyramid[row].length; column++) {
        if (state.isExposed(row, column)) {
          refs.add(PyramidCardRef.pyramid(row, column));
        }
      }
    }
    if (state.waste.isNotEmpty) {
      refs.add(PyramidCardRef.waste(state.waste.length - 1));
    }
    return refs;
  }
}
