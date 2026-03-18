import 'dart:async';

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';

import '../../shared/win_screen.dart';
import 'hearts_game_state.dart';
import 'hearts_stats.dart';
import 'hearts_stats_store.dart';

class HeartsGame extends StatefulWidget {
  const HeartsGame({super.key, this.initialState});

  final HeartsGameState? initialState;

  @override
  State<HeartsGame> createState() => _HeartsGameState();
}

class _HeartsGameState extends State<HeartsGame> with WidgetsBindingObserver {
  late HeartsGameState state;
  final HeartsStatsStore _statsStore = HeartsStatsStore();
  HeartsStats _stats = const HeartsStats();
  final List<HeartsGameState> _history = [];
  bool _loading = true;
  bool _hasRecordedMatchStart = false;
  bool _recordedCurrentHand = false;
  bool _recordedCurrentMatch = false;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState ?? HeartsGameState.newMatch();
    _hasRecordedMatchStart = widget.initialState != null;
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiTimer?.cancel();
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
        ? HeartsGameState.tryDecode(prefs.getString(HeartsGameState.storageKey))
        : null;
    final stats = await _statsStore.load();

    if (!mounted) {
      return;
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        _hasRecordedMatchStart = true;
      }
      _stats = stats;
      _recordedCurrentHand = state.lastRoundAppliedScores != null;
      _recordedCurrentMatch = state.isMatchComplete;
      _loading = false;
    });

    if (!_hasRecordedMatchStart) {
      await _recordMatchStarted();
    }
    _driveAi();
  }

  Duration get _aiDelay => switch (state.speed) {
    HeartsSpeed.instant => const Duration(milliseconds: 1),
    HeartsSpeed.normal => kCardAutoMoveDuration,
    HeartsSpeed.relaxed => const Duration(milliseconds: 950),
  };

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(HeartsGameState.storageKey, state.encode());
  }

  Future<void> _recordMatchStarted() async {
    if (_hasRecordedMatchStart) {
      return;
    }
    _hasRecordedMatchStart = true;
    final next = _stats.recordMatchStarted();
    setState(() {
      _stats = next;
    });
    await _statsStore.save(next);
  }

  Future<void> _recordHandIfNeeded() async {
    if (_recordedCurrentHand || state.lastRoundAppliedScores == null) {
      return;
    }
    final handBest =
        state.lastRoundAppliedScores![0] ==
        state.lastRoundAppliedScores!.reduce((a, b) => a < b ? a : b);
    final next = _stats.recordHand(
      humanWonHand: handBest,
      humanShotMoon: state.lastRoundMoonShooter == HeartsGameState.humanPlayer,
    );
    _recordedCurrentHand = true;
    setState(() {
      _stats = next;
    });
    await _statsStore.save(next);
  }

  Future<void> _recordMatchIfNeeded() async {
    if (_recordedCurrentMatch || !state.isMatchComplete) {
      return;
    }
    final humanWon =
        state.matchScores[0] ==
        state.matchScores.reduce((a, b) => a < b ? a : b);
    final next = _stats.recordMatchFinished(
      humanWonMatch: humanWon,
      finalScore: state.matchScores[0],
    );
    _recordedCurrentMatch = true;
    setState(() {
      _stats = next;
    });
    await _statsStore.save(next);
  }

  Future<void> _applyState(
    HeartsGameState nextState, {
    bool recordHistory = false,
  }) async {
    if (recordHistory) {
      _history.add(state);
    }
    setState(() {
      state = nextState;
    });
    await _persistState();
    await _recordHandIfNeeded();
    await _recordMatchIfNeeded();
    _driveAi();
  }

  void _driveAi() {
    _aiTimer?.cancel();
    if (!mounted ||
        !state.isPlaying ||
        state.isPaused ||
        state.currentPlayer == 0) {
      return;
    }
    _aiTimer = Timer(_aiDelay, () async {
      if (!mounted) {
        return;
      }
      final nextState = state.autoPlayCurrentPlayer();
      await _applyState(nextState);
    });
  }

  Future<void> _togglePause() async {
    await _applyState(state.togglePause());
  }

  Future<void> _setSpeed(HeartsSpeed speed) async {
    await _applyState(state.setSpeed(speed));
  }

  Future<void> _togglePassSelection(String cardKey) async {
    await _applyState(state.togglePassSelection(cardKey));
  }

  Future<void> _confirmPass() async {
    if (!state.isPassing || state.passDirection == HeartsPassDirection.hold) {
      return;
    }
    await _applyState(state.confirmHumanPass(), recordHistory: true);
  }

  Future<void> _playHumanCard(String cardKey) async {
    await _applyState(state.playHumanCard(cardKey), recordHistory: true);
  }

  Future<void> _undo() async {
    if (_history.isEmpty || state.isPaused) {
      return;
    }
    final previous = _history.removeLast();
    await _applyState(previous);
  }

  Future<void> _newMatch() async {
    _history.clear();
    _recordedCurrentHand = false;
    _recordedCurrentMatch = false;
    _hasRecordedMatchStart = false;
    await _applyState(state.newMatch());
    await _recordMatchStarted();
  }

  Future<bool> _confirmNewMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new match?'),
        content: const Text('Your current Hearts match will be replaced.'),
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

  Future<void> _confirmAndStartNewMatch() async {
    if (await _confirmNewMatch()) {
      await _newMatch();
    }
  }

  Future<void> _startNextHand() async {
    _history.clear();
    _recordedCurrentHand = false;
    await _applyState(state.startNextHand());
  }

  Future<void> _showStats() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hearts statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: 'Matches', value: '${_stats.matchesStarted}'),
            _StatRow(label: 'Match wins', value: '${_stats.matchesWon}'),
            _StatRow(label: 'Hands played', value: '${_stats.handsPlayed}'),
            _StatRow(label: 'Hands won', value: '${_stats.handsWon}'),
            _StatRow(
              label: 'Shoot the moon',
              value: '${_stats.shootTheMoonCount}',
            ),
            _StatRow(
              label: 'Best final score',
              value: _stats.bestMatchScore == null
                  ? '—'
                  : '${_stats.bestMatchScore}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRules() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How Hearts works'),
        content: const SingleChildScrollView(
          child: Text(
            '• Each hand starts with a pass: left, right, across, then hold.\n\n'
            '• The 2♣ leads the first trick. You must follow suit when you can.\n\n'
            '• Hearts cannot be led until hearts are broken, unless you only have hearts.\n\n'
            '• Hearts are worth 1 point each. The Q♠ is worth 13. Low score wins.\n\n'
            '• If one player takes all 26 points, they shoot the moon: they score 0 and everyone else gets 26.\n\n'
            '• The match ends when someone reaches 100 or more. Lowest total score wins.\n\n'
            '• Undo is available for your own pass/play decisions before continuing.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard(BuildContext context) {
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
                    'Hand ${state.handNumber + 1} • ${state.passDirectionLabel}',
                    key: const Key('hearts_status_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('hearts_undo'),
                  tooltip: 'Undo',
                  onPressed: _history.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: const Key('hearts_pause'),
                  tooltip: state.isPaused ? 'Resume' : 'Pause',
                  onPressed: _togglePause,
                  icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Game menu',
                  onSelected: (value) async {
                    switch (value) {
                      case 'new':
                        await _newMatch();
                      case 'stats':
                        await _showStats();
                      case 'rules':
                        await _showRules();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'new', child: Text('New match')),
                    PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    PopupMenuItem(value: 'rules', child: Text('Rules / help')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            GameStatsRow(
              dark: false,
              items: [
                GameStatItem(
                  label: 'Match',
                  value: '${state.matchScores[0]}',
                  icon: Icons.scoreboard_outlined,
                ),
                GameStatItem(
                  label: 'Hand',
                  value: '${state.handPoints[0]}',
                  icon: Icons.favorite_outline,
                ),
                GameStatItem(
                  label: 'Tricks',
                  value: '${state.tricksWon[0]}',
                  icon: Icons.style_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (int player = 0; player < 4; player++)
                  Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: player == 0
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.playerLabel(player),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text('Match: ${state.matchScores[player]}'),
                        Text('Hand: ${state.handPoints[player]}'),
                        Text('Tricks: ${state.tricksWon[player]}'),
                        if (player != 0) Text('Cards: ${state.hands[player].length}'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final speed in HeartsSpeed.values)
                  ChoiceChip(
                    key: Key('hearts_speed_${speed.name}'),
                    label: Text(switch (speed) {
                      HeartsSpeed.instant => 'Fast',
                      HeartsSpeed.normal => 'Normal',
                      HeartsSpeed.relaxed => 'Relaxed',
                    }),
                    selected: state.speed == speed,
                    onSelected: (_) => _setSpeed(speed),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(state.message, key: const Key('hearts_message')),
            if (state.lastRoundMoonShooter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${state.playerLabel(state.lastRoundMoonShooter!)} shot the moon.',
                  key: const Key('hearts_moon_banner'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OpponentStatus(
                  label: 'North',
                  details: '${state.hands[2].length} cards',
                  active: state.currentPlayer == 2 && state.isPlaying,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OpponentStatus(
                    label: 'West',
                    details: '${state.hands[1].length} cards',
                    active: state.currentPlayer == 1 && state.isPlaying,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          state.currentTrick.isEmpty
                              ? 'Current trick'
                              : 'Trick in progress',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final play in state.currentTrick)
                              Column(
                                children: [
                                  Text(state.playerLabel(play.player)),
                                  _CardFace(card: play.card, compact: true),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _OpponentStatus(
                    label: 'East',
                    details: '${state.hands[3].length} cards',
                    active: state.currentPlayer == 3 && state.isPlaying,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanHand(BuildContext context) {
    final isPassing =
        state.isPassing && state.passDirection != HeartsPassDirection.hold;
    final legal = state.legalPlaysFor(0).map((card) => card.key).toSet();

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
                    isPassing ? 'Your hand — choose 3 to pass' : 'Your hand',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (state.isRoundComplete && !state.isMatchComplete)
                  FilledButton(
                    key: const Key('hearts_next_hand'),
                    onPressed: _startNextHand,
                    child: const Text('Next hand'),
                  ),
                if (state.isMatchComplete)
                  FilledButton(
                    key: const Key('hearts_new_match'),
                    onPressed: _newMatch,
                    child: const Text('New match'),
                  ),
                if (isPassing)
                  FilledButton(
                    key: const Key('hearts_confirm_pass'),
                    onPressed: state.selectedPassCards.length == 3
                        ? _confirmPass
                        : null,
                    child: Text('Pass ${state.selectedPassCards.length}/3'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final card in state.hands[0])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (state.isPaused ||
                              state.isRoundComplete ||
                              state.isMatchComplete) {
                            return;
                          }
                          if (isPassing) {
                            _togglePassSelection(card.key);
                          } else if (state.isHumanTurn &&
                              legal.contains(card.key)) {
                            _playHumanCard(card.key);
                          }
                        },
                        child: _CardFace(
                          key: Key('hearts_human_card_${card.key}'),
                          card: card,
                          selected: state.selectedPassCards.contains(card.key),
                          playable:
                              !isPassing &&
                              legal.contains(card.key) &&
                              state.isHumanTurn &&
                              !state.isPaused,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _humanWonMatch =>
      state.isMatchComplete &&
      state.matchScores[0] == state.matchScores.reduce((a, b) => a < b ? a : b);

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.hearts,
      title: 'Table Won!',
      subtitle: 'The moon rises, hearts drift upward, and the table is yours.',
      stats: [
        WinScreenStat(
          label: 'Final score',
          value: '${state.matchScores[0]}',
          icon: Icons.scoreboard_outlined,
        ),
        WinScreenStat(
          label: 'Match wins',
          value: '${_stats.matchesWon}',
          icon: Icons.emoji_events_outlined,
        ),
        WinScreenStat(
          label: 'Hands won',
          value: '${_stats.handsWon}',
          icon: Icons.favorite_outline,
        ),
      ],
      onNewGame: _newMatch,
      onBackToMenu: _backToMenu,
      newGameLabel: 'New Match',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Hearts'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showRules,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _togglePause,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: _undo,
              undoEnabled: _history.isNotEmpty && !state.isPaused,
              onHint: state.isPassing && state.selectedPassCards.length < 3
                  ? null
                  : _showRules,
              hintEnabled: !state.isPaused,
              onNewDeal: _confirmAndStartNewMatch,
              onStatistics: _showStats,
              newDealLabel: 'New Match',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildScoreboard(context),
                            const SizedBox(height: 16),
                            Expanded(child: _buildTable(context)),
                            const SizedBox(height: 16),
                            _buildHumanHand(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_humanWonMatch) _buildWinOverlay(),
                ],
              ),
            ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.card,
    this.selected = false,
    this.playable = false,
    this.compact = false,
  });

  final HeartsCard card;
  final bool selected;
  final bool playable;
  final bool compact;

  PlayingCard _toPlayingCard() {
    final suit = switch (card.suit) {
      HeartsSuit.clubs => Suit.clubs,
      HeartsSuit.diamonds => Suit.diamonds,
      HeartsSuit.spades => Suit.spades,
      HeartsSuit.hearts => Suit.hearts,
    };
    final value = switch (card.rank) {
      2 => CardValue.two,
      3 => CardValue.three,
      4 => CardValue.four,
      5 => CardValue.five,
      6 => CardValue.six,
      7 => CardValue.seven,
      8 => CardValue.eight,
      9 => CardValue.nine,
      10 => CardValue.ten,
      11 => CardValue.jack,
      12 => CardValue.queen,
      13 => CardValue.king,
      _ => CardValue.ace,
    };
    return PlayingCard(suit, value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: kCardHighlightDuration,
      scale: selected ? 1.04 : 1,
      child: ClassicPlayingCard(
        card: _toPlayingCard(),
        width: compact ? 64 : 72,
        height: compact ? 86 : 100,
        borderColor: Theme.of(context).colorScheme.outlineVariant,
        highlightColor: selected || playable ? Theme.of(context).colorScheme.primary : null,
        borderWidth: selected || playable ? 2 : 1.2,
      ),
    );
  }
}

class _OpponentStatus extends StatelessWidget {
  const _OpponentStatus({
    required this.label,
    required this.details,
    required this.active,
  });

  final String label;
  final String details;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: kCardHighlightDuration,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(details),
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
