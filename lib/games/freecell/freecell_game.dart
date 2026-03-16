import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import '../klondike/card_model.dart';
import 'freecell_game_state.dart';
import 'freecell_advisor.dart';
import 'freecell_stats.dart';
import 'freecell_stats_store.dart';

class FreeCellGame extends StatefulWidget {
  const FreeCellGame({super.key, this.initialState});
  final FreeCellGameState? initialState;
  @override
  State<FreeCellGame> createState() => _FreeCellGameState();
}

class _FreeCellGameState extends State<FreeCellGame> {
  late FreeCellGameState state;
  late FreeCellGameState _initialDealState;
  final List<FreeCellGameState> _history = [];
  final FreeCellStatsStore _statsStore = FreeCellStatsStore();
  FreeCellStats _stats = const FreeCellStats();
  bool _hasRecordedCurrentWin = false;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? FreeCellGameState();
    _initialDealState = state.copy();
    _hasRecordedCurrentWin = false; // Detect win logic later
    _loadStats();
  }

  Future<void> _loadStats() async {
    final loaded = await _statsStore.load();
    if (!mounted) return;
    setState(() { _stats = loaded.recordDealStarted(); });
    await _statsStore.save(_stats);
  }

  void _recordHistory() {
    _history.add(state.copy());
  }

  bool _runRecordedMutation(bool Function() mutation) {
    _recordHistory();
    var changed = false;
    setState(() {
      changed = mutation();
      if (!changed) _history.removeLast();
    });
    if (changed) {
      _maybeRecordWin();
    }
    return changed;
  }

  void _maybeRecordWin() {
    // Win detection logic to be implemented for MVP
    // (e.g., all foundation piles have 13 cards)
    if (_hasRecordedCurrentWin) return;
    final won = state.foundations.every((f) => f.length == 13);
    if (won) {
      _hasRecordedCurrentWin = true;
      final nextStats = _stats.recordWin();
      setState(() { _stats = nextStats; });
      _statsStore.save(nextStats);
    }
  }

  void _onNewDeal() {
    setState(() {
      state.dealNewGame();
      _initialDealState = state.copy();
      _history.clear();
      _hasRecordedCurrentWin = false;
      _stats = _stats.recordDealStarted();
    });
    _statsStore.save(_stats);
  }

  @override
  Widget build(BuildContext context) {
    // Barebones layout for MVP
    return Scaffold(
      appBar: AppBar(title: const Text('FreeCell')),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _buildFreecell(i)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _buildFoundation(i)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(8, (i) => _buildCascade(i)),
              ),
            ),
            ElevatedButton(
              onPressed: _onNewDeal,
              child: const Text('New Deal'),
            ),
            Text('Deals: ${_stats.dealsStarted}, Wins: ${_stats.wins}, Current win streak: ${_stats.currentStreak}'),
          ],
        ),
      ),
    );
  }

  Widget _buildFreecell(int index) {
    final card = state.freecells[index];
    return SizedBox(
      width: 50,
      height: 70,
      child: Card(
        child: card != null ? PlayingCardView(card: card.card) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildFoundation(int index) {
    final pile = state.foundations[index];
    return SizedBox(
      width: 50,
      height: 70,
      child: Card(
        color: Colors.green[100],
        child: pile.isNotEmpty ? PlayingCardView(card: pile.last.card) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCascade(int index) {
    final pile = state.cascades[index];
    return Container(
      width: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: pile.map((card) => Card(
          child: PlayingCardView(card: card.card),
        )).toList(),
      ),
    );
  }
}
