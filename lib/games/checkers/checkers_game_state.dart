import 'dart:convert';

enum CheckersSide { red, black }

enum CheckersGameStatus { active, redWon, blackWon, draw, paused }

enum CheckersGameMode { vsAi, passAndPlay }

enum CheckersDifficulty {
  easy('easy', 'Easy', 2),
  medium('medium', 'Medium', 4),
  hard('hard', 'Hard', 6);

  const CheckersDifficulty(this.id, this.label, this.searchDepth);
  final String id;
  final String label;
  final int searchDepth;
}

class CheckersPiece {
  const CheckersPiece({required this.side, this.isKing = false});

  final CheckersSide side;
  final bool isKing;

  CheckersPiece copyWith({CheckersSide? side, bool? isKing}) {
    return CheckersPiece(
      side: side ?? this.side,
      isKing: isKing ?? this.isKing,
    );
  }

  Map<String, Object?> toJson() => {'side': side.name, 'isKing': isKing};

  factory CheckersPiece.fromJson(Map<String, dynamic> json) {
    return CheckersPiece(
      side: CheckersSide.values.byName(json['side'] as String),
      isKing: json['isKing'] as bool? ?? false,
    );
  }
}

class CheckersMove {
  const CheckersMove({
    required this.path,
    this.capturedSquares = const [],
    this.promotes = false,
  });

  final List<(int, int)> path;
  final List<(int, int)> capturedSquares;
  final bool promotes;

  int get fromRow => path.first.$1;
  int get fromCol => path.first.$2;
  int get toRow => path.last.$1;
  int get toCol => path.last.$2;
  bool get isCapture => capturedSquares.isNotEmpty;
  bool get isMultiJump => capturedSquares.length > 1;

  Map<String, Object?> toJson() => {
    'path': path.map((square) => [square.$1, square.$2]).toList(),
    'capturedSquares': capturedSquares
        .map((square) => [square.$1, square.$2])
        .toList(),
    'promotes': promotes,
  };

  factory CheckersMove.fromJson(Map<String, dynamic> json) {
    return CheckersMove(
      path: (json['path'] as List<dynamic>)
          .map(
            (square) => (
              ((square as List<dynamic>)[0] as num).toInt(),
              (square[1] as num).toInt(),
            ),
          )
          .toList(),
      capturedSquares: (json['capturedSquares'] as List<dynamic>? ?? const [])
          .map(
            (square) => (
              ((square as List<dynamic>)[0] as num).toInt(),
              (square[1] as num).toInt(),
            ),
          )
          .toList(),
      promotes: json['promotes'] as bool? ?? false,
    );
  }

  String notation(CheckersGameState state) {
    final separator = isCapture ? 'x' : '-';
    return path
        .map((square) => _squareName(square.$1, square.$2))
        .join(separator);
  }
}

class CheckersHistoryEntry {
  const CheckersHistoryEntry({
    required this.move,
    required this.notation,
    required this.position,
  });

  final CheckersMove move;
  final String notation;
  final String position;

  Map<String, Object?> toJson() => {
    'move': move.toJson(),
    'notation': notation,
    'position': position,
  };

  factory CheckersHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CheckersHistoryEntry(
      move: CheckersMove.fromJson(json['move'] as Map<String, dynamic>),
      notation: json['notation'] as String,
      position: json['position'] as String,
    );
  }
}

class CheckersGameState {
  CheckersGameState._({
    required this.board,
    required this.turn,
    required this.status,
    required this.message,
    required this.mode,
    required this.difficulty,
    required this.moveHistory,
    required this.elapsedSeconds,
    required this.selectedSquare,
    required this.lastMove,
    required this.resultRecorded,
  });

  static const storageKey = 'classic_suite.checkers.saved_state';

  final List<List<CheckersPiece?>> board;
  final CheckersSide turn;
  final CheckersGameStatus status;
  final String message;
  final CheckersGameMode mode;
  final CheckersDifficulty difficulty;
  final List<CheckersHistoryEntry> moveHistory;
  final int elapsedSeconds;
  final (int, int)? selectedSquare;
  final CheckersMove? lastMove;
  final bool resultRecorded;

  factory CheckersGameState.newGame({
    CheckersGameMode mode = CheckersGameMode.vsAi,
    CheckersDifficulty difficulty = CheckersDifficulty.medium,
  }) {
    return CheckersGameState._(
      board: _initialBoard(),
      turn: CheckersSide.red,
      status: CheckersGameStatus.active,
      message: 'Red to move.',
      mode: mode,
      difficulty: difficulty,
      moveHistory: const [],
      elapsedSeconds: 0,
      selectedSquare: null,
      lastMove: null,
      resultRecorded: false,
    );
  }

  factory CheckersGameState.debug({
    required List<List<CheckersPiece?>> board,
    CheckersSide turn = CheckersSide.red,
    CheckersGameStatus status = CheckersGameStatus.active,
    String message = 'Debug board',
    CheckersGameMode mode = CheckersGameMode.vsAi,
    CheckersDifficulty difficulty = CheckersDifficulty.medium,
    List<CheckersHistoryEntry> moveHistory = const [],
    int elapsedSeconds = 0,
    (int, int)? selectedSquare,
    CheckersMove? lastMove,
    bool resultRecorded = false,
  }) {
    return CheckersGameState._(
      board: board.map((row) => List<CheckersPiece?>.from(row)).toList(),
      turn: turn,
      status: status,
      message: message,
      mode: mode,
      difficulty: difficulty,
      moveHistory: List<CheckersHistoryEntry>.from(moveHistory),
      elapsedSeconds: elapsedSeconds,
      selectedSquare: selectedSquare,
      lastMove: lastMove,
      resultRecorded: resultRecorded,
    );
  }

  factory CheckersGameState.fromJson(Map<String, dynamic> json) {
    return CheckersGameState._(
      board: (json['board'] as List<dynamic>)
          .map(
            (row) => (row as List<dynamic>)
                .map(
                  (cell) => cell == null
                      ? null
                      : CheckersPiece.fromJson(cell as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList(),
      turn: CheckersSide.values.byName(json['turn'] as String),
      status: CheckersGameStatus.values.byName(json['status'] as String),
      message: json['message'] as String? ?? 'Red to move.',
      mode: CheckersGameMode.values.byName(json['mode'] as String? ?? 'vsAi'),
      difficulty: CheckersDifficulty.values.byName(
        json['difficulty'] as String? ?? 'medium',
      ),
      moveHistory: (json['moveHistory'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                CheckersHistoryEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      selectedSquare: json['selectedSquare'] == null
          ? null
          : (
              ((json['selectedSquare'] as List<dynamic>)[0] as num).toInt(),
              ((json['selectedSquare'] as List<dynamic>)[1] as num).toInt(),
            ),
      lastMove: json['lastMove'] == null
          ? null
          : CheckersMove.fromJson(json['lastMove'] as Map<String, dynamic>),
      resultRecorded: json['resultRecorded'] as bool? ?? false,
    );
  }

  static CheckersGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return CheckersGameState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'board': board
        .map((row) => row.map((cell) => cell?.toJson()).toList())
        .toList(),
    'turn': turn.name,
    'status': status.name,
    'message': message,
    'mode': mode.name,
    'difficulty': difficulty.name,
    'moveHistory': moveHistory.map((entry) => entry.toJson()).toList(),
    'elapsedSeconds': elapsedSeconds,
    'selectedSquare': selectedSquare == null
        ? null
        : [selectedSquare!.$1, selectedSquare!.$2],
    'lastMove': lastMove?.toJson(),
    'resultRecorded': resultRecorded,
  };

  String encode() => jsonEncode(toJson());

  CheckersGameState copyWith({
    List<List<CheckersPiece?>>? board,
    CheckersSide? turn,
    CheckersGameStatus? status,
    String? message,
    CheckersGameMode? mode,
    CheckersDifficulty? difficulty,
    List<CheckersHistoryEntry>? moveHistory,
    int? elapsedSeconds,
    (int, int)? selectedSquare,
    bool clearSelectedSquare = false,
    CheckersMove? lastMove,
    bool clearLastMove = false,
    bool? resultRecorded,
  }) {
    return CheckersGameState._(
      board:
          board ??
          this.board.map((row) => List<CheckersPiece?>.from(row)).toList(),
      turn: turn ?? this.turn,
      status: status ?? this.status,
      message: message ?? this.message,
      mode: mode ?? this.mode,
      difficulty: difficulty ?? this.difficulty,
      moveHistory:
          moveHistory ?? List<CheckersHistoryEntry>.from(this.moveHistory),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      selectedSquare: clearSelectedSquare
          ? null
          : (selectedSquare ?? this.selectedSquare),
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      resultRecorded: resultRecorded ?? this.resultRecorded,
    );
  }

  bool get isPaused => status == CheckersGameStatus.paused;
  bool get isFinished =>
      status == CheckersGameStatus.redWon ||
      status == CheckersGameStatus.blackWon ||
      status == CheckersGameStatus.draw;
  bool get isHumanTurn =>
      !isPaused &&
      !isFinished &&
      (mode == CheckersGameMode.passAndPlay || turn == CheckersSide.red);
  CheckersSide get aiSide => CheckersSide.black;

  CheckersPiece? pieceAt(int row, int col) => board[row][col];

  CheckersGameState incrementElapsed() {
    if (isPaused || isFinished) return this;
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  CheckersGameState togglePause() {
    if (isFinished) return this;
    return copyWith(
      status: isPaused ? CheckersGameStatus.active : CheckersGameStatus.paused,
      message: isPaused ? '${turn.label} to move.' : 'Game paused.',
    );
  }

  CheckersGameState setMode(CheckersGameMode nextMode) {
    return CheckersGameState.newGame(mode: nextMode, difficulty: difficulty);
  }

  CheckersGameState setDifficulty(CheckersDifficulty nextDifficulty) {
    return CheckersGameState.newGame(mode: mode, difficulty: nextDifficulty);
  }

  CheckersGameState markResultRecorded() => copyWith(resultRecorded: true);

  CheckersGameState selectSquare(int row, int col) {
    if (isPaused || isFinished) return this;
    final piece = pieceAt(row, col);
    if (piece == null || piece.side != turn) {
      return copyWith(clearSelectedSquare: true);
    }
    if (mode == CheckersGameMode.vsAi && piece.side != CheckersSide.red) {
      return this;
    }
    final moves = legalMovesForSquare(row, col);
    if (moves.isEmpty) {
      return copyWith(
        clearSelectedSquare: true,
        message: mandatoryCaptureExists
            ? 'A capture is available. You must take it.'
            : '${turn.label} to move.',
      );
    }
    return copyWith(
      selectedSquare: (row, col),
      message: piece.isKing
          ? '${piece.side.label} king selected.'
          : '${piece.side.label} piece selected.',
    );
  }

  bool get mandatoryCaptureExists => legalMoves.any((move) => move.isCapture);

  List<CheckersMove> legalMovesForSquare(int row, int col) {
    return legalMoves
        .where((move) => move.fromRow == row && move.fromCol == col)
        .toList();
  }

  List<CheckersMove> get legalMoves => _generateLegalMoves(turn);

  CheckersGameState applyMove(CheckersMove move, {bool fromAi = false}) {
    final piece = board[move.fromRow][move.fromCol];
    if (piece == null) return this;

    final nextBoard = board
        .map((row) => List<CheckersPiece?>.from(row))
        .toList();
    nextBoard[move.fromRow][move.fromCol] = null;
    for (final captured in move.capturedSquares) {
      nextBoard[captured.$1][captured.$2] = null;
    }

    var movedPiece = piece;
    if (!piece.isKing && _promotionRow(piece.side) == move.toRow) {
      movedPiece = piece.copyWith(isKing: true);
    }
    nextBoard[move.toRow][move.toCol] = movedPiece;

    final preview = copyWith(
      board: nextBoard,
      turn: _opponent(turn),
      lastMove: move,
      clearSelectedSquare: true,
    );
    final notation = move.notation(this);
    final history = List<CheckersHistoryEntry>.from(moveHistory)
      ..add(
        CheckersHistoryEntry(
          move: move,
          notation: notation,
          position: preview.positionKey,
        ),
      );

    return preview
        .copyWith(moveHistory: history)
        ._finishGameIfNeeded(movedByAi: fromAi, notation: notation);
  }

  CheckersGameState _finishGameIfNeeded({
    required bool movedByAi,
    required String notation,
  }) {
    final nextSide = turn;
    final legal = legalMoves;
    if (legal.isEmpty) {
      final winner = _opponent(turn);
      return copyWith(
        status: winner == CheckersSide.red
            ? CheckersGameStatus.redWon
            : CheckersGameStatus.blackWon,
        message: '${winner.label} wins.',
      );
    }

    final positionCount = <String, int>{};
    for (final entry in moveHistory) {
      positionCount.update(
        entry.position,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    positionCount.update(positionKey, (value) => value + 1, ifAbsent: () => 1);
    if (positionCount.values.any((count) => count >= 3)) {
      return copyWith(
        status: CheckersGameStatus.draw,
        message: 'Draw by repetition.',
      );
    }

    return copyWith(
      message: mandatoryCaptureExists
          ? '${nextSide.label} to move. Capture required.'
          : '${nextSide.label} to move${movedByAi ? ' after $notation.' : '.'}',
    );
  }

  String get positionKey {
    final buffer = StringBuffer();
    for (final row in board) {
      for (final piece in row) {
        if (piece == null) {
          buffer.write('.');
        } else if (piece.side == CheckersSide.red) {
          buffer.write(piece.isKing ? 'R' : 'r');
        } else {
          buffer.write(piece.isKing ? 'B' : 'b');
        }
      }
    }
    buffer.write('/${turn.name}');
    return buffer.toString();
  }

  List<CheckersMove> _generateLegalMoves(CheckersSide side) {
    final captures = <CheckersMove>[];
    final simpleMoves = <CheckersMove>[];

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == null || piece.side != side) continue;
        captures.addAll(_captureSequencesFrom(row, col, piece));
        if (captures.isEmpty) {
          simpleMoves.addAll(_simpleMovesFrom(row, col, piece));
        }
      }
    }

    return captures.isNotEmpty ? captures : simpleMoves;
  }

  List<CheckersMove> _simpleMovesFrom(int row, int col, CheckersPiece piece) {
    final moves = <CheckersMove>[];
    for (final delta in _movementDirections(piece, captures: false)) {
      final nextRow = row + delta.$1;
      final nextCol = col + delta.$2;
      if (!_inBounds(nextRow, nextCol) || board[nextRow][nextCol] != null) {
        continue;
      }
      moves.add(
        CheckersMove(
          path: [(row, col), (nextRow, nextCol)],
          promotes: !piece.isKing && _promotionRow(piece.side) == nextRow,
        ),
      );
    }
    return moves;
  }

  List<CheckersMove> _captureSequencesFrom(
    int row,
    int col,
    CheckersPiece piece,
  ) {
    final workingBoard = board
        .map((sourceRow) => List<CheckersPiece?>.from(sourceRow))
        .toList();
    return _buildCaptures(
      boardState: workingBoard,
      row: row,
      col: col,
      piece: piece,
      path: [(row, col)],
      captured: const [],
    );
  }

  List<CheckersMove> _buildCaptures({
    required List<List<CheckersPiece?>> boardState,
    required int row,
    required int col,
    required CheckersPiece piece,
    required List<(int, int)> path,
    required List<(int, int)> captured,
  }) {
    final results = <CheckersMove>[];
    var extended = false;

    for (final delta in _movementDirections(piece, captures: true)) {
      final midRow = row + delta.$1;
      final midCol = col + delta.$2;
      final landingRow = row + (delta.$1 * 2);
      final landingCol = col + (delta.$2 * 2);
      if (!_inBounds(midRow, midCol) || !_inBounds(landingRow, landingCol)) {
        continue;
      }
      final jumped = boardState[midRow][midCol];
      if (jumped == null || jumped.side == piece.side) continue;
      if (boardState[landingRow][landingCol] != null) continue;

      extended = true;
      final nextBoard = boardState
          .map((sourceRow) => List<CheckersPiece?>.from(sourceRow))
          .toList();
      nextBoard[row][col] = null;
      nextBoard[midRow][midCol] = null;

      var nextPiece = piece;
      final promotes = !piece.isKing && _promotionRow(piece.side) == landingRow;
      if (promotes) {
        nextPiece = piece.copyWith(isKing: true);
      }
      nextBoard[landingRow][landingCol] = nextPiece;

      final nextPath = [...path, (landingRow, landingCol)];
      final nextCaptured = [...captured, (midRow, midCol)];

      if (promotes && !piece.isKing) {
        results.add(
          CheckersMove(
            path: nextPath,
            capturedSquares: nextCaptured,
            promotes: true,
          ),
        );
        continue;
      }

      final continuations = _buildCaptures(
        boardState: nextBoard,
        row: landingRow,
        col: landingCol,
        piece: nextPiece,
        path: nextPath,
        captured: nextCaptured,
      );
      if (continuations.isEmpty) {
        results.add(
          CheckersMove(
            path: nextPath,
            capturedSquares: nextCaptured,
            promotes: promotes,
          ),
        );
      } else {
        results.addAll(continuations);
      }
    }

    if (!extended && captured.isNotEmpty) {
      return [CheckersMove(path: path, capturedSquares: captured)];
    }
    return results;
  }

  Iterable<(int, int)> _movementDirections(
    CheckersPiece piece, {
    required bool captures,
  }) {
    if (piece.isKing) {
      return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
    }
    final forward = piece.side == CheckersSide.red ? -1 : 1;
    return [(forward, -1), (forward, 1)];
  }

  int _promotionRow(CheckersSide side) => side == CheckersSide.red ? 0 : 7;

  bool _inBounds(int row, int col) =>
      row >= 0 && row < 8 && col >= 0 && col < 8;
}

List<List<CheckersPiece?>> _initialBoard() {
  final board = List<List<CheckersPiece?>>.generate(
    8,
    (_) => List<CheckersPiece?>.filled(8, null),
  );
  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 8; col++) {
      if ((row + col).isOdd) {
        board[row][col] = const CheckersPiece(side: CheckersSide.black);
      }
    }
  }
  for (int row = 5; row < 8; row++) {
    for (int col = 0; col < 8; col++) {
      if ((row + col).isOdd) {
        board[row][col] = const CheckersPiece(side: CheckersSide.red);
      }
    }
  }
  return board;
}

CheckersSide _opponent(CheckersSide side) =>
    side == CheckersSide.red ? CheckersSide.black : CheckersSide.red;

String _squareName(int row, int col) =>
    '${String.fromCharCode(97 + col)}${8 - row}';

extension on CheckersSide {
  String get label => this == CheckersSide.red ? 'Red' : 'Black';
}
