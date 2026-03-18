import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import '../klondike/card_model.dart';
import 'spider_advisor.dart';
import 'spider_game_state.dart';
import 'spider_stats.dart';
import 'spider_stats_store.dart';

class SpiderGame extends StatefulWidget {
  const SpiderGame({super.key, this.initialState});

  final SpiderGameState? initialState;

  @override
  State<SpiderGame> createState() => _SpiderGameState();
}

class _SpiderGameState extends State<SpiderGame> with WidgetsBindingObserver {
  static const Duration _saveInterval = Duration(seconds: 15);

  late SpiderGameState state;
  late SpiderGameState _initialDealState;
  final List<SpiderGameState> _history = [];
  final List<SpiderGameState> _redoHistory = [];
  final SpiderStatsStore _statsStore = SpiderStatsStore();
  _ActiveSpiderDrag? _activeTableauDrag;
  SpiderSuggestion? _activeHint;
  Timer? _ticker;
  Timer? _periodicSaveTimer;
  SpiderStats _stats = const SpiderStats();
  bool _loading = true;
  bool _hasRecordedCurrentWin = false;
  int _dealAnimationNonce = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState?.copy() ?? SpiderGameState();
    _initialDealState = state.copy();
    _hasRecordedCurrentWin = state.isWon;
    _loadGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _periodicSaveTimer?.cancel();
    _persistState();
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

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = widget.initialState == null
        ? SpiderGameState.tryDecode(prefs.getString(SpiderGameState.storageKey))
        : null;
    final loadedStats = await _statsStore.load();
    if (!mounted) {
      return;
    }

    if (saved != null) {
      state = saved;
    }

    final nextStats = widget.initialState == null && saved == null
        ? loadedStats.recordDealStarted()
        : loadedStats;
    await _statsStore.save(nextStats);
    if (!mounted) {
      return;
    }

    setState(() {
      _stats = nextStats;
      _initialDealState = state.copy();
      _hasRecordedCurrentWin = state.isWon;
      _loading = false;
    });
    _syncTimers();
    if (saved == null) {
      await _persistState();
    }
  }

  Future<bool?> _showResumeDialog(SpiderGameState saved) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resume Game?'),
          content: Text(
            'Resume your saved Spider game?\n\nMoves ${saved.moveCount} • Time ${formatElapsedSeconds(saved.elapsedSeconds)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('New deal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  void _syncTimers() {
    _ticker?.cancel();
    if (!state.isWon) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || state.isWon) {
          return;
        }
        setState(() {
          state.incrementElapsed();
        });
        _persistState();
      });
    }

    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer.periodic(_saveInterval, (_) => _persistState());
  }

  Future<void> _persistState() async {
    if (widget.initialState != null || _loading || state.isWon) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SpiderGameState.storageKey, state.encode());
  }

  Future<void> _clearSavedState() async {
    if (widget.initialState != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SpiderGameState.storageKey);
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

  bool _applySuggestion(SpiderSuggestion suggestion) {
    switch (suggestion.kind) {
      case SpiderSuggestionKind.moveRun:
        final targetPileIndex = suggestion.targetPileIndex;
        if (targetPileIndex == null) {
          return false;
        }
        return state.moveCardsToTableau(
          suggestion.cards,
          state.tableau[targetPileIndex],
        );
      case SpiderSuggestionKind.dealFromStock:
        return state.dealFromStock();
      case SpiderSuggestionKind.noMoves:
        return false;
    }
  }

  void _recordHistory() {
    _history.add(state.copy());
    _redoHistory.clear();
  }

  bool _runRecordedMutation(bool Function() mutation) {
    _recordHistory();
    var changed = false;
    setState(() {
      changed = mutation();
      if (!changed) {
        _history.removeLast();
      }
      _activeHint = null;
      _activeTableauDrag = null;
    });
    if (changed) {
      _maybeRecordWin();
      _persistState();
    }
    return changed;
  }

  void _maybeRecordWin() {
    if (_hasRecordedCurrentWin || !state.isWon) {
      return;
    }
    _hasRecordedCurrentWin = true;
    final nextStats = _stats.recordWin();
    setState(() {
      _stats = nextStats;
    });
    _statsStore.save(nextStats);
    _clearSavedState();
    _syncTimers();
  }

  void _recordStartedDeal({required bool resetStreak}) {
    var nextStats = _stats;
    if (resetStreak) {
      nextStats = nextStats.recordAbandonedDeal();
    }
    nextStats = nextStats.recordDealStarted();
    setState(() {
      _stats = nextStats;
    });
    _statsStore.save(nextStats);
  }

  void _triggerDealAnimation() {
    setState(() {
      _dealAnimationNonce++;
    });
  }

  void _handleStockTap() {
    final changed = _runRecordedMutation(state.dealFromStock);
    if (changed) {
      _triggerDealAnimation();
      return;
    }
    if (state.stock.isNotEmpty) {
      _showMessage('Fill every tableau column before dealing a new row.');
    }
  }

  void _handleCardTap(int pileIndex, int cardIndex) {
    final suggestion = SpiderAdvisor.bestTapMove(state, pileIndex, cardIndex);
    if (suggestion == null) {
      return;
    }
    _runRecordedMutation(() => _applySuggestion(suggestion));
  }

  void _undoMove() {
    if (_history.isEmpty) {
      return;
    }
    setState(() {
      _redoHistory.add(state.copy());
      final previous = _history.removeLast();
      state.restoreFrom(previous);
      _activeHint = null;
      _activeTableauDrag = null;
      _hasRecordedCurrentWin = state.isWon;
    });
    _syncTimers();
    _persistState();
  }

  void _redoMove() {
    if (_redoHistory.isEmpty) {
      return;
    }
    setState(() {
      _history.add(state.copy());
      final next = _redoHistory.removeLast();
      state.restoreFrom(next);
      _activeHint = null;
      _activeTableauDrag = null;
      _hasRecordedCurrentWin = state.isWon;
    });
  }

  void _restartDeal() {
    setState(() {
      state.restoreFrom(_initialDealState);
      _history.clear();
      _redoHistory.clear();
      _activeHint = null;
      _activeTableauDrag = null;
      _hasRecordedCurrentWin = state.isWon;
    });
  }

  void _dealNewGame({int? suitMode}) {
    final shouldResetStreak = !state.isWon && _history.isNotEmpty;
    setState(() {
      if (suitMode != null) {
        state.suitMode = suitMode;
      }
      state.dealNewGame();
      _initialDealState = state.copy();
      _history.clear();
      _redoHistory.clear();
      _activeHint = null;
      _activeTableauDrag = null;
      _hasRecordedCurrentWin = false;
      _dealAnimationNonce = 0;
    });
    _recordStartedDeal(resetStreak: shouldResetStreak);
  }

  void _showHint() {
    setState(() {
      _activeHint = SpiderAdvisor.bestHint(state);
    });
  }

  Future<void> _openSettings() async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        int selectedSuitMode = state.suitMode;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Spider settings'),
              content: SizedBox(
                width: 360,
                child: RadioGroup<int>(
                  groupValue: selectedSuitMode,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedSuitMode = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      RadioListTile<int>(
                        value: 1,
                        contentPadding: EdgeInsets.zero,
                        title: Text('1-suit'),
                        subtitle: Text(
                          'Classic beginner mode. Fastest wins and easiest planning.',
                        ),
                      ),
                      RadioListTile<int>(
                        value: 2,
                        contentPadding: EdgeInsets.zero,
                        title: Text('2-suit'),
                        subtitle: Text(
                          'Balanced difficulty with two suits to manage.',
                        ),
                      ),
                      RadioListTile<int>(
                        value: 4,
                        contentPadding: EdgeInsets.zero,
                        title: Text('4-suit'),
                        subtitle: Text(
                          'Full Spider challenge with all four suits.',
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
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedSuitMode),
                  child: const Text('Apply and deal'),
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
    _dealNewGame(suitMode: result);
  }

  Future<void> _openHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How to play Spider'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  HelpSection(
                    title: 'Goal',
                    children: [
                      Text(
                        'Build complete same-suit runs from King down to Ace. Every completed run is cleared. Clear all eight runs to win.',
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Same-suit run example',
                    children: [
                      HelpDiagram(
                        'K♠ Q♠ J♠ 10♠ 9♠ 8♠ 7♠ 6♠ 5♠ 4♠ 3♠ 2♠ A♠\n\nMixed suits can stack temporarily, but only a same-suit run moves as one clean block.',
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Suit modes',
                    children: [
                      HelpBulletList(
                        items: [
                          '1-suit: easiest mode, all cards are the same suit.',
                          '2-suit: medium difficulty, two suits appear.',
                          '4-suit: classic hard mode, all four suits appear.',
                        ],
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Moves',
                    children: [
                      HelpBulletList(
                        items: [
                          'Move face-up cards in descending order.',
                          'You can place a run on a card that is exactly one rank higher.',
                          'Empty columns can hold any card or valid run.',
                          'Only runs in the same suit are fully movable as a stack.',
                        ],
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Dealing new cards',
                    children: [
                      Text(
                        'Tap the stock to deal one new card to each tableau column. You must have at least one card in every column before dealing.',
                      ),
                    ],
                  ),
                ],
              ),
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

  Future<void> _openStatistics() async {
    if (!mounted) {
      return;
    }
    final percent = (_stats.winRate * 100).round();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Spider statistics'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        label: 'Deals',
                        value: '${_stats.dealsStarted}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatTile(
                        label: 'Wins',
                        value: '${_stats.wins}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        label: 'Win rate',
                        value: '$percent%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatTile(
                        label: 'Best streak',
                        value: '${_stats.bestStreak}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatTile(
                  label: 'Current streak',
                  value: '${_stats.currentStreak}',
                  fullWidth: true,
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

  Widget _buildStatTile({
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  bool _isHiddenByActiveDrag(int pileIndex, int cardIndex) {
    final drag = _activeTableauDrag;
    if (drag == null || drag.pileIndex != pileIndex) {
      return false;
    }
    return cardIndex >= drag.startIndex;
  }

  void _clearActiveDrag() {
    if (_activeTableauDrag == null) {
      return;
    }
    setState(() {
      _activeTableauDrag = null;
    });
  }

  void _setActiveDrag(int pileIndex, int startIndex) {
    final next = _ActiveSpiderDrag(
      pileIndex: pileIndex,
      startIndex: startIndex,
    );
    if (_activeTableauDrag == next) {
      return;
    }
    setState(() {
      _activeTableauDrag = next;
    });
  }

  Widget _cardWidget(
    KlondikeCard card,
    _SpiderLayoutMetrics metrics, {
    _HintRole role = _HintRole.none,
    Key? key,
  }) {
    return _buildHintFrame(
      key: key,
      role: role,
      borderRadius: BorderRadius.circular(metrics.cornerRadius + 3),
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: metrics.cardWidth,
        height: metrics.cardHeight,
        child: PlayingCardView(
          card: card.card,
          showBack: !card.faceUp,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.cornerRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildStock(_SpiderLayoutMetrics metrics) {
    final role = _stockHintRole;
    final child = state.stock.isEmpty
        ? _buildSlotPlaceholder(metrics, label: 'STK', role: role)
        : SizedBox(
            width: metrics.cardWidth,
            height: metrics.cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (
                  int layer = 0;
                  layer < math.min(state.dealsRemaining, 3);
                  layer++
                )
                  Positioned(
                    left: layer * 2,
                    top: layer * 2,
                    child: _cardWidget(
                      KlondikeCard(PlayingCard(Suit.spades, CardValue.ace)),
                      metrics,
                    ),
                  ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${state.dealsRemaining}',
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

    return GestureDetector(
      key: const Key('spider_stock'),
      onTap: _handleStockTap,
      child: _buildHintFrame(
        key: role == _HintRole.none ? null : const Key('spider_hint_stock'),
        role: role,
        borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
        padding: const EdgeInsets.all(2),
        child: child,
      ),
    );
  }

  Widget _buildCompletedRun(int index, _SpiderLayoutMetrics metrics) {
    final role = _completedRunHintRole(index);
    if (index >= state.completedRuns.length) {
      return _buildSlotPlaceholder(metrics, label: 'AK', role: role);
    }
    final run = state.completedRuns[index];
    return _buildHintFrame(
      role: role,
      borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
      padding: const EdgeInsets.all(2),
      child: _cardWidget(run.first, metrics),
    );
  }

  Widget _buildSlotPlaceholder(
    _SpiderLayoutMetrics metrics, {
    String? label,
    _HintRole role = _HintRole.none,
  }) {
    final borderColor = role == _HintRole.source
        ? const Color(0xFFFFD971)
        : role == _HintRole.target
        ? const Color(0xFFBDE0FF)
        : Colors.white.withValues(alpha: 0.45);
    final backgroundColor = role == _HintRole.source
        ? const Color(0x33F6C453)
        : role == _HintRole.target
        ? const Color(0x3329B6F6)
        : Colors.white.withValues(alpha: 0.08);
    final decoration = _hintDecoration(role);

    return _buildHintFrame(
      role: role,
      borderRadius: BorderRadius.circular(metrics.cornerRadius),
      child: Container(
        width: metrics.cardWidth,
        height: metrics.cardHeight,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(metrics.cornerRadius),
          border: Border.all(
            color: borderColor,
            width: role == _HintRole.none ? 1.2 : 2,
          ),
          boxShadow: decoration?.boxShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          label ?? '',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: metrics.cardWidth * 0.24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildHintFrame({
    required Widget child,
    _HintRole role = _HintRole.none,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Key? key,
  }) {
    final decoration = _hintDecoration(role);
    return AnimatedContainer(
      key: key,
      duration: kCardHighlightDuration,
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: decoration == null
          ? null
          : BoxDecoration(
              borderRadius: borderRadius,
              color: decoration.color,
              border: decoration.border,
              boxShadow: decoration.boxShadow,
            ),
      child: child,
    );
  }

  _HintDecoration? _hintDecoration(_HintRole role) {
    switch (role) {
      case _HintRole.none:
        return null;
      case _HintRole.source:
        return const _HintDecoration(
          color: Color(0x26F6C453),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFF6C453), width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x55F6C453),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        );
      case _HintRole.target:
        return const _HintDecoration(
          color: Color(0x1F29B6F6),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFF8DD9FF), width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x4429B6F6),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        );
    }
  }

  Widget _buildStack(List<KlondikeCard> cards, _SpiderLayoutMetrics metrics) {
    if (cards.isEmpty) {
      return SizedBox(width: metrics.cardWidth, height: metrics.cardHeight);
    }

    return SizedBox(
      width: metrics.cardWidth,
      height: _stackHeight(cards, metrics),
      child: Stack(
        children: [
          for (int i = 0; i < cards.length; i++)
            Positioned(
              left: 0,
              top: _stackOffsetForIndex(cards, i, metrics),
              width: metrics.cardWidth,
              height: metrics.cardHeight,
              child: _cardWidget(cards[i], metrics),
            ),
        ],
      ),
    );
  }

  Widget _buildTableauPile(
    int pileIndex,
    _SpiderLayoutMetrics metrics,
    double regionHeight,
  ) {
    final pile = state.tableau[pileIndex];
    final visibleEntries = [
      for (int idx = 0; idx < pile.length; idx++)
        if (!_isHiddenByActiveDrag(pileIndex, idx))
          (index: idx, card: pile[idx]),
    ];
    final visibleCards = [for (final entry in visibleEntries) entry.card];
    final pileHeight = _stackHeight(visibleCards, metrics);
    final dropHintTop = _stackOffsetForIndex(
      visibleCards,
      visibleCards.length,
      metrics,
    );

    return DragTarget<List<KlondikeCard>>(
      key: Key('spider_tableau_$pileIndex'),
      builder: (context, candidate, rejected) {
        final hintRole = _tableauHintRole(pileIndex);
        final showDropHint =
            candidate.isNotEmpty || hintRole == _HintRole.target;
        return _buildHintFrame(
          role: hintRole == _HintRole.target
              ? _HintRole.target
              : _HintRole.none,
          borderRadius: BorderRadius.circular(metrics.cornerRadius + 6),
          padding: const EdgeInsets.all(2),
          child: SizedBox(
            width: metrics.cardWidth,
            height: math.max(regionHeight, pileHeight),
            child: pile.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: _buildSlotPlaceholder(
                      metrics,
                      label: 'Any',
                      role: hintRole,
                    ),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (showDropHint)
                        Positioned(
                          left: 0,
                          top: dropHintTop,
                          child: KeyedSubtree(
                            key: Key('spider_tableau_${pileIndex}_drop_hint'),
                            child: _buildSlotPlaceholder(
                              metrics,
                              label: '',
                              role: _HintRole.target,
                            ),
                          ),
                        ),
                      for (
                        int visibleIndex = 0;
                        visibleIndex < visibleEntries.length;
                        visibleIndex++
                      )
                        Positioned(
                          left: 0,
                          top: _stackOffsetForIndex(
                            visibleCards,
                            visibleIndex,
                            metrics,
                          ),
                          width: metrics.cardWidth,
                          height: metrics.cardHeight,
                          child:
                              visibleEntries[visibleIndex].card.faceUp &&
                                  state.canPickUpRun(
                                    pileIndex,
                                    visibleEntries[visibleIndex].index,
                                  )
                              ? _buildDraggableTableauCard(
                                  pile,
                                  visibleEntries[visibleIndex].index,
                                  pileIndex,
                                  metrics,
                                )
                              : _cardWidget(
                                  visibleEntries[visibleIndex].card,
                                  metrics,
                                  role: _cardHintRole(
                                    pileIndex,
                                    visibleEntries[visibleIndex].index,
                                  ),
                                ),
                        ),
                    ],
                  ),
          ),
        );
      },
      onWillAcceptWithDetails: (details) {
        return state.canMoveCardsToTableau(details.data, pile);
      },
      onAcceptWithDetails: (details) {
        _runRecordedMutation(
          () => state.moveCardsToTableau(details.data, pile),
        );
      },
    );
  }

  Widget _buildDraggableTableauCard(
    List<KlondikeCard> pile,
    int idx,
    int pileIndex,
    _SpiderLayoutMetrics metrics,
  ) {
    final card = pile[idx];
    final stack = pile.sublist(idx);
    return Draggable<List<KlondikeCard>>(
      key: Key('spider_tableau_${pileIndex}_card_$idx'),
      data: stack,
      onDragStarted: () => _setActiveDrag(pileIndex, idx),
      onDragUpdate: (_) => _setActiveDrag(pileIndex, idx),
      onDragEnd: (_) => _clearActiveDrag(),
      onDraggableCanceled: (_, offset) => _clearActiveDrag(),
      onDragCompleted: _clearActiveDrag,
      feedback: Material(
        color: Colors.transparent,
        child: _buildStack(stack, metrics),
      ),
      childWhenDragging: SizedBox(
        width: metrics.cardWidth,
        height: metrics.cardHeight,
      ),
      child: GestureDetector(
        onTap: () => _handleCardTap(pileIndex, idx),
        child: _cardWidget(card, metrics, role: _cardHintRole(pileIndex, idx)),
      ),
    );
  }

  Widget _buildStatusChip(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.88)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintBanner() {
    final hint = _activeHint;
    return AnimatedSwitcher(
      duration: kCardHighlightDuration,
      child: hint == null
          ? const SizedBox.shrink()
          : Container(
              key: const Key('spider_hint_banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _hintIcon(hint.kind),
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hint.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _hintIcon(SpiderSuggestionKind kind) {
    return switch (kind) {
      SpiderSuggestionKind.moveRun => Icons.compare_arrows_rounded,
      SpiderSuggestionKind.dealFromStock => Icons.layers_outlined,
      SpiderSuggestionKind.noMoves => Icons.info_outline_rounded,
    };
  }

  _HintRole _cardHintRole(int pileIndex, int cardIndex) {
    final hint = _activeHint;
    if (hint == null || hint.kind != SpiderSuggestionKind.moveRun) {
      return _HintRole.none;
    }
    if (hint.sourcePileIndex != pileIndex || hint.sourceCardIndex == null) {
      return _HintRole.none;
    }
    return cardIndex >= hint.sourceCardIndex!
        ? _HintRole.source
        : _HintRole.none;
  }

  _HintRole _tableauHintRole(int pileIndex) {
    final hint = _activeHint;
    if (hint == null || hint.kind != SpiderSuggestionKind.moveRun) {
      return _HintRole.none;
    }
    return hint.targetPileIndex == pileIndex
        ? _HintRole.target
        : _HintRole.none;
  }

  _HintRole get _stockHintRole {
    final hint = _activeHint;
    if (hint == null || hint.kind != SpiderSuggestionKind.dealFromStock) {
      return _HintRole.none;
    }
    return _HintRole.source;
  }

  _HintRole _completedRunHintRole(int index) {
    return _HintRole.none;
  }

  double _stackHeight(List<KlondikeCard> cards, _SpiderLayoutMetrics metrics) {
    if (cards.isEmpty) {
      return metrics.cardHeight;
    }
    return _stackOffsetForIndex(cards, cards.length - 1, metrics) +
        metrics.cardHeight;
  }

  double _stackOffsetForIndex(
    List<KlondikeCard> cards,
    int index,
    _SpiderLayoutMetrics metrics,
  ) {
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += cards[i].faceUp
          ? metrics.faceUpOverlap
          : metrics.faceDownOverlap;
    }
    return offset;
  }

  double _tableauRegionHeight(_SpiderLayoutMetrics metrics) {
    double tallest = metrics.cardHeight;
    for (final pile in state.tableau) {
      tallest = math.max(tallest, _stackHeight(pile, metrics));
    }
    return tallest;
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay(_SpiderLayoutMetrics metrics) {
    return GameWinScreen(
      key: const Key('spider_win_overlay'),
      theme: WinScreenTheme.spider,
      title: 'Spider Solved!',
      subtitle:
          'Completed runs stack away cleanly. Spin up another Spider deal anytime.',
      stats: [
        WinScreenStat(
          label: 'Runs',
          value: '${state.completedRuns.length}/8',
          icon: Icons.layers_outlined,
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
      newGameLabel: 'New Deal',
    );
  }

  Widget _buildTopShelf(_SpiderLayoutMetrics metrics) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStock(metrics),
        SizedBox(width: metrics.groupSpacing),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < 8; i++) ...[
                  if (i > 0) SizedBox(width: metrics.foundationSpacing),
                  _buildCompletedRun(i, metrics),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3F25),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<int>(value: 1, label: Text('1-suit')),
                    ButtonSegment<int>(value: 2, label: Text('2-suit')),
                    ButtonSegment<int>(value: 4, label: Text('4-suit')),
                  ],
                  selected: {state.suitMode},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    final next = selection.first;
                    if (next == state.suitMode) {
                      return;
                    }
                    _dealNewGame(suitMode: next);
                  },
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(
                      Colors.white.withValues(alpha: 0.96),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white.withValues(alpha: 0.18);
                      }
                      return Colors.white.withValues(alpha: 0.05);
                    }),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _dealNewGame,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('New Game'),
                ),
                OutlinedButton.icon(
                  onPressed: _restartDeal,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Restart'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Hint',
                  child: IconButton.filledTonal(
                    onPressed: _showHint,
                    icon: const Icon(Icons.lightbulb_outline),
                  ),
                ),
                Tooltip(
                  message: 'Undo',
                  child: IconButton.filledTonal(
                    onPressed: _history.isEmpty ? null : _undoMove,
                    icon: const Icon(Icons.undo),
                  ),
                ),
                Tooltip(
                  message: 'Redo',
                  child: IconButton.filledTonal(
                    onPressed: _redoHistory.isEmpty ? null : _redoMove,
                    icon: const Icon(Icons.redo),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openStatistics,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Stats'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealAnimationOverlay(_SpiderLayoutMetrics metrics) {
    if (_dealAnimationNonce == 0) {
      return const SizedBox.shrink();
    }

    final stockLeft = 0.0;
    final stockTop = 0.0;
    final targetTop =
        metrics.cardHeight + metrics.groupSpacing + metrics.sectionSpacing;

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_dealAnimationNonce),
        tween: Tween(begin: 0, end: 1),
        duration: kCardDealDuration,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Stack(
            children: [
              for (int i = 0; i < 10; i++)
                Positioned(
                  left: ui.lerpDouble(
                    stockLeft + (i % 3) * 2,
                    i * (metrics.pileWidth + metrics.tableauSpacing),
                    value,
                  )!,
                  top: ui.lerpDouble(stockTop + (i % 3) * 2, targetTop, value)!,
                  child: Opacity(
                    opacity: (1 - value * 0.55).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: ui.lerpDouble(0.94, 1.0, value)!,
                      child: SizedBox(
                        width: metrics.cardWidth,
                        height: metrics.cardHeight,
                        child: PlayingCardView(
                          card: PlayingCard(Suit.spades, CardValue.ace),
                          showBack: true,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              metrics.cornerRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmNewDeal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new game?'),
        content: const Text('Current progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('New Game')),
        ],
      ),
    );
    if (confirmed == true) {
      _dealNewGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Spider Solitaire'),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _openHelp),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
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
              final metrics = _SpiderLayoutMetrics.fromWidth(
                constraints.maxWidth,
              );
              final tableauHeight = _tableauRegionHeight(metrics);

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopShelf(metrics),
                      SizedBox(height: metrics.groupSpacing),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusChip(
                            'Moves ${_history.length}',
                            icon: Icons.swipe_outlined,
                          ),
                          _buildStatusChip(
                            'Wins ${_stats.wins} • Streak ${_stats.currentStreak}',
                            icon: Icons.emoji_events_outlined,
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: kCardHighlightDuration,
                        curve: Curves.easeOutCubic,
                        child: _activeHint == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _buildHintBanner(),
                              ),
                      ),
                      SizedBox(height: metrics.sectionSpacing),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: tableauHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < 10; i++) ...[
                                  if (i > 0)
                                    SizedBox(width: metrics.tableauSpacing),
                                  _buildTableauPile(i, metrics, tableauHeight),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildDealAnimationOverlay(metrics),
                  if (state.isWon) _buildWinOverlay(metrics),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveSpiderDrag {
  const _ActiveSpiderDrag({required this.pileIndex, required this.startIndex});

  final int pileIndex;
  final int startIndex;

  @override
  bool operator ==(Object other) {
    return other is _ActiveSpiderDrag &&
        other.pileIndex == pileIndex &&
        other.startIndex == startIndex;
  }

  @override
  int get hashCode => Object.hash(pileIndex, startIndex);
}

enum _HintRole { none, source, target }

class _HintDecoration {
  const _HintDecoration({
    required this.color,
    required this.border,
    required this.boxShadow,
  });

  final Color color;
  final Border border;
  final List<BoxShadow> boxShadow;
}

class _SpiderLayoutMetrics {
  const _SpiderLayoutMetrics({
    required this.cardWidth,
    required this.cardHeight,
    required this.cornerRadius,
    required this.groupSpacing,
    required this.foundationSpacing,
    required this.tableauSpacing,
    required this.sectionSpacing,
    required this.faceDownOverlap,
    required this.faceUpOverlap,
  });

  final double cardWidth;
  final double cardHeight;
  final double cornerRadius;
  final double groupSpacing;
  final double foundationSpacing;
  final double tableauSpacing;
  final double sectionSpacing;
  final double faceDownOverlap;
  final double faceUpOverlap;

  double get pileWidth => cardWidth + 4;

  factory _SpiderLayoutMetrics.fromWidth(double width) {
    final tableauSpacing = width < 420
        ? 2.0
        : width < 760
        ? 3.0
        : 6.0;
    final groupSpacing = width < 420 ? 8.0 : 12.0;
    final foundationSpacing = width < 420 ? 4.0 : 8.0;
    final horizontalPadding = width < 420 ? 2.0 : 8.0;
    final baseCardWidth =
        (width - horizontalPadding - (tableauSpacing * 9)) / 10;
    final cardWidth = baseCardWidth.clamp(24.0, 72.0);
    final cardHeight = cardWidth * 1.4;

    return _SpiderLayoutMetrics(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      cornerRadius: math.max(5, cardWidth * 0.1),
      groupSpacing: groupSpacing,
      foundationSpacing: foundationSpacing,
      tableauSpacing: tableauSpacing,
      sectionSpacing: width < 420 ? 12.0 : 18.0,
      faceDownOverlap: (cardHeight * 0.10).clamp(5.0, 9.0),
      faceUpOverlap: (cardHeight * 0.18).clamp(11.0, 18.0),
    );
  }
}
