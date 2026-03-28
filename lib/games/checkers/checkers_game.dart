import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
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

class _CheckersGameState extends State<CheckersGame>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState ?? CheckersGameState.newGame();
    _hasRecordedStart = widget.initialState != null;
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _aiTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _persistState();
    }
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
    if (_loading || state.isFinished) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => state = state.incrementElapsed());
      await _persistState();
    });
  }

  void _maybeRunAi() {
    _aiTimer?.cancel();
    if (!mounted || _loading || state.isFinished) return;
    if (state.mode != CheckersGameMode.vsAi ||
        state.turn != CheckersSide.black) {
      return;
    }
    _aiTimer = Timer(kAiMoveDelay, () async {
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
    if (_undoStack.isEmpty) return;
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

  Future<bool> _confirmNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new game?'),
        content: const Text('Your current Checkers game will be replaced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmAndStartNewGame() async {
    if (await _confirmNewGame()) {
      await _newGame();
    }
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelpSection(
                title: 'Capture example',
                children: [
                  HelpDiagram(
                    'r = your red piece   b = black piece\n\n. . . .\n. r . .\n. . b .\n. . . x   ← jump over b into x to capture',
                  ),
                ],
              ),
              HelpSection(
                title: 'Rules',
                children: [
                  HelpBulletList(
                    items: [
                      'Red moves first. Regular pieces move one square diagonally forward.',
                      'Captures are mandatory. If a jump is available, you must take it. Multi-jumps are generated automatically and played as one move.',
                      'Kings can move and capture backward. Reaching the back rank crowns a piece.',
                      'Easy/Medium/Hard adjust the AI minimax depth: 2 / 4 / 6 plies.',
                      'Undo rolls back one full turn versus the AI, or one move in pass-and-play.',
                      'The game auto-saves when you leave and restores when you come back.',
                    ],
                  ),
                ],
              ),
            ],
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

  Future<void> _showSettings() async {
    final result =
        await showModalBottomSheet<(CheckersGameMode, CheckersDifficulty)>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            var selectedMode = state.mode;
            var selectedDifficulty = state.difficulty;
            return StatefulBuilder(
              builder: (context, setModalState) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checkers settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mode',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Vs AI'),
                            selected: selectedMode == CheckersGameMode.vsAi,
                            onSelected: (_) {
                              setModalState(() {
                                selectedMode = CheckersGameMode.vsAi;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Pass & play'),
                            selected:
                                selectedMode == CheckersGameMode.passAndPlay,
                            onSelected: (_) {
                              setModalState(() {
                                selectedMode = CheckersGameMode.passAndPlay;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AI difficulty',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final difficulty in CheckersDifficulty.values)
                            ChoiceChip(
                              label: Text(difficulty.label),
                              selected: selectedDifficulty == difficulty,
                              onSelected: selectedMode == CheckersGameMode.vsAi
                                  ? (_) {
                                      setModalState(() {
                                        selectedDifficulty = difficulty;
                                      });
                                    }
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop((selectedMode, selectedDifficulty)),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

    if (result == null) {
      return;
    }

    final (mode, difficulty) = result;
    if (mode != state.mode) {
      _undoStack.clear();
      _hasRecordedStart = false;
      await _applyState(
        CheckersGameState.newGame(mode: mode, difficulty: difficulty),
      );
      await _recordStartedGame();
      return;
    }
    if (difficulty != state.difficulty) {
      await _setDifficulty(difficulty);
    }
  }

  Widget _buildTopPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checkers',
                  key: const Key('checkers_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  state.mode == CheckersGameMode.vsAi
                      ? '${state.difficulty.label} AI'
                      : 'Pass & play',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GameStatsRow(
              dark: false,
              items: [
                GameStatItem(
                  label: 'Turn',
                  value: state.turn == CheckersSide.red ? 'RED' : 'BLACK',
                  icon: Icons.swap_vert_rounded,
                ),
                GameStatItem(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                ),
                GameStatItem(
                  label: 'Moves',
                  value: '${state.moveHistory.length}',
                  icon: Icons.swap_horiz_rounded,
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

  bool get _playerWon => state.status == CheckersGameStatus.redWon;

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.checkers,
      title: 'Kings Rule!',
      subtitle: 'Your crowned pieces celebrate with a little extra sparkle.',
      stats: [
        WinScreenStat(
          label: 'Time',
          value: formatElapsedSeconds(state.elapsedSeconds),
          icon: Icons.timer_outlined,
        ),
        WinScreenStat(
          label: 'Moves',
          value: '${state.moveHistory.length}',
          icon: Icons.swap_horiz_rounded,
        ),
        WinScreenStat(
          label: 'Wins',
          value: '${_stats.wins}',
          icon: Icons.emoji_events_outlined,
        ),
      ],
      onNewGame: _newGame,
      onBackToMenu: _backToMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Checkers'),
        actions: buildGameAppBarActions(
          onHelp: _showHelp,
          onSettings: _showSettings,
        ),
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: _undo,
              undoEnabled: _undoStack.isNotEmpty,
              onHint: _showHelp,
              onNewDeal: _confirmAndStartNewGame,
              onStatistics: _showStats,
              newDealLabel: 'New Game',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTopPanel(context),
                              const SizedBox(height: 16),
                              _buildBoard(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_playerWon) _buildWinOverlay(),
                ],
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

    return AnimatedContainer(
      duration: kBoardPieceMoveDuration,
      curve: Curves.easeOutCubic,
      color: background,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (isLegalTarget)
                Center(
                  child: AnimatedContainer(
                    duration: piece == null
                        ? kBoardPieceMoveDuration
                        : kBoardPieceCaptureDuration,
                    curve: Curves.easeOutCubic,
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
                  child: AnimatedScale(
                    duration: kBoardPieceMoveDuration,
                    curve: Curves.easeOutCubic,
                    scale: isSelected ? 1.05 : 1,
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
                                  : const [
                                      Color(0xFF444A55),
                                      Color(0xFF12151C),
                                    ],
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
                ),
            ],
          ),
        ),
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
