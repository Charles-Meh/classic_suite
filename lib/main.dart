import 'package:flutter/material.dart';

import 'core/game_list_page.dart';
import 'games/klondike/klondike_game.dart';
import 'games/spider/spider_game.dart';
import 'shared/game_definition.dart';
import 'games/freecell/freecell_game.dart';
import 'games/sudoku/sudoku_game.dart';

void main() {
  runApp(const ClassicSuiteApp());
}

class ClassicSuiteApp extends StatelessWidget {
  const ClassicSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Suite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6B43)),
      ),
      home: GameListPage(
        games: const [
          GameDefinition(title: 'Klondike Klondike', builder: _buildKlondike),
          GameDefinition(title: 'Spider Klondike', builder: _buildSpider),
          GameDefinition(title: 'FreeCell', builder: _buildFreeCell),
          GameDefinition(title: 'Sudoku', builder: _buildSudoku),
        ],
      ),
    );
  }
}

Widget _buildKlondike(BuildContext context) => const KlondikeGame();

Widget _buildSpider(BuildContext context) => const SpiderGame();

Widget _buildFreeCell(BuildContext context) => const FreeCellGame();

Widget _buildSudoku(BuildContext context) => const SudokuGame();
