import 'package:flutter/material.dart';

import 'sudoku_game_state.dart';

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, this.initialState});

  final SudokuGameState? initialState;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late SudokuGameState state;

  @override
  void initState() {
    super.initState();
    state = widget.initialState?.copy() ?? SudokuGameState();
  }

  void _newPuzzle() {
    setState(() {
      state.reset();
    });
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardSize = (constraints.maxHeight - 180)
                  .clamp(220.0, 420.0)
                  .toDouble();

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Starter puzzle',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.givensCount} givens',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('sudoku_new_puzzle'),
                        onPressed: _newPuzzle,
                        icon: const Icon(Icons.refresh),
                        label: const Text('New puzzle'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Initial scaffold only: board rendering is in place, entry/editing comes next.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
    final isBoxEdgeRight = (col + 1) % 3 == 0 && col != 8;
    final isBoxEdgeBottom = (row + 1) % 3 == 0 && row != 8;

    return Container(
      key: Key('sudoku_cell_${row}_$col'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value == 0 ? const Color(0xFFF8FAFD) : Colors.white,
        border: Border(
          top: BorderSide(
            color: row == 0 ? const Color(0xFF23324A) : const Color(0xFF9BA8BC),
            width: row == 0 ? 0 : 0.6,
          ),
          left: BorderSide(
            color: col == 0 ? const Color(0xFF23324A) : const Color(0xFF9BA8BC),
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
          fontWeight: value == 0 ? FontWeight.w400 : FontWeight.w700,
          color: const Color(0xFF1C2A3D),
        ),
      ),
    );
  }
}
