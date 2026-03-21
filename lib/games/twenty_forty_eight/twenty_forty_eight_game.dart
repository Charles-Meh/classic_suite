import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import 'twenty_forty_eight_game_state.dart';
import 'twenty_forty_eight_stats.dart';
import 'twenty_forty_eight_stats_store.dart';

class TwentyFortyEightGame extends StatefulWidget {
  const TwentyFortyEightGame({super.key, this.initialState});

  final TwentyFortyEightGameState? initialState;

  @override
  State<TwentyFortyEightGame> createState() => _TwentyFortyEightGameState();
}

class _TwentyFortyEightGameState extends State<TwentyFortyEightGame>
    with WidgetsBindingObserver {
  late TwentyFortyEightGameState state;
  final TwentyFortyEightStatsStore _statsStore = TwentyFortyEightStatsStore();
  TwentyFortyEightStats _stats = const TwentyFortyEightStats();
  Timer? _ticker;
  bool _loading = true;
  bool _hasRecordedStart = false;
  bool _hasRecordedFinish = false;
  int _gestureLock = 0;
  Offset _dragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState ?? TwentyFortyEightGameState.newGame();
    _hasRecordedStart = state.moveCount > 0;
    _hasRecordedFinish = state.isLost || state.isWon;
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      if (mounted && state.isActive) {
        setState(() {
          state = state.pause();
        });
        _persistState();
        _syncTicker();
      }
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = widget.initialState == null
        ? TwentyFortyEightGameState.tryDecode(
            prefs.getString(TwentyFortyEightGameState.storageKey),
          )
        : null;
    final stats = await _statsStore.load();

    if (!mounted) {
      return;
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        _hasRecordedStart = state.moveCount > 0;
        _hasRecordedFinish = state.isLost || state.isWon;
      }
      _stats = stats;
      _loading = false;
    });
    _syncTicker();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TwentyFortyEightGameState.storageKey, state.encode());
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (!mounted || !state.isActive) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        return;
      }
      setState(() {
        state = state.incrementElapsed();
      });
      await _persistState();
    });
  }

  Future<void> _recordStartedGameIfNeeded() async {
    if (_hasRecordedStart) {
      return;
    }
    _hasRecordedStart = true;
    final nextStats = _stats.recordGameStarted();
    setState(() {
      _stats = nextStats;
    });
    await _statsStore.save(nextStats);
  }

  Future<void> _recordFinishedGameIfNeeded() async {
    if (_hasRecordedFinish || (!state.isLost && !state.isWon)) {
      return;
    }
    _hasRecordedFinish = true;
    final nextStats = _stats.recordFinishedGame(
      won: state.hasWon,
      score: state.score,
      highestTile: state.highestTile,
      moveCount: state.moveCount,
    );
    setState(() {
      _stats = nextStats;
    });
    await _statsStore.save(nextStats);
  }

  Future<void> _applyState(TwentyFortyEightGameState nextState) async {
    final startBefore = state.moveCount == 0;
    final finishedBefore = state.isLost || state.isWon;
    setState(() {
      state = nextState;
    });

    if (startBefore && nextState.moveCount > 0) {
      await _recordStartedGameIfNeeded();
    }
    if (!finishedBefore && (nextState.isLost || nextState.isWon)) {
      await _recordFinishedGameIfNeeded();
    }

    _syncTicker();
    await _persistState();
  }

  Future<void> _startNewGame() async {
    _hasRecordedStart = false;
    _hasRecordedFinish = false;
    await _applyState(TwentyFortyEightGameState.newGame());
  }

  Future<void> _confirmStartNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new game?'),
        content: const Text('Current progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New Game'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startNewGame();
    }
  }

  Future<void> _handleUndo() async {
    await _applyState(state.undo());
  }

  Future<void> _handleResume() async {
    await _applyState(state.resume());
  }

  Future<void> _handleContinue() async {
    await _applyState(state.continuePast2048());
  }

  Future<void> _handleMove(MoveDirection direction) async {
    if (_gestureLock > 0) {
      return;
    }
    final result = state.move(direction);
    if (!result.changed) {
      await _applyState(result.state);
      return;
    }

    _gestureLock++;
    await _applyState(result.state);
    await Future<void>.delayed(kTileSlideDuration);
    if (!mounted) {
      return;
    }
    setState(() {
      state = state.clearTransientFlags();
      _gestureLock = math.max(0, _gestureLock - 1);
    });
    await _persistState();
  }

  Future<void> _showStatistics() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('2048 statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(label: 'Games', value: '${_stats.gamesStarted}'),
              _StatRow(label: 'Wins', value: '${_stats.gamesWon}'),
              _StatRow(
                label: 'Win rate',
                value: '${(_stats.winRate * 100).toStringAsFixed(0)}%',
              ),
              _StatRow(label: 'Best score', value: '${_stats.bestScore}'),
              _StatRow(label: 'Best tile', value: '${_stats.bestTile}'),
              _StatRow(label: 'Total score', value: '${_stats.totalScore}'),
              _StatRow(
                label: 'Longest run',
                value: '${_stats.longestRunMoves} moves',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHowToPlay() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How to play'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelpSection(
                  title: 'Merge example',
                  children: [
                    HelpDiagram(
                      'Before swipe left      After swipe left\n[2][2][4][ ]   →       [4][4][ ][ ]\n\nEach tile merges once per move.',
                    ),
                  ],
                ),
                HelpSection(
                  title: 'Rules',
                  children: [
                    HelpBulletList(
                      items: [
                        'Swipe anywhere on the board area to slide every tile.',
                        'Matching values merge once per move.',
                        'Reach 2048 to win, then keep going if you want a bigger tile.',
                        'Undo gives you a safety net.',
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
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameStatsRow(
              dark: false,
              items: [
                GameStatItem(
                  label: 'Score',
                  value: '${state.score}',
                  icon: Icons.star_outline_rounded,
                ),
                GameStatItem(
                  label: 'Best',
                  value: '${_stats.bestScore}',
                  icon: Icons.emoji_events_outlined,
                ),
                GameStatItem(
                  label: 'Moves',
                  value: '${state.moveCount}',
                  icon: Icons.swipe_rounded,
                ),
                GameStatItem(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                ),
              ],
            ),
            if (state.hasWon && !state.keepGoing) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('2048_continue'),
                onPressed: _handleContinue,
                icon: const Icon(Icons.trending_up),
                label: const Text('Keep going'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 520.0);
        final gap = width * 0.025;
        final cellSize = (width - (gap * 5)) / 4;

        return Center(
          child: GestureDetector(
            key: const Key('2048_swipe_surface'),
            behavior: HitTestBehavior.opaque,
            onPanStart: state.isPaused
                ? null
                : (_) {
                    _dragDelta = Offset.zero;
                  },
            onPanUpdate: state.isPaused
                ? null
                : (details) {
                    _dragDelta += details.delta;
                  },
            onPanEnd: state.isPaused
                ? null
                : (_) {
                    final delta = _dragDelta;
                    _dragDelta = Offset.zero;
                    if (delta.distance < 36) {
                      return;
                    }
                    if (delta.dx.abs() > delta.dy.abs()) {
                      _handleMove(
                        delta.dx < 0 ? MoveDirection.left : MoveDirection.right,
                      );
                    } else {
                      _handleMove(
                        delta.dy < 0 ? MoveDirection.up : MoveDirection.down,
                      );
                    }
                  },
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  for (int row = 0; row < 4; row++)
                    for (int column = 0; column < 4; column++)
                      Positioned(
                        left: gap + column * (cellSize + gap),
                        top: gap + row * (cellSize + gap),
                        width: cellSize,
                        height: cellSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                  for (final tile in state.tiles)
                    AnimatedPositioned(
                      key: Key('2048_tile_${tile.id}'),
                      duration: kTileSlideDuration,
                      curve: Curves.easeOutCubic,
                      left: gap + tile.column * (cellSize + gap),
                      top: gap + tile.row * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: _TileCard(tile: tile),
                    ),
                  if (state.isPaused || state.isLost)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: kCardOverlayDuration,
                        decoration: BoxDecoration(
                          color: scheme.scrim.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.isPaused ? 'Paused' : 'Game over',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.isPaused
                                      ? 'Your board is saved.'
                                      : 'Start a new run or undo the last move.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (state.isPaused)
                                      FilledButton(
                                        onPressed: _handleResume,
                                        child: const Text('Resume'),
                                      ),
                                    OutlinedButton(
                                      onPressed: _confirmStartNewGame,
                                      child: const Text('Restart'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (state.isWon) _buildWinOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.twentyFortyEight,
      title: '2048!',
      subtitle:
          'Tiles burst, confetti flies, and that score looks pretty good too.',
      stats: [
        WinScreenStat(
          label: 'Score',
          value: '${state.score}',
          icon: Icons.star_outline_rounded,
        ),
        WinScreenStat(
          label: 'Moves',
          value: '${state.moveCount}',
          icon: Icons.swipe_rounded,
        ),
        WinScreenStat(
          label: 'Best tile',
          value: '${state.highestTile}',
          icon: Icons.auto_awesome,
        ),
      ],
      onNewGame: _confirmStartNewGame,
      onBackToMenu: _backToMenu,
      newGameLabel: 'New Run',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('2048'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHowToPlay,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            key: const Key('2048_settings_action'),
            tooltip: 'Settings',
            onPressed: null,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: _handleUndo,
              undoEnabled: state.canUndo,
              onHint: null,
              showHintButton: false,
              onNewDeal: _confirmStartNewGame,
              onStatistics: _showStatistics,
              newDealLabel: 'New Game',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildBoard(context),
                      ],
                    ),
                  ),
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

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile});

  final TwentyFortyEightTile tile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _backgroundFor(tile.value, scheme);
    final foreground = tile.value <= 4 ? scheme.onSurface : Colors.white;
    final fontSize = tile.value >= 1024
        ? 28.0
        : tile.value >= 128
        ? 34.0
        : 40.0;
    final scale = tile.isNew
        ? 0.88
        : tile.isMerged
        ? 1.08
        : 1.0;

    return AnimatedScale(
      duration: kTileMergePopDuration,
      curve: Curves.easeOutBack,
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [background.withValues(alpha: 0.96), background],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${tile.value}',
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Color _backgroundFor(int value, ColorScheme scheme) {
    return switch (value) {
      2 => scheme.surface,
      4 => scheme.surfaceContainerHigh,
      8 => const Color(0xFFE99854),
      16 => const Color(0xFFE9844A),
      32 => const Color(0xFFE46A44),
      64 => const Color(0xFFD64F3B),
      128 => const Color(0xFFC9A13E),
      256 => const Color(0xFFB88E2F),
      512 => const Color(0xFFA87B22),
      1024 => const Color(0xFF866719),
      2048 => scheme.primary,
      _ => scheme.tertiary,
    };
  }
}
