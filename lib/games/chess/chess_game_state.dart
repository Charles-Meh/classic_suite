import 'dart:convert';

enum ChessSide { white, black }

enum ChessPieceType { king, queen, rook, bishop, knight, pawn }

enum ChessGameStatus { active, whiteWon, blackWon, draw, paused }

enum ChessGameMode { vsAi, passAndPlay }

enum ChessDifficulty {
  easy('easy', 'Easy', 2),
  medium('medium', 'Medium', 4),
  hard('hard', 'Hard', 6);

  const ChessDifficulty(this.id, this.label, this.searchDepth);
  final String id;
  final String label;
  final int searchDepth;
}

class ChessPiece {
  const ChessPiece(this.side, this.type);

  final ChessSide side;
  final ChessPieceType type;

  ChessPiece copyWith({ChessSide? side, ChessPieceType? type}) {
    return ChessPiece(side ?? this.side, type ?? this.type);
  }

  Map<String, Object?> toJson() => {'side': side.name, 'type': type.name};

  factory ChessPiece.fromJson(Map<String, dynamic> json) {
    return ChessPiece(
      ChessSide.values.byName(json['side'] as String),
      ChessPieceType.values.byName(json['type'] as String),
    );
  }

  String get assetName =>
      '${side == ChessSide.white ? 'w' : 'b'}${switch (type) {
        ChessPieceType.king => 'K',
        ChessPieceType.queen => 'Q',
        ChessPieceType.rook => 'R',
        ChessPieceType.bishop => 'B',
        ChessPieceType.knight => 'N',
        ChessPieceType.pawn => 'P',
      }}';

  String get symbol => switch ((side, type)) {
    (ChessSide.white, ChessPieceType.king) => '♔',
    (ChessSide.white, ChessPieceType.queen) => '♕',
    (ChessSide.white, ChessPieceType.rook) => '♖',
    (ChessSide.white, ChessPieceType.bishop) => '♗',
    (ChessSide.white, ChessPieceType.knight) => '♘',
    (ChessSide.white, ChessPieceType.pawn) => '♙',
    (ChessSide.black, ChessPieceType.king) => '♚',
    (ChessSide.black, ChessPieceType.queen) => '♛',
    (ChessSide.black, ChessPieceType.rook) => '♜',
    (ChessSide.black, ChessPieceType.bishop) => '♝',
    (ChessSide.black, ChessPieceType.knight) => '♞',
    (ChessSide.black, ChessPieceType.pawn) => '♟',
  };
}

class ChessMove {
  const ChessMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.promotion,
    this.isCastleKingSide = false,
    this.isCastleQueenSide = false,
    this.isEnPassant = false,
  });

  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final ChessPieceType? promotion;
  final bool isCastleKingSide;
  final bool isCastleQueenSide;
  final bool isEnPassant;

  Map<String, Object?> toJson() => {
    'fromRow': fromRow,
    'fromCol': fromCol,
    'toRow': toRow,
    'toCol': toCol,
    'promotion': promotion?.name,
    'isCastleKingSide': isCastleKingSide,
    'isCastleQueenSide': isCastleQueenSide,
    'isEnPassant': isEnPassant,
  };

  factory ChessMove.fromJson(Map<String, dynamic> json) {
    return ChessMove(
      fromRow: (json['fromRow'] as num).toInt(),
      fromCol: (json['fromCol'] as num).toInt(),
      toRow: (json['toRow'] as num).toInt(),
      toCol: (json['toCol'] as num).toInt(),
      promotion: json['promotion'] == null
          ? null
          : ChessPieceType.values.byName(json['promotion'] as String),
      isCastleKingSide: json['isCastleKingSide'] as bool? ?? false,
      isCastleQueenSide: json['isCastleQueenSide'] as bool? ?? false,
      isEnPassant: json['isEnPassant'] as bool? ?? false,
    );
  }

  String get uci =>
      '${_squareName(fromRow, fromCol)}${_squareName(toRow, toCol)}${promotion == null ? '' : promotion!.name[0]}';

  String toDisplay(ChessGameState state) {
    final moving = state.board[fromRow][fromCol];
    final capture = state.board[toRow][toCol] != null || isEnPassant;
    if (isCastleKingSide) {
      return 'O-O';
    }
    if (isCastleQueenSide) {
      return 'O-O-O';
    }
    final piece = moving?.type == ChessPieceType.pawn
        ? (capture ? _squareName(fromRow, fromCol)[0] : '')
        : _pieceLetter(moving!.type);
    final target = _squareName(toRow, toCol);
    final suffix = promotion == null ? '' : '=${_pieceLetter(promotion!)}';
    return '$piece${capture ? 'x' : ''}$target$suffix';
  }

  static String _pieceLetter(ChessPieceType type) => switch (type) {
    ChessPieceType.king => 'K',
    ChessPieceType.queen => 'Q',
    ChessPieceType.rook => 'R',
    ChessPieceType.bishop => 'B',
    ChessPieceType.knight => 'N',
    ChessPieceType.pawn => '',
  };
}

class ChessHistoryEntry {
  const ChessHistoryEntry({
    required this.move,
    required this.notation,
    required this.fen,
  });

  final ChessMove move;
  final String notation;
  final String fen;

  Map<String, Object?> toJson() => {
    'move': move.toJson(),
    'notation': notation,
    'fen': fen,
  };

  factory ChessHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ChessHistoryEntry(
      move: ChessMove.fromJson(json['move'] as Map<String, dynamic>),
      notation: json['notation'] as String,
      fen: json['fen'] as String,
    );
  }
}

class ChessGameState {
  ChessGameState._({
    required this.board,
    required this.turn,
    required this.status,
    required this.message,
    required this.mode,
    required this.difficulty,
    required this.moveHistory,
    required this.whiteKingMoved,
    required this.blackKingMoved,
    required this.whiteLeftRookMoved,
    required this.whiteRightRookMoved,
    required this.blackLeftRookMoved,
    required this.blackRightRookMoved,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
    required this.elapsedSeconds,
    required this.lastMove,
    required this.showHint,
    required this.selectedSquare,
    required this.hintMove,
    required this.resultRecorded,
  });

  static const storageKey = 'classic_suite.chess.saved_state';

  final List<List<ChessPiece?>> board;
  final ChessSide turn;
  final ChessGameStatus status;
  final String message;
  final ChessGameMode mode;
  final ChessDifficulty difficulty;
  final List<ChessHistoryEntry> moveHistory;
  final bool whiteKingMoved;
  final bool blackKingMoved;
  final bool whiteLeftRookMoved;
  final bool whiteRightRookMoved;
  final bool blackLeftRookMoved;
  final bool blackRightRookMoved;
  final (int, int)? enPassantTarget;
  final int halfmoveClock;
  final int fullmoveNumber;
  final int elapsedSeconds;
  final ChessMove? lastMove;
  final bool showHint;
  final (int, int)? selectedSquare;
  final ChessMove? hintMove;
  final bool resultRecorded;

  factory ChessGameState.newGame({
    ChessGameMode mode = ChessGameMode.vsAi,
    ChessDifficulty difficulty = ChessDifficulty.medium,
  }) {
    return ChessGameState._(
      board: _initialBoard(),
      turn: ChessSide.white,
      status: ChessGameStatus.active,
      message: 'White to move.',
      mode: mode,
      difficulty: difficulty,
      moveHistory: const [],
      whiteKingMoved: false,
      blackKingMoved: false,
      whiteLeftRookMoved: false,
      whiteRightRookMoved: false,
      blackLeftRookMoved: false,
      blackRightRookMoved: false,
      enPassantTarget: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      elapsedSeconds: 0,
      lastMove: null,
      showHint: false,
      selectedSquare: null,
      hintMove: null,
      resultRecorded: false,
    );
  }

  factory ChessGameState.debug({
    required List<List<ChessPiece?>> board,
    ChessSide turn = ChessSide.white,
    ChessGameStatus status = ChessGameStatus.active,
    String message = 'Debug board',
    ChessGameMode mode = ChessGameMode.vsAi,
    ChessDifficulty difficulty = ChessDifficulty.medium,
    List<ChessHistoryEntry> moveHistory = const [],
    bool whiteKingMoved = false,
    bool blackKingMoved = false,
    bool whiteLeftRookMoved = false,
    bool whiteRightRookMoved = false,
    bool blackLeftRookMoved = false,
    bool blackRightRookMoved = false,
    (int, int)? enPassantTarget,
    int halfmoveClock = 0,
    int fullmoveNumber = 1,
    int elapsedSeconds = 0,
    ChessMove? lastMove,
    bool showHint = false,
    (int, int)? selectedSquare,
    ChessMove? hintMove,
    bool resultRecorded = false,
  }) {
    return ChessGameState._(
      board: board.map((row) => List<ChessPiece?>.from(row)).toList(),
      turn: turn,
      status: status,
      message: message,
      mode: mode,
      difficulty: difficulty,
      moveHistory: List<ChessHistoryEntry>.from(moveHistory),
      whiteKingMoved: whiteKingMoved,
      blackKingMoved: blackKingMoved,
      whiteLeftRookMoved: whiteLeftRookMoved,
      whiteRightRookMoved: whiteRightRookMoved,
      blackLeftRookMoved: blackLeftRookMoved,
      blackRightRookMoved: blackRightRookMoved,
      enPassantTarget: enPassantTarget,
      halfmoveClock: halfmoveClock,
      fullmoveNumber: fullmoveNumber,
      elapsedSeconds: elapsedSeconds,
      lastMove: lastMove,
      showHint: showHint,
      selectedSquare: selectedSquare,
      hintMove: hintMove,
      resultRecorded: resultRecorded,
    );
  }

  factory ChessGameState.fromJson(Map<String, dynamic> json) {
    return ChessGameState._(
      board: (json['board'] as List<dynamic>)
          .map(
            (row) => (row as List<dynamic>)
                .map(
                  (cell) => cell == null
                      ? null
                      : ChessPiece.fromJson(cell as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList(),
      turn: ChessSide.values.byName(json['turn'] as String),
      status: ChessGameStatus.values.byName(json['status'] as String),
      message: json['message'] as String,
      mode: ChessGameMode.values.byName(json['mode'] as String),
      difficulty: ChessDifficulty.values.byName(json['difficulty'] as String),
      moveHistory: (json['moveHistory'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ChessHistoryEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      whiteKingMoved: json['whiteKingMoved'] as bool? ?? false,
      blackKingMoved: json['blackKingMoved'] as bool? ?? false,
      whiteLeftRookMoved: json['whiteLeftRookMoved'] as bool? ?? false,
      whiteRightRookMoved: json['whiteRightRookMoved'] as bool? ?? false,
      blackLeftRookMoved: json['blackLeftRookMoved'] as bool? ?? false,
      blackRightRookMoved: json['blackRightRookMoved'] as bool? ?? false,
      enPassantTarget: json['enPassantTarget'] == null
          ? null
          : ((json['enPassantTarget'] as List<dynamic>)[0] as num).toInt() == -1
          ? null
          : (
              ((json['enPassantTarget'] as List<dynamic>)[0] as num).toInt(),
              ((json['enPassantTarget'] as List<dynamic>)[1] as num).toInt(),
            ),
      halfmoveClock: (json['halfmoveClock'] as num?)?.toInt() ?? 0,
      fullmoveNumber: (json['fullmoveNumber'] as num?)?.toInt() ?? 1,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      lastMove: json['lastMove'] == null
          ? null
          : ChessMove.fromJson(json['lastMove'] as Map<String, dynamic>),
      showHint: json['showHint'] as bool? ?? false,
      selectedSquare: json['selectedSquare'] == null
          ? null
          : (
              ((json['selectedSquare'] as List<dynamic>)[0] as num).toInt(),
              ((json['selectedSquare'] as List<dynamic>)[1] as num).toInt(),
            ),
      hintMove: json['hintMove'] == null
          ? null
          : ChessMove.fromJson(json['hintMove'] as Map<String, dynamic>),
      resultRecorded: json['resultRecorded'] as bool? ?? false,
    );
  }

  static ChessGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ChessGameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    'whiteKingMoved': whiteKingMoved,
    'blackKingMoved': blackKingMoved,
    'whiteLeftRookMoved': whiteLeftRookMoved,
    'whiteRightRookMoved': whiteRightRookMoved,
    'blackLeftRookMoved': blackLeftRookMoved,
    'blackRightRookMoved': blackRightRookMoved,
    'enPassantTarget': enPassantTarget == null
        ? null
        : [enPassantTarget!.$1, enPassantTarget!.$2],
    'halfmoveClock': halfmoveClock,
    'fullmoveNumber': fullmoveNumber,
    'elapsedSeconds': elapsedSeconds,
    'lastMove': lastMove?.toJson(),
    'showHint': showHint,
    'selectedSquare': selectedSquare == null
        ? null
        : [selectedSquare!.$1, selectedSquare!.$2],
    'hintMove': hintMove?.toJson(),
    'resultRecorded': resultRecorded,
  };

  String encode() => jsonEncode(toJson());

  ChessGameState copyWith({
    List<List<ChessPiece?>>? board,
    ChessSide? turn,
    ChessGameStatus? status,
    String? message,
    ChessGameMode? mode,
    ChessDifficulty? difficulty,
    List<ChessHistoryEntry>? moveHistory,
    bool? whiteKingMoved,
    bool? blackKingMoved,
    bool? whiteLeftRookMoved,
    bool? whiteRightRookMoved,
    bool? blackLeftRookMoved,
    bool? blackRightRookMoved,
    (int, int)? enPassantTarget,
    bool clearEnPassant = false,
    int? halfmoveClock,
    int? fullmoveNumber,
    int? elapsedSeconds,
    ChessMove? lastMove,
    bool clearLastMove = false,
    bool? showHint,
    (int, int)? selectedSquare,
    bool clearSelectedSquare = false,
    ChessMove? hintMove,
    bool clearHint = false,
    bool? resultRecorded,
  }) {
    return ChessGameState._(
      board:
          board ??
          this.board.map((row) => List<ChessPiece?>.from(row)).toList(),
      turn: turn ?? this.turn,
      status: status ?? this.status,
      message: message ?? this.message,
      mode: mode ?? this.mode,
      difficulty: difficulty ?? this.difficulty,
      moveHistory:
          moveHistory ?? List<ChessHistoryEntry>.from(this.moveHistory),
      whiteKingMoved: whiteKingMoved ?? this.whiteKingMoved,
      blackKingMoved: blackKingMoved ?? this.blackKingMoved,
      whiteLeftRookMoved: whiteLeftRookMoved ?? this.whiteLeftRookMoved,
      whiteRightRookMoved: whiteRightRookMoved ?? this.whiteRightRookMoved,
      blackLeftRookMoved: blackLeftRookMoved ?? this.blackLeftRookMoved,
      blackRightRookMoved: blackRightRookMoved ?? this.blackRightRookMoved,
      enPassantTarget: clearEnPassant
          ? null
          : (enPassantTarget ?? this.enPassantTarget),
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      showHint: showHint ?? this.showHint,
      selectedSquare: clearSelectedSquare
          ? null
          : (selectedSquare ?? this.selectedSquare),
      hintMove: clearHint ? null : (hintMove ?? this.hintMove),
      resultRecorded: resultRecorded ?? this.resultRecorded,
    );
  }

  bool get isPaused => status == ChessGameStatus.paused;
  bool get isFinished =>
      status == ChessGameStatus.whiteWon ||
      status == ChessGameStatus.blackWon ||
      status == ChessGameStatus.draw;
  bool get isHumanTurn =>
      !isPaused &&
      !isFinished &&
      (mode == ChessGameMode.passAndPlay || turn == ChessSide.white);
  ChessSide get aiSide => ChessSide.black;

  ChessPiece? pieceAt(int row, int col) => board[row][col];

  ChessGameState incrementElapsed() {
    if (isPaused || isFinished) return this;
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  ChessGameState togglePause() {
    if (isFinished) return this;
    return copyWith(
      status: isPaused ? ChessGameStatus.active : ChessGameStatus.paused,
      message: isPaused ? '${turn.name.capitalize()} to move.' : 'Game paused.',
    );
  }

  ChessGameState selectSquare(int row, int col) {
    if (isPaused || isFinished) return this;
    final piece = pieceAt(row, col);
    if (piece == null || piece.side != turn) {
      return copyWith(clearSelectedSquare: true, clearHint: true);
    }
    if (mode == ChessGameMode.vsAi && piece.side != ChessSide.white) {
      return this;
    }
    return copyWith(
      selectedSquare: (row, col),
      clearHint: true,
      message: '${piece.side.name.capitalize()} ${piece.type.name} selected.',
    );
  }

  List<ChessMove> legalMovesForSquare(int row, int col) {
    final piece = pieceAt(row, col);
    if (piece == null) return const [];
    return legalMoves
        .where((move) => move.fromRow == row && move.fromCol == col)
        .toList();
  }

  List<ChessMove> get legalMoves => _generateLegalMoves(turn);

  bool get inCheck => isKingInCheck(turn);

  bool isKingInCheck(ChessSide side) {
    (int, int)? king;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece?.side == side && piece?.type == ChessPieceType.king) {
          king = (row, col);
          break;
        }
      }
    }
    if (king == null) return false;
    return _isSquareAttacked(king.$1, king.$2, _opponent(side));
  }

  ChessGameState setMode(ChessGameMode nextMode) {
    return ChessGameState.newGame(mode: nextMode, difficulty: difficulty);
  }

  ChessGameState setDifficulty(ChessDifficulty nextDifficulty) {
    return copyWith(
      difficulty: nextDifficulty,
      message:
          '${nextDifficulty.label} selected. ${turn.name.capitalize()} to move.',
    );
  }

  ChessGameState withHint(ChessMove? move) {
    return copyWith(
      showHint: move != null,
      hintMove: move,
      message: move == null ? message : 'Hint: ${move.toDisplay(this)}',
    );
  }

  ChessGameState clearHint() => copyWith(showHint: false, clearHint: true);

  ChessGameState markResultRecorded() => copyWith(resultRecorded: true);

  ChessGameState applyMove(
    ChessMove move, {
    bool fromAi = false,
    bool evaluateResult = true,
  }) {
    final piece = board[move.fromRow][move.fromCol];
    if (piece == null) return this;
    final nextBoard = board.map((row) => List<ChessPiece?>.from(row)).toList();
    final captured = move.isEnPassant
        ? nextBoard[move.fromRow][move.toCol]
        : nextBoard[move.toRow][move.toCol];
    nextBoard[move.fromRow][move.fromCol] = null;

    ChessPiece movedPiece = piece;
    if (piece.type == ChessPieceType.pawn &&
        (move.toRow == 0 || move.toRow == 7)) {
      movedPiece = ChessPiece(
        piece.side,
        move.promotion ?? ChessPieceType.queen,
      );
    }

    if (move.isEnPassant) {
      nextBoard[move.fromRow][move.toCol] = null;
    }

    nextBoard[move.toRow][move.toCol] = movedPiece;

    if (move.isCastleKingSide) {
      nextBoard[move.toRow][5] = nextBoard[move.toRow][7];
      nextBoard[move.toRow][7] = null;
    } else if (move.isCastleQueenSide) {
      nextBoard[move.toRow][3] = nextBoard[move.toRow][0];
      nextBoard[move.toRow][0] = null;
    }

    bool nextWhiteKingMoved = whiteKingMoved;
    bool nextBlackKingMoved = blackKingMoved;
    bool nextWhiteLeftRookMoved = whiteLeftRookMoved;
    bool nextWhiteRightRookMoved = whiteRightRookMoved;
    bool nextBlackLeftRookMoved = blackLeftRookMoved;
    bool nextBlackRightRookMoved = blackRightRookMoved;

    if (piece.side == ChessSide.white && piece.type == ChessPieceType.king)
      nextWhiteKingMoved = true;
    if (piece.side == ChessSide.black && piece.type == ChessPieceType.king)
      nextBlackKingMoved = true;
    if (piece.side == ChessSide.white &&
        piece.type == ChessPieceType.rook &&
        move.fromRow == 7 &&
        move.fromCol == 0)
      nextWhiteLeftRookMoved = true;
    if (piece.side == ChessSide.white &&
        piece.type == ChessPieceType.rook &&
        move.fromRow == 7 &&
        move.fromCol == 7)
      nextWhiteRightRookMoved = true;
    if (piece.side == ChessSide.black &&
        piece.type == ChessPieceType.rook &&
        move.fromRow == 0 &&
        move.fromCol == 0)
      nextBlackLeftRookMoved = true;
    if (piece.side == ChessSide.black &&
        piece.type == ChessPieceType.rook &&
        move.fromRow == 0 &&
        move.fromCol == 7)
      nextBlackRightRookMoved = true;

    if (captured?.type == ChessPieceType.rook) {
      if (captured!.side == ChessSide.white &&
          move.toRow == 7 &&
          move.toCol == 0)
        nextWhiteLeftRookMoved = true;
      if (captured.side == ChessSide.white &&
          move.toRow == 7 &&
          move.toCol == 7)
        nextWhiteRightRookMoved = true;
      if (captured.side == ChessSide.black &&
          move.toRow == 0 &&
          move.toCol == 0)
        nextBlackLeftRookMoved = true;
      if (captured.side == ChessSide.black &&
          move.toRow == 0 &&
          move.toCol == 7)
        nextBlackRightRookMoved = true;
    }

    final nextEnPassant =
        piece.type == ChessPieceType.pawn &&
            (move.fromRow - move.toRow).abs() == 2
        ? ((move.fromRow + move.toRow) ~/ 2, move.fromCol)
        : null;
    final nextTurn = _opponent(turn);
    final preview = copyWith(
      board: nextBoard,
      turn: nextTurn,
      whiteKingMoved: nextWhiteKingMoved,
      blackKingMoved: nextBlackKingMoved,
      whiteLeftRookMoved: nextWhiteLeftRookMoved,
      whiteRightRookMoved: nextWhiteRightRookMoved,
      blackLeftRookMoved: nextBlackLeftRookMoved,
      blackRightRookMoved: nextBlackRightRookMoved,
      enPassantTarget: nextEnPassant,
      clearEnPassant: nextEnPassant == null,
      halfmoveClock: (piece.type == ChessPieceType.pawn || captured != null)
          ? 0
          : halfmoveClock + 1,
      fullmoveNumber: turn == ChessSide.black
          ? fullmoveNumber + 1
          : fullmoveNumber,
      lastMove: move,
      clearSelectedSquare: true,
      clearHint: true,
      showHint: false,
    );

    final notation = move.toDisplay(this);
    final history = List<ChessHistoryEntry>.from(
      moveHistory,
    )..add(ChessHistoryEntry(move: move, notation: notation, fen: preview.fen));
    final next = preview.copyWith(moveHistory: history);
    return evaluateResult
        ? next._finishGameIfNeeded(movedByAi: fromAi, notation: notation)
        : next;
  }

  ChessGameState _finishGameIfNeeded({
    required bool movedByAi,
    required String notation,
  }) {
    final sideToMove = turn;
    final legal = legalMoves;
    final checked = isKingInCheck(turn);
    if (legal.isEmpty) {
      if (checked) {
        final winner = _opponent(turn);
        return copyWith(
          status: winner == ChessSide.white
              ? ChessGameStatus.whiteWon
              : ChessGameStatus.blackWon,
          message: '${winner.name.capitalize()} wins by checkmate.',
        );
      }
      return copyWith(
        status: ChessGameStatus.draw,
        message: 'Draw by stalemate.',
      );
    }
    if (halfmoveClock >= 100) {
      return copyWith(
        status: ChessGameStatus.draw,
        message: 'Draw by fifty-move rule.',
      );
    }
    if (_insufficientMaterial()) {
      return copyWith(
        status: ChessGameStatus.draw,
        message: 'Draw by insufficient material.',
      );
    }
    return copyWith(
      message: checked
          ? '${sideToMove.name.capitalize()} is in check.'
          : '${sideToMove.name.capitalize()} to move${movedByAi ? ' after $notation.' : '.'}',
    );
  }

  bool _insufficientMaterial() {
    final pieces = <ChessPiece>[];
    for (final row in board) {
      for (final piece in row) {
        if (piece != null) pieces.add(piece);
      }
    }
    if (pieces.every((p) => p.type == ChessPieceType.king)) return true;
    if (pieces.length == 3) {
      return pieces.any(
        (p) =>
            p.type == ChessPieceType.bishop || p.type == ChessPieceType.knight,
      );
    }
    return false;
  }

  List<ChessMove> _generateLegalMoves(ChessSide side) {
    final candidates = <ChessMove>[];
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == null || piece.side != side) continue;
        candidates.addAll(_generatePseudoMoves(row, col, piece));
      }
    }
    return candidates.where((move) {
      final applied = _applyForAnalysis(move);
      return !applied.isKingInCheck(side);
    }).toList();
  }

  ChessGameState _applyForAnalysis(ChessMove move) {
    return applyMove(move, evaluateResult: false).copyWith(
      moveHistory: moveHistory,
      message: message,
      resultRecorded: resultRecorded,
    );
  }

  List<ChessMove> _generatePseudoMoves(int row, int col, ChessPiece piece) {
    return switch (piece.type) {
      ChessPieceType.pawn => _pawnMoves(row, col, piece.side),
      ChessPieceType.knight => _knightMoves(row, col, piece.side),
      ChessPieceType.bishop => _slidingMoves(row, col, piece.side, const [
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
      ]),
      ChessPieceType.rook => _slidingMoves(row, col, piece.side, const [
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ]),
      ChessPieceType.queen => _slidingMoves(row, col, piece.side, const [
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ]),
      ChessPieceType.king => _kingMoves(row, col, piece.side),
    };
  }

  List<ChessMove> _pawnMoves(int row, int col, ChessSide side) {
    final direction = side == ChessSide.white ? -1 : 1;
    final startRow = side == ChessSide.white ? 6 : 1;
    final promotionRow = side == ChessSide.white ? 0 : 7;
    final moves = <ChessMove>[];
    final nextRow = row + direction;
    if (_inBounds(nextRow, col) && board[nextRow][col] == null) {
      if (nextRow == promotionRow) {
        for (final promo in [
          ChessPieceType.queen,
          ChessPieceType.rook,
          ChessPieceType.bishop,
          ChessPieceType.knight,
        ]) {
          moves.add(
            ChessMove(
              fromRow: row,
              fromCol: col,
              toRow: nextRow,
              toCol: col,
              promotion: promo,
            ),
          );
        }
      } else {
        moves.add(
          ChessMove(fromRow: row, fromCol: col, toRow: nextRow, toCol: col),
        );
      }
      final jumpRow = row + (direction * 2);
      if (row == startRow && board[jumpRow][col] == null) {
        moves.add(
          ChessMove(fromRow: row, fromCol: col, toRow: jumpRow, toCol: col),
        );
      }
    }
    for (final dc in const [-1, 1]) {
      final captureCol = col + dc;
      if (!_inBounds(nextRow, captureCol)) continue;
      final target = board[nextRow][captureCol];
      if (target != null && target.side != side) {
        if (nextRow == promotionRow) {
          for (final promo in [
            ChessPieceType.queen,
            ChessPieceType.rook,
            ChessPieceType.bishop,
            ChessPieceType.knight,
          ]) {
            moves.add(
              ChessMove(
                fromRow: row,
                fromCol: col,
                toRow: nextRow,
                toCol: captureCol,
                promotion: promo,
              ),
            );
          }
        } else {
          moves.add(
            ChessMove(
              fromRow: row,
              fromCol: col,
              toRow: nextRow,
              toCol: captureCol,
            ),
          );
        }
      }
      if (enPassantTarget == (nextRow, captureCol)) {
        moves.add(
          ChessMove(
            fromRow: row,
            fromCol: col,
            toRow: nextRow,
            toCol: captureCol,
            isEnPassant: true,
          ),
        );
      }
    }
    return moves;
  }

  List<ChessMove> _knightMoves(int row, int col, ChessSide side) {
    final moves = <ChessMove>[];
    for (final delta in const [
      (2, 1),
      (2, -1),
      (-2, 1),
      (-2, -1),
      (1, 2),
      (1, -2),
      (-1, 2),
      (-1, -2),
    ]) {
      final nr = row + delta.$1;
      final nc = col + delta.$2;
      if (!_inBounds(nr, nc)) continue;
      final target = board[nr][nc];
      if (target == null || target.side != side) {
        moves.add(ChessMove(fromRow: row, fromCol: col, toRow: nr, toCol: nc));
      }
    }
    return moves;
  }

  List<ChessMove> _slidingMoves(
    int row,
    int col,
    ChessSide side,
    List<(int, int)> deltas,
  ) {
    final moves = <ChessMove>[];
    for (final delta in deltas) {
      int nr = row + delta.$1;
      int nc = col + delta.$2;
      while (_inBounds(nr, nc)) {
        final target = board[nr][nc];
        if (target == null) {
          moves.add(
            ChessMove(fromRow: row, fromCol: col, toRow: nr, toCol: nc),
          );
        } else {
          if (target.side != side) {
            moves.add(
              ChessMove(fromRow: row, fromCol: col, toRow: nr, toCol: nc),
            );
          }
          break;
        }
        nr += delta.$1;
        nc += delta.$2;
      }
    }
    return moves;
  }

  List<ChessMove> _kingMoves(int row, int col, ChessSide side) {
    final moves = <ChessMove>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (!_inBounds(nr, nc)) continue;
        final target = board[nr][nc];
        if (target == null || target.side != side) {
          moves.add(
            ChessMove(fromRow: row, fromCol: col, toRow: nr, toCol: nc),
          );
        }
      }
    }
    final homeRow = side == ChessSide.white ? 7 : 0;
    final kingMoved = side == ChessSide.white ? whiteKingMoved : blackKingMoved;
    if (!kingMoved &&
        row == homeRow &&
        col == 4 &&
        !_isSquareAttacked(homeRow, 4, _opponent(side))) {
      final rightRookMoved = side == ChessSide.white
          ? whiteRightRookMoved
          : blackRightRookMoved;
      if (!rightRookMoved &&
          board[homeRow][5] == null &&
          board[homeRow][6] == null &&
          !_isSquareAttacked(homeRow, 5, _opponent(side)) &&
          !_isSquareAttacked(homeRow, 6, _opponent(side)) &&
          board[homeRow][7]?.type == ChessPieceType.rook &&
          board[homeRow][7]?.side == side) {
        moves.add(
          ChessMove(
            fromRow: row,
            fromCol: col,
            toRow: homeRow,
            toCol: 6,
            isCastleKingSide: true,
          ),
        );
      }
      final leftRookMoved = side == ChessSide.white
          ? whiteLeftRookMoved
          : blackLeftRookMoved;
      if (!leftRookMoved &&
          board[homeRow][1] == null &&
          board[homeRow][2] == null &&
          board[homeRow][3] == null &&
          !_isSquareAttacked(homeRow, 3, _opponent(side)) &&
          !_isSquareAttacked(homeRow, 2, _opponent(side)) &&
          board[homeRow][0]?.type == ChessPieceType.rook &&
          board[homeRow][0]?.side == side) {
        moves.add(
          ChessMove(
            fromRow: row,
            fromCol: col,
            toRow: homeRow,
            toCol: 2,
            isCastleQueenSide: true,
          ),
        );
      }
    }
    return moves;
  }

  bool _isSquareAttacked(int row, int col, ChessSide bySide) {
    final pawnDir = bySide == ChessSide.white ? -1 : 1;
    for (final dc in const [-1, 1]) {
      final r = row - pawnDir;
      final c = col + dc;
      if (_inBounds(r, c)) {
        final piece = board[r][c];
        if (piece?.side == bySide && piece?.type == ChessPieceType.pawn)
          return true;
      }
    }
    for (final delta in const [
      (2, 1),
      (2, -1),
      (-2, 1),
      (-2, -1),
      (1, 2),
      (1, -2),
      (-1, 2),
      (-1, -2),
    ]) {
      final r = row + delta.$1;
      final c = col + delta.$2;
      if (_inBounds(r, c)) {
        final piece = board[r][c];
        if (piece?.side == bySide && piece?.type == ChessPieceType.knight)
          return true;
      }
    }
    for (final delta in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      if (_rayAttacked(row, col, bySide, delta, const [
        ChessPieceType.rook,
        ChessPieceType.queen,
      ]))
        return true;
    }
    for (final delta in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
      if (_rayAttacked(row, col, bySide, delta, const [
        ChessPieceType.bishop,
        ChessPieceType.queen,
      ]))
        return true;
    }
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (_inBounds(r, c)) {
          final piece = board[r][c];
          if (piece?.side == bySide && piece?.type == ChessPieceType.king)
            return true;
        }
      }
    }
    return false;
  }

  bool _rayAttacked(
    int row,
    int col,
    ChessSide bySide,
    (int, int) delta,
    List<ChessPieceType> attackers,
  ) {
    int r = row + delta.$1;
    int c = col + delta.$2;
    while (_inBounds(r, c)) {
      final piece = board[r][c];
      if (piece == null) {
        r += delta.$1;
        c += delta.$2;
        continue;
      }
      return piece.side == bySide && attackers.contains(piece.type);
    }
    return false;
  }

  bool _inBounds(int row, int col) =>
      row >= 0 && row < 8 && col >= 0 && col < 8;

  String get fen {
    final rows = <String>[];
    for (final row in board) {
      int empty = 0;
      final buffer = StringBuffer();
      for (final piece in row) {
        if (piece == null) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty);
            empty = 0;
          }
          final char = switch (piece.type) {
            ChessPieceType.king => 'k',
            ChessPieceType.queen => 'q',
            ChessPieceType.rook => 'r',
            ChessPieceType.bishop => 'b',
            ChessPieceType.knight => 'n',
            ChessPieceType.pawn => 'p',
          };
          buffer.write(
            piece.side == ChessSide.white ? char.toUpperCase() : char,
          );
        }
      }
      if (empty > 0) buffer.write(empty);
      rows.add(buffer.toString());
    }
    final castling = StringBuffer();
    if (!whiteKingMoved &&
        !whiteRightRookMoved &&
        board[7][4]?.type == ChessPieceType.king &&
        board[7][7]?.type == ChessPieceType.rook)
      castling.write('K');
    if (!whiteKingMoved &&
        !whiteLeftRookMoved &&
        board[7][4]?.type == ChessPieceType.king &&
        board[7][0]?.type == ChessPieceType.rook)
      castling.write('Q');
    if (!blackKingMoved &&
        !blackRightRookMoved &&
        board[0][4]?.type == ChessPieceType.king &&
        board[0][7]?.type == ChessPieceType.rook)
      castling.write('k');
    if (!blackKingMoved &&
        !blackLeftRookMoved &&
        board[0][4]?.type == ChessPieceType.king &&
        board[0][0]?.type == ChessPieceType.rook)
      castling.write('q');
    return '${rows.join('/')}'
        ' ${turn == ChessSide.white ? 'w' : 'b'} '
        '${castling.isEmpty ? '-' : castling} '
        '${enPassantTarget == null ? '-' : _squareName(enPassantTarget!.$1, enPassantTarget!.$2)} '
        '$halfmoveClock $fullmoveNumber';
  }
}

List<List<ChessPiece?>> _initialBoard() {
  ChessPiece? w(ChessPieceType type) => ChessPiece(ChessSide.white, type);
  ChessPiece? b(ChessPieceType type) => ChessPiece(ChessSide.black, type);
  return [
    [
      b(ChessPieceType.rook),
      b(ChessPieceType.knight),
      b(ChessPieceType.bishop),
      b(ChessPieceType.queen),
      b(ChessPieceType.king),
      b(ChessPieceType.bishop),
      b(ChessPieceType.knight),
      b(ChessPieceType.rook),
    ],
    List<ChessPiece?>.filled(8, b(ChessPieceType.pawn)),
    List<ChessPiece?>.filled(8, null),
    List<ChessPiece?>.filled(8, null),
    List<ChessPiece?>.filled(8, null),
    List<ChessPiece?>.filled(8, null),
    List<ChessPiece?>.filled(8, w(ChessPieceType.pawn)),
    [
      w(ChessPieceType.rook),
      w(ChessPieceType.knight),
      w(ChessPieceType.bishop),
      w(ChessPieceType.queen),
      w(ChessPieceType.king),
      w(ChessPieceType.bishop),
      w(ChessPieceType.knight),
      w(ChessPieceType.rook),
    ],
  ];
}

ChessSide _opponent(ChessSide side) =>
    side == ChessSide.white ? ChessSide.black : ChessSide.white;
String _squareName(int row, int col) =>
    '${String.fromCharCode(97 + col)}${8 - row}';

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
