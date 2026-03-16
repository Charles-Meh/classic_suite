import 'dart:convert';
import 'dart:math';

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.id,
    required this.name,
    required this.board,
    required this.solution,
  });

  final String id;
  final String name;
  final List<List<int>> board;
  final List<List<int>> solution;
}

class SudokuGameState {
  SudokuGameState._({
    required this.puzzleId,
    required this.puzzleName,
    required this.givens,
    required this.solution,
    required this.board,
    this.selectedRow,
    this.selectedCol,
    this.completed = false,
    this.message =
        'Fill the board so every row, column, and 3×3 box contains 1-9.',
  });

  factory SudokuGameState({int? puzzleIndex}) {
    final puzzle = puzzles[(puzzleIndex ?? 0) % puzzles.length];
    return SudokuGameState.fromPuzzle(puzzle);
  }

  factory SudokuGameState.fromPuzzle(SudokuPuzzle puzzle) {
    return SudokuGameState._(
      puzzleId: puzzle.id,
      puzzleName: puzzle.name,
      givens: _copyBoard(puzzle.board),
      solution: _copyBoard(puzzle.solution),
      board: _copyBoard(puzzle.board),
    );
  }

  static const String storageKey = 'classic_suite.sudoku.saved_state';
  static const String manualSaveKey = 'classic_suite.sudoku.manual_save';

  final String puzzleId;
  final String puzzleName;
  final List<List<int>> givens;
  final List<List<int>> solution;
  final List<List<int>> board;
  int? selectedRow;
  int? selectedCol;
  bool completed;
  String message;

  static final List<SudokuPuzzle> puzzles = [
    const SudokuPuzzle(
      id: 'starter',
      name: 'Starter puzzle',
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
      givens: _copyBoard(givens),
      solution: _copyBoard(solution),
      board: _copyBoard(board),
      selectedRow: selectedRow,
      selectedCol: selectedCol,
      completed: completed,
      message: message,
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
    final selectedRow = json['selectedRow'] as int?;
    final selectedCol = json['selectedCol'] as int?;

    final state = SudokuGameState._(
      puzzleId: puzzle.id,
      puzzleName: puzzle.name,
      givens: _copyBoard(puzzle.board),
      solution: _copyBoard(puzzle.solution),
      board: board,
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

  void selectCell(int row, int col) {
    selectedRow = row;
    selectedCol = col;
    if (isGiven(row, col)) {
      message = 'That clue is locked in place.';
    } else if (completed) {
      message = 'Puzzle complete. Start a new one to play again.';
    } else {
      message = 'Selected row ${row + 1}, column ${col + 1}.';
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
    if (board[row][col] == 0) {
      message = 'That cell is already empty.';
      return false;
    }
    board[row][col] = 0;
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

    board[row][col] = value;
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

  static SudokuGameState nextPuzzle([int? seed]) {
    final index = seed == null
        ? Random().nextInt(puzzles.length)
        : seed % puzzles.length;
    return SudokuGameState.fromPuzzle(puzzles[index]);
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

  static int _boxIndex(int row, int col) => (row ~/ 3) * 3 + (col ~/ 3);

  static List<List<int>> _copyBoard(List<List<int>> source) {
    return [
      for (final row in source) [...row],
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
}
