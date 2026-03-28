import 'dart:convert';
import 'dart:math';

const int _minBoardSide = 5;
const int _maxBoardSide = 40;

class MinesweeperConfig {
  const MinesweeperConfig({
    required this.id,
    required this.label,
    required this.rows,
    required this.columns,
    required this.mines,
    required this.isPreset,
  });

  factory MinesweeperConfig.easy() {
    return const MinesweeperConfig(
      id: 'easy',
      label: 'Easy',
      rows: 9,
      columns: 9,
      mines: 10,
      isPreset: true,
    );
  }

  factory MinesweeperConfig.medium() {
    return const MinesweeperConfig(
      id: 'medium',
      label: 'Medium',
      rows: 16,
      columns: 16,
      mines: 40,
      isPreset: true,
    );
  }

  factory MinesweeperConfig.hard() {
    return const MinesweeperConfig(
      id: 'hard',
      label: 'Hard',
      rows: 16,
      columns: 30,
      mines: 99,
      isPreset: true,
    );
  }

  factory MinesweeperConfig.custom({
    required int rows,
    required int columns,
    required int mines,
  }) {
    return MinesweeperConfig(
      id: 'custom',
      label: 'Custom',
      rows: rows,
      columns: columns,
      mines: mines,
      isPreset: false,
    );
  }

  final String id;
  final String label;
  final int rows;
  final int columns;
  final int mines;
  final bool isPreset;

  static List<MinesweeperConfig> presets() {
    return [
      MinesweeperConfig.easy(),
      MinesweeperConfig.medium(),
      MinesweeperConfig.hard(),
    ];
  }

  int get cellCount => rows * columns;

  int get maxAllowedMines => max(1, cellCount - 1);

  String? validate() {
    if (rows < _minBoardSide || rows > _maxBoardSide) {
      return 'Rows must be between $_minBoardSide and $_maxBoardSide.';
    }
    if (columns < _minBoardSide || columns > _maxBoardSide) {
      return 'Columns must be between $_minBoardSide and $_maxBoardSide.';
    }
    if (mines < 1) {
      return 'At least one mine is required.';
    }
    if (mines >= cellCount) {
      return 'Mine count must leave at least one safe cell.';
    }
    return null;
  }

  MinesweeperConfig copyWith({
    String? id,
    String? label,
    int? rows,
    int? columns,
    int? mines,
    bool? isPreset,
  }) {
    return MinesweeperConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      mines: mines ?? this.mines,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'rows': rows,
      'columns': columns,
      'mines': mines,
      'isPreset': isPreset,
    };
  }

  factory MinesweeperConfig.fromJson(Map<String, dynamic> json) {
    return MinesweeperConfig(
      id: json['id'] as String,
      label: json['label'] as String,
      rows: (json['rows'] as num).toInt(),
      columns: (json['columns'] as num).toInt(),
      mines: (json['mines'] as num).toInt(),
      isPreset: json['isPreset'] as bool,
    );
  }
}

enum MinesweeperGameStatus { ready, running, won, lost }

class MinesweeperCell {
  const MinesweeperCell({
    this.hasMine = false,
    this.revealed = false,
    this.flagged = false,
    this.exploded = false,
    this.adjacentMines = 0,
  });

  final bool hasMine;
  final bool revealed;
  final bool flagged;
  final bool exploded;
  final int adjacentMines;

  MinesweeperCell copyWith({
    bool? hasMine,
    bool? revealed,
    bool? flagged,
    bool? exploded,
    int? adjacentMines,
  }) {
    return MinesweeperCell(
      hasMine: hasMine ?? this.hasMine,
      revealed: revealed ?? this.revealed,
      flagged: flagged ?? this.flagged,
      exploded: exploded ?? this.exploded,
      adjacentMines: adjacentMines ?? this.adjacentMines,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'hasMine': hasMine,
      'revealed': revealed,
      'flagged': flagged,
      'exploded': exploded,
      'adjacentMines': adjacentMines,
    };
  }

  factory MinesweeperCell.fromJson(Map<String, dynamic> json) {
    return MinesweeperCell(
      hasMine: json['hasMine'] as bool,
      revealed: json['revealed'] as bool,
      flagged: json['flagged'] as bool,
      exploded: json['exploded'] as bool,
      adjacentMines: (json['adjacentMines'] as num).toInt(),
    );
  }
}

class MinesweeperGameState {
  MinesweeperGameState._({
    required this.config,
    required this.board,
    required this.status,
    required this.message,
    required this.elapsedSeconds,
    required this.generated,
  });

  static const String storageKey = 'classic_suite.minesweeper.saved_state';

  final MinesweeperConfig config;
  final List<List<MinesweeperCell>> board;
  final MinesweeperGameStatus status;
  final String message;
  final int elapsedSeconds;
  final bool generated;

  static List<List<MinesweeperCell>> _blankBoard(int rows, int columns) {
    return List<List<MinesweeperCell>>.generate(
      rows,
      (_) => List<MinesweeperCell>.filled(columns, const MinesweeperCell()),
    );
  }

  MinesweeperGameState copyWith({
    MinesweeperConfig? config,
    List<List<MinesweeperCell>>? board,
    MinesweeperGameStatus? status,
    String? message,
    int? elapsedSeconds,
    bool? generated,
  }) {
    return MinesweeperGameState._(
      config: config ?? this.config,
      board: board ?? copyBoard(),
      status: status ?? this.status,
      message: message ?? this.message,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      generated: generated ?? this.generated,
    );
  }

  factory MinesweeperGameState.newGame(MinesweeperConfig config) {
    return MinesweeperGameState._(
      config: config,
      board: _blankBoard(config.rows, config.columns),
      status: MinesweeperGameStatus.ready,
      message: 'Clear every safe tile. First tap is always safe.',
      elapsedSeconds: 0,
      generated: false,
    );
  }

  factory MinesweeperGameState.debug({
    required MinesweeperConfig config,
    required List<List<MinesweeperCell>> board,
    MinesweeperGameStatus status = MinesweeperGameStatus.running,
    String message = 'Debug board',
    int elapsedSeconds = 0,
    bool generated = true,
  }) {
    return MinesweeperGameState._(
      config: config,
      board: board
          .map((row) => row.map((cell) => cell.copyWith()).toList())
          .toList(),
      status: status,
      message: message,
      elapsedSeconds: elapsedSeconds,
      generated: generated,
    );
  }

  factory MinesweeperGameState.fromJson(Map<String, dynamic> json) {
    final config = MinesweeperConfig.fromJson(
      json['config'] as Map<String, dynamic>,
    );
    final boardJson = json['board'] as List<dynamic>;
    final board = boardJson
        .map(
          (row) => (row as List<dynamic>)
              .map(
                (cell) =>
                    MinesweeperCell.fromJson(cell as Map<String, dynamic>),
              )
              .toList(),
        )
        .toList();

    return MinesweeperGameState._(
      config: config,
      board: board,
      status: MinesweeperGameStatus.values.byName(json['status'] as String),
      message: json['message'] as String,
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
      generated: json['generated'] as bool,
    );
  }

  static MinesweeperGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return MinesweeperGameState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'config': config.toJson(),
      'board': board
          .map((row) => row.map((cell) => cell.toJson()).toList())
          .toList(),
      'status': status.name,
      'message': message,
      'elapsedSeconds': elapsedSeconds,
      'generated': generated,
    };
  }

  int get rows => config.rows;
  int get columns => config.columns;
  int get mineCount => config.mines;

  int get flagsPlaced {
    var count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (cell.flagged) {
          count++;
        }
      }
    }
    return count;
  }

  int get remainingMines => mineCount - flagsPlaced;

  int get revealedSafeCells {
    var count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (cell.revealed && !cell.hasMine) {
          count++;
        }
      }
    }
    return count;
  }

  bool get isComplete => status == MinesweeperGameStatus.won;
  bool get isLost => status == MinesweeperGameStatus.lost;
  bool get isActive => status == MinesweeperGameStatus.running;

  MinesweeperCell cellAt(int row, int column) => board[row][column];

  List<List<MinesweeperCell>> copyBoard() {
    return board
        .map((row) => row.map((cell) => cell.copyWith()).toList())
        .toList();
  }

  MinesweeperGameState incrementElapsed() {
    if (status != MinesweeperGameStatus.running) {
      return this;
    }
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  MinesweeperGameState withElapsedSeconds(int seconds) {
    return copyWith(elapsedSeconds: seconds < 0 ? 0 : seconds);
  }

  MinesweeperGameState revealCell(int row, int column, {int? seed}) {
    if (!_isInBounds(row, column)) {
      return this;
    }
    final tapped = board[row][column];
    if (tapped.revealed || tapped.flagged || isComplete || isLost) {
      return this;
    }

    var next = this;
    if (!generated) {
      next = _generateBoard(row, column, seed: seed);
    }

    final workingBoard = next.copyBoard();
    final cell = workingBoard[row][column];
    if (cell.hasMine) {
      workingBoard[row][column] = cell.copyWith(revealed: true, exploded: true);
      next = next
          ._revealAllMines(workingBoard)
          .copyWith(
            status: MinesweeperGameStatus.lost,
            message: 'Boom. Tap restart and try again.',
          );
      return next;
    }

    _floodReveal(workingBoard, row, column);
    next = next.copyWith(
      board: workingBoard,
      status: MinesweeperGameStatus.running,
      message: 'Clear run going.',
    );
    return next._finishIfSolved();
  }

  MinesweeperGameState toggleFlag(int row, int column) {
    if (!_isInBounds(row, column) || isComplete || isLost) {
      return this;
    }
    final cell = board[row][column];
    if (cell.revealed) {
      return this;
    }

    final workingBoard = copyBoard();
    workingBoard[row][column] = cell.copyWith(flagged: !cell.flagged);
    return copyWith(
      board: workingBoard,
      message: workingBoard[row][column].flagged
          ? 'Flag placed.'
          : 'Flag removed.',
    );
  }

  MinesweeperGameState chordCell(int row, int column) {
    if (!_isInBounds(row, column) || isComplete || isLost) {
      return this;
    }

    final cell = board[row][column];
    if (!cell.revealed || cell.adjacentMines == 0) {
      return this;
    }

    final neighbors = _neighborCoordinates(row, column);
    final flaggedNeighbors = neighbors
        .where((offset) => board[offset.$1][offset.$2].flagged)
        .length;
    if (flaggedNeighbors != cell.adjacentMines) {
      return copyWith(
        message:
            'Chord needs ${cell.adjacentMines} adjacent flags before it can open.',
      );
    }

    var next = this;
    for (final neighbor in neighbors) {
      final neighborCell = next.board[neighbor.$1][neighbor.$2];
      if (neighborCell.flagged || neighborCell.revealed) {
        continue;
      }
      next = next.revealCell(neighbor.$1, neighbor.$2);
      if (next.isLost) {
        return next;
      }
    }

    return next.copyWith(message: 'Chord opened surrounding tiles.');
  }

  MinesweeperGameState _finishIfSolved() {
    if (revealedSafeCells != (rows * columns) - mineCount) {
      return this;
    }

    final workingBoard = copyBoard();
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final cell = workingBoard[row][column];
        if (cell.hasMine) {
          workingBoard[row][column] = cell.copyWith(flagged: true);
        }
      }
    }

    return copyWith(
      board: workingBoard,
      status: MinesweeperGameStatus.won,
      message: 'Board cleared. Nice work.',
    );
  }

  MinesweeperGameState _revealAllMines(
    List<List<MinesweeperCell>> workingBoard,
  ) {
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final cell = workingBoard[row][column];
        if (cell.hasMine) {
          workingBoard[row][column] = cell.copyWith(revealed: true);
        }
      }
    }
    return copyWith(board: workingBoard);
  }

  MinesweeperGameState _generateBoard(
    int safeRow,
    int safeColumn, {
    int? seed,
  }) {
    final random = seed == null ? Random() : Random(seed);
    final workingBoard = _blankBoard(rows, columns);

    final excluded = _safeStartingZone(safeRow, safeColumn);
    final usableExcluded = (rows * columns) - excluded.length > mineCount
        ? excluded
        : <(int, int)>{(safeRow, safeColumn)};

    final candidates = <(int, int)>[];
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        if (!usableExcluded.contains((row, column))) {
          candidates.add((row, column));
        }
      }
    }
    candidates.shuffle(random);

    for (int index = 0; index < mineCount; index++) {
      final mine = candidates[index];
      workingBoard[mine.$1][mine.$2] = const MinesweeperCell(hasMine: true);
    }

    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final cell = workingBoard[row][column];
        if (cell.hasMine) {
          continue;
        }
        final adjacent = _neighborCoordinates(
          row,
          column,
        ).where((offset) => workingBoard[offset.$1][offset.$2].hasMine).length;
        workingBoard[row][column] = cell.copyWith(adjacentMines: adjacent);
      }
    }

    return copyWith(
      board: workingBoard,
      generated: true,
      status: MinesweeperGameStatus.running,
      message: 'Board ready. Good luck.',
    );
  }

  Set<(int, int)> _safeStartingZone(int row, int column) {
    final cells = <(int, int)>{};
    for (int r = max(0, row - 1); r <= min(rows - 1, row + 1); r++) {
      for (int c = max(0, column - 1); c <= min(columns - 1, column + 1); c++) {
        cells.add((r, c));
      }
    }
    return cells;
  }

  void _floodReveal(
    List<List<MinesweeperCell>> workingBoard,
    int row,
    int column,
  ) {
    final queue = <(int, int)>[(row, column)];
    final visited = <(int, int)>{};

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) {
        continue;
      }

      final cell = workingBoard[current.$1][current.$2];
      if (cell.flagged || cell.revealed) {
        continue;
      }

      workingBoard[current.$1][current.$2] = cell.copyWith(revealed: true);
      if (cell.adjacentMines != 0) {
        continue;
      }

      for (final neighbor in _neighborCoordinates(current.$1, current.$2)) {
        final neighborCell = workingBoard[neighbor.$1][neighbor.$2];
        if (!neighborCell.hasMine &&
            !neighborCell.revealed &&
            !neighborCell.flagged) {
          queue.add(neighbor);
        }
      }
    }
  }

  List<(int, int)> _neighborCoordinates(int row, int column) {
    final neighbors = <(int, int)>[];
    for (int r = max(0, row - 1); r <= min(rows - 1, row + 1); r++) {
      for (int c = max(0, column - 1); c <= min(columns - 1, column + 1); c++) {
        if (r == row && c == column) {
          continue;
        }
        neighbors.add((r, c));
      }
    }
    return neighbors;
  }

  bool _isInBounds(int row, int column) {
    return row >= 0 && row < rows && column >= 0 && column < columns;
  }
}
