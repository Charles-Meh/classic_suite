import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/duration_format.dart';
import 'tripeaks_game_state.dart';
import 'tripeaks_stats.dart';
import 'tripeaks_stats_store.dart';

class TriPeaksGame extends StatefulWidget {
  const TriPeaksGame({super.key, this.initialState});

  final TriPeaksGameState? initialState;

  @override
  State<TriPeaksGame> createState() => _TriPeaksGameState();
}

class _TriPeaksGameState extends State<TriPeaksGame> {
  static const _historyKey = 'classic_suite.tripeaks.history';
  static const _redoHistoryKey = 'classic_suite.tripeaks.redo_history';

  late TriPeaksGameState state;
  late TriPeaksGameState _initialDealState;
  final TriPeaksStatsStore _statsStore = TriPeaksStatsStore();
  final List<TriPeaksGameState> _history = [];
  final List<TriPeaksGameState> _redoHistory = [];
  TriPeaksStats _stats = const TriPeaksStats();
  Timer? _ticker;
  bool _loading = true;
  bool _hasRecordedStart = false;
  bool _hasRecordedResult = false;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? TriPeaksGameState.newGame();
    _initialDealState = state.copyWith();
    _hasRecordedStart = widget.initialState != null;
    _hasRecordedResult = state.isWon || state.isLost;
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = widget.initialState == null
        ? TriPeaksGameState.tryDecode(prefs.getString(TriPeaksGameState.storageKey))
        : null;
    final history = widget.initialState == null
        ? (prefs.getStringList(_historyKey) ?? const [])
            .map(TriPeaksGameState.tryDecode)
            .whereType<TriPeaksGameState>()
            .toList()
        : <TriPeaksGameState>[];
    final redoHistory = widget.initialState == null
        ? (prefs.getStringList(_redoHistoryKey) ?? const [])
            .map(TriPeaksGameState.tryDecode)
            .whereType<TriPeaksGameState>()
            .toList()
        : <TriPeaksGameState>[];
    final stats = await _statsStore.load();

    if (!mounted) {
      return;
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        _initialDealState = loaded.copyWith();
        _history
          ..clear()
          ..addAll(history);
        _redoHistory
          ..clear()
          ..addAll(redoHistory);
        _hasRecordedStart = true;
        _hasRecordedResult = state.isWon || state.isLost;
      }
      _stats = stats;
      _loading = false;
    });

    _syncTicker();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TriPeaksGameState.storageKey, state.encode());
    await prefs.setStringList(_historyKey, _history.map((entry) => entry.encode()).toList());
    await prefs.setStringList(
      _redoHistoryKey,
      _redoHistory.map((entry) => entry.encode()).toList(),
    );
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

  Future<void> _recordResultIfNeeded() async {
    if (_hasRecordedResult) {
      return;
    }
    TriPeaksStats nextStats = _stats;
    if (state.isWon) {
      nextStats = _stats.recordWin(
        score: state.score,
        longestRun: state.longestRun,
      );
    } else if (state.isLost) {
      nextStats = _stats.recordLoss(longestRun: state.longestRun);
    } else {
      return;
    }

    _hasRecordedResult = true;
    setState(() {
      _stats = nextStats;
    });
    await _statsStore.save(nextStats);
  }

  Future<void> _applyState(TriPeaksGameState nextState) async {
    final previousStatus = state.status;
    setState(() {
      state = nextState;
    });

    await _recordStartedGameIfNeeded();
    if (previousStatus != nextState.status) {
      await _recordResultIfNeeded();
    }

    _syncTicker();
    await _persistState();
  }

  Future<void> _recordMutation(TriPeaksGameState nextState) async {
    if (identical(nextState, state) || nextState.encode() == state.encode()) {
      return;
    }
    _history.add(state.copyWith());
    _redoHistory.clear();
    await _applyState(nextState);
  }

  Future<void> _newGame() async {
    if (!_hasRecordedResult) {
      final nextStats = _stats.recordLoss(longestRun: state.longestRun);
      setState(() {
        _stats = nextStats;
      });
      await _statsStore.save(nextStats);
    }

    final fresh = TriPeaksGameState.newGame();
    _initialDealState = fresh.copyWith();
    _history.clear();
    _redoHistory.clear();
    _hasRecordedStart = false;
    _hasRecordedResult = false;
    await _applyState(fresh);
  }

  Future<void> _restartDeal() async {
    if (!_hasRecordedResult) {
      final nextStats = _stats.recordLoss(longestRun: state.longestRun);
      setState(() {
        _stats = nextStats;
      });
      await _statsStore.save(nextStats);
    }

    final fresh = TriPeaksGameState.newGame(seed: _initialDealState.seed);
    _history.clear();
    _redoHistory.clear();
    _hasRecordedStart = false;
    _hasRecordedResult = false;
    await _applyState(fresh);
  }

  Future<void> _undo() async {
    if (_history.isEmpty) {
      return;
    }
    final previous = _history.removeLast();
    _redoHistory.add(state.copyWith());
    _hasRecordedResult = previous.isWon || previous.isLost;
    await _applyState(previous);
  }

  Future<void> _redo() async {
    if (_redoHistory.isEmpty) {
      return;
    }
    final next = _redoHistory.removeLast();
    _history.add(state.copyWith());
    _hasRecordedResult = next.isWon || next.isLost;
    await _applyState(next);
  }

  Future<void> _togglePaused() async {
    await _applyState(state.togglePaused());
  }

  Future<void> _drawFromStock() async {
    await _recordMutation(state.drawFromStock());
  }

  Future<void> _removeCard(int index) async {
    await _recordMutation(state.removeCard(index));
  }

  Future<void> _showStatistics() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('TriPeaks statistics'),
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
              _StatRow(label: 'Current streak', value: '${_stats.currentStreak}'),
              _StatRow(label: 'Best streak', value: '${_stats.bestStreak}'),
              _StatRow(label: 'Longest run', value: '${_stats.longestRunEver}'),
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
            'Remove exposed peak cards that are exactly one rank above or below '
            'the waste card. Aces wrap with Kings. Draw from stock when you are '
            'stuck. Longer removal streaks score more points.',
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
                    'TriPeaks Solitaire',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  key: const Key('tripeaks_stats'),
                  onPressed: _showStatistics,
                  icon: const Icon(Icons.bar_chart_rounded),
                ),
                IconButton(
                  key: const Key('tripeaks_pause'),
                  onPressed: _togglePaused,
                  icon: Icon(state.paused ? Icons.play_arrow : Icons.pause),
                ),
                IconButton(
                  key: const Key('tripeaks_help'),
                  onPressed: _showHowToPlay,
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  label: 'Score',
                  value: '${state.score}',
                  color: scheme.primaryContainer,
                  icon: Icons.stars_rounded,
                ),
                _MetricChip(
                  label: 'Run',
                  value: '${state.currentRun}',
                  color: scheme.secondaryContainer,
                  icon: Icons.bolt_rounded,
                ),
                _MetricChip(
                  label: 'Best run',
                  value: '${state.longestRun}',
                  color: scheme.tertiaryContainer,
                  icon: Icons.timeline_rounded,
                ),
                _MetricChip(
                  label: 'Stock',
                  value: '${state.stock.length}',
                  color: scheme.surfaceContainerHighest,
                  icon: Icons.layers_outlined,
                ),
                _MetricChip(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  color: scheme.surfaceContainerLow,
                  icon: Icons.timer_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                state.message,
                key: ValueKey<String>(state.message),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    TriPeaksCard? card,
    _TriPeaksMetrics metrics, {
    bool highlighted = false,
    Key? key,
    VoidCallback? onTap,
  }) {
    final borderColor = highlighted
        ? const Color(0xFFFFD54F)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.25);
    final glow = highlighted
        ? [
            const BoxShadow(
              color: Color(0x66FFD54F),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ]
        : null;

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: metrics.cardWidth,
        height: metrics.cardHeight,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radius + 4),
          color: highlighted ? const Color(0x22FFD54F) : Colors.transparent,
          border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
          boxShadow: glow,
        ),
        child: card == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(metrics.radius),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const SizedBox.expand(),
              )
            : PlayingCardView(
                card: card.card,
                showBack: !card.faceUp,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(metrics.radius),
                ),
              ),
      ),
    );
  }

  Widget _buildStockAndWaste(_TriPeaksMetrics metrics) {
    return Row(
      children: [
        GestureDetector(
          key: const Key('tripeaks_stock'),
          onTap: state.stock.isEmpty || state.paused || state.isWon || state.isLost
              ? null
              : _drawFromStock,
          child: SizedBox(
            width: metrics.cardWidth,
            height: metrics.cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (state.stock.isNotEmpty)
                  for (int layer = 0; layer < math.min(3, state.stock.length); layer++)
                    Positioned(
                      left: layer * 2,
                      top: layer * 2,
                      child: _buildCard(
                        TriPeaksCard(
                          card: PlayingCard(Suit.spades, CardValue.ace),
                          faceUp: false,
                        ),
                        metrics,
                      ),
                    )
                else
                  _buildCard(null, metrics),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${state.stock.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: metrics.columnGap * 1.5),
        _buildCard(
          state.wasteTop,
          metrics,
          key: const Key('tripeaks_waste'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('tripeaks_undo'),
                onPressed: _history.isEmpty ? null : _undo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              OutlinedButton.icon(
                key: const Key('tripeaks_redo'),
                onPressed: _redoHistory.isEmpty ? null : _redo,
                icon: const Icon(Icons.redo),
                label: const Text('Redo'),
              ),
              OutlinedButton.icon(
                key: const Key('tripeaks_new'),
                onPressed: _newGame,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('New game'),
              ),
              OutlinedButton.icon(
                key: const Key('tripeaks_restart'),
                onPressed: _restartDeal,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableau(_TriPeaksMetrics metrics) {
    final rows = <int, List<TriPeaksPosition>>{};
    for (final position in TriPeaksGameState.layout) {
      rows.putIfAbsent(position.row, () => []).add(position);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: metrics.boardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int row = 0; row <= 3; row++) ...[
                  SizedBox(
                    height: metrics.rowStride,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final position in rows[row]!)
                          Positioned(
                            left: position.column * metrics.columnGap,
                            child: _buildCard(
                              state.tableau[position.index],
                              metrics,
                              key: Key('tripeaks_tableau_${position.index}'),
                              highlighted: state.isValidMove(position.index),
                              onTap: state.isValidMove(position.index)
                                  ? () => _removeCard(position.index)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (row < 3) SizedBox(height: metrics.overlapGap),
                ],
                SizedBox(height: metrics.sectionGap),
                _buildStockAndWaste(metrics),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(_TriPeaksMetrics metrics) {
    final Color tint;
    final String title;
    final String subtitle;
    final IconData icon;

    if (state.paused) {
      tint = Colors.black.withValues(alpha: 0.42);
      title = 'Paused';
      subtitle = 'Tap play to resume your current deal.';
      icon = Icons.pause_circle_filled;
    } else if (state.isWon) {
      tint = const Color(0x8814532D);
      title = 'You won';
      subtitle = 'All 28 peak cards are gone. Score: ${state.score}.';
      icon = Icons.emoji_events;
    } else {
      tint = const Color(0x88B3261E);
      title = 'No moves left';
      subtitle = 'Draws are gone too. Start a fresh deal or restart this one.';
      icon = Icons.info_outline;
    }

    return Positioned.fill(
      child: Container(
        color: tint,
        alignment: Alignment.center,
        child: Container(
          width: math.min(420, metrics.boardWidth),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (state.paused)
                    FilledButton.icon(
                      onPressed: _togglePaused,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    ),
                  if (!state.paused)
                    FilledButton.icon(
                      onPressed: _newGame,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('New game'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('tripeaks_overlay_stats'),
                    onPressed: _showStatistics,
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('Statistics'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _restartDeal,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TriPeaks Solitaire')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = _TriPeaksMetrics.fromWidth(constraints.maxWidth);
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 16),
                                _buildTableau(metrics),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (state.paused || state.isWon || state.isLost)
                        _buildOverlay(metrics),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
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
        children: [Expanded(child: Text(label)), Text(value)],
      ),
    );
  }
}

class _TriPeaksMetrics {
  const _TriPeaksMetrics({
    required this.cardWidth,
    required this.cardHeight,
    required this.radius,
    required this.columnGap,
    required this.rowStride,
    required this.overlapGap,
    required this.sectionGap,
    required this.boardWidth,
  });

  final double cardWidth;
  final double cardHeight;
  final double radius;
  final double columnGap;
  final double rowStride;
  final double overlapGap;
  final double sectionGap;
  final double boardWidth;

  factory _TriPeaksMetrics.fromWidth(double width) {
    final cardWidth = width < 420 ? 42.0 : width < 720 ? 54.0 : 72.0;
    final cardHeight = cardWidth * 1.4;
    final columnGap = cardWidth * 0.82;
    return _TriPeaksMetrics(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      radius: math.max(6, cardWidth * 0.1),
      columnGap: columnGap,
      rowStride: cardHeight,
      overlapGap: cardHeight * 0.08,
      sectionGap: 20,
      boardWidth: (10 * columnGap) + cardWidth,
    );
  }
}
