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
  bool _noteMode = false;
  SudokuDifficulty _selectedDifficulty = SudokuDifficulty.easy;
  int _difficultyCursor = 0;

  @override
  void initState() {
    super.initState();
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
    final pool = SudokuGameState.puzzlesByDifficulty(_selectedDifficulty);
    final nextIndex = (pool.isEmpty
        ? 0
        : (_difficultyCursor + 1) % pool.length);

    setState(() {
      _difficultyCursor = nextIndex;
      state = SudokuGameState(
        puzzleIndex: nextIndex,
        difficulty: _selectedDifficulty,
      );
      state.message =
          'Fresh ${_selectedDifficulty.label.toLowerCase()} board loaded.';
    });
    await _persistState();
  }

  Future<void> _setDifficulty(SudokuDifficulty difficulty) async {
    setState(() {
      _selectedDifficulty = difficulty;
      _difficultyCursor = 0;
      state = SudokuGameState(puzzleIndex: 0, difficulty: difficulty);
      state.message = '${difficulty.label} puzzle loaded.';
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
      _selectedDifficulty = state.difficulty;
      _syncDifficultyCursor();
    });
    _showSnack('Saved game restored.');
  }

  Future<void> _handleDigitInput(int value) async {
    setState(() {
      if (_noteMode) {
        state.toggleNoteForSelection(value);
      } else {
        state.setSelectedValue(value);
      }
    });
    await _persistState();
  }

  Future<void> _handleClear() async {
    setState(() {
      state.clearSelectedCell();
    });
    await _persistState();
  }

  Future<void> _handleUndo() async {
    setState(() {
      state.undo();
    });
    await _persistState();
  }

  Future<void> _handleRedo() async {
    setState(() {
      state.redo();
    });
    await _persistState();
  }

  Future<void> _handleHint() async {
    setState(() {
      state.applyHint();
    });
    await _persistState();
  }

  Future<void> _fillSelectionNotes() async {
    setState(() {
      state.fillPencilMarksForSelection();
    });
    await _persistState();
  }

  Future<void> _fillAllNotes() async {
    setState(() {
      state.autoFillAllPencilMarks();
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
                                    constraints.maxHeight - 360,
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
                          _handleDigitInput(int.parse(label));
                          return KeyEventResult.handled;
                        }
                        if (label == 'n' || label == 'N') {
                          setState(() {
                            _noteMode = !_noteMode;
                          });
                          return KeyEventResult.handled;
                        }
                        if (label == 'h' || label == 'H') {
                          _handleHint();
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
                                  _statChip(state.difficulty.label),
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
                              _difficultyPicker(),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: state.completed
                                      ? const Color(0xFFE3F4E9)
                                      : Colors.white.withValues(alpha: 0.85),
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
                                    fontWeight: state.completed
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _selectionSummary(),
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
                              _buildModeAndActionBar(),
                              const SizedBox(height: 12),
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
                                'Tap a square, then use digits 1-9. Press N for notes, H for a hint, and Clear/Delete/0 to erase.',
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

  Widget _difficultyPicker() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final difficulty in SudokuDifficulty.values)
          ChoiceChip(
            key: Key('sudoku_difficulty_${difficulty.name}'),
            label: Text(difficulty.label),
            selected: _selectedDifficulty == difficulty,
            onSelected: (selected) {
              if (!selected || _selectedDifficulty == difficulty) {
                return;
              }
              _setDifficulty(difficulty);
            },
          ),
      ],
    );
  }

  Widget _selectionSummary() {
    if (!state.hasSelection) {
      return const Text('Select a cell to place values or pencil marks.');
    }

    final row = state.selectedRow!;
    final col = state.selectedCol!;
    final value = state.board[row][col];
    final notes = state.notesForCell(row, col).toList()..sort();
    final candidates = state.candidatesForCell(row, col).toList()..sort();

    String summary;
    if (state.isGiven(row, col)) {
      summary = 'Row ${row + 1}, column ${col + 1} is a locked clue.';
    } else if (value != 0) {
      summary = 'Row ${row + 1}, column ${col + 1} = $value.';
    } else if (notes.isNotEmpty) {
      summary = 'Row ${row + 1}, column ${col + 1} notes: ${notes.join(', ')}.';
    } else if (candidates.isNotEmpty) {
      summary =
          'Row ${row + 1}, column ${col + 1} candidates: ${candidates.join(', ')}.';
    } else {
      summary = 'Row ${row + 1}, column ${col + 1} has no legal candidates.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        summary,
        key: const Key('sudoku_selection_summary'),
        textAlign: TextAlign.center,
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

  Widget _buildModeAndActionBar() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        FilterChip(
          key: const Key('sudoku_note_mode'),
          label: Text(_noteMode ? 'Pencil mode on' : 'Pencil mode off'),
          avatar: const Icon(Icons.edit_note),
          selected: _noteMode,
          onSelected: state.completed
              ? null
              : (selected) {
                  setState(() {
                    _noteMode = selected;
                  });
                },
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_hint'),
          onPressed: state.completed ? null : _handleHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Hint'),
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_fill_notes'),
          onPressed: state.completed ? null : _fillSelectionNotes,
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Cell notes'),
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_fill_all_notes'),
          onPressed: state.completed ? null : _fillAllNotes,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('All notes'),
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_undo'),
          onPressed: state.canUndo ? _handleUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          key: const Key('sudoku_redo'),
          onPressed: state.canRedo ? _handleRedo : null,
          icon: const Icon(Icons.redo),
          label: const Text('Redo'),
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
                    : _noteMode
                    ? const Color(0xFF4F5FA8)
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
        child: value == 0
            ? _buildNotes(row, col)
            : _buildValue(value, given, conflict),
      ),
    );
  }

  Widget _buildValue(int value, bool given, bool conflict) {
    return Text(
      '$value',
      style: TextStyle(
        fontSize: 20,
        fontWeight: given ? FontWeight.w800 : FontWeight.w700,
        color: conflict
            ? const Color(0xFF8E1B10)
            : given
            ? const Color(0xFF1C2A3D)
            : const Color(0xFF0D47A1),
      ),
    );
  }

  Widget _buildNotes(int row, int col) {
    final notes = state.notesForCell(row, col);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int group = 0; group < 3; group++)
            Expanded(
              child: Row(
                children: [
                  for (int offset = 1; offset <= 3; offset++)
                    Expanded(
                      child: Center(
                        child: Text(
                          notes.contains(group * 3 + offset)
                              ? '${group * 3 + offset}'
                              : '',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(
                              0xFF5A6783,
                            ).withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

double minValue(double a, double b) => a < b ? a : b;
