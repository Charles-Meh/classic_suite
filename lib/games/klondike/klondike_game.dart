import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';

import 'card_model.dart';
import 'game_state.dart';
import 'klondike_advisor.dart';
import 'klondike_autocomplete.dart';
import 'klondike_stats.dart';
import 'klondike_stats_store.dart';
import 'winnable_seed_corpus.dart';

/// Main widget for the Klondike Solitaire game. All game logic and rendering
/// lives here; the state object contains the current tableau, stock, waste,
/// and foundations.
class KlondikeGame extends StatefulWidget {
  const KlondikeGame({super.key, this.initialState});

  final GameState? initialState;

  @override
  State<KlondikeGame> createState() => _KlondikeGameState();
}

class _KlondikeGameState extends State<KlondikeGame>
    with WidgetsBindingObserver {
  static const Duration _saveInterval = Duration(seconds: 15);

  late GameState state;
  final List<GameState> _history = [];
  final WinnableSeedCorpus _winnableSeedCorpus = WinnableSeedCorpus();
  final KlondikeStatsStore _statsStore = KlondikeStatsStore();
  _ActiveTableauDrag? _activeTableauDrag;
  KlondikeSuggestion? _activeHint;
  Timer? _ticker;
  Timer? _periodicSaveTimer;
  bool _loading = true;
  bool _isWasteDragging = false;
  bool _isAutocompleteRunning = false;
  bool _hasRecordedCurrentWin = false;
  KlondikeStats _stats = const KlondikeStats();
  _DealMode _dealMode = _DealMode.winning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState?.copy() ?? GameState(drawCount: 1);
    if (widget.initialState == null) {
      final seed = _winnableSeedCorpus.nextSeed(drawCount: state.drawCount);
      state.dealWinnableGame(seed);
    }
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
        ? GameState.tryDecode(prefs.getString(GameState.storageKey))
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
      _hasRecordedCurrentWin = state.isWon;
      _loading = false;
    });
    _syncTimers();
    if (saved == null) {
      await _persistState();
    }
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
    await prefs.setString(GameState.storageKey, state.encode());
  }

  Future<void> _clearSavedState() async {
    if (widget.initialState != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(GameState.storageKey);
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
    _syncTimers();
    _persistState();
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
      _history.clear();
      _activeHint = null;
      _activeTableauDrag = null;
      _isWasteDragging = false;
      _isAutocompleteRunning = false;
      _hasRecordedCurrentWin = false;
    });
    _recordStartedDeal(resetStreak: shouldResetStreak);
    _clearSavedState();
    _syncTimers();
    _persistState();
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
      await Future<void>.delayed(kCardAutoMoveDuration);
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
    _persistState();
  }

  Widget _buildAutocompleteButton() {
    return AnimatedSwitcher(
      duration: kCardHighlightDuration,
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
              title: const Text('Klondike Solitaire settings'),
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
          title: const Text('Klondike Solitaire statistics'),
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
      case _GameMenuAction.settings:
        _openSettings();
    }
  }

  Future<void> _openHelp() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How to play Klondike Solitaire'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  HelpSection(
                    title: 'Layout',
                    children: [
                      HelpDiagram(
                        '[Stock] [Waste]     [A♣] [A♦] [A♥] [A♠]\n\n'
                        'T1   T2   T3   T4   T5   T6   T7\n'
                        'K♣\n'
                        'Q♦  9♣\n'
                        'J♣  8♥  4♠\n\n'
                        'Tableau builds down in alternating colors. Foundations build up by suit.',
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Goal',
                    children: [
                      Text(
                        'Build the four foundation piles from Ace to King, one suit per pile.',
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Tableau rules',
                    children: [
                      HelpBulletList(
                        items: [
                          'Build downward in alternating colors.',
                          'Only Kings can move to an empty tableau column.',
                          'You can drag a face-up run as a stack.',
                          'When a face-down card is uncovered, it flips up automatically.',
                        ],
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Stock and waste',
                    children: [
                      Text(
                        'Tap the stock to draw cards into the waste. When the stock is empty, tap it again to recycle the waste back into the stock.',
                      ),
                    ],
                  ),
                  HelpSection(
                    title: 'Helpful tips',
                    children: [
                      HelpBulletList(
                        items: [
                          'Move Aces and Twos to the foundations early when it is safe.',
                          'Empty columns are valuable because only Kings can fill them.',
                          'Use Hint if you get stuck, and Undo if you want to back up a move.',
                        ],
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
        child: _KlondikeCardView(
          card: card,
          cornerRadius: metrics.cornerRadius,
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

  Widget _buildStack(List<KlondikeCard> cards, _KlondikeLayoutMetrics metrics) {
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
            : _buildSlotPlaceholder(metrics, role: role),
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
        child: _buildSlotPlaceholder(metrics, role: role),
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
        child: _buildSlotPlaceholder(metrics, role: role),
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
      childWhenDragging: _buildSlotPlaceholder(metrics),
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
        return AnimatedContainer(
          duration: kCardDropDuration,
          width: metrics.cardWidth,
          height: math.max(regionHeight, pileHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(metrics.cornerRadius),
          ),
          child: visibleCards.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: _buildSlotPlaceholder(
                    metrics,
                    key: hintRole == _HintRole.target
                        ? Key('hint_target_tableau_$pileIndex')
                        : null,
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
        child: Row(
          children: [
            // Left: Undo and Hint
            Tooltip(
              message: 'Undo',
              child: IconButton.filledTonal(
                onPressed: _history.isEmpty || _isAutocompleteRunning
                    ? null
                    : _undoMove,
                icon: const Icon(Icons.undo),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Hint',
              child: IconButton.filledTonal(
                onPressed: _isAutocompleteRunning ? null : _showHint,
                icon: const Icon(Icons.lightbulb_outline),
              ),
            ),
            const Spacer(),
            // Center: New Deal
            FilledButton.icon(
              onPressed: _confirmNewDeal,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('New Deal'),
            ),
            const Spacer(),
            // Right: Statistics
            Tooltip(
              message: 'Statistics',
              child: IconButton.filledTonal(
                onPressed: _openStatistics,
                icon: const Icon(Icons.bar_chart_rounded),
              ),
            ),
          ],
        ),
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

  _HintRole _hintRoleForCard(KlondikeCard card) {
    final hint = _activeHint;
    if (hint == null) {
      return _HintRole.none;
    }
    return hint.cards.isNotEmpty && identical(hint.cards.first, card)
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
    const labels = ['♣', '♦', '♥', '♠'];
    return labels[index];
  }

  double _tableauRegionHeight(_KlondikeLayoutMetrics metrics) {
    double tallest = metrics.cardHeight;
    for (final pile in state.tableau) {
      tallest = math.max(tallest, _stackHeight(pile, metrics));
    }
    return tallest;
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay(_KlondikeLayoutMetrics metrics) {
    return GameWinScreen(
      key: const Key('win_overlay'),
      theme: WinScreenTheme.klondike,
      title: 'You Win!',
      subtitle:
          'Cards are flying home. Deal another Klondike round when you are ready.',
      stats: [
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
        WinScreenStat(
          label: 'Draw',
          value: '${state.drawCount}',
          icon: Icons.layers_outlined,
        ),
      ],
      onNewGame: _dealNewGame,
      onBackToMenu: _backToMenu,
      newGameLabel: 'New Deal',
    );
  }

  Future<void> _showNewDealConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start new game?'),
          content: const Text('Current progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('New Game'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _dealNewGame();
    }
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
        title: const Text('Klondike Solitaire'),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _openHelp),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
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
                                        SizedBox(
                                          width: metrics.foundationSpacing,
                                        ),
                                      _buildFoundation(i, metrics),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusChip('Moves ${state.moveCount}'),
                                _buildStatusChip(
                                  'Score ${state.score}',
                                  icon: Icons.emoji_events_outlined,
                                ),
                                _buildStatusChip(
                                  formatElapsedSeconds(state.elapsedSeconds),
                                  icon: Icons.timer_outlined,
                                ),
                              ],
                            ),
                            SizedBox(height: metrics.sectionSpacing),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SizedBox(
                                  height: tableauHeight,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (int i = 0; i < 7; i++) ...[
                                        if (i > 0)
                                          SizedBox(
                                            width: metrics.tableauSpacing,
                                          ),
                                        _buildTableauPile(
                                          i,
                                          metrics,
                                          tableauHeight,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox.shrink(),
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

class _KlondikeCardView extends StatelessWidget {
  const _KlondikeCardView({required this.card, required this.cornerRadius});

  final KlondikeCard card;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (!card.faceUp) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B4D9C), Color(0xFF143C7B)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cornerRadius - 2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
        ),
      );
    }

    final isRed =
        card.card.suit == Suit.hearts || card.card.suit == Suit.diamonds;
    final color = isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A);
    final rank = switch (card.card.value) {
      CardValue.ace => 'A',
      CardValue.two => '2',
      CardValue.three => '3',
      CardValue.four => '4',
      CardValue.five => '5',
      CardValue.six => '6',
      CardValue.seven => '7',
      CardValue.eight => '8',
      CardValue.nine => '9',
      CardValue.ten => '10',
      CardValue.jack => 'J',
      CardValue.queen => 'Q',
      CardValue.king => 'K',
      _ => '?',
    };
    final suit = switch (card.card.suit) {
      Suit.clubs => '♣',
      Suit.diamonds => '♦',
      Suit.hearts => '♥',
      Suit.spades => '♠',
      _ => '?',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: const Color(0xFFD6D6D6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank,
                    style: TextStyle(
                      color: color,
                      fontSize: rank == '10' ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    suit,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                suit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: RotatedBox(
                quarterTurns: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank,
                      style: TextStyle(
                        color: color,
                        fontSize: rank == '10' ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

enum _GameMenuAction { newDeal, settings }

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
