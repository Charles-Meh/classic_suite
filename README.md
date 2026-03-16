# classic_suite

A Flutter application containing a suite of classic games. This project is structured so that each game lives inside its own module under `lib/games`, with shared code and assets available in dedicated directories.

## Project layout

```
lib/
  main.dart           # entry point; shows game launcher
  core/               # navigation and launcher widgets
  shared/             # shared models, utilities
  games/
    klondike/        # Klondike Klondike game module (first game) with drag/drop, tap-to-move, hint, undo, and autocomplete
assets/
  games/
    klondike/        # assets for individual games
  shared/             # assets used by multiple games
```

To add a new game:
1. Create a subdirectory under `lib/games/` (e.g. `lib/games/pac_man`).
2. Implement a widget for the game and export it with a const constructor.
3. Add any game-specific assets under `assets/games/<game_name>` and update `pubspec.yaml` if necessary.
4. Register the game in `main.dart` by adding a `GameDefinition` entry in the `GameListPage` invocation.

```dart
GameDefinition(
  title: 'My Game',
  builder: (context) => const MyGameWidget(),
  iconAsset: 'assets/games/my_game/icon.png', // optional
),
```

5. Run `flutter pub get` and rebuild the app.

```
flutter run
```

6. Add widget tests similar to `test/widget_test.dart` to cover navigation.

```
```
A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
