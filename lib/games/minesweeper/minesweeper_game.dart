import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';
import '../../shared/duration_format.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';
import 'minesweeper_game_state.dart';
import 'minesweeper_stats.dart';
import 'minesweeper_stats_store.dart';

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key, this.initialState});

  final MinesweeperGameState? initialState;

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame>
    with WidgetsBindingObserver {
  late MinesweeperGameState state;
  final MinesweeperStatsStore _statsStore = MinesweeperStatsStore();
  MinesweeperStats _stats = const MinesweeperStats();
  Timer? _ticker;
  bool _loading = true;
  bool _flagMode = false;
  bool _hasRecordedStart = false;
  bool _hasRecordedResult = false;
  MinesweeperConfig _lastCustomConfig = MinesweeperConfig.custom(
    rows: 16,
    columns: 16,
    mines: 40,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state =
        widget.initialState ??
        MinesweeperGameState.newGame(MinesweeperConfig.easy());
    if (!state.config.isPreset) {
      _lastCustomConfig = state.config;
    }
    _hasRecordedStart = state.generated;
    _hasRecordedResult = state.isComplete || state.isLost;
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
        ? MinesweeperGameState.tryDecode(
            prefs.getString(MinesweeperGameState.storageKey),
          )
        : null;
    final stats = await _statsStore.load();

    if (!mounted) {
      return;
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        if (!state.config.isPreset) {
          _lastCustomConfig = state.config;
        }
        _hasRecordedStart = state.generated;
        _hasRecordedResult = state.isComplete || state.isLost;
      }
      _stats = stats;
      _loading = false;
    });

    _syncTicker();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MinesweeperGameState.storageKey, state.encode());
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

  Future<void> _recordStartedGameIfNeeded() async {
    if (_hasRecordedStart) {
      return;
    }
    _hasRecordedStart = true;
    final nextStats = _stats.recordGameStarted();
    setState(() {
      _stats = nextStats;
    });
    await _statsStore.save(nextStats);
  }

  Future<void> _recordResultIfNeeded() async {
    if (_hasRecordedResult) {
      return;
    }
    MinesweeperStats nextStats = _stats;
    if (state.isComplete) {
      nextStats = _stats.recordWin(
        difficultyId: state.config.id,
        seconds: state.elapsedSeconds,
      );
    } else if (state.isLost) {
      nextStats = _stats.recordLoss();
    } else {
      return;
    }

    _hasRecordedResult = true;
    setState(() {
      _stats = nextStats;
    });
    await _statsStore.save(nextStats);
  }

  Future<void> _applyState(MinesweeperGameState nextState) async {
    final previousStatus = state.status;
    final wasGenerated = state.generated;
    setState(() {
      state = nextState;
      if (!state.config.isPreset) {
        _lastCustomConfig = state.config;
      }
    });

    if (!wasGenerated && nextState.generated) {
      await _recordStartedGameIfNeeded();
    }
    if (previousStatus != nextState.status) {
      await _recordResultIfNeeded();
    }

    _syncTicker();
    await _persistState();
  }

  Future<void> _newGame(MinesweeperConfig config) async {
    if (state.generated && !state.isComplete && !state.isLost) {
      final nextStats = _stats.recordLoss();
      setState(() {
        _stats = nextStats;
      });
      await _statsStore.save(nextStats);
    }

    _hasRecordedStart = false;
    _hasRecordedResult = false;
    await _applyState(MinesweeperGameState.newGame(config));
  }

  Future<void> _handleCellTap(int row, int column) async {
    if (_flagMode && !state.cellAt(row, column).revealed) {
      await _applyState(state.toggleFlag(row, column));
      return;
    }

    final cell = state.cellAt(row, column);
    final nextState = cell.revealed
        ? state.chordCell(row, column)
        : state.revealCell(row, column);
    if (!identical(nextState, state) || nextState != state) {
      await _applyState(nextState);
    }
  }

  Future<void> _handleCellLongPress(int row, int column) async {
    await _applyState(state.toggleFlag(row, column));
  }

  Future<void> _showStatistics() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Minesweeper statistics'),
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
              const SizedBox(height: 12),
              _StatRow(
                label: 'Best Easy',
                value: _stats.bestEasySeconds == null
                    ? '—'
                    : formatElapsedSeconds(_stats.bestEasySeconds!),
              ),
              _StatRow(
                label: 'Best Medium',
                value: _stats.bestMediumSeconds == null
                    ? '—'
                    : formatElapsedSeconds(_stats.bestMediumSeconds!),
              ),
              _StatRow(
                label: 'Best Hard',
                value: _stats.bestHardSeconds == null
                    ? '—'
                    : formatElapsedSeconds(_stats.bestHardSeconds!),
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
                  title: 'Number clue example',
                  children: [
                    HelpDiagram(
                      '□ □ □\n□ 3 □   ← this 3 means exactly three surrounding squares hide mines.\n🚩 □ 🚩',
                    ),
                  ],
                ),
                HelpSection(
                  title: 'Core rules',
                  children: [
                    HelpBulletList(
                      items: [
                        'Reveal every safe tile.',
                        'Use flag mode or long-press to mark mines.',
                        'Tap a revealed number to chord-open neighbors once the correct number of flags are placed.',
                        'Your first tap is always safe.',
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

  Future<bool> _confirmNewBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new board?'),
        content: const Text('Your current Minesweeper board will be replaced.'),
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

  Future<void> _confirmAndStartNewBoard() async {
    if (await _confirmNewBoard()) {
      await _newGame(state.config);
    }
  }

  Future<void> _openCustomDialog() async {
    String rowsValue = '${_lastCustomConfig.rows}';
    String columnsValue = '${_lastCustomConfig.columns}';
    String minesValue = '${_lastCustomConfig.mines}';

    final result = await showDialog<MinesweeperConfig>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewConfig = MinesweeperConfig.custom(
              rows: int.tryParse(rowsValue) ?? 0,
              columns: int.tryParse(columnsValue) ?? 0,
              mines: int.tryParse(minesValue) ?? 0,
            );
            final validationMessage = previewConfig.validate();

            return AlertDialog(
              title: const Text('Custom board'),
              scrollable: true,
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const Key('minesweeper_custom_rows'),
                      initialValue: rowsValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rows'),
                      onChanged: (value) =>
                          setDialogState(() => rowsValue = value),
                    ),
                    TextFormField(
                      key: const Key('minesweeper_custom_columns'),
                      initialValue: columnsValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Columns'),
                      onChanged: (value) =>
                          setDialogState(() => columnsValue = value),
                    ),
                    TextFormField(
                      key: const Key('minesweeper_custom_mines'),
                      initialValue: minesValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mines'),
                      onChanged: (value) =>
                          setDialogState(() => minesValue = value),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationMessage ??
                            'Use a board size between 5×5 and 40×40.',
                        style: TextStyle(
                          color: validationMessage == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('minesweeper_apply_custom'),
                  onPressed: validationMessage == null
                      ? () => Navigator.of(context).pop(previewConfig)
                      : null,
                  child: const Text('Start board'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _lastCustomConfig = result;
      await _newGame(result);
    }
  }

  Future<void> _showSettings() async {
    await _openCustomDialog();
  }

  Widget _buildDifficultySelector() {
    final options = [
      MinesweeperConfig.easy(),
      MinesweeperConfig.medium(),
      MinesweeperConfig.hard(),
      if (!state.config.isPreset) state.config else _lastCustomConfig,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final config in options)
          ChoiceChip(
            key: Key('minesweeper_difficulty_${config.id}'),
            label: Text(config.label),
            selected:
                state.config.id == config.id &&
                (config.id != 'custom' || !state.config.isPreset),
            onSelected: (_) async {
              if (config.id == 'custom') {
                await _openCustomDialog();
              } else {
                await _newGame(config);
              }
            },
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bestTime = _stats.bestTimeFor(state.config.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${state.config.label} • ${state.rows}×${state.columns} • ${state.mineCount} mines',
              key: const Key('minesweeper_board_label'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GameStatsRow(
              dark: false,
              items: [
                GameStatItem(
                  label: 'Mines',
                  value: '${state.remainingMines}',
                  icon: Icons.flag_rounded,
                ),
                GameStatItem(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                ),
                GameStatItem(
                  label: 'Best',
                  value: bestTime == null ? '—' : formatElapsedSeconds(bestTime),
                  icon: Icons.emoji_events_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDifficultySelector(),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: kHintPulseDuration,
              child: Text(
                state.message,
                key: ValueKey<String>(state.message),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context, BoxConstraints viewportConstraints) {
    final boardViewportHeight = math.max(
      220.0,
      viewportConstraints.maxHeight - 300,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: boardViewportHeight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context).size;
              final availableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : media.width - 56;
              final availableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : boardViewportHeight - 24;
              const spacing = 2.0;
              const minimumTileSize = 8.0;
              final preferredMaxTileSize = switch (state.config.id) {
                'easy' => 42.0,
                'medium' => 30.0,
                'hard' => 22.0,
                _ => 22.0,
              };
              final tileSize = math.max(
                minimumTileSize,
                math.min(
                  preferredMaxTileSize,
                  math.min(
                    (availableWidth - (state.columns * spacing)) /
                        state.columns,
                    (availableHeight - (state.rows * spacing)) / state.rows,
                  ),
                ),
              );
              final boardWidth = state.columns * (tileSize + spacing);
              final boardHeight = state.rows * (tileSize + spacing);

              return Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: boardWidth,
                    height: boardHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int row = 0; row < state.rows; row++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                int column = 0;
                                column < state.columns;
                                column++
                              )
                                _MinesweeperTile(
                                  key: Key('minesweeper_cell_${row}_$column'),
                                  cell: state.cellAt(row, column),
                                  size: tileSize,
                                  onTap: () => _handleCellTap(row, column),
                                  onLongPress: () =>
                                      _handleCellLongPress(row, column),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FilterChip(
            key: const Key('minesweeper_flag_mode'),
            selected: _flagMode,
            onSelected: (value) {
              setState(() {
                _flagMode = value;
              });
            },
            avatar: Icon(
              _flagMode ? Icons.flag : Icons.touch_app_outlined,
              size: 18,
            ),
            label: Text(_flagMode ? 'Flag mode on' : 'Reveal mode'),
          ),
        ),
      ),
    );
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.minesweeper,
      title: 'Minefield Cleared!',
      subtitle:
          'Flags wave, the board sweeps clean, and every safe tile is revealed.',
      stats: [
        WinScreenStat(
          label: 'Time',
          value: formatElapsedSeconds(state.elapsedSeconds),
          icon: Icons.timer_outlined,
        ),
        WinScreenStat(
          label: 'Mines',
          value: '${state.mineCount}',
          icon: Icons.flag_outlined,
        ),
        WinScreenStat(
          label: 'Wins',
          value: '${_stats.gamesWon}',
          icon: Icons.emoji_events_outlined,
        ),
      ],
      onNewGame: () => _newGame(state.config),
      onBackToMenu: _backToMenu,
      newGameLabel: 'New Board',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Minesweeper'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHowToPlay,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: null,
              undoEnabled: false,
              onHint: () {
                setState(() {
                  _flagMode = !_flagMode;
                });
              },
              onNewDeal: _confirmAndStartNewBoard,
              onStatistics: _showStatistics,
              newDealLabel: 'New Board',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, viewportConstraints) {
                  return Stack(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 16),
                                Expanded(child: _buildBoard(context, viewportConstraints)),
                                const SizedBox(height: 16),
                                _buildControls(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (state.isComplete) _buildWinOverlay(),
                    ],
                  );
                },
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

class _MinesweeperTile extends StatelessWidget {
  const _MinesweeperTile({
    super.key,
    required this.cell,
    required this.size,
    required this.onTap,
    required this.onLongPress,
  });

  final MinesweeperCell cell;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final revealed = cell.revealed;
    final foreground = switch (cell.adjacentMines) {
      1 => Colors.blue.shade700,
      2 => Colors.green.shade700,
      3 => Colors.red.shade700,
      4 => Colors.indigo.shade700,
      5 => Colors.brown.shade700,
      6 => Colors.teal.shade700,
      7 => Colors.black87,
      8 => Colors.grey.shade800,
      _ => scheme.onSurface,
    };

    Color backgroundColor;
    if (revealed && cell.exploded) {
      backgroundColor = scheme.errorContainer;
    } else if (revealed) {
      backgroundColor = scheme.surfaceContainerHighest;
    } else if (cell.flagged) {
      backgroundColor = scheme.primaryContainer;
    } else {
      backgroundColor = scheme.surfaceContainerLow;
    }

    Widget child;
    if (cell.revealed && cell.hasMine) {
      child = const Icon(Icons.circle, size: 14);
    } else if (!cell.revealed && cell.flagged) {
      child = const Icon(Icons.flag, size: 16);
    } else if (cell.revealed && cell.adjacentMines > 0) {
      child = Text(
        '${cell.adjacentMines}',
        style: TextStyle(fontWeight: FontWeight.w800, color: foreground),
      );
    } else {
      child = const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: size + 2,
        height: size + 2,
        child: AnimatedScale(
          duration: kMinesweeperRevealDuration,
          scale: revealed ? 0.98 : 1,
          child: Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: revealed
                    ? scheme.outlineVariant
                    : scheme.outline.withValues(alpha: 0.35),
              ),
              boxShadow: revealed
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: kMinesweeperRevealDuration,
              child: SizedBox(
                key: ValueKey<String>(
                  '${cell.revealed}_${cell.flagged}_${cell.hasMine}_${cell.adjacentMines}_${cell.exploded}',
                ),
                width: size,
                height: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
