import 'package:flutter/material.dart';

import '../shared/game_definition.dart';

/// Displays a scrollable list of games registered in [games].
class GameListPage extends StatelessWidget {
  final List<GameDefinition> games;

  const GameListPage({super.key, required this.games});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classic Suite')),
      body: ListView.builder(
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return ListTile(
            title: Text(game.title),
            leading: game.iconAsset != null
                ? Image.asset(game.iconAsset!)
                : null,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: game.builder));
            },
          );
        },
      ),
    );
  }
}
