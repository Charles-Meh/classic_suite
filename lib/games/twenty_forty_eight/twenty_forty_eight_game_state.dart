import 'dart:convert';
import 'dart:math';

enum MoveDirection { up, down, left, right }

enum TwentyFortyEightStatus { ready, playing, won, lost }

class TwentyFortyEightTile {
  const TwentyFortyEightTile({
    required this.id,
    required this.value,
    required this.row,
    required this.column,
    this.previousRow,
    this.previousColumn,
    this.isNew = false,
    this.isMerged = false,
  });

  final int id;
  final int value;
  final int row;
  final int column;
  final int? previousRow;
  final int? previousColumn;
  final bool isNew;
  final bool isMerged;

  TwentyFortyEightTile copyWith({
    int? id,
    int? value,
    int? row,
    int? column,
    int? previousRow,
    int? previousColumn,
    bool clearPreviousPosition = false,
    bool? isNew,
    bool? isMerged,
  }) {
    return TwentyFortyEightTile(
      id: id ?? this.id,
      value: value ?? this.value,
      row: row ?? this.row,
      column: column ?? this.column,
      previousRow: clearPreviousPosition
          ? null
          : previousRow ?? this.previousRow,
      previousColumn: clearPreviousPosition
          ? null
          : previousColumn ?? this.previousColumn,
      isNew: isNew ?? this.isNew,
      isMerged: isMerged ?? this.isMerged,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'value': value,
    'row': row,
    'column': column,
    'previousRow': previousRow,
    'previousColumn': previousColumn,
    'isNew': isNew,
    'isMerged': isMerged,
  };

  factory TwentyFortyEightTile.fromJson(Map<String, dynamic> json) {
    return TwentyFortyEightTile(
      id: (json['id'] as num).toInt(),
      value: (json['value'] as num).toInt(),
      row: (json['row'] as num).toInt(),
      column: (json['column'] as num).toInt(),
      previousRow: (json['previousRow'] as num?)?.toInt(),
      previousColumn: (json['previousColumn'] as num?)?.toInt(),
      isNew: json['isNew'] as bool,
      isMerged: json['isMerged'] as bool,
    );
  }
}

class TwentyFortyEightSnapshot {
  const TwentyFortyEightSnapshot({
    required this.tiles,
    required this.score,
    required this.moveCount,
    required this.hasWon,
    required this.keepGoing,
    required this.status,
    required this.nextTileId,
    required this.startedAt,
    required this.elapsedSeconds,
  });

  final List<TwentyFortyEightTile> tiles;
  final int score;
  final int moveCount;
  final bool hasWon;
  final bool keepGoing;
  final TwentyFortyEightStatus status;
  final int nextTileId;
  final DateTime? startedAt;
  final int elapsedSeconds;

  Map<String, Object?> toJson() => {
    'tiles': tiles.map((tile) => tile.toJson()).toList(),
    'score': score,
    'moveCount': moveCount,
    'hasWon': hasWon,
    'keepGoing': keepGoing,
    'status': status.name,
    'nextTileId': nextTileId,
    'startedAt': startedAt?.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
  };

  factory TwentyFortyEightSnapshot.fromJson(Map<String, dynamic> json) {
    return TwentyFortyEightSnapshot(
      tiles: (json['tiles'] as List<dynamic>)
          .map(
            (tile) =>
                TwentyFortyEightTile.fromJson(tile as Map<String, dynamic>),
          )
          .toList(),
      score: (json['score'] as num).toInt(),
      moveCount: (json['moveCount'] as num).toInt(),
      hasWon: json['hasWon'] as bool,
      keepGoing: json['keepGoing'] as bool,
      status: TwentyFortyEightStatus.values.byName(json['status'] as String),
      nextTileId: (json['nextTileId'] as num).toInt(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
    );
  }
}

class TwentyFortyEightMoveResult {
  const TwentyFortyEightMoveResult({
    required this.state,
    required this.changed,
    this.spawnedTile,
    this.gainedScore = 0,
  });

  final TwentyFortyEightGameState state;
  final bool changed;
  final TwentyFortyEightTile? spawnedTile;
  final int gainedScore;
}

class TwentyFortyEightGameState {
  TwentyFortyEightGameState._({
    required this.tiles,
    required this.score,
    required this.moveCount,
    required this.hasWon,
    required this.keepGoing,
    required this.status,
    required this.undoStack,
    required this.nextTileId,
    required this.startedAt,
    required this.elapsedSeconds,
  });

  static const String storageKey = 'classic_suite.2048.saved_state';
  static const int boardSize = 4;

  final List<TwentyFortyEightTile> tiles;
  final int score;
  final int moveCount;
  final bool hasWon;
  final bool keepGoing;
  final TwentyFortyEightStatus status;
  final List<TwentyFortyEightSnapshot> undoStack;
  final int nextTileId;
  final DateTime? startedAt;
  final int elapsedSeconds;

  factory TwentyFortyEightGameState.newGame({int? seed}) {
    final random = seed == null ? Random() : Random(seed);
    var nextId = 1;
    final first = _spawnOnBoard(const [], nextId: nextId, random: random);
    nextId = first.nextTileId;
    final second = _spawnOnBoard(first.tiles, nextId: nextId, random: random);
    return TwentyFortyEightGameState._(
      tiles: second.tiles,
      score: 0,
      moveCount: 0,
      hasWon: false,
      keepGoing: false,
      status: TwentyFortyEightStatus.ready,
      undoStack: const [],
      nextTileId: second.nextTileId,
      startedAt: null,
      elapsedSeconds: 0,
    );
  }

  factory TwentyFortyEightGameState.debug({
    required List<TwentyFortyEightTile> tiles,
    int score = 0,
    int moveCount = 0,
    bool hasWon = false,
    bool keepGoing = false,
    TwentyFortyEightStatus status = TwentyFortyEightStatus.playing,
    List<TwentyFortyEightSnapshot> undoStack = const [],
    int? nextTileId,
    DateTime? startedAt,
    int elapsedSeconds = 0,
  }) {
    return TwentyFortyEightGameState._(
      tiles: tiles.map((tile) => tile.copyWith()).toList(),
      score: score,
      moveCount: moveCount,
      hasWon: hasWon,
      keepGoing: keepGoing,
      status: status,
      undoStack: List<TwentyFortyEightSnapshot>.from(undoStack),
      nextTileId:
          nextTileId ??
          (tiles.fold<int>(
                0,
                (maxId, tile) => tile.id > maxId ? tile.id : maxId,
              ) +
              1),
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds,
    );
  }

  factory TwentyFortyEightGameState.fromJson(Map<String, dynamic> json) {
    return TwentyFortyEightGameState._(
      tiles: (json['tiles'] as List<dynamic>)
          .map(
            (tile) =>
                TwentyFortyEightTile.fromJson(tile as Map<String, dynamic>),
          )
          .toList(),
      score: (json['score'] as num).toInt(),
      moveCount: (json['moveCount'] as num).toInt(),
      hasWon: json['hasWon'] as bool,
      keepGoing: json['keepGoing'] as bool,
      status: TwentyFortyEightStatus.values.byName(json['status'] as String),
      undoStack: (json['undoStack'] as List<dynamic>)
          .map(
            (entry) => TwentyFortyEightSnapshot.fromJson(
              entry as Map<String, dynamic>,
            ),
          )
          .toList(),
      nextTileId: (json['nextTileId'] as num).toInt(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
    );
  }

  static TwentyFortyEightGameState? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return TwentyFortyEightGameState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'tiles': tiles.map((tile) => tile.toJson()).toList(),
    'score': score,
    'moveCount': moveCount,
    'hasWon': hasWon,
    'keepGoing': keepGoing,
    'status': status.name,
    'undoStack': undoStack.map((snapshot) => snapshot.toJson()).toList(),
    'nextTileId': nextTileId,
    'startedAt': startedAt?.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
  };

  String encode() => jsonEncode(toJson());

  bool get canUndo => undoStack.isNotEmpty;
  bool get isLost => status == TwentyFortyEightStatus.lost;
  bool get isWon => hasWon && !keepGoing;
  bool get isActive => status == TwentyFortyEightStatus.playing;
  bool get isGameOver => isLost || isWon;
  int get highestTile => tiles.fold<int>(
    0,
    (maxValue, tile) => tile.value > maxValue ? tile.value : maxValue,
  );
  bool get canMove => !_hasNoMoves(tiles);

  TwentyFortyEightTile? tileAt(int row, int column) {
    for (final tile in tiles) {
      if (tile.row == row && tile.column == column) {
        return tile;
      }
    }
    return null;
  }

  List<List<int>> get valueGrid {
    final grid = List<List<int>>.generate(
      boardSize,
      (_) => List<int>.filled(boardSize, 0),
    );
    for (final tile in tiles) {
      grid[tile.row][tile.column] = tile.value;
    }
    return grid;
  }

  TwentyFortyEightSnapshot _snapshot() {
    return TwentyFortyEightSnapshot(
      tiles: tiles
          .map(
            (tile) => tile.copyWith(
              clearPreviousPosition: true,
              isNew: false,
              isMerged: false,
            ),
          )
          .toList(),
      score: score,
      moveCount: moveCount,
      hasWon: hasWon,
      keepGoing: keepGoing,
      status: status,
      nextTileId: nextTileId,
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds,
    );
  }

  TwentyFortyEightGameState undo() {
    if (!canUndo) {
      return this;
    }
    final snapshot = undoStack.last;
    return TwentyFortyEightGameState._(
      tiles: snapshot.tiles,
      score: snapshot.score,
      moveCount: snapshot.moveCount,
      hasWon: snapshot.hasWon,
      keepGoing: snapshot.keepGoing,
      status: snapshot.status,
      undoStack: undoStack.sublist(0, undoStack.length - 1),
      nextTileId: snapshot.nextTileId,
      startedAt: snapshot.startedAt,
      elapsedSeconds: snapshot.elapsedSeconds,
    );
  }

  TwentyFortyEightGameState copyWith({
    List<TwentyFortyEightTile>? tiles,
    int? score,
    int? moveCount,
    bool? hasWon,
    bool? keepGoing,
    TwentyFortyEightStatus? status,
    List<TwentyFortyEightSnapshot>? undoStack,
    int? nextTileId,
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? elapsedSeconds,
  }) {
    return TwentyFortyEightGameState._(
      tiles: tiles ?? this.tiles,
      score: score ?? this.score,
      moveCount: moveCount ?? this.moveCount,
      hasWon: hasWon ?? this.hasWon,
      keepGoing: keepGoing ?? this.keepGoing,
      status: status ?? this.status,
      undoStack: undoStack ?? this.undoStack,
      nextTileId: nextTileId ?? this.nextTileId,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  TwentyFortyEightGameState clearTransientFlags() {
    return copyWith(
      tiles: [
        for (final tile in tiles)
          tile.copyWith(
            clearPreviousPosition: true,
            isNew: false,
            isMerged: false,
          ),
      ],
    );
  }

  TwentyFortyEightGameState incrementElapsed() {
    if (!isActive) {
      return this;
    }
    return copyWith(elapsedSeconds: elapsedSeconds + 1);
  }

  TwentyFortyEightGameState continuePast2048() {
    if (!hasWon) {
      return this;
    }
    return copyWith(
      keepGoing: true,
      status: canMove
          ? TwentyFortyEightStatus.playing
          : TwentyFortyEightStatus.lost,
    );
  }

  TwentyFortyEightMoveResult move(MoveDirection direction, {int? seed}) {
    if (isLost || (hasWon && !keepGoing)) {
      return TwentyFortyEightMoveResult(state: this, changed: false);
    }

    final preparedTiles = [
      for (final tile in tiles)
        tile.copyWith(
          clearPreviousPosition: true,
          isNew: false,
          isMerged: false,
        ),
    ];

    final mergedTiles = <TwentyFortyEightTile>[];
    var nextScore = score;
    var changed = false;

    final traversals = _traversalIndices(direction);

    if (direction == MoveDirection.left || direction == MoveDirection.right) {
      for (final row in traversals.primary) {
        final line = <TwentyFortyEightTile>[];
        for (final column in traversals.secondary) {
          final tile = _tileAt(preparedTiles, row, column);
          if (tile != null) {
            line.add(tile);
          }
        }
        final result = _mergeLine(
          line,
          isRow: true,
          fixedIndex: row,
          direction: direction,
        );
        mergedTiles.addAll(result.tiles);
        nextScore += result.gainedScore;
        changed = changed || result.changed;
      }
    } else {
      for (final column in traversals.primary) {
        final line = <TwentyFortyEightTile>[];
        for (final row in traversals.secondary) {
          final tile = _tileAt(preparedTiles, row, column);
          if (tile != null) {
            line.add(tile);
          }
        }
        final result = _mergeLine(
          line,
          isRow: false,
          fixedIndex: column,
          direction: direction,
        );
        mergedTiles.addAll(result.tiles);
        nextScore += result.gainedScore;
        changed = changed || result.changed;
      }
    }

    if (!changed) {
      return TwentyFortyEightMoveResult(state: this, changed: false);
    }

    final random = seed == null ? Random() : Random(seed);
    final spawned = _spawnOnBoard(
      mergedTiles,
      nextId: nextTileId,
      random: random,
    );
    final highestTile = spawned.tiles.fold<int>(
      0,
      (maxValue, tile) => tile.value > maxValue ? tile.value : maxValue,
    );
    final wonNow = hasWon || highestTile >= 2048;
    final lostNow = _hasNoMoves(spawned.tiles);
    final nextStatus = lostNow
        ? TwentyFortyEightStatus.lost
        : wonNow && !keepGoing
        ? TwentyFortyEightStatus.won
        : TwentyFortyEightStatus.playing;

    final nextState = TwentyFortyEightGameState._(
      tiles: spawned.tiles,
      score: nextScore,
      moveCount: moveCount + 1,
      hasWon: wonNow,
      keepGoing: keepGoing,
      status: nextStatus,
      undoStack: [...undoStack, _snapshot()],
      nextTileId: spawned.nextTileId,
      startedAt: startedAt ?? DateTime.now(),
      elapsedSeconds: elapsedSeconds,
    );

    return TwentyFortyEightMoveResult(
      state: nextState,
      changed: true,
      spawnedTile: spawned.spawnedTile,
      gainedScore: nextScore - score,
    );
  }

  static _LineMergeResult _mergeLine(
    List<TwentyFortyEightTile> line, {
    required bool isRow,
    required int fixedIndex,
    required MoveDirection direction,
  }) {
    final ordered = [...line]
      ..sort(
        (a, b) =>
            direction == MoveDirection.right || direction == MoveDirection.down
            ? (isRow ? b.column.compareTo(a.column) : b.row.compareTo(a.row))
            : (isRow ? a.column.compareTo(b.column) : a.row.compareTo(b.row)),
      );

    final merged = <TwentyFortyEightTile>[];
    var writeIndex = 0;
    var changed = false;
    var gainedScore = 0;
    var index = 0;

    while (index < ordered.length) {
      final current = ordered[index];
      final next = index + 1 < ordered.length ? ordered[index + 1] : null;
      final target =
          direction == MoveDirection.right || direction == MoveDirection.down
          ? boardSize - 1 - writeIndex
          : writeIndex;

      if (next != null && next.value == current.value) {
        final newValue = current.value * 2;
        gainedScore += newValue;
        final row = isRow ? fixedIndex : target;
        final column = isRow ? target : fixedIndex;
        merged.add(
          TwentyFortyEightTile(
            id: current.id,
            value: newValue,
            row: row,
            column: column,
            previousRow: current.row,
            previousColumn: current.column,
            isMerged: true,
          ),
        );
        changed =
            changed ||
            current.row != row ||
            current.column != column ||
            next.row != row ||
            next.column != column ||
            current.value != newValue;
        index += 2;
      } else {
        final row = isRow ? fixedIndex : target;
        final column = isRow ? target : fixedIndex;
        merged.add(
          current.copyWith(
            row: row,
            column: column,
            previousRow: current.row,
            previousColumn: current.column,
          ),
        );
        changed = changed || current.row != row || current.column != column;
        index += 1;
      }
      writeIndex += 1;
    }

    return _LineMergeResult(
      tiles: merged,
      gainedScore: gainedScore,
      changed: changed,
    );
  }

  static ({List<int> primary, List<int> secondary}) _traversalIndices(
    MoveDirection direction,
  ) {
    final forward = [0, 1, 2, 3];
    final reverse = [3, 2, 1, 0];
    return switch (direction) {
      MoveDirection.left => (primary: forward, secondary: forward),
      MoveDirection.right => (primary: forward, secondary: reverse),
      MoveDirection.up => (primary: forward, secondary: forward),
      MoveDirection.down => (primary: forward, secondary: reverse),
    };
  }

  static TwentyFortyEightTile? _tileAt(
    List<TwentyFortyEightTile> tiles,
    int row,
    int column,
  ) {
    for (final tile in tiles) {
      if (tile.row == row && tile.column == column) {
        return tile;
      }
    }
    return null;
  }

  static bool _hasNoMoves(List<TwentyFortyEightTile> tiles) {
    if (tiles.length < boardSize * boardSize) {
      return false;
    }
    final grid = List<List<int>>.generate(
      boardSize,
      (_) => List<int>.filled(boardSize, 0),
    );
    for (final tile in tiles) {
      grid[tile.row][tile.column] = tile.value;
    }
    for (int row = 0; row < boardSize; row++) {
      for (int column = 0; column < boardSize; column++) {
        final value = grid[row][column];
        if (row + 1 < boardSize && grid[row + 1][column] == value) {
          return false;
        }
        if (column + 1 < boardSize && grid[row][column + 1] == value) {
          return false;
        }
      }
    }
    return true;
  }

  static ({
    List<TwentyFortyEightTile> tiles,
    TwentyFortyEightTile spawnedTile,
    int nextTileId,
  })
  _spawnOnBoard(
    List<TwentyFortyEightTile> tiles, {
    required int nextId,
    required Random random,
  }) {
    final occupied = tiles.map((tile) => (tile.row, tile.column)).toSet();
    final open = <(int, int)>[];
    for (int row = 0; row < boardSize; row++) {
      for (int column = 0; column < boardSize; column++) {
        if (!occupied.contains((row, column))) {
          open.add((row, column));
        }
      }
    }
    final spot = open[random.nextInt(open.length)];
    final spawnedTile = TwentyFortyEightTile(
      id: nextId,
      value: random.nextInt(10) == 0 ? 4 : 2,
      row: spot.$1,
      column: spot.$2,
      isNew: true,
    );
    return (
      tiles: [...tiles, spawnedTile],
      spawnedTile: spawnedTile,
      nextTileId: nextId + 1,
    );
  }
}

class _LineMergeResult {
  const _LineMergeResult({
    required this.tiles,
    required this.gainedScore,
    required this.changed,
  });

  final List<TwentyFortyEightTile> tiles;
  final int gainedScore;
  final bool changed;
}
