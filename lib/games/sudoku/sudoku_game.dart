import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/animation_constants.dart';
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Settings',
            onSelected: (value) async {
              switch (value) {
                case 'difficulty':
                  await _openDifficultySettings();
                case 'new':
                  await _newPuzzle();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'difficulty', child: Text('Difficulty')),
              PopupMenuItem(value: 'new', child: Text('New game')),
            ],
          ),
        ],
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
          minimum: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize =
                        (constraints.maxWidth < 500
                                ? constraints.maxWidth - 8
                                : minValue(
                                    constraints.maxWidth - 8,
                                    constraints.maxHeight - 280,
                                  ))
                            .clamp(260.0, 520.0)
                            .toDouble();

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
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildMessageCard(),
                                  const SizedBox(height: 18),
                                  Center(
                                    child: SizedBox(
                                      width: boardSize,
                                      height: boardSize,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFF23324A),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                            for (int row = 0; row < 9; row++)
                                              Expanded(child: _buildRow(row)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildBottomActions(),
                                  const SizedBox(height: 12),
                                  _buildPad(),
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

  Widget _buildBottomActions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          key: const Key('sudoku_new_puzzle'),
          onPressed: _newPuzzle,
          icon: const Icon(Icons.refresh),
          label: const Text('New Game'),
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_undo'),
          onPressed: state.canUndo ? _handleUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
      ],
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
