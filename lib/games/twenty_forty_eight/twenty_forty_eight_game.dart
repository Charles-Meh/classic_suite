import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/duration_format.dart';
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

  Future<void> _handleUndo() async {
    await _applyState(state.undo());
  }

  Future<void> _handleResume() async {
    await _applyState(state.resume());
  }

  Future<void> _handleContinue() async {
    await _applyState(state.continuePast2048());
  }

  Future<void> _handlePause() async {
    await _applyState(state.pause());
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
    await Future<void>.delayed(const Duration(milliseconds: 175));
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
          content: const Text(
            'Swipe anywhere on the board area to slide every tile. Matching values merge once per move. '
            'Reach 2048 to win, then keep going if you want a bigger tile. Undo gives you a safety net.',
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
                    'Score ${state.score} • Best ${_stats.bestScore}',
                    key: const Key('2048_score_label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('2048_restart'),
                  tooltip: 'Restart game',
                  onPressed: _startNewGame,
                  icon: const Icon(Icons.restart_alt),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Game menu',
                  onSelected: (value) async {
                    switch (value) {
                      case 'stats':
                        await _showStatistics();
                      case 'help':
                        await _showHowToPlay();
                      case 'restart':
                        await _startNewGame();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    PopupMenuItem(value: 'help', child: Text('How to play')),
                    PopupMenuItem(value: 'restart', child: Text('Restart')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CounterBadge(
                  label: 'Moves',
                  value: '${state.moveCount}',
                  icon: Icons.swipe_rounded,
                  color: scheme.primaryContainer,
                ),
                _CounterBadge(
                  label: 'Top tile',
                  value: '${state.highestTile}',
                  icon: Icons.auto_awesome,
                  color: scheme.secondaryContainer,
                ),
                _CounterBadge(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                  color: scheme.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('2048_undo'),
                  onPressed: state.canUndo ? _handleUndo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const Key('2048_pause'),
                  onPressed: state.isPaused ? _handleResume : _handlePause,
                  icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(state.isPaused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(width: 10),
                if (state.hasWon && !state.keepGoing)
                  OutlinedButton.icon(
                    key: const Key('2048_continue'),
                    onPressed: _handleContinue,
                    icon: const Icon(Icons.trending_up),
                    label: const Text('Keep going'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                state.message,
                key: ValueKey<String>(state.message),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
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
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      left: gap + tile.column * (cellSize + gap),
                      top: gap + tile.row * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: _TileCard(tile: tile),
                    ),
                  if (state.isPaused || state.isWon || state.isLost)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
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
                                  state.isPaused
                                      ? 'Paused'
                                      : state.isLost
                                      ? 'Game over'
                                      : '2048 reached',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.isPaused
                                      ? 'Your board is saved.'
                                      : state.isLost
                                      ? 'Start a new run or undo the last move.'
                                      : 'You can keep going for 4096 and beyond.',
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
                                    if (state.isWon && !state.keepGoing)
                                      FilledButton(
                                        onPressed: _handleContinue,
                                        child: const Text('Keep going'),
                                      ),
                                    OutlinedButton(
                                      onPressed: _startNewGame,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2048')),
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
                        const SizedBox(height: 16),
                        Text(
                          'Swipe anywhere over the board. Matching tiles merge once per move. Reach 2048, then keep going if you want.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
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
      duration: const Duration(milliseconds: 150),
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
