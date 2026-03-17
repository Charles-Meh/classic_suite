import 'package:flutter/material.dart';

import 'core/game_list_page.dart';
import 'games/klondike/klondike_game.dart';
import 'games/spider/spider_game.dart';
import 'shared/game_definition.dart';
import 'games/freecell/freecell_game.dart';
import 'games/minesweeper/minesweeper_game.dart';
import 'games/pyramid/pyramid_game.dart';
import 'games/sudoku/sudoku_game.dart';
import 'games/hearts/hearts_game.dart';
import 'games/twenty_forty_eight/twenty_forty_eight_game.dart';
import 'games/chess/chess_game.dart';
import 'games/checkers/checkers_game.dart';
import 'games/tripeaks/tripeaks_game.dart';

void main() {
  runApp(const ClassicSuiteApp());
}

class ClassicSuiteApp extends StatelessWidget {
  const ClassicSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E6B43),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E6B43),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Classic Suite',
      themeMode: ThemeMode.system,
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      home: GameListPage(
        games: const [
          GameDefinition(title: 'Klondike Solitaire', builder: _buildKlondike),
          GameDefinition(title: 'Spider Solitaire', builder: _buildSpider),
          GameDefinition(title: 'FreeCell', builder: _buildFreeCell),
          GameDefinition(title: 'Sudoku', builder: _buildSudoku),
          GameDefinition(title: 'Minesweeper', builder: _buildMinesweeper),
          GameDefinition(title: 'Pyramid Solitaire', builder: _buildPyramid),
          GameDefinition(title: 'Hearts', builder: _buildHearts),
          GameDefinition(title: '2048', builder: _build2048),
          GameDefinition(title: 'Chess', builder: _buildChess),
          GameDefinition(title: 'Checkers', builder: _buildCheckers),
          GameDefinition(title: 'TriPeaks Solitaire', builder: _buildTriPeaks),
        ],
      ),
    );
  }
}

Widget _buildKlondike(BuildContext context) => const KlondikeGame();

Widget _buildSpider(BuildContext context) => const SpiderGame();

Widget _buildFreeCell(BuildContext context) => const FreeCellGame();

Widget _buildSudoku(BuildContext context) => const SudokuGame();

Widget _buildMinesweeper(BuildContext context) => const MinesweeperGame();

Widget _buildPyramid(BuildContext context) => const PyramidGame();

Widget _buildHearts(BuildContext context) => const HeartsGame();

Widget _build2048(BuildContext context) => const TwentyFortyEightGame();

Widget _buildChess(BuildContext context) => const ChessGame();

Widget _buildCheckers(BuildContext context) => const CheckersGame();

Widget _buildTriPeaks(BuildContext context) => const TriPeaksGame();
