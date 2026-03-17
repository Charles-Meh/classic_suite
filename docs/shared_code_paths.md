# Shared code paths

This repo still leans game-local for most logic, but Minesweeper added one reusable shared path while staying aligned with the roadmap goal of extracting common systems incrementally.

## Added in this pass

### `lib/shared/duration_format.dart`
A small shared formatter for elapsed game time (`mm:ss`).

Current consumer:
- `lib/games/minesweeper/minesweeper_game.dart`

Intended future consumers:
- Sudoku timer/best-time UI
- 2048 session timer
- any shared stats dialogs or result overlays that need consistent elapsed-time presentation

## Minesweeper-specific persistence/stat tracking
These remain game-local for now because the suite does not yet have a generalized timed-stats abstraction:
- `lib/games/minesweeper/minesweeper_game_state.dart`
- `lib/games/minesweeper/minesweeper_stats.dart`
- `lib/games/minesweeper/minesweeper_stats_store.dart`

That keeps the implementation tidy today without prematurely forcing a generic stats model that the other games do not share yet.
