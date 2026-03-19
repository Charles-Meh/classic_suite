import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
import '../../shared/classic_game_ui.dart';
import '../../shared/help_widgets.dart';
import '../../shared/win_screen.dart';

import 'sudoku_game_state.dart';

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, this.initialState});

  final SudokuGameState? initialState;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> with WidgetsBindingObserver {
  late SudokuGameState state;
  bool _loading = true;
  SudokuDifficulty _selectedDifficulty = SudokuDifficulty.easy;
  int _difficultyCursor = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.initialState?.copy() ?? SudokuGameState();
    _selectedDifficulty = state.difficulty;
    _syncDifficultyCursor();
    _loadSavedState();
  }

  void _syncDifficultyCursor() {
    final pool = SudokuGameState.puzzlesByDifficulty(_selectedDifficulty);
    _difficultyCursor = pool.indexWhere(
      (puzzle) => puzzle.id == state.puzzleId,
    );
    if (_difficultyCursor < 0) {
      _difficultyCursor = 0;
    }
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = SudokuGameState.tryDecode(
      prefs.getString(SudokuGameState.storageKey),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (loaded != null) {
        state = loaded;
        _selectedDifficulty = state.difficulty;
        _syncDifficultyCursor();
      }
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _persistState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SudokuGameState.storageKey, state.encode());
  }

  Future<void> _applyAndPersist(VoidCallback update) async {
    setState(() {
      update();
    });
    await _persistState();
  }

  Future<void> _newPuzzle() async {
    final pool = SudokuGameState.puzzlesByDifficulty(_selectedDifficulty);
    final nextIndex = pool.isEmpty ? 0 : (_difficultyCursor + 1) % pool.length;

    setState(() {
      _difficultyCursor = nextIndex;
      state = SudokuGameState(
        puzzleIndex: nextIndex,
        difficulty: _selectedDifficulty,
      );
      state.message =
          'New ${_selectedDifficulty.label.toLowerCase()} game started.';
    });
    await _persistState();
  }

  Future<void> _setDifficulty(SudokuDifficulty difficulty) async {
    setState(() {
      _selectedDifficulty = difficulty;
      _difficultyCursor = 0;
      state = SudokuGameState(puzzleIndex: 0, difficulty: difficulty);
      state.message = '${difficulty.label} game started.';
    });
    await _persistState();
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to play Sudoku'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelpSection(
                title: 'Goal',
                children: [
                  Text(
                    'Fill every row, column, and 3×3 box with the digits 1-9 without repeats.',
                  ),
                ],
              ),
              HelpSection(
                title: 'Valid vs invalid',
                children: [
                  HelpDiagram(
                    'Valid row:   1 2 3 4 5 6 7 8 9\nInvalid row: 1 2 3 4 5 6 7 8 8  ← repeated 8',
                  ),
                ],
              ),
              HelpSection(
                title: 'Controls',
                children: [
                  HelpBulletList(
                    items: [
                      'Tap a cell, then choose a number.',
                      'Use the color feedback to spot duplicates in a row, column, or box.',
                      'Undo reverses your last move.',
                      'The game autosaves as you play.',
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDifficultySettings() async {
    final selected = await showDialog<SudokuDifficulty>(
      context: context,
      builder: (context) {
        var choice = _selectedDifficulty;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Difficulty'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final difficulty in SudokuDifficulty.values)
                  ListTile(
                    key: Key('sudoku_difficulty_${difficulty.name}'),
                    title: Text(difficulty.label),
                    trailing: choice == difficulty
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.circle_outlined),
                    onTap: () {
                      setLocalState(() {
                        choice = difficulty;
                      });
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(choice),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _selectedDifficulty) {
      return;
    }

    await _setDifficulty(selected);
  }

  Future<void> _handleDigitInput(int value) async {
    await _applyAndPersist(() {
      state.setSelectedValue(value);
    });
  }

  Future<void> _handleClear() async {
    await _applyAndPersist(() {
      state.clearSelectedCell();
    });
  }

  Future<void> _handleUndo() async {
    await _applyAndPersist(() {
      state.undo();
    });
  }

  Future<void> _showHint() async {
    await _applyAndPersist(() {
      state.applyHint();
    });
  }

  Future<bool> _confirmNewPuzzle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start new puzzle?'),
        content: const Text('Your current Sudoku progress will be replaced.'),
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

  Future<void> _confirmAndStartNewPuzzle() async {
    if (await _confirmNewPuzzle()) {
      await _newPuzzle();
    }
  }

  Future<void> _showStatistics() async {
    final filled = state.board
        .expand((row) => row)
        .where((value) => value != 0)
        .length;
    final givens = state.givens
        .expand((row) => row)
        .where((value) => value != 0)
        .length;
    final remaining = 81 - filled;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sudoku statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: 'Difficulty', value: state.difficulty.label),
            _StatRow(label: 'Puzzle', value: state.puzzleName),
            _StatRow(label: 'Starter clues', value: '$givens'),
            _StatRow(label: 'Filled cells', value: '$filled / 81'),
            _StatRow(label: 'Remaining', value: '$remaining'),
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

  void _handleCellTap(int row, int col) {
    setState(() {
      state.selectCell(row, col);
    });
  }

  void _backToMenu() {
    Navigator.of(context).maybePop();
  }

  Widget _buildWinOverlay() {
    return GameWinScreen(
      theme: WinScreenTheme.sudoku,
      title: 'Grid Complete!',
      subtitle:
          'The final numbers lock in with a golden glow. Nice clean solve.',
      stats: [
        WinScreenStat(
          label: 'Difficulty',
          value: state.difficulty.label,
          icon: Icons.tune_rounded,
        ),
        WinScreenStat(
          label: 'Puzzle',
          value: state.puzzleName,
          icon: Icons.grid_4x4_rounded,
        ),
      ],
      onNewGame: _newPuzzle,
      onBackToMenu: _backToMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filled = state.board
        .expand((row) => row)
        .where((value) => value != 0)
        .length;
    final remaining = 81 - filled;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openDifficultySettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : GameBottomBar(
              onUndo: _handleUndo,
              undoEnabled: state.canUndo,
              onHint: _showHint,
              hintEnabled: !state.completed,
              onNewDeal: _confirmAndStartNewPuzzle,
              onStatistics: _showStatistics,
              newDealLabel: 'New Game',
            ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7FB), Color(0xFFE3EBF7)],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final reservedHeight = constraints.maxHeight >= 760
                        ? 250.0
                        : 190.0;
                    final boardSize = minValue(
                      constraints.maxWidth - 8,
                      constraints.maxHeight - reservedHeight,
                    ).clamp(220.0, 520.0).toDouble();

                    return Stack(
                      children: [
                        Focus(
                          autofocus: true,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }

                            final label = event.character;
                            if (label != null &&
                                RegExp(r'^[1-9]$').hasMatch(label)) {
                              _handleDigitInput(int.parse(label));
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey ==
                                    LogicalKeyboardKey.backspace ||
                                event.logicalKey == LogicalKeyboardKey.delete ||
                                event.logicalKey == LogicalKeyboardKey.digit0 ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpad0) {
                              _handleClear();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GameStatsRow(
                                    dark: false,
                                    items: [
                                      GameStatItem(
                                        label: 'Difficulty',
                                        value: state.difficulty.label,
                                        icon: Icons.tune_rounded,
                                      ),
                                      GameStatItem(
                                        label: 'Filled',
                                        value: '$filled/81',
                                        icon: Icons.edit_note_rounded,
                                      ),
                                      GameStatItem(
                                        label: 'Left',
                                        value: '$remaining',
                                        icon: Icons.grid_view_rounded,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildMessageCard(),
                                  const SizedBox(height: 18),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Column(
                                        children: [
                                          Center(
                                            child: SizedBox(
                                              width: boardSize,
                                              height: boardSize,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF23324A,
                                                    ),
                                                    width: 2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x22000000),
                                                      blurRadius: 18,
                                                      offset: Offset(0, 10),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    for (
                                                      int row = 0;
                                                      row < 9;
                                                      row++
                                                    )
                                                      Expanded(
                                                        child: _buildRow(row),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildPad(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (state.completed) _buildWinOverlay(),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: state.completed
            ? const Color(0xFFE3F4E9)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        state.message,
        key: const Key('sudoku_status_message'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: state.completed ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPad() {
    final invalid = state.invalidValuesForSelection();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int value = 1; value <= 9; value++)
          SizedBox(
            width: 56,
            height: 56,
            child: FilledButton(
              key: Key('sudoku_digit_$value'),
              onPressed: state.completed
                  ? null
                  : () => _handleDigitInput(value),
              style: FilledButton.styleFrom(
                backgroundColor: invalid.contains(value)
                    ? const Color(0xFF9C4237)
                    : null,
              ),
              child: Text('$value'),
            ),
          ),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            key: const Key('sudoku_clear_cell'),
            onPressed: state.completed ? null : _handleClear,
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Clear'),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int row) {
    return Row(
      children: [
        for (int col = 0; col < 9; col++) Expanded(child: _buildCell(row, col)),
      ],
    );
  }

  Widget _buildCell(int row, int col) {
    final value = state.board[row][col];
    final given = state.isGiven(row, col);
    final selected = state.isSelected(row, col);
    final related = state.isRelatedToSelection(row, col);
    final conflict = state.isConflictingCell(row, col);
    final isBoxEdgeRight = (col + 1) % 3 == 0 && col != 8;
    final isBoxEdgeBottom = (row + 1) % 3 == 0 && row != 8;

    Color background = Colors.white;
    if (selected) {
      background = const Color(0xFFCCE4FF);
    } else if (conflict) {
      background = const Color(0xFFFAD2CF);
    } else if (related) {
      background = const Color(0xFFF3F7FD);
    }

    return GestureDetector(
      onTap: () => _handleCellTap(row, col),
      child: AnimatedContainer(
        duration: kSudokuHintDuration,
        curve: Curves.easeOutCubic,
        key: Key('sudoku_cell_${row}_$col'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            top: BorderSide(
              color: row == 0
                  ? const Color(0xFF23324A)
                  : const Color(0xFF9BA8BC),
              width: row == 0 ? 0 : 0.6,
            ),
            left: BorderSide(
              color: col == 0
                  ? const Color(0xFF23324A)
                  : const Color(0xFF9BA8BC),
              width: col == 0 ? 0 : 0.6,
            ),
            right: BorderSide(
              color: isBoxEdgeRight
                  ? const Color(0xFF23324A)
                  : const Color(0xFF9BA8BC),
              width: isBoxEdgeRight ? 2 : 0.6,
            ),
            bottom: BorderSide(
              color: isBoxEdgeBottom
                  ? const Color(0xFF23324A)
                  : const Color(0xFF9BA8BC),
              width: isBoxEdgeBottom ? 2 : 0.6,
            ),
          ),
        ),
        child: value == 0 ? const SizedBox.shrink() : _buildValue(value, given),
      ),
    );
  }

  Widget _buildValue(int value, bool given) {
    return Text(
      '$value',
      style: TextStyle(
        fontSize: 20,
        fontWeight: given ? FontWeight.w800 : FontWeight.w700,
        color: const Color(0xFF1C2A3D),
      ),
    );
  }
}

double minValue(double a, double b) => a < b ? a : b;

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
