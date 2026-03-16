class SudokuGameState {
  SudokuGameState({List<List<int>>? board})
    : board = board != null ? _copyBoard(board) : _copyBoard(_starterBoard);

  final List<List<int>> board;

  static const List<List<int>> _starterBoard = [
    [5, 3, 0, 0, 7, 0, 0, 0, 0],
    [6, 0, 0, 1, 9, 5, 0, 0, 0],
    [0, 9, 8, 0, 0, 0, 0, 6, 0],
    [8, 0, 0, 0, 6, 0, 0, 0, 3],
    [4, 0, 0, 8, 0, 3, 0, 0, 1],
    [7, 0, 0, 0, 2, 0, 0, 0, 6],
    [0, 6, 0, 0, 0, 0, 2, 8, 0],
    [0, 0, 0, 4, 1, 9, 0, 0, 5],
    [0, 0, 0, 0, 8, 0, 0, 7, 9],
  ];

  SudokuGameState copy() => SudokuGameState(board: board);

  void reset() {
    final fresh = _copyBoard(_starterBoard);
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        board[row][col] = fresh[row][col];
      }
    }
  }

  int get givensCount =>
      board.expand((row) => row).where((value) => value != 0).length;

  static List<List<int>> _copyBoard(List<List<int>> source) {
    return [
      for (final row in source) [...row],
    ];
  }
}
