import 'package:flutter/widgets.dart';

/// Lightweight descriptor used by the launcher to display and
/// navigate to a specific game.
class GameDefinition {
  /// Title shown in the game list.
  final String title;

  /// Builder used when the user selects the game.
  final WidgetBuilder builder;

  /// Optional path to an icon asset.
  final String? iconAsset;

  const GameDefinition({
    required this.title,
    required this.builder,
    this.iconAsset,
  });
}
