import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/duration_format.dart';
import 'minesweeper_game_state.dart';
import 'minesweeper_stats.dart';
import 'minesweeper_stats_store.dart';

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key, this.initialState});

  final MinesweeperGameState? initialState;

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame> {
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
    state = widget.initialState ?? MinesweeperGameState.newGame(MinesweeperConfig.easy());
    if (!state.config.isPreset) {
      _lastCustomConfig = state.config;
    }
    _hasRecordedStart = state.generated;
    _hasRecordedResult = state.isComplete || state.isLost;
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
              _StatRow(label: 'Current streak', value: '${_stats.currentStreak}'),
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
          content: const Text(
            'Reveal every safe tile. Use flag mode or long-press to mark mines. '
            'Tap a revealed number to chord-open the surrounding tiles once the right number of flags are in place. '
            'Your first tap is always safe.',
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
                      onChanged: (value) => setDialogState(() => rowsValue = value),
                    ),
                    TextFormField(
                      key: const Key('minesweeper_custom_columns'),
                      initialValue: columnsValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Columns'),
                      onChanged: (value) => setDialogState(() => columnsValue = value),
                    ),
                    TextFormField(
                      key: const Key('minesweeper_custom_mines'),
                      initialValue: minesValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mines'),
                      onChanged: (value) => setDialogState(() => minesValue = value),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationMessage ?? 'Use a board size between 5×5 and 40×40.',
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
            selected: state.config.id == config.id &&
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
    final scheme = Theme.of(context).colorScheme;
    final bestTime = _stats.bestTimeFor(state.config.id);

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
                    '${state.config.label} • ${state.rows}×${state.columns} • ${state.mineCount} mines',
                    key: const Key('minesweeper_board_label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('minesweeper_restart'),
                  tooltip: 'Restart board',
                  onPressed: () => _newGame(state.config),
                  icon: const Icon(Icons.restart_alt),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Game menu',
                  onSelected: (value) async {
                    switch (value) {
                      case 'new':
                        await _newGame(state.config);
                      case 'stats':
                        await _showStatistics();
                      case 'help':
                        await _showHowToPlay();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'new', child: Text('New board')),
                    PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    PopupMenuItem(value: 'help', child: Text('How to play')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDifficultySelector(),
            const SizedBox(height: 16),
            Row(
              children: [
                _CounterBadge(
                  label: 'Mines left',
                  value: '${state.remainingMines}',
                  icon: Icons.flag_rounded,
                  color: scheme.primaryContainer,
                ),
                const SizedBox(width: 12),
                _CounterBadge(
                  label: 'Time',
                  value: formatElapsedSeconds(state.elapsedSeconds),
                  icon: Icons.timer_outlined,
                  color: scheme.secondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CounterBadge(
                    label: 'Best',
                    value: bestTime == null ? '—' : formatElapsedSeconds(bestTime),
                    icon: Icons.emoji_events_outlined,
                    color: scheme.tertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
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
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      state.message,
                      key: ValueKey<String>(state.message),
                      style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildBoard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width - 56;
            final tileSize = math.max(
              14,
              math.min(34, (availableWidth / state.columns) - 2),
            ).toDouble();
            final boardWidth = state.columns * (tileSize + 2);
            final boardHeight = state.rows * (tileSize + 2);

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: boardWidth,
                height: boardHeight,
                child: Column(
                  children: [
                    for (int row = 0; row < state.rows; row++)
                      Row(
                        children: [
                          for (int column = 0; column < state.columns; column++)
                            _MinesweeperTile(
                              key: Key('minesweeper_cell_${row}_$column'),
                              cell: state.cellAt(row, column),
                              size: tileSize,
                              onTap: () => _handleCellTap(row, column),
                              onLongPress: () => _handleCellLongPress(row, column),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minesweeper')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildBoard(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
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
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: revealed ? 0.98 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
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
            duration: const Duration(milliseconds: 160),
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
    );
  }
}
