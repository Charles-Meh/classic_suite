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
import '../klondike/card_model.dart';
import 'freecell_advisor.dart';
import 'freecell_game_state.dart';
import 'freecell_stats.dart';
import 'freecell_stats_store.dart';

class FreeCellGame extends StatefulWidget {
  const FreeCellGame({super.key, this.initialState});

  final FreeCellGameState? initialState;

  @override
  State<FreeCellGame> createState() => _FreeCellGameState();
}

class _FreeCellGameState extends State<FreeCellGame> {
  static const _soundEnabledKey = 'freecell_sound_enabled';
  static const _animationSpeedKey = 'freecell_animation_speed';

  late FreeCellGameState state;
  final List<FreeCellGameState> _history = [];
  final FreeCellStatsStore _statsStore = FreeCellStatsStore();
  Timer? _ticker;

  FreeCellStats _stats = const FreeCellStats();
  _FreeCellAnimationSpeed _animationSpeed = _FreeCellAnimationSpeed.normal;
  _ActiveFreeCellDrag? _activeDrag;
  bool _soundEnabled = true;
  bool _hasRecordedCurrentWin = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? FreeCellGameState();
    _hasRecordedCurrentWin = state.isWon;
    _loadPreferences();
    _loadStats();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _animationSpeed = _FreeCellAnimationSpeed.fromStorage(
        prefs.getString(_animationSpeedKey),
      );
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, _soundEnabled);
    await prefs.setString(_animationSpeedKey, _animationSpeed.storageValue);
  }

  Future<void> _loadStats() async {
    final loaded = await _statsStore.load();
    if (!mounted) {
      return;
    }

    final nextStats = widget.initialState == null
        ? loaded.recordDealStarted()
        : loaded;
    await _statsStore.save(nextStats);
    if (!mounted) {
      return;
    }

    setState(() {
      _stats = nextStats;
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || state.isWon) {
        return;
      }
      setState(() {
        _elapsedSeconds += 1;
      });
    });
  }

  void _recordHistory() {
    _history.add(state.copy());
  }

  bool _runRecordedMutation(bool Function() mutation) {
    _recordHistory();
    var changed = false;
    setState(() {
      changed = mutation();
      if (!changed) {
        _history.removeLast();
      }
      _activeDrag = null;
    });
    if (changed) {
      _maybeRecordWin();
    }
    return changed;
  }

  void _maybeRecordWin() {
    if (_hasRecordedCurrentWin || !state.isWon) {
      return;
    }
    _hasRecordedCurrentWin = true;
    final nextStats = _stats.recordWin(_elapsedSeconds);
    setState(() {
      _stats = nextStats;
    });
    _statsStore.save(nextStats);
  }

  void _recordStartedDeal({required bool resetStreak}) {
    var next = _stats;
    if (resetStreak) {
      next = next.recordAbandonedDeal();
    }
    next = next.recordDealStarted();
    setState(() {
      _stats = next;
      _elapsedSeconds = 0;
    });
    _statsStore.save(next);
  }

  void _undo() {
    if (_history.isEmpty) {
      return;
    }
    setState(() {
      final previous = _history.removeLast();
      state.restoreFrom(previous);
      _activeDrag = null;
      _hasRecordedCurrentWin = state.isWon;
    });
  }

  void _dealNewGame() {
    final shouldResetStreak = !state.isWon && _history.isNotEmpty;
    setState(() {
      state.dealNewGame();
      _history.clear();
      _activeDrag = null;
      _hasRecordedCurrentWin = false;
      _elapsedSeconds = 0;
    });
    _recordStartedDeal(resetStreak: shouldResetStreak);
  }

  Future<void> _confirmNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new deal?'),
        content: const Text('Current progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New Deal'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _dealNewGame();
    }
  }

  Future<void> _autoMoveToFoundation() async {
    if (state.isWon) {
      return;
    }

    _recordHistory();
    var movedAny = false;
    while (mounted) {
      var moved = false;
      setState(() {
        moved = state.autoMoveSafeToFoundation();
        if (moved) {
          movedAny = true;
        }
      });
      if (!moved) {
        break;
      }
      await Future<void>.delayed(_animationSpeed.delay);
    }

    if (!mounted) {
      return;
    }

    if (!movedAny && _history.isNotEmpty) {
      _history.removeLast();
    }
    _maybeRecordWin();
  }

  Future<void> _openSettings() async {
    final result = await showDialog<_FreeCellSettings>(
      context: context,
      builder: (dialogContext) {
        var soundEnabled = _soundEnabled;
        var animationSpeed = _animationSpeed;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('FreeCell settings'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: soundEnabled,
                        title: const Text('Sound'),
                        subtitle: const Text(
                          'Keep the standard card move sounds enabled.',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            soundEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Animation speed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<_FreeCellAnimationSpeed>(
                        groupValue: animationSpeed,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            animationSpeed = value;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            RadioListTile<_FreeCellAnimationSpeed>(
                              value: _FreeCellAnimationSpeed.fast,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Fast'),
                            ),
                            RadioListTile<_FreeCellAnimationSpeed>(
                              value: _FreeCellAnimationSpeed.normal,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Normal'),
                            ),
                            RadioListTile<_FreeCellAnimationSpeed>(
                              value: _FreeCellAnimationSpeed.relaxed,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Relaxed'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _FreeCellSettings(
                        soundEnabled: soundEnabled,
                        animationSpeed: animationSpeed,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _soundEnabled = result.soundEnabled;
      _animationSpeed = result.animationSpeed;
    });
    await _savePreferences();
  }

  Future<void> _openStatistics() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('FreeCell statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(label: 'Deals', value: '${_stats.dealsStarted}'),
              _StatRow(label: 'Wins', value: '${_stats.wins}'),
              _StatRow(
                label: 'Win rate',
                value: '${(_stats.winRate * 100).round()}%',
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

  Future<void> _openHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How FreeCell works'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                HelpSection(
                  title: 'Layout',
                  children: [
                    HelpDiagram(
                      '[FC][FC][FC][FC]   [A♣][A♦][A♥][A♠]\n'
                      ' free cells        foundations\n\n'
                      '[8♣ 7♦ 6♣] [K♥ Q♣] [J♦] ...\n'
                      '       cascades build down in alternating colors',
                    ),
                  ],
                ),
                HelpSection(
                  title: 'Core rules',
                  children: [
                    HelpBulletList(
                      items: [
                        'Build the four foundations from Ace up to King by suit.',
                        'In the cascades, build downward in alternating colors.',
                        'Each free cell holds exactly one card.',
                        'Empty cascades are powerful because they increase the size of runs you can move.',
                        'Tap a card for a smart automatic move, or drag single cards and ordered runs yourself.',
                        'Auto move sends safe cards home when they cannot hurt your position.',
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

  void _handleTap(List<KlondikeCard> cards) {
    final suggestion = FreeCellAdvisor.bestTapMove(state, cards);
    if (suggestion == null) {
      return;
    }
    _runRecordedMutation(() {
      if (suggestion.toFoundation) {
        return state.moveToFoundation(cards.first);
      }
      if (suggestion.toFreecell) {
        return state.moveToFreecell(cards.first);
      }
      final targetIndex = suggestion.targetCascadeIndex;
      if (targetIndex == null) {
        return false;
      }
      return state.moveCardsToCascade(cards, state.cascades[targetIndex]);
    });
  }

  void _setActiveDrag(_ActiveFreeCellDrag drag) {
    if (_activeDrag == drag) {
      return;
    }
    setState(() {
      _activeDrag = drag;
    });
  }

  void _clearActiveDrag() {
    if (_activeDrag == null) {
      return;
    }
    setState(() {
      _activeDrag = null;
    });
  }

  bool _isCascadeCardHidden(int cascadeIndex, int cardIndex) {
    final drag = _activeDrag;
    if (drag == null ||
        drag.zone != _DragZone.cascade ||
        drag.index != cascadeIndex) {
      return false;
    }
    return cardIndex >= drag.startIndex;
  }

  Widget _buildCardFace(
    KlondikeCard card,
    _FreeCellLayoutMetrics metrics, {
    bool highlighted = false,
  }) {
    return AnimatedContainer(
      duration: _animationSpeed.duration,
      curve: Curves.easeOutCubic,
      padding: highlighted ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.cornerRadius + 3),
        border: highlighted
            ? Border.all(color: Colors.amber.shade300, width: 2)
            : null,
      ),
      child: ClassicPlayingCard(
        card: card.card,
        width: metrics.cardWidth,
        height: metrics.cardHeight,
        cornerRadius: metrics.cornerRadius,
      ),
    );
  }

  Widget _buildPlaceholder(
    _FreeCellLayoutMetrics metrics, {
    String? label,
    bool active = false,
  }) {
    return AnimatedContainer(
      duration: _animationSpeed.duration,
      width: metrics.cardWidth,
      height: metrics.cardHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(metrics.cornerRadius),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.42),
          width: active ? 2 : 1.2,
        ),
      ),
      child: label == null
          ? null
          : Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: metrics.cardWidth * 0.28,
                letterSpacing: 1,
              ),
            ),
    );
  }

  Widget _buildFreecellSlot(int index, _FreeCellLayoutMetrics metrics) {
    final card = state.freecells[index];
    return DragTarget<_FreeCellDragData>(
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return SizedBox(
          width: metrics.cardWidth,
          height: metrics.cardHeight,
          child: card == null
              ? _buildPlaceholder(metrics, label: 'FC', active: active)
              : _buildFreecellDraggable(card, index, metrics),
        );
      },
      onWillAcceptWithDetails: (details) =>
          details.data.cards.length == 1 &&
          state.canMoveToFreecell(
            details.data.cards.first,
            freecellIndex: index,
          ),
      onAcceptWithDetails: (details) {
        _runRecordedMutation(
          () => state.moveToFreecell(
            details.data.cards.first,
            freecellIndex: index,
          ),
        );
      },
    );
  }

  Widget _buildFreecellDraggable(
    KlondikeCard card,
    int freecellIndex,
    _FreeCellLayoutMetrics metrics,
  ) {
    return Draggable<_FreeCellDragData>(
      data: _FreeCellDragData([card]),
      feedback: Material(
        color: Colors.transparent,
        child: _buildCardFace(card, metrics),
      ),
      onDragStarted: () => _setActiveDrag(
        const _ActiveFreeCellDrag(
          zone: _DragZone.freecell,
          index: 0,
          startIndex: 0,
          length: 1,
        ).copyWith(index: freecellIndex),
      ),
      onDragEnd: (_) => _clearActiveDrag(),
      onDraggableCanceled: (velocity, offset) => _clearActiveDrag(),
      onDragCompleted: _clearActiveDrag,
      childWhenDragging: _buildPlaceholder(metrics, label: 'FC'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap([card]),
        child: _buildCardFace(card, metrics),
      ),
    );
  }

  Widget _buildFoundationSlot(int index, _FreeCellLayoutMetrics metrics) {
    final pile = state.foundations[index];
    return DragTarget<_FreeCellDragData>(
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return SizedBox(
          width: metrics.cardWidth,
          height: metrics.cardHeight,
          child: pile.isEmpty
              ? _buildPlaceholder(
                  metrics,
                  label: _foundationLabel(index),
                  active: active,
                )
              : _buildFoundationDraggable(pile.last, index, metrics),
        );
      },
      onWillAcceptWithDetails: (details) =>
          details.data.cards.length == 1 &&
          state.canMoveToFoundation(details.data.cards.first),
      onAcceptWithDetails: (details) {
        _runRecordedMutation(
          () => state.moveToFoundation(details.data.cards.first),
        );
      },
    );
  }

  Widget _buildFoundationDraggable(
    KlondikeCard card,
    int foundationIndex,
    _FreeCellLayoutMetrics metrics,
  ) {
    return Draggable<_FreeCellDragData>(
      data: _FreeCellDragData([card]),
      feedback: Material(
        color: Colors.transparent,
        child: _buildCardFace(card, metrics),
      ),
      onDragStarted: () => _setActiveDrag(
        const _ActiveFreeCellDrag(
          zone: _DragZone.foundation,
          index: 0,
          startIndex: 0,
          length: 1,
        ).copyWith(index: foundationIndex),
      ),
      onDragEnd: (_) => _clearActiveDrag(),
      onDraggableCanceled: (velocity, offset) => _clearActiveDrag(),
      onDragCompleted: _clearActiveDrag,
      childWhenDragging: _buildPlaceholder(
        metrics,
        label: _foundationLabel(foundationIndex),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap([card]),
        child: _buildCardFace(card, metrics),
      ),
    );
  }

  Widget _buildCascade(
    int cascadeIndex,
    _FreeCellLayoutMetrics metrics,
    double regionHeight,
  ) {
    final pile = state.cascades[cascadeIndex];
    final visibleEntries = [
      for (int i = 0; i < pile.length; i++)
        if (!_isCascadeCardHidden(cascadeIndex, i)) (index: i, card: pile[i]),
    ];
    final visibleCards = [for (final entry in visibleEntries) entry.card];
    final pileHeight = _cascadeHeight(visibleCards, metrics);
    final dropHintTop = _cascadeTopForIndex(visibleCards.length, metrics);

    return DragTarget<_FreeCellDragData>(
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return SizedBox(
          width: metrics.cardWidth,
          height: math.max(regionHeight, pileHeight),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (pile.isEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  child: _buildPlaceholder(metrics, label: 'K', active: active),
                ),
              if (pile.isNotEmpty && active)
                Positioned(
                  left: 0,
                  top: dropHintTop,
                  child: _buildPlaceholder(metrics, active: true),
                ),
              for (
                int visibleIndex = 0;
                visibleIndex < visibleEntries.length;
                visibleIndex++
              )
                Positioned(
                  left: 0,
                  top: _cascadeTopForIndex(visibleIndex, metrics),
                  width: metrics.cardWidth,
                  height: metrics.cardHeight,
                  child: _buildCascadeDraggable(
                    pile,
                    visibleEntries[visibleIndex].index,
                    cascadeIndex,
                    metrics,
                  ),
                ),
            ],
          ),
        );
      },
      onWillAcceptWithDetails: (details) =>
          state.canMoveCardsToCascade(details.data.cards, pile),
      onAcceptWithDetails: (details) {
        _runRecordedMutation(
          () => state.moveCardsToCascade(details.data.cards, pile),
        );
      },
    );
  }

  Widget _buildCascadeDraggable(
    List<KlondikeCard> pile,
    int startIndex,
    int cascadeIndex,
    _FreeCellLayoutMetrics metrics,
  ) {
    final stack = pile.sublist(startIndex);
    final draggable = _isOrderedStack(stack);

    if (!draggable) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap([pile[startIndex]]),
        child: _buildCardFace(pile[startIndex], metrics),
      );
    }

    return Draggable<_FreeCellDragData>(
      data: _FreeCellDragData(stack),
      feedback: Material(
        color: Colors.transparent,
        child: _buildStack(stack, metrics),
      ),
      onDragStarted: () => _setActiveDrag(
        _ActiveFreeCellDrag(
          zone: _DragZone.cascade,
          index: cascadeIndex,
          startIndex: startIndex,
          length: stack.length,
        ),
      ),
      onDragEnd: (_) => _clearActiveDrag(),
      onDraggableCanceled: (velocity, offset) => _clearActiveDrag(),
      onDragCompleted: _clearActiveDrag,
      childWhenDragging: SizedBox(
        width: metrics.cardWidth,
        height: metrics.cardHeight,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(stack),
        child: _buildCardFace(pile[startIndex], metrics),
      ),
    );
  }

  Widget _buildStack(List<KlondikeCard> cards, _FreeCellLayoutMetrics metrics) {
    return SizedBox(
      width: metrics.cardWidth,
      height: _cascadeHeight(cards, metrics),
      child: Stack(
        children: [
          for (int index = 0; index < cards.length; index++)
            Positioned(
              left: 0,
              top: _cascadeTopForIndex(index, metrics),
              width: metrics.cardWidth,
              height: metrics.cardHeight,
              child: _buildCardFace(cards[index], metrics),
            ),
        ],
      ),
    );
  }

  bool _isOrderedStack(List<KlondikeCard> cards) {
    if (cards.isEmpty) {
      return false;
    }
    for (int i = 0; i < cards.length - 1; i++) {
      final upper = cards[i];
      final lower = cards[i + 1];
      final upperRed =
          upper.card.suit == Suit.hearts || upper.card.suit == Suit.diamonds;
      final lowerRed =
          lower.card.suit == Suit.hearts || lower.card.suit == Suit.diamonds;
      if (upperRed == lowerRed || upper.valueIndex != lower.valueIndex + 1) {
        return false;
      }
    }
    return true;
  }

  double _cascadeTopForIndex(int index, _FreeCellLayoutMetrics metrics) =>
      index * metrics.cascadeOverlap;

  double _cascadeHeight(
    List<KlondikeCard> cards,
    _FreeCellLayoutMetrics metrics,
  ) {
    if (cards.isEmpty) {
      return metrics.cardHeight;
    }
    return _cascadeTopForIndex(cards.length - 1, metrics) + metrics.cardHeight;
  }

  double _cascadeRegionHeight(_FreeCellLayoutMetrics metrics) {
    var tallest = metrics.cardHeight;
    for (final pile in state.cascades) {
      tallest = math.max(tallest, _cascadeHeight(pile, metrics));
    }
    return tallest;
  }

  String _foundationLabel(int index) {
    const labels = ['C', 'D', 'H', 'S'];
    return labels[index];
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.freecell,
      title: 'FreeCell Clear!',
      subtitle:
          'The foundations filled like water. Every cell is unlocked now.',
      stats: [
        WinScreenStat(
          label: 'Time',
          value: formatElapsedSeconds(_elapsedSeconds),
          icon: Icons.timer_outlined,
        ),
        WinScreenStat(
          label: 'Wins',
          value: '${_stats.wins}',
          icon: Icons.emoji_events_outlined,
        ),
        WinScreenStat(
          label: 'Streak',
          value: '${_stats.currentStreak}',
          icon: Icons.local_fire_department_outlined,
        ),
      ],
      onNewGame: _dealNewGame,
      onBackToMenu: _backToMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
        title: const Text('FreeCell'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _openHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      bottomNavigationBar: GameBottomBar(
        onUndo: _history.isEmpty ? null : _undo,
        onHint: null,
        hintEnabled: false,
        onNewDeal: _confirmNewGame,
        onStatistics: _openStatistics,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E6B43), Color(0xFF14532D)],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _FreeCellLayoutMetrics.fromWidth(
                constraints.maxWidth,
              );
              final cascadeHeight = _cascadeRegionHeight(metrics);
              final cascadeBoardWidth =
                  (metrics.cardWidth * 8) + (metrics.cascadeSpacing * 7);
              return Stack(
                children: [
                  Column(
                    children: [
                      Card(
                        color: Colors.black.withValues(alpha: 0.12),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              GameStatsRow(
                                items: [
                                  GameStatItem(
                                    label: 'Time',
                                    value: formatElapsedSeconds(_elapsedSeconds),
                                    icon: Icons.timer_outlined,
                                  ),
                                  GameStatItem(
                                    label: 'Free cells',
                                    value: '${state.emptyFreecellCount}/4',
                                    icon: Icons.inbox_outlined,
                                  ),
                                  GameStatItem(
                                    label: 'Open columns',
                                    value: '${state.emptyCascadeCount}',
                                    icon: Icons.view_week_outlined,
                                  ),
                                  GameStatItem(
                                    label: 'Best',
                                    value: _stats.bestTimeSeconds == null
                                        ? '—'
                                        : formatElapsedSeconds(
                                            _stats.bestTimeSeconds!,
                                          ),
                                    icon: Icons.emoji_events_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.center,
                                child: OutlinedButton.icon(
                                  onPressed: _autoMoveToFoundation,
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Auto move'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: metrics.sectionSpacing),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < 4; i++) ...[
                              if (i > 0) SizedBox(width: metrics.groupSpacing),
                              _buildFreecellSlot(i, metrics),
                            ],
                            SizedBox(width: metrics.groupSpacing * 2),
                            for (int i = 0; i < 4; i++) ...[
                              if (i > 0) SizedBox(width: metrics.groupSpacing),
                              _buildFoundationSlot(i, metrics),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: metrics.sectionSpacing),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(
                              constraints.maxWidth,
                              cascadeBoardWidth,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                height: cascadeHeight,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (int i = 0; i < 8; i++) ...[
                                      if (i > 0)
                                        SizedBox(width: metrics.cascadeSpacing),
                                      _buildCascade(i, metrics, cascadeHeight),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  if (state.isWon) _buildWinOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _DragZone { cascade, freecell, foundation }

enum _FreeCellAnimationSpeed {
  fast('fast', kCardFlipDuration),
  normal('normal', kCardMoveDuration),
  relaxed('relaxed', Duration(milliseconds: 260));

  const _FreeCellAnimationSpeed(this.storageValue, this.duration);

  final String storageValue;
  final Duration duration;

  Duration get delay => duration;

  static _FreeCellAnimationSpeed fromStorage(String? value) {
    return _FreeCellAnimationSpeed.values.firstWhere(
      (speed) => speed.storageValue == value,
      orElse: () => _FreeCellAnimationSpeed.normal,
    );
  }
}

class _FreeCellSettings {
  const _FreeCellSettings({
    required this.soundEnabled,
    required this.animationSpeed,
  });

  final bool soundEnabled;
  final _FreeCellAnimationSpeed animationSpeed;
}

class _FreeCellLayoutMetrics {
  const _FreeCellLayoutMetrics({
    required this.cardWidth,
    required this.cardHeight,
    required this.cornerRadius,
    required this.groupSpacing,
    required this.cascadeSpacing,
    required this.sectionSpacing,
    required this.cascadeOverlap,
  });

  final double cardWidth;
  final double cardHeight;
  final double cornerRadius;
  final double groupSpacing;
  final double cascadeSpacing;
  final double sectionSpacing;
  final double cascadeOverlap;

  factory _FreeCellLayoutMetrics.fromWidth(double width) {
    final cascadeSpacing = width < 480
        ? 4.0
        : width < 900
        ? 6.0
        : 10.0;
    final groupSpacing = width < 480 ? 6.0 : 10.0;
    final available = width - (cascadeSpacing * 7);
    final cardWidth = (available / 8).clamp(54.0, 98.0);
    final cardHeight = cardWidth * 1.42;
    return _FreeCellLayoutMetrics(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      cornerRadius: math.max(6, cardWidth * 0.08),
      groupSpacing: groupSpacing,
      cascadeSpacing: cascadeSpacing,
      sectionSpacing: width < 480 ? 16.0 : 22.0,
      cascadeOverlap: (cardHeight * 0.28).clamp(20.0, 32.0),
    );
  }
}

class _FreeCellDragData {
  const _FreeCellDragData(this.cards);

  final List<KlondikeCard> cards;
}

class _ActiveFreeCellDrag {
  const _ActiveFreeCellDrag({
    required this.zone,
    required this.index,
    required this.startIndex,
    required this.length,
  });

  final _DragZone zone;
  final int index;
  final int startIndex;
  final int length;

  _ActiveFreeCellDrag copyWith({
    _DragZone? zone,
    int? index,
    int? startIndex,
    int? length,
  }) {
    return _ActiveFreeCellDrag(
      zone: zone ?? this.zone,
      index: index ?? this.index,
      startIndex: startIndex ?? this.startIndex,
      length: length ?? this.length,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ActiveFreeCellDrag &&
        other.zone == zone &&
        other.index == index &&
        other.startIndex == startIndex &&
        other.length == length;
  }

  @override
  int get hashCode => Object.hash(zone, index, startIndex, length);
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
