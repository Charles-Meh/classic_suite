import 'dart:convert';
import 'dart:math';

enum SudokuDifficulty { easy, medium, hard }

extension SudokuDifficultyLabel on SudokuDifficulty {
  String get label {
    switch (this) {
      case SudokuDifficulty.easy:
        return 'Easy';
      case SudokuDifficulty.medium:
        return 'Medium';
      case SudokuDifficulty.hard:
        return 'Hard';
    }
  }
}

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.board,
    required this.solution,
  });

  final String id;
  final String name;
  final SudokuDifficulty difficulty;
  final List<List<int>> board;
  final List<List<int>> solution;
}

class SudokuHint {
  const SudokuHint({
    required this.row,
    required this.col,
    required this.value,
    required this.label,
    required this.description,
  });

  final int row;
  final int col;
  final int value;
  final String label;
  final String description;
}

class _SudokuSnapshot {
  const _SudokuSnapshot({
    required this.board,
    required this.notes,
    required this.selectedRow,
    required this.selectedCol,
    required this.completed,
    required this.message,
  });

  final List<List<int>> board;
  final List<List<Set<int>>> notes;
  final int? selectedRow;
  final int? selectedCol;
  final bool completed;
  final String message;

  _SudokuSnapshot copy() {
    return _SudokuSnapshot(
      board: SudokuGameState._copyBoard(board),
      notes: SudokuGameState._copyNotes(notes),
      selectedRow: selectedRow,
      selectedCol: selectedCol,
      completed: completed,
      message: message,
    );
  }
}

class SudokuGameState {
  SudokuGameState._({
    required this.puzzleId,
    required this.puzzleName,
    required this.difficulty,
    required this.givens,
    required this.solution,
    required this.board,
    required this.notes,
    this.selectedRow,
    this.selectedCol,
    this.completed = false,
    this.message =
        'Fill the board so every row, column, and 3×3 box contains 1-9.',
    List<_SudokuSnapshot>? undoStack,
    List<_SudokuSnapshot>? redoStack,
  }) : _undoStack = undoStack ?? <_SudokuSnapshot>[],
       _redoStack = redoStack ?? <_SudokuSnapshot>[];

  factory SudokuGameState({
    int? puzzleIndex,
    SudokuDifficulty difficulty = SudokuDifficulty.easy,
  }) {
    final matches = puzzlesByDifficulty(difficulty);
    final pool = matches.isEmpty ? puzzles : matches;
    final puzzle = pool[(puzzleIndex ?? 0) % pool.length];
    return SudokuGameState.fromPuzzle(puzzle);
  }

  factory SudokuGameState.fromPuzzle(SudokuPuzzle puzzle) {
    return SudokuGameState._(
      puzzleId: puzzle.id,
      puzzleName: puzzle.name,
      difficulty: puzzle.difficulty,
      givens: _copyBoard(puzzle.board),
      solution: _copyBoard(puzzle.solution),
      board: _copyBoard(puzzle.board),
      notes: _emptyNotes(),
    );
  }

  static const String storageKey = 'classic_suite.sudoku.saved_state';
  static const String manualSaveKey = 'classic_suite.sudoku.manual_save';

  final String puzzleId;
  final String puzzleName;
  final SudokuDifficulty difficulty;
  final List<List<int>> givens;
  final List<List<int>> solution;
  final List<List<int>> board;
  final List<List<Set<int>>> notes;
  int? selectedRow;
  int? selectedCol;
  bool completed;
  String message;
  final List<_SudokuSnapshot> _undoStack;
  final List<_SudokuSnapshot> _redoStack;

  static final List<SudokuPuzzle> puzzles = [
    const SudokuPuzzle(
      id: 'starter',
      name: 'Starter puzzle',
      difficulty: SudokuDifficulty.easy,
      board: [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9],
      ],
      solution: [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9],
      ],
    ),
    const SudokuPuzzle(
      id: 'cascade',
      name: 'Cascade puzzle',
      difficulty: SudokuDifficulty.medium,
      board: [
        [0, 0, 0, 2, 6, 0, 7, 0, 1],
        [6, 8, 0, 0, 7, 0, 0, 9, 0],
        [1, 9, 0, 0, 0, 4, 5, 0, 0],
        [8, 2, 0, 1, 0, 0, 0, 4, 0],
        [0, 0, 4, 6, 0, 2, 9, 0, 0],
        [0, 5, 0, 0, 0, 3, 0, 2, 8],
        [0, 0, 9, 3, 0, 0, 0, 7, 4],
        [0, 4, 0, 0, 5, 0, 0, 3, 6],
        [7, 0, 3, 0, 1, 8, 0, 0, 0],
      ],
      solution: [
        [4, 3, 5, 2, 6, 9, 7, 8, 1],
        [6, 8, 2, 5, 7, 1, 4, 9, 3],
        [1, 9, 7, 8, 3, 4, 5, 6, 2],
        [8, 2, 6, 1, 9, 5, 3, 4, 7],
        [3, 7, 4, 6, 8, 2, 9, 1, 5],
        [9, 5, 1, 7, 4, 3, 6, 2, 8],
        [5, 1, 9, 3, 2, 6, 8, 7, 4],
        [2, 4, 8, 9, 5, 7, 1, 3, 6],
        [7, 6, 3, 4, 1, 8, 2, 5, 9],
      ],
    ),
    const SudokuPuzzle(
      id: 'crosswind',
      name: 'Crosswind puzzle',
      difficulty: SudokuDifficulty.hard,
      board: [
        [0, 2, 0, 6, 0, 8, 0, 0, 0],
        [5, 8, 0, 0, 0, 9, 7, 0, 0],
        [0, 0, 0, 0, 4, 0, 0, 0, 0],
        [3, 7, 0, 0, 0, 0, 5, 0, 0],
        [6, 0, 0, 0, 0, 0, 0, 0, 4],
        [0, 0, 8, 0, 0, 0, 0, 1, 3],
        [0, 0, 0, 0, 2, 0, 0, 0, 0],
        [0, 0, 9, 8, 0, 0, 0, 3, 6],
        [0, 0, 0, 3, 0, 6, 0, 9, 0],
      ],
      solution: [
        [1, 2, 3, 6, 7, 8, 9, 4, 5],
        [5, 8, 4, 2, 3, 9, 7, 6, 1],
        [9, 6, 7, 1, 4, 5, 3, 2, 8],
        [3, 7, 2, 4, 6, 1, 5, 8, 9],
        [6, 9, 1, 5, 8, 3, 2, 7, 4],
        [4, 5, 8, 7, 9, 2, 6, 1, 3],
        [8, 3, 6, 9, 2, 4, 1, 5, 7],
        [2, 1, 9, 8, 5, 7, 4, 3, 6],
        [7, 4, 5, 3, 1, 6, 8, 9, 2],
      ],
    ),
  ];

  SudokuGameState copy() {
    return SudokuGameState._(
      puzzleId: puzzleId,
      puzzleName: puzzleName,
      difficulty: difficulty,
      givens: _copyBoard(givens),
      solution: _copyBoard(solution),
      board: _copyBoard(board),
      notes: _copyNotes(notes),
      selectedRow: selectedRow,
      selectedCol: selectedCol,
      completed: completed,
      message: message,
      undoStack: [for (final snapshot in _undoStack) snapshot.copy()],
      redoStack: [for (final snapshot in _redoStack) snapshot.copy()],
    );
  }

  factory SudokuGameState.fromJson(Map<String, dynamic> json) {
    final puzzleId = json['puzzleId'] as String?;
    final puzzle = puzzles.firstWhere(
      (candidate) => candidate.id == puzzleId,
      orElse: () => puzzles.first,
    );
    final boardJson = json['board'];
    final board = _parseBoard(boardJson) ?? _copyBoard(puzzle.board);
    final notesJson = json['notes'];
    final notes = _parseNotes(notesJson) ?? _emptyNotes();
    final selectedRow = json['selectedRow'] as int?;
    final selectedCol = json['selectedCol'] as int?;

    final state = SudokuGameState._(
      puzzleId: puzzle.id,
      puzzleName: puzzle.name,
      difficulty: puzzle.difficulty,
      givens: _copyBoard(puzzle.board),
      solution: _copyBoard(puzzle.solution),
      board: board,
      notes: notes,
      selectedRow: selectedRow != null && selectedRow >= 0 && selectedRow < 9
          ? selectedRow
          : null,
      selectedCol: selectedCol != null && selectedCol >= 0 && selectedCol < 9
          ? selectedCol
          : null,
      completed: json['completed'] == true,
      message: (json['message'] as String?) ?? 'Saved game restored.',
    );

    state._recomputeStatus();
    return state;
  }

  Map<String, dynamic> toJson() {
    return {
      'puzzleId': puzzleId,
      'board': board,
      'notes': [
        for (final row in notes)
          [for (final cell in row) (cell.toList()..sort())],
      ],
      'selectedRow': selectedRow,
      'selectedCol': selectedCol,
      'completed': completed,
      'message': message,
    };
  }

  String encode() => jsonEncode(toJson());

  static SudokuGameState? tryDecode(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return SudokuGameState.fromJson(decoded);
      }
      if (decoded is Map) {
        return SudokuGameState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  int get givensCount =>
      givens.expand((row) => row).where((value) => value != 0).length;

  int get filledCount =>
      board.expand((row) => row).where((value) => value != 0).length;

  bool get hasSelection => selectedRow != null && selectedCol != null;

  bool get isSolved => completed;

  int get remainingCount => 81 - filledCount;

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  bool isGiven(int row, int col) => givens[row][col] != 0;

  bool isSelected(int row, int col) => selectedRow == row && selectedCol == col;

  bool isRelatedToSelection(int row, int col) {
    if (!hasSelection) {
      return false;
    }
    return selectedRow == row ||
        selectedCol == col ||
        _boxIndex(selectedRow!, selectedCol!) == _boxIndex(row, col);
  }

  bool isCorrectValue(int row, int col) {
    final value = board[row][col];
    return value != 0 && value == solution[row][col];
  }

  Set<int> notesForCell(int row, int col) =>
      Set<int>.unmodifiable(notes[row][col]);

  bool isConflictingCell(int row, int col) {
    final value = board[row][col];
    if (value == 0) {
      return false;
    }

    for (int index = 0; index < 9; index++) {
      if (index != col && board[row][index] == value) {
        return true;
      }
      if (index != row && board[index][col] == value) {
        return true;
      }
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if ((r != row || c != col) && board[r][c] == value) {
          return true;
        }
      }
    }

    return false;
  }

  Set<int> invalidValuesForSelection() {
    if (!hasSelection || isGiven(selectedRow!, selectedCol!)) {
      return const <int>{};
    }

    final row = selectedRow!;
    final col = selectedCol!;
    final invalid = <int>{};
    for (int value = 1; value <= 9; value++) {
      if (!_canPlaceValue(row, col, value)) {
        invalid.add(value);
      }
    }
    return invalid;
  }

  Set<int> candidatesForCell(int row, int col) {
    if (board[row][col] != 0) {
      return const <int>{};
    }
    final candidates = <int>{};
    for (int value = 1; value <= 9; value++) {
      if (_canPlaceValue(row, col, value)) {
        candidates.add(value);
      }
    }
    return candidates;
  }

  void selectCell(int row, int col) {
    selectedRow = row;
    selectedCol = col;
    if (isGiven(row, col)) {
      message = 'That clue is locked in place.';
    } else if (completed) {
      message = 'Puzzle complete. Start a new one to play again.';
    } else {
      final noteCount = notes[row][col].length;
      if (board[row][col] == 0 && noteCount > 0) {
        message =
            'Selected row ${row + 1}, column ${col + 1}. $noteCount pencil marks saved.';
      } else {
        message = 'Selected row ${row + 1}, column ${col + 1}.';
      }
    }
  }

  bool clearSelectedCell() {
    if (!hasSelection) {
      message = 'Pick a cell first.';
      return false;
    }
    final row = selectedRow!;
    final col = selectedCol!;
    if (isGiven(row, col)) {
      message = 'Starter clues cannot be cleared.';
      return false;
    }
    if (board[row][col] == 0 && notes[row][col].isEmpty) {
      message = 'That cell is already empty.';
      return false;
    }
    _recordSnapshot();
    board[row][col] = 0;
    notes[row][col].clear();
    completed = false;
    message = 'Cleared row ${row + 1}, column ${col + 1}.';
    return true;
  }

  bool setSelectedValue(int value) {
    if (value < 1 || value > 9) {
      message = 'Only digits 1-9 are allowed.';
      return false;
    }
    if (!hasSelection) {
      message = 'Pick a cell first.';
      return false;
    }

    final row = selectedRow!;
    final col = selectedCol!;
    if (isGiven(row, col)) {
      message = 'Starter clues cannot be changed.';
      return false;
    }

    _recordSnapshot();
    board[row][col] = value;
    notes[row][col].clear();
    _clearPeersNote(row, col, value);
    if (!_canPlaceValue(row, col, value, ignoreCurrentCell: true)) {
      completed = false;
      message = 'That creates a duplicate in the row, column, or box.';
      return false;
    }

    if (value != solution[row][col]) {
      completed = false;
      message =
          'Placed $value. No duplicate conflict, but it is not the final answer.';
      return true;
    }

    _recomputeStatus();
    if (completed) {
      message = 'Solved. Nicely done.';
    } else {
      message = 'Placed $value.';
    }
    return true;
  }

  bool toggleNoteForSelection(int value) {
    if (value < 1 || value > 9) {
      message = 'Only digits 1-9 are allowed.';
      return false;
    }
    if (!hasSelection) {
      message = 'Pick a cell first.';
      return false;
    }

    final row = selectedRow!;
    final col = selectedCol!;
    if (isGiven(row, col)) {
      message = 'Starter clues cannot be annotated.';
      return false;
    }
    if (board[row][col] != 0) {
      message = 'Clear the value before adding pencil marks.';
      return false;
    }

    _recordSnapshot();
    final cellNotes = notes[row][col];
    if (cellNotes.contains(value)) {
      cellNotes.remove(value);
      message =
          'Removed pencil mark $value from row ${row + 1}, column ${col + 1}.';
    } else {
      cellNotes.add(value);
      message =
          'Added pencil mark $value to row ${row + 1}, column ${col + 1}.';
    }
    completed = false;
    return true;
  }

  bool fillPencilMarksForSelection() {
    if (!hasSelection) {
      message = 'Pick a cell first.';
      return false;
    }
    final row = selectedRow!;
    final col = selectedCol!;
    if (isGiven(row, col)) {
      message = 'Starter clues already have their final values.';
      return false;
    }
    if (board[row][col] != 0) {
      message = 'That cell already has a value.';
      return false;
    }

    final candidates = candidatesForCell(row, col);
    _recordSnapshot();
    notes[row][col]
      ..clear()
      ..addAll(candidates);
    message = candidates.isEmpty
        ? 'No legal pencil marks fit there right now.'
        : 'Filled ${candidates.length} pencil marks for row ${row + 1}, column ${col + 1}.';
    return true;
  }

  bool autoFillAllPencilMarks() {
    _recordSnapshot();
    var changed = false;
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] != 0 || isGiven(row, col)) {
          continue;
        }
        final candidates = candidatesForCell(row, col);
        if (!setEquals(notes[row][col], candidates)) {
          notes[row][col]
            ..clear()
            ..addAll(candidates);
          changed = true;
        }
      }
    }
    if (!changed) {
      _undoStack.removeLast();
      message = 'Pencil marks are already up to date.';
      return false;
    }
    message = 'Filled pencil marks for all open cells.';
    return true;
  }

  SudokuHint? nextHint() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] != 0) {
          continue;
        }
        final candidates = candidatesForCell(row, col);
        if (candidates.length == 1) {
          final value = candidates.first;
          return SudokuHint(
            row: row,
            col: col,
            value: value,
            label: 'Naked single',
            description: 'Row ${row + 1}, column ${col + 1} only fits $value.',
          );
        }
      }
    }

    for (int row = 0; row < 9; row++) {
      final hint = _hiddenSingleInRow(row);
      if (hint != null) {
        return hint;
      }
    }
    for (int col = 0; col < 9; col++) {
      final hint = _hiddenSingleInColumn(col);
      if (hint != null) {
        return hint;
      }
    }
    for (int box = 0; box < 9; box++) {
      final hint = _hiddenSingleInBox(box);
      if (hint != null) {
        return hint;
      }
    }

    return null;
  }

  bool applyHint() {
    final hint = nextHint();
    if (hint == null) {
      message =
          'No simple hint found. Try scanning candidates or use pencil marks.';
      return false;
    }

    selectCell(hint.row, hint.col);
    final placed = setSelectedValue(hint.value);
    if (placed) {
      message = '${hint.label}: ${hint.description}';
    }
    return placed;
  }

  bool undo() {
    if (!canUndo) {
      message = 'Nothing to undo yet.';
      return false;
    }
    _redoStack.add(_snapshot());
    _restoreSnapshot(_undoStack.removeLast());
    message = 'Undid the last move.';
    return true;
  }

  bool redo() {
    if (!canRedo) {
      message = 'Nothing to redo.';
      return false;
    }
    _undoStack.add(_snapshot());
    _restoreSnapshot(_redoStack.removeLast());
    message = 'Redid the move.';
    return true;
  }

  void _recomputeStatus() {
    completed = _boardsEqual(board, solution) && !hasAnyConflicts;
  }

  bool get hasAnyConflicts {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (isConflictingCell(row, col)) {
          return true;
        }
      }
    }
    return false;
  }

  static SudokuGameState nextPuzzle({SudokuDifficulty? difficulty, int? seed}) {
    final pool = difficulty == null || puzzlesByDifficulty(difficulty).isEmpty
        ? puzzles
        : puzzlesByDifficulty(difficulty);
    final index = seed == null
        ? Random().nextInt(pool.length)
        : seed % pool.length;
    return SudokuGameState.fromPuzzle(pool[index]);
  }

  static List<SudokuPuzzle> puzzlesByDifficulty(SudokuDifficulty difficulty) {
    return puzzles.where((puzzle) => puzzle.difficulty == difficulty).toList();
  }

  static bool _boardsEqual(List<List<int>> left, List<List<int>> right) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (left[row][col] != right[row][col]) {
          return false;
        }
      }
    }
    return true;
  }

  bool _canPlaceValue(
    int row,
    int col,
    int value, {
    bool ignoreCurrentCell = false,
  }) {
    for (int index = 0; index < 9; index++) {
      if (index != col && board[row][index] == value) {
        return false;
      }
      if (index != row && board[index][col] == value) {
        return false;
      }
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if ((ignoreCurrentCell ? (r != row || c != col) : true) &&
            board[r][c] == value &&
            (r != row || c != col)) {
          return false;
        }
      }
    }
    return true;
  }

  SudokuHint? _hiddenSingleInRow(int row) {
    for (int value = 1; value <= 9; value++) {
      final cells = <(int, int)>[];
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0 &&
            candidatesForCell(row, col).contains(value)) {
          cells.add((row, col));
        }
      }
      if (cells.length == 1) {
        final cell = cells.single;
        return SudokuHint(
          row: cell.$1,
          col: cell.$2,
          value: value,
          label: 'Hidden single',
          description:
              'Only row ${row + 1} can place $value in column ${cell.$2 + 1}.',
        );
      }
    }
    return null;
  }

  SudokuHint? _hiddenSingleInColumn(int col) {
    for (int value = 1; value <= 9; value++) {
      final cells = <(int, int)>[];
      for (int row = 0; row < 9; row++) {
        if (board[row][col] == 0 &&
            candidatesForCell(row, col).contains(value)) {
          cells.add((row, col));
        }
      }
      if (cells.length == 1) {
        final cell = cells.single;
        return SudokuHint(
          row: cell.$1,
          col: cell.$2,
          value: value,
          label: 'Hidden single',
          description:
              'Only column ${col + 1} can place $value in row ${cell.$1 + 1}.',
        );
      }
    }
    return null;
  }

  SudokuHint? _hiddenSingleInBox(int box) {
    final boxRow = (box ~/ 3) * 3;
    final boxCol = (box % 3) * 3;
    for (int value = 1; value <= 9; value++) {
      final cells = <(int, int)>[];
      for (int row = boxRow; row < boxRow + 3; row++) {
        for (int col = boxCol; col < boxCol + 3; col++) {
          if (board[row][col] == 0 &&
              candidatesForCell(row, col).contains(value)) {
            cells.add((row, col));
          }
        }
      }
      if (cells.length == 1) {
        final cell = cells.single;
        return SudokuHint(
          row: cell.$1,
          col: cell.$2,
          value: value,
          label: 'Box single',
          description:
              'In box ${box + 1}, only row ${cell.$1 + 1}, column ${cell.$2 + 1} can take $value.',
        );
      }
    }
    return null;
  }

  void _recordSnapshot() {
    _undoStack.add(_snapshot());
    _redoStack.clear();
  }

  _SudokuSnapshot _snapshot() {
    return _SudokuSnapshot(
      board: _copyBoard(board),
      notes: _copyNotes(notes),
      selectedRow: selectedRow,
      selectedCol: selectedCol,
      completed: completed,
      message: message,
    );
  }

  void _restoreSnapshot(_SudokuSnapshot snapshot) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        board[row][col] = snapshot.board[row][col];
        notes[row][col]
          ..clear()
          ..addAll(snapshot.notes[row][col]);
      }
    }
    selectedRow = snapshot.selectedRow;
    selectedCol = snapshot.selectedCol;
    completed = snapshot.completed;
    message = snapshot.message;
    _recomputeStatus();
  }

  void _clearPeersNote(int row, int col, int value) {
    for (int index = 0; index < 9; index++) {
      if (index != col) {
        notes[row][index].remove(value);
      }
      if (index != row) {
        notes[index][col].remove(value);
      }
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (r != row || c != col) {
          notes[r][c].remove(value);
        }
      }
    }
  }

  static int _boxIndex(int row, int col) => (row ~/ 3) * 3 + (col ~/ 3);

  static List<List<int>> _copyBoard(List<List<int>> source) {
    return [
      for (final row in source) [...row],
    ];
  }

  static List<List<Set<int>>> _emptyNotes() {
    return [
      for (int row = 0; row < 9; row++)
        [for (int col = 0; col < 9; col++) <int>{}],
    ];
  }

  static List<List<Set<int>>> _copyNotes(List<List<Set<int>>> source) {
    return [
      for (final row in source)
        [
          for (final cell in row) {...cell},
        ],
    ];
  }

  static List<List<int>>? _parseBoard(dynamic source) {
    if (source is! List || source.length != 9) {
      return null;
    }
    final board = <List<int>>[];
    for (final row in source) {
      if (row is! List || row.length != 9) {
        return null;
      }
      final parsedRow = <int>[];
      for (final cell in row) {
        if (cell is! int || cell < 0 || cell > 9) {
          return null;
        }
        parsedRow.add(cell);
      }
      board.add(parsedRow);
    }
    return board;
  }

  static List<List<Set<int>>>? _parseNotes(dynamic source) {
    if (source is! List || source.length != 9) {
      return null;
    }
    final parsed = <List<Set<int>>>[];
    for (final row in source) {
      if (row is! List || row.length != 9) {
        return null;
      }
      final parsedRow = <Set<int>>[];
      for (final cell in row) {
        if (cell is! List) {
          return null;
        }
        final values = <int>{};
        for (final item in cell) {
          if (item is! int || item < 1 || item > 9) {
            return null;
          }
          values.add(item);
        }
        parsedRow.add(values);
      }
      parsed.add(parsedRow);
    }
    return parsed;
  }
}

bool setEquals(Set<int> left, Set<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}
