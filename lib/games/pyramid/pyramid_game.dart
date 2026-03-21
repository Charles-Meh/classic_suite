import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import 'pyramid_advisor.dart';
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
  PyramidHint? _activeHint;
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
        state = loaded.copyWith(
          paused: false,
          message: loaded.isWon ? loaded.message : 'Game restored.',
        );
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
    _activeHint = null;
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
      _activeHint = null;
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
      _activeHint = null;
      state = previous.copyWith(message: 'Undid the last move.');
    });
    _hasRecordedResult = state.isWon;
    _syncTicker();
    await _persistState();
  }

  Future<void> _onCardTap(PyramidCardRef ref) async {
    final nextState = state.tapCard(ref);
    if (_activeHint != null) {
      setState(() {
        _activeHint = null;
      });
    }
    if (identical(nextState, state) || nextState.encode() == state.encode()) {
      return;
    }
    await _applyState(nextState);
  }

  Future<void> _drawStock() async {
    final nextState = state.drawFromStock();
    if (_activeHint != null) {
      setState(() {
        _activeHint = null;
      });
    }
    if (identical(nextState, state) || nextState.encode() == state.encode()) {
      return;
    }
    await _applyState(nextState);
  }

  void _showHint() {
    setState(() {
      _activeHint = PyramidAdvisor.bestHint(state);
    });
  }

  bool _isHintedCard(PyramidCardRef ref) => _activeHint?.cardRef == ref;

  Future<void> _restartDeal() async {
    final seed = _initialDeal?.seed ?? state.seed;
    await _startFreshGame(seed: seed);
  }

  Future<bool> _confirmNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new game?'),
        content: const Text('Your current pyramid deal will be replaced.'),
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

  Future<void> _confirmAndStartFreshGame() async {
    if (await _confirmNewGame()) {
      await _startFreshGame();
    }
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

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('pyramid_settings_dialog'),
          title: const Text('Pyramid settings'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('pyramid_restart_deal_action'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Restart current deal'),
                  subtitle: const Text(
                    'Replay this exact pyramid layout from the start.',
                  ),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await _restartDeal();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('pyramid_new_deal_action'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.casino_outlined),
                  title: const Text('Start new deal'),
                  subtitle: const Text(
                    'Generate a fresh shuffled pyramid game.',
                  ),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await _confirmAndStartFreshGame();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopShelf() {
    return Center(
      child: Row(
        key: const Key('pyramid_top_shelf'),
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const Key('pyramid_stock'),
            onTap: _drawStock,
            child: _StockCard(stockCount: state.stock.length),
          ),
          const SizedBox(width: 12),
          _buildWasteCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    return GameStatsRow(
      dark: true,
      items: [
        GameStatItem(
          label: 'Time',
          value: formatElapsedSeconds(state.elapsedSeconds),
          icon: Icons.timer_outlined,
        ),
        GameStatItem(
          label: 'Cleared',
          value: '${state.removedCount}/28',
          icon: Icons.layers_clear_outlined,
        ),
      ],
    );
  }

  Widget _buildWasteCard() {
    final top = state.wasteTop;
    if (top == null) {
      return const _EmptyPileCard();
    }
    final ref = PyramidCardRef.waste(state.waste.length - 1);
    return _PlayableCard(
      key: const Key('pyramid_waste_card'),
      card: top,
      selected: state.selectedCard == ref,
      highlighted: _isHintedCard(ref),
      onTap: () => _onCardTap(ref),
    );
  }

  Widget _buildPyramid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 64;
        final cardWidth = math.max(56.0, math.min(84.0, availableWidth / 8.5));
        final horizontalOverlap = cardWidth * 0.52;
        final cardHeight = cardWidth * 1.4;
        final totalWidth = cardWidth + (6 * horizontalOverlap);
        final boardWidth = totalWidth + 12;
        final contentWidth = math.max(availableWidth, boardWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Center(
              child: SizedBox(
                width: boardWidth,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPyramidCard(int row, int column) {
    final card = state.pyramid[row][column];
    if (card.removed) {
      return const SizedBox(width: 82, height: 116);
    }

    final ref = PyramidCardRef.pyramid(row, column);
    final exposed = state.isExposed(row, column);
    return _PlayableCard(
      key: Key('pyramid_card_${row}_$column'),
      card: card,
      selected: state.selectedCard == ref,
      highlighted: _isHintedCard(ref),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Pyramid Solitaire'),
        actions: [
          IconButton(
            key: const Key('pyramid_help_action'),
            tooltip: 'Help',
            onPressed: _showHowToPlay,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            key: const Key('pyramid_settings_action'),
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: _undo,
              undoEnabled: _undoStack.isNotEmpty,
              onHint: _showHint,
              hintEnabled: !state.isWon,
              onNewDeal: _confirmAndStartFreshGame,
              onStatistics: _showStatistics,
              newDealLabel: 'New Deal',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E6B43), Color(0xFF14532D)],
                ),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTopShelf(),
                                const SizedBox(height: 12),
                                _buildHeaderStats(),
                                const SizedBox(height: 24),
                                _buildPyramid(context),
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
  const _StockCard({required this.stockCount});

  final int stockCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClassicPlayingCard(
            card: PlayingCard(Suit.spades, CardValue.ace),
            width: 82,
            height: 116,
            showBack: true,
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$stockCount',
                  key: const Key('pyramid_stock_count'),
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
    );
  }
}

class _EmptyPileCard extends StatelessWidget {
  const _EmptyPileCard();

  @override
  Widget build(BuildContext context) {
    return ClassicCardPlaceholder(
      width: 82,
      height: 116,
      label: '',
      dark: true,
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

  PlayingCard _toPlayingCard() {
    final suit = switch (card.suit) {
      PyramidSuit.clubs => Suit.clubs,
      PyramidSuit.diamonds => Suit.diamonds,
      PyramidSuit.hearts => Suit.hearts,
      PyramidSuit.spades => Suit.spades,
    };
    final value = switch (card.rank) {
      PyramidRank.ace => CardValue.ace,
      PyramidRank.two => CardValue.two,
      PyramidRank.three => CardValue.three,
      PyramidRank.four => CardValue.four,
      PyramidRank.five => CardValue.five,
      PyramidRank.six => CardValue.six,
      PyramidRank.seven => CardValue.seven,
      PyramidRank.eight => CardValue.eight,
      PyramidRank.nine => CardValue.nine,
      PyramidRank.ten => CardValue.ten,
      PyramidRank.jack => CardValue.jack,
      PyramidRank.queen => CardValue.queen,
      PyramidRank.king => CardValue.king,
    };
    return PlayingCard(suit, value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: kCardDropDuration,
        scale: selected ? 1.03 : 1,
        child: ClassicPlayingCard(
          card: _toPlayingCard(),
          width: 82,
          height: 116,
          disabled: !enabled,
          borderColor: Theme.of(context).colorScheme.outlineVariant,
          highlightColor: selected
              ? Theme.of(context).colorScheme.primary
              : highlighted
              ? Theme.of(context).colorScheme.tertiary
              : null,
          borderWidth: selected || highlighted ? 2.2 : 1.2,
          valueLabel: '${card.value}',
        ),
      ),
    );
  }
}
