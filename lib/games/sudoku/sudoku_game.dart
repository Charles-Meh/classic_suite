import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_game_state.dart';

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, this.initialState});

  final SudokuGameState? initialState;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late SudokuGameState state;
  bool _loading = true;
  bool _saving = false;
  int _puzzleCursor = 0;

  @override
  void initState() {
    super.initState();
    state = widget.initialState?.copy() ?? SudokuGameState();
    _puzzleCursor = SudokuGameState.puzzles.indexWhere(
      (puzzle) => puzzle.id == state.puzzleId,
    );
    if (_puzzleCursor < 0) {
      _puzzleCursor = 0;
    }
    _loadSavedState();
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
        _puzzleCursor = SudokuGameState.puzzles.indexWhere(
          (puzzle) => puzzle.id == state.puzzleId,
        );
        if (_puzzleCursor < 0) {
          _puzzleCursor = 0;
        }
      }
      _loading = false;
    });
  }

  Future<void> _persistState() async {
    setState(() {
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SudokuGameState.storageKey, state.encode());

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  Future<void> _newPuzzle() async {
    setState(() {
      _puzzleCursor = (_puzzleCursor + 1) % SudokuGameState.puzzles.length;
      state = SudokuGameState(puzzleIndex: _puzzleCursor);
      state.message = 'Fresh board loaded.';
    });
    await _persistState();
  }

  Future<void> _saveNow() async {
    setState(() {
      state.message = 'Game saved.';
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SudokuGameState.manualSaveKey, state.encode());
    await prefs.setString(SudokuGameState.storageKey, state.encode());

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
    _showSnack('Sudoku progress saved.');
  }

  Future<void> _reloadSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = SudokuGameState.tryDecode(
      prefs.getString(SudokuGameState.manualSaveKey),
    );

    if (!mounted) {
      return;
    }

    if (loaded == null) {
      _showSnack('No saved Sudoku game found.');
      return;
    }

    setState(() {
      state = loaded;
      _puzzleCursor = SudokuGameState.puzzles.indexWhere(
        (puzzle) => puzzle.id == state.puzzleId,
      );
      if (_puzzleCursor < 0) {
        _puzzleCursor = 0;
      }
    });
    _showSnack('Saved game restored.');
  }

  Future<void> _handleValueInput(int value) async {
    setState(() {
      state.setSelectedValue(value);
    });
    await _persistState();
  }

  Future<void> _handleClear() async {
    setState(() {
      state.clearSelectedCell();
    });
    await _persistState();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
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
                                    constraints.maxHeight - 290,
                                  ))
                            .clamp(260.0, 520.0)
                            .toDouble();

                    return Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final label = event.character;
                        if (label != null &&
                            RegExp(r'^[1-9]$').hasMatch(label)) {
                          _handleValueInput(int.parse(label));
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.backspace ||
                            event.logicalKey == LogicalKeyboardKey.delete ||
                            event.logicalKey == LogicalKeyboardKey.digit0 ||
                            event.logicalKey == LogicalKeyboardKey.numpad0) {
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                state.puzzleName,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _statChip('${state.givensCount} givens'),
                                  _statChip('${state.remainingCount} open'),
                                  _statChip(
                                    state.hasAnyConflicts
                                        ? 'Conflicts found'
                                        : 'Board valid',
                                    color: state.hasAnyConflicts
                                        ? const Color(0xFFB3261E)
                                        : const Color(0xFF1E6B43),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: state.completed
                                      ? const Color(0xFFE3F4E9)
                                      : Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  state.message,
                                  key: const Key('sudoku_status_message'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: state.completed
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
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
                                      borderRadius: BorderRadius.circular(16),
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
                              const SizedBox(height: 18),
                              _buildPad(),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    key: const Key('sudoku_new_puzzle'),
                                    onPressed: _newPuzzle,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('New puzzle'),
                                  ),
                                  OutlinedButton.icon(
                                    key: const Key('sudoku_save_game'),
                                    onPressed: _saveNow,
                                    icon: Icon(
                                      _saving ? Icons.save_as : Icons.save,
                                    ),
                                    label: Text(_saving ? 'Saving…' : 'Save'),
                                  ),
                                  OutlinedButton.icon(
                                    key: const Key('sudoku_load_game'),
                                    onPressed: _reloadSavedGame,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Load'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap a square, then use the keypad or keyboard digits 1-9. Use Clear, Delete, or 0 to erase.',
                                textAlign: TextAlign.center,
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

  Widget _statChip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF23324A)).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFF23324A),
          fontWeight: FontWeight.w600,
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
                  : () => _handleValueInput(value),
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
    final correct = state.isCorrectValue(row, col);
    final isBoxEdgeRight = (col + 1) % 3 == 0 && col != 8;
    final isBoxEdgeBottom = (row + 1) % 3 == 0 && row != 8;

    Color background = Colors.white;
    if (selected) {
      background = const Color(0xFFCCE4FF);
    } else if (conflict) {
      background = const Color(0xFFFAD2CF);
    } else if (related) {
      background = const Color(0xFFF3F7FD);
    } else if (!given && value != 0) {
      background = correct ? const Color(0xFFF6FBF7) : const Color(0xFFFFFBF1);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          state.selectCell(row, col);
        });
      },
      child: Container(
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
        child: Text(
          value == 0 ? '' : '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: given ? FontWeight.w800 : FontWeight.w700,
            color: conflict
                ? const Color(0xFF8E1B10)
                : given
                ? const Color(0xFF1C2A3D)
                : const Color(0xFF0D47A1),
          ),
        ),
      ),
    );
  }
}

double minValue(double a, double b) => a < b ? a : b;
