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
        title: const Text('How to play Hearts'),
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

  // ---------------------------------------------------------------------------
  // Score strip — compact row of 4 player indicators at the top
  // ---------------------------------------------------------------------------

  Widget _buildScoreStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _PlayerChip(state: state, player: i),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table centre — compass-layout trick display with opponent indicators
  // ---------------------------------------------------------------------------

  Widget _buildTableCenter() {
    final isPassing =
        state.isPassing && state.passDirection != HeartsPassDirection.hold;
    return Expanded(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                // North
                Align(
                  alignment: const Alignment(0, -0.85),
                  child: _OpponentLabel(state: state, player: 2),
                ),
                Align(
                  alignment: const Alignment(0, -0.42),
                  child: _TrickSlot(play: _trickPlayFor(2)),
                ),
                // West
                Align(
                  alignment: const Alignment(-0.85, 0),
                  child: _OpponentLabel(state: state, player: 1),
                ),
                Align(
                  alignment: const Alignment(-0.38, 0),
                  child: _TrickSlot(play: _trickPlayFor(1)),
                ),
                // East
                Align(
                  alignment: const Alignment(0.85, 0),
                  child: _OpponentLabel(state: state, player: 3),
                ),
                Align(
                  alignment: const Alignment(0.38, 0),
                  child: _TrickSlot(play: _trickPlayFor(3)),
                ),
                // South (you)
                Align(
                  alignment: const Alignment(0, 0.42),
                  child: _TrickSlot(play: _trickPlayFor(0)),
                ),
                // Status message in the centre
                Center(child: _buildStatusChip()),
                // Pass direction indicator
                if (isPassing)
                  Align(
                    alignment: const Alignment(0, 0.85),
                    child: _buildPassDirectionChip(),
                  ),
                // Round / match actions
                if (state.isRoundComplete || state.isMatchComplete)
                  Align(
                    alignment: const Alignment(0, 0.85),
                    child: _buildRoundActions(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  HeartsTrickPlay? _trickPlayFor(int player) {
    for (final play in state.currentTrick) {
      if (play.player == player) return play;
    }
    return null;
  }

  Widget _buildStatusChip() {
    final msg = state.message;
    if (msg.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('hearts_message'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.lastRoundMoonShooter != null
            ? '${state.playerLabel(state.lastRoundMoonShooter!)} shot the moon!'
            : msg,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPassDirectionChip() {
    final icon = switch (state.passDirection) {
      HeartsPassDirection.left => Icons.arrow_back_rounded,
      HeartsPassDirection.right => Icons.arrow_forward_rounded,
      HeartsPassDirection.across => Icons.swap_vert_rounded,
      HeartsPassDirection.hold => Icons.front_hand_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            state.passDirectionLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundActions() {
    if (state.isMatchComplete) {
      return FilledButton.icon(
        key: const Key('hearts_new_match'),
        onPressed: _newMatch,
        icon: const Icon(Icons.casino_outlined),
        label: const Text('New Match'),
      );
    }
    return FilledButton.icon(
      key: const Key('hearts_next_hand'),
      onPressed: _startNextHand,
      icon: const Icon(Icons.skip_next_rounded),
      label: const Text('Next Hand'),
    );
  }

  // ---------------------------------------------------------------------------
  // Human hand — overlapping fan of cards with pass/play interactions
  // ---------------------------------------------------------------------------

  Widget _buildPlayerHand() {
    final isPassing =
        state.isPassing && state.passDirection != HeartsPassDirection.hold;
    final legal = state.legalPlaysFor(0).map((card) => card.key).toSet();
    final hand = state.hands[0];

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F3F25),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pass confirmation row
            if (isPassing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Select ${3 - state.selectedPassCards.length} more'
                      '${state.selectedPassCards.isEmpty ? ' cards to pass' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('hearts_confirm_pass'),
                      onPressed: state.selectedPassCards.length == 3
                          ? _confirmPass
                          : null,
                      child: Text('Pass ${state.selectedPassCards.length}/3'),
                    ),
                  ],
                ),
              ),
            // Card fan
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double cardW = 72;
                  const double cardH = 100;
                  if (hand.isEmpty) {
                    return const SizedBox(height: cardH);
                  }
                  final available = constraints.maxWidth - cardW;
                  final overlap = hand.length > 1
                      ? (available / (hand.length - 1)).clamp(18.0, 52.0)
                      : 0.0;
                  final totalWidth = cardW + overlap * (hand.length - 1);

                  return SizedBox(
                    height: cardH + 22,
                    child: Center(
                      child: SizedBox(
                        width: totalWidth,
                        height: cardH + 22,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < hand.length; i++)
                              _buildHandCard(
                                hand[i],
                                i,
                                overlap,
                                isPassing,
                                legal,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandCard(
    HeartsCard card,
    int index,
    double overlap,
    bool isPassing,
    Set<String> legal,
  ) {
    final isSelected = state.selectedPassCards.contains(card.key);
    final isPlayable =
        !isPassing &&
        legal.contains(card.key) &&
        state.isHumanTurn &&
        !state.isPaused;
    final isDimmed =
        !isPassing &&
        state.isPlaying &&
        state.isHumanTurn &&
        !isPlayable &&
        !state.isPaused;
    final yOffset = isSelected ? -20.0 : (isDimmed ? 8.0 : 0.0);

    return AnimatedPositioned(
      duration: kCardHighlightDuration,
      curve: Curves.easeOut,
      left: index * overlap,
      top: yOffset + 22,
      child: GestureDetector(
        onTap: () {
          if (state.isPaused ||
              state.isRoundComplete ||
              state.isMatchComplete) {
            return;
          }
          if (isPassing) {
            _togglePassSelection(card.key);
          } else if (isPlayable) {
            _playHumanCard(card.key);
          }
        },
        child: _CardFace(
          key: Key('hearts_human_card_${card.key}'),
          card: card,
          selected: isSelected,
          playable: isPlayable,
          dimmed: isDimmed,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar — dark green, Undo | New Match | Statistics
  // ---------------------------------------------------------------------------

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
            Tooltip(
              message: 'Undo',
              child: IconButton.filledTonal(
                key: const Key('hearts_undo'),
                onPressed: _history.isEmpty || state.isPaused ? null : _undo,
                icon: const Icon(Icons.undo),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _confirmAndStartNewMatch,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('New Match'),
            ),
            const Spacer(),
            Tooltip(
              message: 'Statistics',
              child: IconButton.filledTonal(
                onPressed: _showStats,
                icon: const Icon(Icons.bar_chart_rounded),
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
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showRules,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Game menu',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'new':
                  await _confirmAndStartNewMatch();
                case 'stats':
                  await _showStats();
                case 'pause':
                  await _togglePause();
                case 'speed_instant':
                  await _setSpeed(HeartsSpeed.instant);
                case 'speed_normal':
                  await _setSpeed(HeartsSpeed.normal);
                case 'speed_relaxed':
                  await _setSpeed(HeartsSpeed.relaxed);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new', child: Text('New match')),
              const PopupMenuItem(value: 'stats', child: Text('Statistics')),
              PopupMenuItem(
                value: 'pause',
                child: Text(state.isPaused ? 'Resume' : 'Pause'),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'speed_instant',
                checked: state.speed == HeartsSpeed.instant,
                child: const Text('Fast'),
              ),
              CheckedPopupMenuItem(
                value: 'speed_normal',
                checked: state.speed == HeartsSpeed.normal,
                child: const Text('Normal'),
              ),
              CheckedPopupMenuItem(
                value: 'speed_relaxed',
                checked: state.speed == HeartsSpeed.relaxed,
                child: const Text('Relaxed'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _loading ? null : _buildBottomBar(),
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
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildScoreStrip(),
                      _buildTableCenter(),
                      _buildPlayerHand(),
                    ],
                  ),
                  if (_humanWonMatch) _buildWinOverlay(),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// Private helper widgets
// =============================================================================

/// A single card rendered using the playing_cards package.
class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.card,
    this.selected = false,
    this.playable = false,
    this.dimmed = false,
    this.compact = false,
  });

  final HeartsCard card;
  final bool selected;
  final bool playable;
  final bool dimmed;
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
    final Color? highlight = selected
        ? const Color(0xFFFFD971)
        : playable
        ? const Color(0xFF8DD9FF)
        : null;
    return AnimatedOpacity(
      duration: kCardHighlightDuration,
      opacity: dimmed ? 0.45 : 1.0,
      child: AnimatedScale(
        duration: kCardHighlightDuration,
        scale: selected ? 1.06 : 1,
        child: ClassicPlayingCard(
          card: _toPlayingCard(),
          width: compact ? 68 : 72,
          height: compact ? 95 : 100,
          borderColor: highlight ?? Colors.white.withValues(alpha: 0.35),
          highlightColor: highlight,
          borderWidth: highlight != null ? 2.4 : 1.2,
        ),
      ),
    );
  }
}

/// Compact player score indicator for the top strip.
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.state, required this.player});

  final HeartsGameState state;
  final int player;

  @override
  Widget build(BuildContext context) {
    final isActive = state.isPlaying && state.currentPlayer == player;
    final isHuman = player == 0;
    return AnimatedContainer(
      duration: kCardHighlightDuration,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFFD971).withValues(alpha: 0.22)
            : isHuman
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFFD971).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.playerLabel(player),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: isHuman ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${state.matchScores[player]}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (state.handPoints[player] > 0)
            Text(
              '+${state.handPoints[player]}',
              style: TextStyle(
                color: state.handPoints[player] > 10
                    ? const Color(0xFFFF8A80)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Opponent name / card-count badge next to the table.
class _OpponentLabel extends StatelessWidget {
  const _OpponentLabel({required this.state, required this.player});

  final HeartsGameState state;
  final int player;

  @override
  Widget build(BuildContext context) {
    final isActive = state.isPlaying && state.currentPlayer == player;
    final cardCount = state.hands[player].length;
    return AnimatedContainer(
      duration: kCardHighlightDuration,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFFD971).withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFFD971).withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.playerLabel(player),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$cardCount',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single slot in the trick area — shows a card or an empty placeholder.
class _TrickSlot extends StatelessWidget {
  const _TrickSlot({this.play});

  final HeartsTrickPlay? play;

  @override
  Widget build(BuildContext context) {
    if (play != null) {
      return _CardFace(card: play!.card, compact: true);
    }
    return Container(
      width: 68,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
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
