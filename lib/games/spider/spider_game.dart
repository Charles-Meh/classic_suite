import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

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

class _SpiderGameState extends State<SpiderGame> {
  late SpiderGameState state;
  late SpiderGameState _initialDealState;
  final List<SpiderGameState> _history = [];
  final List<SpiderGameState> _redoHistory = [];
  final SpiderStatsStore _statsStore = SpiderStatsStore();
  _ActiveSpiderDrag? _activeTableauDrag;
  SpiderSuggestion? _activeHint;
  SpiderStats _stats = const SpiderStats();
  bool _hasRecordedCurrentWin = false;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? SpiderGameState();
    _initialDealState = state.copy();
    _hasRecordedCurrentWin = state.isWon;
    _loadStats();
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

  void _handleStockTap() {
    final changed = _runRecordedMutation(state.dealFromStock);
    if (!changed && state.stock.isNotEmpty) {
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
                      ),
                      RadioListTile<int>(
                        value: 4,
                        contentPadding: EdgeInsets.zero,
                        title: Text('4-suit'),
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

  void _handleMenuAction(_SpiderMenuAction action) {
    switch (action) {
      case _SpiderMenuAction.newDeal:
        _dealNewGame();
      case _SpiderMenuAction.restartDeal:
        _restartDeal();
      case _SpiderMenuAction.statistics:
        _openStatistics();
      case _SpiderMenuAction.settings:
        _openSettings();
    }
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
      duration: const Duration(milliseconds: 180),
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
      duration: const Duration(milliseconds: 180),
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

  Widget _buildWinOverlay(_SpiderLayoutMetrics metrics) {
    final panelWidth = math.min(metrics.cardWidth * 7.4, 420.0);
    return Positioned.fill(
      child: Container(
        key: const Key('spider_win_overlay'),
        color: Colors.black.withValues(alpha: 0.28),
        alignment: Alignment.center,
        child: Container(
          width: panelWidth,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7E39B), Color(0xFFF3C65E), Color(0xFFE0A93B)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 44,
                color: Color(0xFF7A4A00),
              ),
              const SizedBox(height: 16),
              Text(
                'You won',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: math.max(28, metrics.cardWidth * 0.62),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: const Color(0xFF4E2D00),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All eight runs are cleared. Deal another Spider game whenever you are ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: math.max(14, metrics.cardWidth * 0.24),
                  height: 1.35,
                  color: const Color(0xFF6A4300),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _dealNewGame,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('New deal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF14532D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _suitModeLabel() {
    return switch (state.suitMode) {
      1 => '1-suit',
      2 => '2-suit',
      4 => '4-suit',
      _ => '${state.suitMode}-suit',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spider Solitaire'),
        actions: [
          IconButton(
            tooltip: 'Hint',
            onPressed: _showHint,
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _history.isEmpty ? null : _undoMove,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoHistory.isEmpty ? null : _redoMove,
            icon: const Icon(Icons.redo),
          ),
          PopupMenuButton<_SpiderMenuAction>(
            tooltip: 'Game menu',
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem<_SpiderMenuAction>(
                value: _SpiderMenuAction.newDeal,
                child: Text('New deal'),
              ),
              PopupMenuItem<_SpiderMenuAction>(
                value: _SpiderMenuAction.restartDeal,
                child: Text('Restart deal'),
              ),
              PopupMenuItem<_SpiderMenuAction>(
                value: _SpiderMenuAction.statistics,
                child: Text('Statistics'),
              ),
              PopupMenuItem<_SpiderMenuAction>(
                value: _SpiderMenuAction.settings,
                child: Text('Settings'),
              ),
            ],
          ),
        ],
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
              final metrics = _SpiderLayoutMetrics.fromWidth(
                constraints.maxWidth,
              );
              final tableauHeight = _tableauRegionHeight(metrics);

              return Stack(
                children: [
                  Column(
                    children: [
                      Row(
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
                                    if (i > 0)
                                      SizedBox(
                                        width: metrics.foundationSpacing,
                                      ),
                                    _buildCompletedRun(i, metrics),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: metrics.groupSpacing),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusChip(
                            _suitModeLabel(),
                            icon: Icons.style_outlined,
                          ),
                          _buildStatusChip(
                            'Deals ${state.dealsRemaining}',
                            icon: Icons.layers_outlined,
                          ),
                          _buildStatusChip(
                            'Runs ${state.completedRuns.length}/8',
                            icon: Icons.verified_outlined,
                          ),
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
                        duration: const Duration(milliseconds: 180),
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

enum _SpiderMenuAction { newDeal, restartDeal, statistics, settings }

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

  factory _SpiderLayoutMetrics.fromWidth(double width) {
    final tableauSpacing = width < 420
        ? 3.0
        : width < 780
        ? 4.0
        : 8.0;
    final groupSpacing = width < 420 ? 8.0 : 12.0;
    final foundationSpacing = width < 420 ? 4.0 : 8.0;
    final baseCardWidth = (width - (tableauSpacing * 9)) / 10;
    final cardWidth = baseCardWidth.clamp(34.0, 78.0);
    final cardHeight = cardWidth * 1.4;

    return _SpiderLayoutMetrics(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      cornerRadius: math.max(6, cardWidth * 0.1),
      groupSpacing: groupSpacing,
      foundationSpacing: foundationSpacing,
      tableauSpacing: tableauSpacing,
      sectionSpacing: width < 420 ? 18.0 : 24.0,
      faceDownOverlap: (cardHeight * 0.12).clamp(7.0, 11.0),
      faceUpOverlap: (cardHeight * 0.24).clamp(18.0, 26.0),
    );
  }
}
