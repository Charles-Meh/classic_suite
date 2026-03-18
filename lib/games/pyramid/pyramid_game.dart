import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import 'pyramid_game_state.dart';
import 'pyramid_stats.dart';
import 'pyramid_stats_store.dart';

class PyramidGame extends StatefulWidget {
  const PyramidGame({super.key, this.initialState});

  final PyramidGameState? initialState;

  @override
  State<PyramidGame> createState() => _PyramidGameState();
}

class _PyramidGameState extends State<PyramidGame> with WidgetsBindingObserver {
  late PyramidGameState state;
  PyramidGameState? _initialDeal;
  final PyramidStatsStore _statsStore = PyramidStatsStore();
  PyramidStats _stats = const PyramidStats();
  final List<PyramidGameState> _undoStack = [];
  Timer? _ticker;
  bool _loading = true;
  bool _hasRecordedResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState ?? PyramidGameState.newGame();
    _initialDeal = state.copyWith();
    _hasRecordedResult = state.isWon;
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
      _persistState();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = widget.initialState == null
        ? PyramidGameState.tryDecode(
            prefs.getString(PyramidGameState.storageKey),
          )
        : null;
    final stats = await _statsStore.load();

    if (!mounted) {
      return;
    }

    PyramidStats nextStats = stats;
    if (widget.initialState == null && loaded == null) {
      nextStats = stats.recordGameStarted();
      await _statsStore.save(nextStats);
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        _initialDeal = PyramidGameState.newGame(seed: loaded.seed);
        _hasRecordedResult = loaded.isWon;
      }
      _stats = nextStats;
      _loading = false;
    });

    await _persistState();
    _syncTicker();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PyramidGameState.storageKey, state.encode());
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

  Future<void> _recordResultIfNeeded(PyramidGameState nextState) async {
    if (_hasRecordedResult) {
      return;
    }
    if (nextState.isWon) {
      _hasRecordedResult = true;
      final nextStats = _stats.recordWin(nextState.elapsedSeconds);
      setState(() {
        _stats = nextStats;
      });
      await _statsStore.save(nextStats);
    }
  }

  Future<void> _startFreshGame({int? seed}) async {
    if (!state.isWon && !_loading) {
      final nextStats = _stats.recordLoss();
      setState(() {
        _stats = nextStats;
      });
      await _statsStore.save(nextStats);
    }

    final next = PyramidGameState.newGame(seed: seed);
    _initialDeal = next.copyWith();
    _undoStack.clear();
    _hasRecordedResult = false;

    final startedStats = _stats.recordGameStarted();
    setState(() {
      _stats = startedStats;
      state = next;
    });
    await _statsStore.save(startedStats);
    _syncTicker();
    await _persistState();
  }

  Future<void> _applyState(
    PyramidGameState nextState, {
    bool trackUndo = true,
  }) async {
    if (trackUndo) {
      _undoStack.add(state.copyWith());
    }

    final previousWon = state.isWon;
    setState(() {
      state = nextState;
    });

    if (!previousWon && nextState.isWon) {
      await _recordResultIfNeeded(nextState);
    }

    _syncTicker();
    await _persistState();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) {
      return;
    }
    final previous = _undoStack.removeLast();
    setState(() {
      state = previous.copyWith(message: 'Undid the last move.');
    });
    _hasRecordedResult = state.isWon;
    _syncTicker();
    await _persistState();
  }

  Future<void> _onCardTap(PyramidCardRef ref) async {
    final nextState = state.tapCard(ref);
    if (identical(nextState, state) || nextState.encode() == state.encode()) {
      return;
    }
    await _applyState(nextState);
  }

  Future<void> _drawStock() async {
    final nextState = state.drawFromStock();
    if (identical(nextState, state) || nextState.encode() == state.encode()) {
      return;
    }
    await _applyState(nextState);
  }

  Future<void> _restartDeal() async {
    final seed = _initialDeal?.seed ?? state.seed;
    await _startFreshGame(seed: seed);
  }

  Future<void> _togglePause() async {
    final nextState = state.togglePause();
    await _applyState(nextState, trackUndo: false);
  }

  Future<void> _showStatistics() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pyramid Solitaire statistics'),
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
              _StatRow(
                label: 'Current streak',
                value: '${_stats.currentStreak}',
              ),
              _StatRow(label: 'Best streak', value: '${_stats.bestStreak}'),
              _StatRow(
                label: 'Best time',
                value: _stats.bestTimeSeconds == null
                    ? '—'
                    : formatElapsedSeconds(_stats.bestTimeSeconds!),
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
                  title: 'Valid move examples',
                  children: [
                    HelpDiagram(
                      'Exposed cards only\nQ + A = 13   ✓\n8 + 5 = 13   ✓\nK alone      ✓',
                    ),
                  ],
                ),
                HelpSection(
                  title: 'Rules',
                  children: [
                    HelpBulletList(
                      items: [
                        'Only exposed pyramid cards can be played.',
                        'Tap one card, then tap another so the pair totals 13.',
                        'Kings clear by themselves.',
                        'You can also match the top waste card with an exposed pyramid card.',
                        'Tap the stock to cycle through the remaining cards.',
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
                    'Pyramid Solitaire',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('pyramid_undo'),
                  tooltip: 'Undo',
                  onPressed: _undoStack.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  key: const Key('pyramid_pause'),
                  tooltip: state.paused ? 'Resume' : 'Pause',
                  onPressed: _togglePause,
                  icon: Icon(
                    state.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
                IconButton(
                  key: const Key('pyramid_restart'),
                  tooltip: 'Restart deal',
                  onPressed: _restartDeal,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Game menu',
                  onSelected: (value) async {
                    switch (value) {
                      case 'new':
                        await _startFreshGame();
                      case 'stats':
                        await _showStatistics();
                      case 'help':
                        await _showHowToPlay();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'new', child: Text('New game')),
                    PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    PopupMenuItem(value: 'help', child: Text('How to play')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CounterBadge(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                  color: scheme.primaryContainer,
                ),
                _CounterBadge(
                  label: 'Cleared',
                  value: '${state.removedCount}/28',
                  icon: Icons.layers_clear_outlined,
                  color: scheme.secondaryContainer,
                ),
                _CounterBadge(
                  label: 'Stock',
                  value: '${state.stock.length}',
                  icon: Icons.style_outlined,
                  color: scheme.tertiaryContainer,
                ),
                _CounterBadge(
                  label: 'Best',
                  value: _stats.bestTimeSeconds == null
                      ? '—'
                      : formatElapsedSeconds(_stats.bestTimeSeconds!),
                  icon: Icons.emoji_events_outlined,
                  color: scheme.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.message,
              key: const Key('pyramid_status_message'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockWasteArea(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                GestureDetector(
                  key: const Key('pyramid_stock'),
                  onTap: _drawStock,
                  child: _StockCard(
                    stockCount: state.stock.length,
                    canRecycle: state.stock.isEmpty && state.waste.isNotEmpty,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waste', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _buildWasteCard(),
              ],
            ),
            if (state.cycleCount > 0)
              Chip(
                label: Text('Cycles ${state.cycleCount}'),
                avatar: const Icon(Icons.refresh_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteCard() {
    final top = state.wasteTop;
    if (top == null) {
      return const _EmptyPileCard(label: 'Waste');
    }
    final ref = PyramidCardRef.waste(state.waste.length - 1);
    return _PlayableCard(
      key: const Key('pyramid_waste_card'),
      card: top,
      selected: state.selectedCard == ref,
      highlighted: false,
      onTap: () => _onCardTap(ref),
    );
  }

  Widget _buildPyramid(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width - 64;
            final cardWidth = math.max(
              56.0,
              math.min(84.0, availableWidth / 8.5),
            );
            final horizontalOverlap = cardWidth * 0.52;
            final cardHeight = cardWidth * 1.4;
            final totalWidth = cardWidth + (6 * horizontalOverlap);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth + 12,
                child: Column(
                  children: [
                    for (int row = 0; row < state.pyramid.length; row++)
                      SizedBox(
                        height: cardHeight * 0.72,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (
                              int column = 0;
                              column < state.pyramid[row].length;
                              column++
                            )
                              Positioned(
                                left:
                                    ((6 - row) * horizontalOverlap / 2) +
                                    (column * horizontalOverlap),
                                top: 0,
                                child: _buildPyramidCard(row, column),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(height: cardHeight * 0.45),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPyramidCard(int row, int column) {
    final card = state.pyramid[row][column];
    if (card.removed) {
      return const _ClearedCardPlaceholder();
    }

    final ref = PyramidCardRef.pyramid(row, column);
    final exposed = state.isExposed(row, column);
    return _PlayableCard(
      key: Key('pyramid_card_${row}_$column'),
      card: card,
      selected: state.selectedCard == ref,
      highlighted: state.isMatchCandidate(ref),
      enabled: exposed,
      onTap: exposed ? () => _onCardTap(ref) : null,
    );
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      key: const Key('pyramid_win_overlay'),
      theme: WinScreenTheme.pyramid,
      title: 'Pyramid Cleared!',
      subtitle:
          'The cards fall away from top to bottom and the sun breaks through.',
      stats: [
        WinScreenStat(
          label: 'Time',
          value: formatElapsedSeconds(state.elapsedSeconds),
          icon: Icons.timer_outlined,
        ),
        WinScreenStat(
          label: 'Wins',
          value: '${_stats.gamesWon}',
          icon: Icons.emoji_events_outlined,
        ),
        WinScreenStat(
          label: 'Streak',
          value: '${_stats.currentStreak}',
          icon: Icons.local_fire_department_outlined,
        ),
      ],
      onNewGame: _startFreshGame,
      onBackToMenu: _backToMenu,
    );
  }

  Widget _buildPausedOverlay() {
    if (state.isWon) {
      return _buildWinOverlay();
    }
    if (!state.paused) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        key: const Key('pyramid_pause_overlay'),
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Paused',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Game saved. Tap resume when you want to keep going.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _togglePause,
                  child: const Text('Resume'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Pyramid Solitaire'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHowToPlay,
            icon: const Icon(Icons.help_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Game menu',
            onSelected: (value) async {
              switch (value) {
                case 'new':
                  await _startFreshGame();
                case 'stats':
                  await _showStatistics();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new', child: Text('New game')),
              PopupMenuItem(value: 'stats', child: Text('Statistics')),
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
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 16),
                            _buildStockWasteArea(context),
                            const SizedBox(height: 16),
                            _buildPyramid(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildPausedOverlay(),
                ],
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

class _StockCard extends StatelessWidget {
  const _StockCard({required this.stockCount, required this.canRecycle});

  final int stockCount;
  final bool canRecycle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 82,
      height: 116,
      decoration: BoxDecoration(
        color: stockCount > 0 ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            canRecycle ? Icons.refresh_rounded : Icons.style_rounded,
            color: stockCount > 0 ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            stockCount > 0 ? '$stockCount' : (canRecycle ? 'Recycle' : 'Empty'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: stockCount > 0
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPileCard extends StatelessWidget {
  const _EmptyPileCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 82,
      height: 116,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _ClearedCardPlaceholder extends StatelessWidget {
  const _ClearedCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _PlayableCard extends StatelessWidget {
  const _PlayableCard({
    super.key,
    required this.card,
    this.onTap,
    this.selected = false,
    this.highlighted = false,
    this.enabled = true,
  });

  final PyramidCard card;
  final VoidCallback? onTap;
  final bool selected;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = card.isRed ? Colors.red.shade700 : scheme.onSurface;
    final borderColor = selected
        ? scheme.primary
        : highlighted
        ? scheme.tertiary
        : scheme.outlineVariant;
    final background = enabled ? scheme.surface : scheme.surfaceContainerLow;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: kCardDropDuration,
        width: 82,
        height: 116,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: selected || highlighted ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: enabled ? 0.10 : 0.04),
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: enabled ? foreground : foreground.withValues(alpha: 0.45),
            fontWeight: FontWeight.w700,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.rankLabel,
                style: const TextStyle(fontSize: 20, height: 1),
              ),
              Text(
                card.suitSymbol,
                style: const TextStyle(fontSize: 18, height: 1.1),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '${card.value}',
                  style: TextStyle(
                    fontSize: 13,
                    color: foreground.withValues(alpha: 0.75),
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
