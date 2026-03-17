import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import 'chess_ai.dart';
import 'chess_game_state.dart';
import 'chess_stats.dart';
import 'chess_stats_store.dart';

class ChessGame extends StatefulWidget {
  const ChessGame({super.key, this.initialState});

  final ChessGameState? initialState;

  @override
  State<ChessGame> createState() => _ChessGameState();
}

enum _ChessMenuAction { newGame, settings, stats, help }

class _ChessGameState extends State<ChessGame> with WidgetsBindingObserver {
  late ChessGameState state;
  final ChessAi _ai = const ChessAi();
  final ChessStatsStore _statsStore = ChessStatsStore();
  ChessStats _stats = const ChessStats();
  final List<ChessGameState> _undoStack = [];
  Timer? _ticker;
  Timer? _aiTimer;
  bool _loading = true;
  bool _hasRecordedStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState ?? ChessGameState.newGame();
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
        ? ChessGameState.tryDecode(prefs.getString(ChessGameState.storageKey))
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
    ChessStats next = _stats;
    if (state.status == ChessGameStatus.whiteWon) {
      next = _stats.recordWin(
        difficultyId: state.mode == ChessGameMode.vsAi
            ? state.difficulty.id
            : 'pass-and-play',
        seconds: state.elapsedSeconds,
      );
    } else if (state.status == ChessGameStatus.blackWon) {
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
    await prefs.setString(ChessGameState.storageKey, state.encode());
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
    if (state.mode != ChessGameMode.vsAi || state.turn != ChessSide.black) {
      return;
    }
    _aiTimer = Timer(kAiMoveDelay, () async {
      final move = _ai.bestMove(state);
      if (move == null || !mounted) return;
      await _applyMove(move, fromAi: true, allowUndoSnapshot: false);
    });
  }

  Future<void> _applyState(ChessGameState next) async {
    setState(() => state = next);
    _syncTimers();
    await _persistState();
    await _recordResultIfNeeded();
    _maybeRunAi();
  }

  Future<void> _applyMove(
    ChessMove move, {
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
    await _applyState(
      state.copyWith(
        clearSelectedSquare: true,
        clearHint: true,
        showHint: false,
      ),
    );
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || state.isPaused) return;
    var previous = _undoStack.removeLast();
    if (state.mode == ChessGameMode.vsAi &&
        previous.turn == ChessSide.black &&
        _undoStack.isNotEmpty) {
      previous = _undoStack.removeLast();
    }
    await _applyState(
      previous.copyWith(message: 'Move undone.', clearHint: true),
    );
  }

  Future<void> _newGame() async {
    _undoStack.clear();
    _hasRecordedStart = false;
    final next = ChessGameState.newGame(
      mode: state.mode,
      difficulty: state.difficulty,
    );
    await _applyState(next);
    await _recordStartedGame();
  }

  Future<void> _setDifficulty(ChessDifficulty difficulty) async {
    _undoStack.clear();
    _hasRecordedStart = false;
    await _applyState(
      ChessGameState.newGame(mode: state.mode, difficulty: difficulty),
    );
    await _recordStartedGame();
  }

  Future<void> _togglePause() async => _applyState(state.togglePause());

  Future<void> _showHint() async {
    final move = _ai.bestMove(
      state,
      depth: math.max(2, state.difficulty.searchDepth - 1),
    );
    await _applyState(state.withHint(move));
  }

  Future<void> _showSettings() async {
    final result = await showModalBottomSheet<(ChessGameMode, ChessDifficulty)>(
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
                    'Chess settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Mode', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('chess_settings_mode_ai'),
                        label: const Text('Vs AI'),
                        selected: selectedMode == ChessGameMode.vsAi,
                        onSelected: (_) {
                          setModalState(() {
                            selectedMode = ChessGameMode.vsAi;
                          });
                        },
                      ),
                      ChoiceChip(
                        key: const Key('chess_settings_mode_local'),
                        label: const Text('Pass & play'),
                        selected: selectedMode == ChessGameMode.passAndPlay,
                        onSelected: (_) {
                          setModalState(() {
                            selectedMode = ChessGameMode.passAndPlay;
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
                      for (final difficulty in ChessDifficulty.values)
                        ChoiceChip(
                          key: Key(
                            'chess_settings_difficulty_${difficulty.name}',
                          ),
                          label: Text(difficulty.label),
                          selected: selectedDifficulty == difficulty,
                          onSelected: selectedMode == ChessGameMode.vsAi
                              ? (_) {
                                  setModalState(() {
                                    selectedDifficulty = difficulty;
                                  });
                                }
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const Key('chess_settings_apply'),
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
        ChessGameState.newGame(mode: mode, difficulty: difficulty),
      );
      await _recordStartedGame();
      return;
    }
    if (difficulty != state.difficulty) {
      await _setDifficulty(difficulty);
    }
  }

  Future<void> _showStats() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chess statistics'),
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
                title: 'Piece movement',
                children: [
                  HelpDiagram(
                    'King   : one square any direction\nQueen  : straight + diagonal any distance\nRook   : straight any distance\nBishop : diagonal any distance\nKnight : L-shape, can jump\nPawn   : forward 1, capture diagonally',
                  ),
                ],
              ),
              HelpSection(
                title: 'Rules',
                children: [
                  HelpBulletList(
                    items: [
                      'White moves first. Tap a piece to see legal moves, then tap a highlighted square.',
                      'Win by checkmating the opposing king. If no legal moves remain and the king is not in check, it is stalemate.',
                      'Castling, en passant, and automatic queen promotion are supported.',
                      'Easy/Medium/Hard change AI search depth: 2 / 4 / 6 plies.',
                      'Undo steps back one full turn against the AI, or one move in pass-and-play.',
                      'The game auto-saves, so pause and resume works naturally when you leave and come back.',
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

  Widget _buildTopPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.mode == ChessGameMode.vsAi
                  ? 'Chess • ${state.difficulty.label} AI'
                  : 'Chess • Pass & play',
              key: const Key('chess_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Badge(
                  label: 'Turn',
                  value: state.turn.name.toUpperCase(),
                  color: scheme.primaryContainer,
                ),
                _Badge(
                  label: 'Clock',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  color: scheme.secondaryContainer,
                ),
                _Badge(
                  label: 'Status',
                  value: state.inCheck
                      ? 'Check'
                      : (state.isFinished ? 'Finished' : 'In play'),
                  color: scheme.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(state.message, key: const Key('chess_message')),
            if (state.showHint && state.hintMove != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Suggested move: ${state.hintMove!.toDisplay(state)}',
                  key: const Key('chess_hint_banner'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
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
            final legalTargets = state.selectedSquare == null
                ? <(int, int)>{}
                : state
                      .legalMovesForSquare(
                        state.selectedSquare!.$1,
                        state.selectedSquare!.$2,
                      )
                      .map((m) => (m.toRow, m.toCol))
                      .toSet();

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
                                child: _ChessSquare(
                                  key: Key('chess_square_${row}_$col'),
                                  piece: state.board[row][col],
                                  isLight: (row + col).isEven,
                                  isSelected:
                                      state.selectedSquare == (row, col),
                                  isLegalTarget: legalTargets.contains((
                                    row,
                                    col,
                                  )),
                                  isLastMove:
                                      state.lastMove != null &&
                                      ((state.lastMove!.fromRow == row &&
                                              state.lastMove!.fromCol == col) ||
                                          (state.lastMove!.toRow == row &&
                                              state.lastMove!.toCol == col)),
                                  isHintTarget:
                                      state.showHint &&
                                      state.hintMove != null &&
                                      ((state.hintMove!.fromRow == row &&
                                              state.hintMove!.fromCol == col) ||
                                          (state.hintMove!.toRow == row &&
                                              state.hintMove!.toCol == col)),
                                  isCheckedKing:
                                      state.inCheck &&
                                      state.board[row][col]?.type ==
                                          ChessPieceType.king &&
                                      state.board[row][col]?.side == state.turn,
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

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('chess_undo'),
              onPressed: _undoStack.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            OutlinedButton.icon(
              key: const Key('chess_hint'),
              onPressed: state.isHumanTurn ? _showHint : null,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Hint'),
            ),
            OutlinedButton.icon(
              key: const Key('chess_pause'),
              onPressed: _togglePause,
              icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(state.isPaused ? 'Resume' : 'Pause'),
            ),
            OutlinedButton.icon(
              key: const Key('chess_new'),
              onPressed: _newGame,
              icon: const Icon(Icons.restart_alt),
              label: const Text('New game'),
            ),
          ],
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
                    final white = state.moveHistory[index * 2];
                    final black = index * 2 + 1 < state.moveHistory.length
                        ? state.moveHistory[index * 2 + 1]
                        : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 36, child: Text('${index + 1}.')),
                          Expanded(child: Text(white.notation)),
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

  bool get _playerWon => state.status == ChessGameStatus.whiteWon;

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.chess,
      title: 'Checkmate!',
      subtitle:
          'The king tips, the confetti lands, and the board belongs to you.',
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
        centerTitle: true,
        title: const Text('Chess'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          PopupMenuButton<_ChessMenuAction>(
            tooltip: 'Game menu',
            onSelected: (value) async {
              switch (value) {
                case _ChessMenuAction.newGame:
                  await _newGame();
                case _ChessMenuAction.settings:
                  await _showSettings();
                case _ChessMenuAction.stats:
                  await _showStats();
                case _ChessMenuAction.help:
                  await _showHelp();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChessMenuAction.newGame,
                child: Text('New game'),
              ),
              PopupMenuItem(
                value: _ChessMenuAction.settings,
                child: Text('Settings'),
              ),
              PopupMenuItem(
                value: _ChessMenuAction.stats,
                child: Text('Statistics'),
              ),
              PopupMenuItem(
                value: _ChessMenuAction.help,
                child: Text('Rules / help'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopPanel(context),
                            const SizedBox(height: 16),
                            _buildBoard(context),
                            const SizedBox(height: 16),
                            _buildControls(context),
                            const SizedBox(height: 16),
                            _buildHistory(context),
                          ],
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

class _ChessSquare extends StatelessWidget {
  const _ChessSquare({
    super.key,
    required this.piece,
    required this.isLight,
    required this.isSelected,
    required this.isLegalTarget,
    required this.isLastMove,
    required this.isHintTarget,
    required this.isCheckedKing,
    required this.onTap,
  });

  final ChessPiece? piece;
  final bool isLight;
  final bool isSelected;
  final bool isLegalTarget;
  final bool isLastMove;
  final bool isHintTarget;
  final bool isCheckedKing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background = isLight
        ? const Color(0xFFF0D9B5)
        : const Color(0xFFB58863);
    if (Theme.of(context).brightness == Brightness.dark) {
      background = isLight ? const Color(0xFF6E6B5B) : const Color(0xFF4A3C2F);
    }
    if (isLastMove) background = background.withValues(alpha: 0.86);
    if (isSelected) background = scheme.primaryContainer;
    if (isCheckedKing) background = scheme.errorContainer;

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
              if (isHintTarget)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1),
                    duration: kHintPulseDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(opacity: value, child: child);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.tertiary, width: 3),
                      ),
                    ),
                  ),
                ),
              if (isLegalTarget)
                Center(
                  child: AnimatedContainer(
                    duration: piece == null
                        ? kBoardPieceMoveDuration
                        : kBoardPieceCaptureDuration,
                    curve: Curves.easeOutCubic,
                    width: piece == null ? 18 : 48,
                    height: piece == null ? 18 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece == null
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.primary.withValues(alpha: 0.18),
                      border: piece == null
                          ? null
                          : Border.all(color: scheme.primary, width: 2),
                    ),
                  ),
                ),
              if (piece != null)
                Positioned.fill(
                  child: AnimatedScale(
                    duration: kBoardPieceMoveDuration,
                    curve: Curves.easeOutCubic,
                    scale: isSelected ? 1.04 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(
                        'assets/chess/cburnett/${piece!.assetName}.svg',
                        semanticsLabel: piece!.symbol,
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
