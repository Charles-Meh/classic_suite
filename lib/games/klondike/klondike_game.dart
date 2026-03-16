import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

import 'card_model.dart';
import 'game_state.dart';
import 'klondike_advisor.dart';
import 'klondike_autocomplete.dart';
import 'klondike_stats.dart';
import 'klondike_stats_store.dart';
import 'winnable_seed_corpus.dart';

/// Main widget for the Klondike Klondike game. All game logic and rendering
/// lives here; the state object contains the current tableau, stock, waste,
/// and foundations.
class KlondikeGame extends StatefulWidget {
  const KlondikeGame({super.key, this.initialState});

  final GameState? initialState;

  @override
  State<KlondikeGame> createState() => _KlondikeGameState();
}

class _KlondikeGameState extends State<KlondikeGame> {
  late GameState state;
  late GameState _initialDealState;
  final List<GameState> _history = [];
  final WinnableSeedCorpus _winnableSeedCorpus = WinnableSeedCorpus();
  final KlondikeStatsStore _statsStore = KlondikeStatsStore();
  _ActiveTableauDrag? _activeTableauDrag;
  KlondikeSuggestion? _activeHint;
  bool _isWasteDragging = false;
  bool _isAutocompleteRunning = false;
  bool _hasRecordedCurrentWin = false;
  KlondikeStats _stats = const KlondikeStats();
  _DealMode _dealMode = _DealMode.random;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? GameState();
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

  bool _applySuggestion(KlondikeSuggestion suggestion) {
    switch (suggestion.kind) {
      case KlondikeSuggestionKind.moveToFoundation:
        if (suggestion.cards.length != 1) {
          return false;
        }
        return state.moveToFoundation(suggestion.cards.first);
      case KlondikeSuggestionKind.moveToTableau:
        final targetIndex = suggestion.targetTableauIndex;
        if (targetIndex == null) {
          return false;
        }
        return state.moveCardsToTableau(
          suggestion.cards,
          state.tableau[targetIndex],
        );
      case KlondikeSuggestionKind.drawFromStock:
        return state.drawFromStock() > 0;
      case KlondikeSuggestionKind.recycleWaste:
        if (state.waste.isEmpty) {
          return false;
        }
        state.recycleWaste();
        return true;
      case KlondikeSuggestionKind.noMoves:
        return false;
    }
  }

  void _recordHistory() {
    _history.add(state.copy());
  }

  bool _runRecordedMutation(bool Function() mutation) {
    if (_isAutocompleteRunning) {
      return false;
    }

    _recordHistory();
    var changed = false;
    setState(() {
      changed = mutation();
      if (!changed) {
        _history.removeLast();
      }
      _activeTableauDrag = null;
      _activeHint = null;
      _isWasteDragging = false;
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
    _runRecordedMutation(() {
      if (state.stock.isEmpty) {
        if (state.waste.isEmpty) {
          return false;
        }
        state.recycleWaste();
        return true;
      }
      return state.drawFromStock() > 0;
    });
  }

  void _handleCardTap(KlondikeCard card) {
    final suggestion = KlondikeAdvisor.bestTapMove(state, card);
    if (suggestion == null) {
      return;
    }
    _runRecordedMutation(() => _applySuggestion(suggestion));
  }

  void _showHint() {
    if (_isAutocompleteRunning) {
      return;
    }
    setState(() {
      _activeHint = KlondikeAdvisor.bestHint(state);
    });
  }

  void _undoMove() {
    if (_isAutocompleteRunning || _history.isEmpty) {
      return;
    }
    setState(() {
      final previous = _history.removeLast();
      state.restoreFrom(previous);
      _activeHint = null;
      _activeTableauDrag = null;
      _isWasteDragging = false;
      _hasRecordedCurrentWin = state.isWon;
    });
  }

  void _restartDeal() {
    if (_isAutocompleteRunning) {
      return;
    }
    setState(() {
      state.restoreFrom(_initialDealState);
      _history.clear();
      _activeHint = null;
      _activeTableauDrag = null;
      _isWasteDragging = false;
      _isAutocompleteRunning = false;
      _hasRecordedCurrentWin = state.isWon;
    });
  }

  void _dealNewGame({int? drawCount, _DealMode? dealMode}) {
    if (_isAutocompleteRunning) {
      return;
    }

    final shouldResetStreak = !state.isWon && _history.isNotEmpty;
    setState(() {
      if (drawCount != null) {
        state.drawCount = drawCount;
      }
      if (dealMode != null) {
        _dealMode = dealMode;
      }
      if (_dealMode == _DealMode.winning) {
        final seed = _winnableSeedCorpus.nextSeed(drawCount: state.drawCount);
        state.dealWinnableGame(seed);
      } else {
        state.dealNewGame();
      }
      _initialDealState = state.copy();
      _history.clear();
      _activeHint = null;
      _activeTableauDrag = null;
      _isWasteDragging = false;
      _isAutocompleteRunning = false;
      _hasRecordedCurrentWin = false;
    });
    _recordStartedDeal(resetStreak: shouldResetStreak);
  }

  bool get _canAutocomplete {
    return !_isAutocompleteRunning &&
        KlondikeAutocomplete.canAutocomplete(state);
  }

  Future<void> _runAutocomplete() async {
    if (!_canAutocomplete) {
      return;
    }

    _recordHistory();
    setState(() {
      _isAutocompleteRunning = true;
      _activeHint = null;
      _activeTableauDrag = null;
      _isWasteDragging = false;
    });

    var movedAny = false;
    while (mounted) {
      var moved = false;
      setState(() {
        moved = KlondikeAutocomplete.applyNextMove(state);
      });
      if (!moved) {
        break;
      }
      movedAny = true;
      await Future<void>.delayed(const Duration(milliseconds: 70));
    }

    if (!mounted) {
      return;
    }

    if (!movedAny && _history.isNotEmpty) {
      _history.removeLast();
    }

    setState(() {
      _isAutocompleteRunning = false;
    });
    _maybeRecordWin();
  }

  Widget _buildAutocompleteButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _canAutocomplete
          ? FilledButton.icon(
              key: const Key('autocomplete_button'),
              onPressed: _runAutocomplete,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Autocomplete'),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _openSettings() async {
    if (_isAutocompleteRunning) {
      return;
    }
    final result = await showDialog<_KlondikeSettings>(
      context: context,
      builder: (dialogContext) {
        int selectedDrawCount = state.drawCount;
        _DealMode selectedDealMode = _dealMode;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Klondike Klondike settings'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draw mode',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      RadioGroup<int>(
                        groupValue: selectedDrawCount,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedDrawCount = value;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            RadioListTile<int>(
                              value: 1,
                              contentPadding: EdgeInsets.zero,
                              title: Text('1-card draw'),
                            ),
                            RadioListTile<int>(
                              value: 3,
                              contentPadding: EdgeInsets.zero,
                              title: Text('3-card draw'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Deal type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      RadioGroup<_DealMode>(
                        groupValue: selectedDealMode,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedDealMode = value;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            RadioListTile<_DealMode>(
                              value: _DealMode.random,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Random deal'),
                              subtitle: Text(
                                'Standard shuffled Klondike deal.',
                              ),
                            ),
                            RadioListTile<_DealMode>(
                              value: _DealMode.winning,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Winning deal'),
                              subtitle: Text(
                                'Normal Klondike deal selected to be winnable for the current draw mode.',
                              ),
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
                      _KlondikeSettings(
                        drawCount: selectedDrawCount,
                        dealMode: selectedDealMode,
                      ),
                    );
                  },
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
    _dealNewGame(drawCount: result.drawCount, dealMode: result.dealMode);
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
          title: const Text('Klondike Klondike statistics'),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
    final next = _ActiveTableauDrag(
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

  void _handleMenuAction(_GameMenuAction action) {
    switch (action) {
      case _GameMenuAction.newDeal:
        _dealNewGame();
      case _GameMenuAction.restartDeal:
        _restartDeal();
      case _GameMenuAction.statistics:
        _openStatistics();
      case _GameMenuAction.settings:
        _openSettings();
    }
  }

  Widget _cardWidget(
    KlondikeCard card,
    _KlondikeLayoutMetrics metrics, {
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

  Widget _buildSlotPlaceholder(
    _KlondikeLayoutMetrics metrics, {
    Key? key,
    String? label,
    bool highlight = false,
    _HintRole role = _HintRole.none,
  }) {
    final effectiveRole = role == _HintRole.none && highlight
        ? _HintRole.target
        : role;
    final decoration = _hintDecoration(effectiveRole);
    final borderColor = effectiveRole == _HintRole.source
        ? const Color(0xFFFFD971)
        : effectiveRole == _HintRole.target
        ? const Color(0xFFBDE0FF)
        : highlight
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.45);
    final backgroundColor = effectiveRole == _HintRole.source
        ? const Color(0x33F6C453)
        : effectiveRole == _HintRole.target
        ? const Color(0x3329B6F6)
        : highlight
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.08);

    return _buildHintFrame(
      key: key,
      role: effectiveRole,
      borderRadius: BorderRadius.circular(metrics.cornerRadius),
      child: Container(
        width: metrics.cardWidth,
        height: metrics.cardHeight,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(metrics.cornerRadius),
          border: Border.all(
            color: borderColor,
            width: effectiveRole == _HintRole.none && !highlight ? 1.2 : 2,
          ),
          boxShadow: decoration?.boxShadow,
        ),
        alignment: Alignment.center,
        child: label == null
            ? null
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: metrics.cardWidth * 0.28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
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

  Widget _buildStack(
    List<KlondikeCard> cards,
    _KlondikeLayoutMetrics metrics,
  ) {
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

  Widget _buildStock(_KlondikeLayoutMetrics metrics) {
    final topFaceDown = state.stock.isNotEmpty ? state.stock.last : null;
    final role = _stockHintRole;
    return GestureDetector(
      key: const Key('stock'),
      onTap: _handleStockTap,
      child: _buildHintFrame(
        key: role == _HintRole.none ? null : const Key('hint_stock'),
        role: role,
        borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
        padding: const EdgeInsets.all(2),
        child: topFaceDown != null
            ? _cardWidget(topFaceDown, metrics)
            : _buildSlotPlaceholder(metrics, label: 'STK', role: role),
      ),
    );
  }

  Widget _buildWaste(_KlondikeLayoutMetrics metrics) {
    final role = _wasteHintRole;
    if (state.waste.isEmpty) {
      return _buildHintFrame(
        key: role == _HintRole.none ? null : const Key('hint_waste'),
        role: role,
        borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
        padding: const EdgeInsets.all(2),
        child: _buildSlotPlaceholder(metrics, label: 'WST', role: role),
      );
    }

    final visibleCount = math.min(
      state.waste.length,
      math.max(state.drawCount + (_isWasteDragging ? 1 : 0), 1),
    );
    final startIndex = state.waste.length - visibleCount;
    final visibleCards = state.waste.sublist(startIndex);
    final cardsToDisplay = _isWasteDragging && visibleCards.isNotEmpty
        ? visibleCards.sublist(0, visibleCards.length - 1)
        : visibleCards;

    if (cardsToDisplay.isEmpty) {
      return _buildHintFrame(
        key: role == _HintRole.none ? null : const Key('hint_waste'),
        role: role,
        borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
        padding: const EdgeInsets.all(2),
        child: _buildSlotPlaceholder(metrics, label: 'WST', role: role),
      );
    }

    final wasteWidth =
        metrics.cardWidth +
        metrics.wasteFanOffset * (cardsToDisplay.length - 1);

    return _buildHintFrame(
      key: role == _HintRole.none ? null : const Key('hint_waste'),
      role: role,
      borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: metrics.wasteSlotWidth,
        height: metrics.cardHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: wasteWidth,
            height: metrics.cardHeight,
            child: Stack(
              children: [
                for (int index = 0; index < cardsToDisplay.length; index++)
                  Positioned(
                    left: metrics.wasteFanOffset * index,
                    width: metrics.cardWidth,
                    height: metrics.cardHeight,
                    child: KeyedSubtree(
                      key: Key('waste_card_${startIndex + index}'),
                      child:
                          index == cardsToDisplay.length - 1 &&
                              !_isWasteDragging
                          ? _buildWasteDraggable(cardsToDisplay[index], metrics)
                          : IgnorePointer(
                              child: _cardWidget(
                                cardsToDisplay[index],
                                metrics,
                                role: _hintRoleForCard(cardsToDisplay[index]),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWasteDraggable(
    KlondikeCard card,
    _KlondikeLayoutMetrics metrics,
  ) {
    return Draggable<List<KlondikeCard>>(
      key: const Key('waste_draggable'),
      data: [card],
      onDragStarted: () {
        setState(() {
          _isWasteDragging = true;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _isWasteDragging = false;
        });
      },
      onDraggableCanceled: (velocity, offset) {
        setState(() {
          _isWasteDragging = false;
        });
      },
      onDragCompleted: () {
        setState(() {
          _isWasteDragging = false;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: _cardWidget(card, metrics),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: GestureDetector(
        onTap: () => _handleCardTap(card),
        child: _cardWidget(card, metrics, role: _hintRoleForCard(card)),
      ),
    );
  }

  Widget _buildFoundation(int index, _KlondikeLayoutMetrics metrics) {
    final pile = state.foundations[index];
    return DragTarget<List<KlondikeCard>>(
      key: Key('foundation_$index'),
      builder: (context, candidate, rejected) {
        final hintRole = _foundationHintRole(index);
        final dragHighlight = candidate.isNotEmpty;
        final child = pile.isEmpty
            ? _buildSlotPlaceholder(
                metrics,
                key: hintRole == _HintRole.target
                    ? Key('hint_target_foundation_$index')
                    : null,
                label: _foundationLabel(index),
                highlight: dragHighlight,
                role: hintRole,
              )
            : _buildFoundationDraggable(pile.last, index, metrics);
        return _buildHintFrame(
          key: hintRole == _HintRole.target && pile.isNotEmpty
              ? Key('hint_target_foundation_$index')
              : null,
          role: hintRole,
          borderRadius: BorderRadius.circular(metrics.cornerRadius + 4),
          padding: const EdgeInsets.all(2),
          child: SizedBox(
            width: metrics.cardWidth,
            height: metrics.cardHeight,
            child: child,
          ),
        );
      },
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.length != 1) {
          return false;
        }
        return state.canMoveToFoundation(data.first);
      },
      onAcceptWithDetails: (details) {
        _runRecordedMutation(() => state.moveToFoundation(details.data.first));
      },
    );
  }

  Widget _buildFoundationDraggable(
    KlondikeCard card,
    int foundationIndex,
    _KlondikeLayoutMetrics metrics,
  ) {
    return Draggable<List<KlondikeCard>>(
      key: Key('foundation_card_$foundationIndex'),
      data: [card],
      feedback: Material(
        color: Colors.transparent,
        child: _cardWidget(card, metrics),
      ),
      childWhenDragging: _buildSlotPlaceholder(
        metrics,
        label: _foundationLabel(foundationIndex),
      ),
      child: GestureDetector(
        onTap: () => _handleCardTap(card),
        child: _cardWidget(card, metrics, role: _hintRoleForCard(card)),
      ),
    );
  }

  Widget _buildTableauPile(
    int pileIndex,
    _KlondikeLayoutMetrics metrics,
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
      key: Key('tableau_$pileIndex'),
      builder: (context, candidate, rejected) {
        final hintRole = _tableauHintRole(pileIndex);
        final dragHighlight = candidate.isNotEmpty;
        final showDropHint = dragHighlight || hintRole == _HintRole.target;
        return _buildHintFrame(
          role: hintRole == _HintRole.target
              ? _HintRole.target
              : _HintRole.none,
          borderRadius: BorderRadius.circular(metrics.cornerRadius + 6),
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: metrics.cardWidth,
            height: math.max(regionHeight, pileHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(metrics.cornerRadius),
            ),
            child: pile.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: _buildSlotPlaceholder(
                      metrics,
                      key: hintRole == _HintRole.target
                          ? Key('hint_target_tableau_$pileIndex')
                          : null,
                      label: 'K',
                      highlight: dragHighlight,
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
                          child: _buildSlotPlaceholder(
                            metrics,
                            key: Key('tableau_${pileIndex}_drop_hint'),
                            role: _HintRole.target,
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
                          child: visibleEntries[visibleIndex].card.faceUp
                              ? _buildDraggableTableauCard(
                                  pile,
                                  visibleEntries[visibleIndex].index,
                                  pileIndex,
                                  metrics,
                                )
                              : _cardWidget(
                                  visibleEntries[visibleIndex].card,
                                  metrics,
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
    _KlondikeLayoutMetrics metrics,
  ) {
    final card = pile[idx];
    final stack = pile.sublist(idx);
    return Draggable<List<KlondikeCard>>(
      key: Key('tableau_${pileIndex}_card_$idx'),
      data: stack,
      onDragStarted: () => _setActiveDrag(pileIndex, idx),
      onDragUpdate: (_) => _setActiveDrag(pileIndex, idx),
      onDragEnd: (_) => _clearActiveDrag(),
      onDraggableCanceled: (velocity, offset) => _clearActiveDrag(),
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
        onTap: () => _handleCardTap(card),
        child: _cardWidget(card, metrics, role: _hintRoleForCard(card)),
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
              key: const Key('hint_banner'),
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

  IconData _hintIcon(KlondikeSuggestionKind kind) {
    return switch (kind) {
      KlondikeSuggestionKind.moveToFoundation => Icons.north_east_rounded,
      KlondikeSuggestionKind.moveToTableau => Icons.compare_arrows_rounded,
      KlondikeSuggestionKind.drawFromStock => Icons.layers_outlined,
      KlondikeSuggestionKind.recycleWaste => Icons.replay_rounded,
      KlondikeSuggestionKind.noMoves => Icons.info_outline_rounded,
    };
  }

  _HintRole _hintRoleForCard(KlondikeCard card) {
    final hint = _activeHint;
    if (hint == null) {
      return _HintRole.none;
    }
    return hint.cards.any((hintCard) => identical(hintCard, card))
        ? _HintRole.source
        : _HintRole.none;
  }

  _HintRole get _stockHintRole {
    final hint = _activeHint;
    if (hint == null) {
      return _HintRole.none;
    }
    if (hint.kind == KlondikeSuggestionKind.drawFromStock) {
      return _HintRole.source;
    }
    if (hint.kind == KlondikeSuggestionKind.recycleWaste) {
      return _HintRole.target;
    }
    return hint.source?.zone == KlondikeLocationZone.stock
        ? _HintRole.source
        : _HintRole.none;
  }

  _HintRole get _wasteHintRole {
    final hint = _activeHint;
    if (hint == null) {
      return _HintRole.none;
    }
    return hint.source?.zone == KlondikeLocationZone.waste
        ? _HintRole.source
        : _HintRole.none;
  }

  _HintRole _foundationHintRole(int foundationIndex) {
    final hint = _activeHint;
    if (hint == null || hint.kind != KlondikeSuggestionKind.moveToFoundation) {
      return _HintRole.none;
    }
    if (hint.cards.isEmpty) {
      return _HintRole.none;
    }
    return _foundationIndexForSuit(hint.cards.first.card.suit) ==
            foundationIndex
        ? _HintRole.target
        : _HintRole.none;
  }

  _HintRole _tableauHintRole(int pileIndex) {
    final hint = _activeHint;
    if (hint == null || hint.kind != KlondikeSuggestionKind.moveToTableau) {
      return _HintRole.none;
    }
    return hint.targetTableauIndex == pileIndex
        ? _HintRole.target
        : _HintRole.none;
  }

  int _foundationIndexForSuit(Suit suit) {
    return switch (suit) {
      Suit.clubs => 0,
      Suit.diamonds => 1,
      Suit.hearts => 2,
      Suit.spades => 3,
      _ => throw ArgumentError('Unsupported suit: $suit'),
    };
  }

  double _stackHeight(
    List<KlondikeCard> cards,
    _KlondikeLayoutMetrics metrics,
  ) {
    if (cards.isEmpty) {
      return metrics.cardHeight;
    }
    return _stackOffsetForIndex(cards, cards.length - 1, metrics) +
        metrics.cardHeight;
  }

  double _stackOffsetForIndex(
    List<KlondikeCard> cards,
    int index,
    _KlondikeLayoutMetrics metrics,
  ) {
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += cards[i].faceUp
          ? metrics.faceUpOverlap
          : metrics.faceDownOverlap;
    }
    return offset;
  }

  String _foundationLabel(int index) {
    const labels = ['C', 'D', 'H', 'S'];
    return labels[index];
  }

  double _tableauRegionHeight(_KlondikeLayoutMetrics metrics) {
    double tallest = metrics.cardHeight;
    for (final pile in state.tableau) {
      tallest = math.max(tallest, _stackHeight(pile, metrics));
    }
    return tallest;
  }

  Widget _buildWinOverlay(_KlondikeLayoutMetrics metrics) {
    final panelWidth = math.min(metrics.cardWidth * 5.8, 420.0);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          key: const Key('win_overlay'),
          color: Colors.black.withValues(alpha: 0.28),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7E39B),
                    Color(0xFFF3C65E),
                    Color(0xFFE0A93B),
                  ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildWinSparkle(delay: 0, icon: Icons.auto_awesome),
                      SizedBox(width: metrics.groupSpacing),
                      Container(
                        width: metrics.cardWidth * 1.18,
                        height: metrics.cardWidth * 1.18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          size: 40,
                          color: Color(0xFF7A4A00),
                        ),
                      ),
                      SizedBox(width: metrics.groupSpacing),
                      _buildWinSparkle(delay: 120, icon: Icons.stars_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You won',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: math.max(28, metrics.cardWidth * 0.56),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: const Color(0xFF4E2D00),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every card is home. Start a fresh Klondike deal whenever you are ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: math.max(14, metrics.cardWidth * 0.22),
                      height: 1.35,
                      color: const Color(0xFF6A4300),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Wins ${_stats.wins} • Streak ${_stats.currentStreak}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: math.max(13, metrics.cardWidth * 0.2),
                      fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _buildWinSparkle({required int delay, required IconData icon}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offset = 10 * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, -offset), child: child),
        );
      },
      child: Icon(icon, color: const Color(0xFF7A4A00), size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klondike Klondike'),
        actions: [
          IconButton(
            tooltip: 'Hint',
            onPressed: _isAutocompleteRunning ? null : _showHint,
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _history.isEmpty || _isAutocompleteRunning
                ? null
                : _undoMove,
            icon: const Icon(Icons.undo),
          ),
          PopupMenuButton<_GameMenuAction>(
            tooltip: 'Game menu',
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem<_GameMenuAction>(
                value: _GameMenuAction.newDeal,
                child: Text('New deal'),
              ),
              PopupMenuItem<_GameMenuAction>(
                value: _GameMenuAction.restartDeal,
                child: Text('Restart deal'),
              ),
              PopupMenuItem<_GameMenuAction>(
                value: _GameMenuAction.statistics,
                child: Text('Statistics'),
              ),
              PopupMenuItem<_GameMenuAction>(
                value: _GameMenuAction.settings,
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
              final metrics = _KlondikeLayoutMetrics.fromWidth(
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStock(metrics),
                              SizedBox(width: metrics.groupSpacing),
                              _buildWaste(metrics),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < 4; i++) ...[
                                if (i > 0)
                                  SizedBox(width: metrics.foundationSpacing),
                                _buildFoundation(i, metrics),
                              ],
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: metrics.groupSpacing),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusChip(
                                  state.drawCount == 1 ? 'Draw 1' : 'Draw 3',
                                  icon: Icons.style_outlined,
                                ),
                                _buildStatusChip(
                                  _dealMode == _DealMode.random
                                      ? 'Random deal'
                                      : 'Winning deal',
                                  icon: _dealMode == _DealMode.random
                                      ? Icons.shuffle
                                      : Icons.verified_outlined,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildAutocompleteButton(),
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
                                for (int i = 0; i < 7; i++) ...[
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

class _ActiveTableauDrag {
  const _ActiveTableauDrag({required this.pileIndex, required this.startIndex});

  final int pileIndex;
  final int startIndex;

  @override
  bool operator ==(Object other) {
    return other is _ActiveTableauDrag &&
        other.pileIndex == pileIndex &&
        other.startIndex == startIndex;
  }

  @override
  int get hashCode => Object.hash(pileIndex, startIndex);
}

enum _DealMode { random, winning }

enum _GameMenuAction { newDeal, restartDeal, statistics, settings }

enum _HintRole { none, source, target }

class _KlondikeSettings {
  const _KlondikeSettings({required this.drawCount, required this.dealMode});

  final int drawCount;
  final _DealMode dealMode;
}

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

class _KlondikeLayoutMetrics {
  const _KlondikeLayoutMetrics({
    required this.cardWidth,
    required this.cardHeight,
    required this.cornerRadius,
    required this.groupSpacing,
    required this.foundationSpacing,
    required this.tableauSpacing,
    required this.sectionSpacing,
    required this.faceDownOverlap,
    required this.faceUpOverlap,
    required this.wasteFanOffset,
    required this.wasteSlotWidth,
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
  final double wasteFanOffset;
  final double wasteSlotWidth;

  factory _KlondikeLayoutMetrics.fromWidth(double width) {
    final tableauSpacing = width < 420
        ? 4.0
        : width < 700
        ? 6.0
        : 10.0;
    final groupSpacing = width < 420 ? 8.0 : 12.0;
    final foundationSpacing = width < 420 ? 4.0 : 8.0;
    final baseCardWidth = (width - (tableauSpacing * 6)) / 7;
    final cardWidth = baseCardWidth.clamp(42.0, 92.0);
    final cardHeight = cardWidth * 1.4;
    final faceDownOverlap = (cardHeight * 0.11).clamp(7.0, 12.0);
    final faceUpOverlap = (cardHeight * 0.32).clamp(24.0, 34.0);
    final wasteFanOffset = (cardWidth * 0.18).clamp(6.0, 14.0);

    return _KlondikeLayoutMetrics(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      cornerRadius: math.max(6, cardWidth * 0.1),
      groupSpacing: groupSpacing,
      foundationSpacing: foundationSpacing,
      tableauSpacing: tableauSpacing,
      sectionSpacing: width < 420 ? 20.0 : 28.0,
      faceDownOverlap: faceDownOverlap,
      faceUpOverlap: faceUpOverlap,
      wasteFanOffset: wasteFanOffset,
      wasteSlotWidth: cardWidth + (wasteFanOffset * 3),
    );
  }
}
