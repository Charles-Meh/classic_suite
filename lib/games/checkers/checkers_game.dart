import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/duration_format.dart';
import 'checkers_ai.dart';
import 'checkers_game_state.dart';
import 'checkers_stats.dart';
import 'checkers_stats_store.dart';

class CheckersGame extends StatefulWidget {
  const CheckersGame({super.key, this.initialState});

  final CheckersGameState? initialState;

  @override
  State<CheckersGame> createState() => _CheckersGameState();
}

class _CheckersGameState extends State<CheckersGame> {
  late CheckersGameState state;
  final CheckersAi _ai = const CheckersAi();
  final CheckersStatsStore _statsStore = CheckersStatsStore();
  final List<CheckersGameState> _undoStack = [];
  CheckersStats _stats = const CheckersStats();
  Timer? _ticker;
  Timer? _aiTimer;
  bool _loading = true;
  bool _hasRecordedStart = false;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? CheckersGameState.newGame();
    _hasRecordedStart = widget.initialState != null;
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _aiTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = widget.initialState == null
        ? CheckersGameState.tryDecode(
            prefs.getString(CheckersGameState.storageKey),
          )
        : null;
    final stats = await _statsStore.load();
    if (!mounted) return;
    setState(() {
      if (loaded != null) {
        state = loaded;
        _hasRecordedStart = true;
      }
      _stats = stats;
      _loading = false;
    });
    if (!_hasRecordedStart) {
      await _recordStartedGame();
    }
    _syncTimers();
    _maybeRunAi();
  }

  Future<void> _recordStartedGame() async {
    if (_hasRecordedStart) return;
    _hasRecordedStart = true;
    final next = _stats.recordGameStarted();
    setState(() => _stats = next);
    await _statsStore.save(next);
  }

  Future<void> _recordResultIfNeeded() async {
    if (state.resultRecorded || !state.isFinished) return;
    var next = _stats;
    if (state.status == CheckersGameStatus.redWon) {
      next = _stats.recordWin(
        bucket: state.mode == CheckersGameMode.vsAi
            ? state.difficulty.id
            : 'local',
        seconds: state.elapsedSeconds,
      );
    } else if (state.status == CheckersGameStatus.blackWon) {
      next = _stats.recordLoss();
    } else {
      next = _stats.recordDraw();
    }
    setState(() {
      _stats = next;
      state = state.markResultRecorded();
    });
    await _statsStore.save(next);
    await _persistState();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CheckersGameState.storageKey, state.encode());
  }

  void _syncTimers() {
    _ticker?.cancel();
    if (_loading || state.isPaused || state.isFinished) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => state = state.incrementElapsed());
      await _persistState();
    });
  }

  void _maybeRunAi() {
    _aiTimer?.cancel();
    if (!mounted || _loading || state.isPaused || state.isFinished) return;
    if (state.mode != CheckersGameMode.vsAi ||
        state.turn != CheckersSide.black) {
      return;
    }
    _aiTimer = Timer(const Duration(milliseconds: 220), () async {
      final move = _ai.bestMove(state);
      if (move == null || !mounted) return;
      await _applyMove(move, fromAi: true, allowUndoSnapshot: false);
    });
  }

  Future<void> _applyState(CheckersGameState next) async {
    setState(() => state = next);
    _syncTimers();
    await _persistState();
    await _recordResultIfNeeded();
    _maybeRunAi();
  }

  Future<void> _applyMove(
    CheckersMove move, {
    required bool fromAi,
    bool allowUndoSnapshot = true,
  }) async {
    if (allowUndoSnapshot) {
      _undoStack.add(state);
    }
    await _applyState(state.applyMove(move, fromAi: fromAi));
  }

  Future<void> _handleSquareTap(int row, int col) async {
    if (!state.isHumanTurn) return;
    if ((row + col).isEven) return;
    final selected = state.selectedSquare;
    final piece = state.pieceAt(row, col);

    if (selected != null) {
      final moves = state.legalMovesForSquare(selected.$1, selected.$2);
      final chosen = moves
          .where((move) => move.toRow == row && move.toCol == col)
          .toList();
      if (chosen.isNotEmpty) {
        await _applyMove(chosen.first, fromAi: false);
        return;
      }
    }

    if (piece != null && piece.side == state.turn) {
      await _applyState(state.selectSquare(row, col));
      return;
    }

    await _applyState(state.copyWith(clearSelectedSquare: true));
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || state.isPaused) return;
    var previous = _undoStack.removeLast();
    if (state.mode == CheckersGameMode.vsAi &&
        previous.turn == CheckersSide.black &&
        _undoStack.isNotEmpty) {
      previous = _undoStack.removeLast();
    }
    await _applyState(previous.copyWith(message: 'Move undone.'));
  }

  Future<void> _newGame() async {
    _undoStack.clear();
    _hasRecordedStart = false;
    final next = CheckersGameState.newGame(
      mode: state.mode,
      difficulty: state.difficulty,
    );
    await _applyState(next);
    await _recordStartedGame();
  }

  Future<void> _setDifficulty(CheckersDifficulty difficulty) async {
    _undoStack.clear();
    _hasRecordedStart = false;
    await _applyState(
      CheckersGameState.newGame(mode: state.mode, difficulty: difficulty),
    );
    await _recordStartedGame();
  }

  Future<void> _setMode(CheckersGameMode mode) async {
    _undoStack.clear();
    _hasRecordedStart = false;
    await _applyState(
      CheckersGameState.newGame(mode: mode, difficulty: state.difficulty),
    );
    await _recordStartedGame();
  }

  Future<void> _togglePause() async => _applyState(state.togglePause());

  Future<void> _showStats() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkers statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: 'Games', value: '${_stats.gamesStarted}'),
            _StatRow(label: 'Wins', value: '${_stats.wins}'),
            _StatRow(label: 'Losses', value: '${_stats.losses}'),
            _StatRow(label: 'Draws', value: '${_stats.draws}'),
            _StatRow(
              label: 'Win rate',
              value: '${(_stats.winRate * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 12),
            _StatRow(
              label: 'Best Easy',
              value: _formatBest(_stats.bestEasySeconds),
            ),
            _StatRow(
              label: 'Best Medium',
              value: _formatBest(_stats.bestMediumSeconds),
            ),
            _StatRow(
              label: 'Best Hard',
              value: _formatBest(_stats.bestHardSeconds),
            ),
            _StatRow(
              label: 'Best Local',
              value: _formatBest(_stats.bestLocalSeconds),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatBest(int? seconds) =>
      seconds == null ? '—' : formatElapsedSeconds(seconds);

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to play'),
        content: const SingleChildScrollView(
          child: Text(
            '• Red moves first. Regular pieces move one square diagonally forward.\n\n'
            '• Captures are mandatory. If a jump is available, you must take it. Multi-jumps are generated automatically and played as one move.\n\n'
            '• Kings can move and capture backward. Reaching the back rank crowns a piece.\n\n'
            '• Easy/Medium/Hard adjust the AI minimax depth: 2 / 4 / 6 plies.\n\n'
            '• Undo rolls back one full turn versus the AI, or one move in pass-and-play.\n\n'
            '• The game auto-saves, so pausing and resuming works naturally if you leave and come back.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.mode == CheckersGameMode.vsAi
                        ? 'Checkers • ${state.difficulty.label} AI'
                        : 'Checkers • Pass & play',
                    key: const Key('checkers_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('checkers_undo'),
                  tooltip: 'Undo',
                  onPressed: _undoStack.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: const Key('checkers_pause'),
                  tooltip: state.isPaused ? 'Resume' : 'Pause',
                  onPressed: _togglePause,
                  icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Game menu',
                  onSelected: (value) async {
                    switch (value) {
                      case 'new':
                        await _newGame();
                      case 'stats':
                        await _showStats();
                      case 'help':
                        await _showHelp();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'new', child: Text('New game')),
                    PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    PopupMenuItem(value: 'help', child: Text('Rules / help')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('checkers_mode_ai'),
                  label: const Text('Vs AI'),
                  selected: state.mode == CheckersGameMode.vsAi,
                  onSelected: (_) => _setMode(CheckersGameMode.vsAi),
                ),
                ChoiceChip(
                  key: const Key('checkers_mode_local'),
                  label: const Text('Pass & play'),
                  selected: state.mode == CheckersGameMode.passAndPlay,
                  onSelected: (_) => _setMode(CheckersGameMode.passAndPlay),
                ),
                for (final difficulty in CheckersDifficulty.values)
                  ChoiceChip(
                    key: Key('checkers_difficulty_${difficulty.name}'),
                    label: Text(difficulty.label),
                    selected: state.difficulty == difficulty,
                    onSelected: state.mode == CheckersGameMode.vsAi
                        ? (_) => _setDifficulty(difficulty)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Badge(
                  label: 'Turn',
                  value: state.turn == CheckersSide.red ? 'RED' : 'BLACK',
                  color: scheme.primaryContainer,
                ),
                _Badge(
                  label: 'Clock',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  color: scheme.secondaryContainer,
                ),
                _Badge(
                  label: 'Status',
                  value: state.isFinished
                      ? 'Finished'
                      : (state.mandatoryCaptureExists
                            ? 'Capture required'
                            : 'In play'),
                  color: scheme.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(state.message, key: const Key('checkers_message')),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    final selected = state.selectedSquare;
    final legalTargets = selected == null
        ? <(int, int)>{}
        : state
              .legalMovesForSquare(selected.$1, selected.$2)
              .map((move) => (move.toRow, move.toCol))
              .toSet();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width - 56;
            final boardSize = math.min(width, 620.0);
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: Column(
                  children: [
                    for (int row = 0; row < 8; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (int col = 0; col < 8; col++)
                              Expanded(
                                child: _CheckersSquare(
                                  key: Key('checkers_square_${row}_$col'),
                                  piece: state.board[row][col],
                                  isDark: (row + col).isOdd,
                                  isSelected: selected == (row, col),
                                  isLegalTarget: legalTargets.contains((
                                    row,
                                    col,
                                  )),
                                  isLastMove:
                                      state.lastMove != null &&
                                      state.lastMove!.path.any(
                                        (square) => square == (row, col),
                                      ),
                                  onTap: () => _handleSquareTap(row, col),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (state.moveHistory.isEmpty)
              Text(
                'No moves yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  itemCount: (state.moveHistory.length / 2).ceil(),
                  itemBuilder: (context, index) {
                    final red = state.moveHistory[index * 2];
                    final black = index * 2 + 1 < state.moveHistory.length
                        ? state.moveHistory[index * 2 + 1]
                        : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 36, child: Text('${index + 1}.')),
                          Expanded(child: Text(red.notation)),
                          Expanded(child: Text(black?.notation ?? '')),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape = constraints.maxWidth > 900;
                  final board = _buildBoard(context);
                  final sidePanel = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopPanel(context),
                      const SizedBox(height: 16),
                      _buildHistory(context),
                    ],
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: landscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: board),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: sidePanel),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  board,
                                  const SizedBox(height: 16),
                                  sidePanel,
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CheckersSquare extends StatelessWidget {
  const _CheckersSquare({
    super.key,
    required this.piece,
    required this.isDark,
    required this.isSelected,
    required this.isLegalTarget,
    required this.isLastMove,
    required this.onTap,
  });

  final CheckersPiece? piece;
  final bool isDark;
  final bool isSelected;
  final bool isLegalTarget;
  final bool isLastMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background = isDark
        ? const Color(0xFF6B4F3A)
        : const Color(0xFFF1E4CF);
    if (Theme.of(context).brightness == Brightness.dark) {
      background = isDark ? const Color(0xFF4B3A2A) : const Color(0xFF90806D);
    }
    if (isLastMove) background = background.withValues(alpha: 0.82);
    if (isSelected) background = scheme.primaryContainer;

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (isLegalTarget)
              Center(
                child: Container(
                  width: piece == null ? 18 : 46,
                  height: piece == null ? 18 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: piece == null
                        ? scheme.primary.withValues(alpha: 0.38)
                        : scheme.primary.withValues(alpha: 0.20),
                    border: piece == null
                        ? null
                        : Border.all(color: scheme.primary, width: 2),
                  ),
                ),
              ),
            if (piece != null)
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: piece!.side == CheckersSide.red
                              ? const [Color(0xFFE15A4F), Color(0xFF9C241C)]
                              : const [Color(0xFF444A55), Color(0xFF12151C)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: piece!.isKing
                          ? Center(
                              child: Icon(
                                Icons.workspace_premium,
                                color: piece!.side == CheckersSide.red
                                    ? const Color(0xFFFFE39A)
                                    : const Color(0xFFD6B56B),
                                size: 28,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}
