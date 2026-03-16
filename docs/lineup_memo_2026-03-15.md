# Classic Suite lineup memo

## Recommendation in one line
Launch with **6 total games**: keep **Klondike Klondike** as the anchor, then add **Spider Klondike, FreeCell, Sudoku, Minesweeper, and 2048**. That is the best balance of popularity, variety, and development leverage. After that, add **Hearts** as the next post-launch game.

## Why 6 total is the sweet spot
There is a clear first tier of classic/simple mobile games that still fit a lightweight offline suite:
- **Klondike / Spider / FreeCell**: very strong mobile demand and high code reuse from the current card stack.
- **Sudoku**: extremely strong demand and broad casual appeal.
- **Minesweeper**: smaller than Sudoku/card games, but still a recognizable classic and a good fit for the app’s offline/brain-game identity.
- After that, popularity drops more sharply. **2048** is the one extra game worth including because it is cheap to build, tiny in asset footprint, and adds a different play pattern.

So the right answer is not “as many as possible.” It is **6 total because the 6th slot can be filled by a very cheap, high-variety game; the 7th+ slot looks much worse on return per dev week.**

## Popularity signals used
Primary signal: **best-known Android app for that game on Google Play** (downloads + review volume), used as a practical proxy for mobile demand and user expectation.

Reference points from current market:
- **Klondike - Classic Card Games** by MobilityWare: **100M+ downloads, 1.81M reviews**.
- **Spider Klondike: Card Games** by MobilityWare: **50M+ downloads, 744K reviews**.
- **FreeCell Klondike: Card Games** by MobilityWare: **10M+ downloads, 336K reviews**.
- **Sudoku.com - Classic Sudoku** by Easybrain: **50M+ downloads, 2.34M reviews**.
- **Minesweeper for Android** by Panu Vuorinen: **5M+ downloads, 112K reviews**.
- **2048** by Solebon LLC (official app): **1M+ downloads, 31.7K reviews**.
- **Hearts: Card Game** by MobilityWare: **1M+ downloads, 54.9K reviews**.

## Ranked launch priority (adjusted for both demand and build leverage)
Because Classic Suite already has Klondike Klondike and already depends on `playing_cards`, launch priority should not equal raw popularity alone.

1. **Spider Klondike**
   - Why: huge audience, obvious fit next to Klondike, strong card-system reuse.
   - Signal: MobilityWare Spider has **50M+ downloads / 744K reviews**.

2. **FreeCell**
   - Why: still large audience, excellent reuse of deck/shuffle/card rendering/state systems, and it broadens the card offering without much asset cost.
   - Signal: MobilityWare FreeCell has **10M+ downloads / 336K reviews**.

3. **Sudoku**
   - Why: massive casual appeal beyond card players; important for genre variety.
   - Signal: Sudoku.com has **50M+ downloads / 2.34M reviews**.

4. **Minesweeper**
   - Why: classic, offline-friendly, compact, fast sessions, recognizable desktop nostalgia.
   - Signal: Minesweeper for Android has **5M+ downloads / 112K reviews**.

5. **2048**
   - Why: lower mobile install ceiling than the above, but trivial asset footprint and very good “one more run” value.
   - Signal: official 2048 app has **1M+ downloads / 31.7K reviews**.

6. **Hearts** (best next game after launch)
   - Why: good card reuse, but AI/UX expectations are materially higher than 2048, so it is a better post-launch addition than a launch blocker.
   - Signal: MobilityWare Hearts has **1M+ downloads / 54.9K reviews**.

## Competitor read
### Multi-game / collection competitors
- **Offline Games - No Wifi Games** by JindoBlu: **100M+ downloads / 424K reviews**.
  - Takeaway: there is clearly huge demand for offline collections.
  - Weakness: users still complain about ad interruptions even in the middle of a game.
- **Microsoft Klondike Collection**: **10M+ downloads / 281K reviews**.
  - Takeaway: multi-game bundles set expectations for daily challenges, stats, multiple modes, and polished presentation.
  - Weakness: ads are a recurring complaint.
- **250+ Klondike Collection**: **10M+ downloads / 88.5K reviews**.
  - Takeaway: players like breadth, rule references, and lots of variants.
  - Weakness: quantity-first collections risk repeated deals, clutter, and lower polish.

### Strong single-game apps that set feature expectations
- **MobilityWare Klondike / Spider / FreeCell**: users expect smooth touch handling, undo, hints, left-handed support, statistics, orientation support, and customization.
- **Sudoku.com**: users expect notes, difficulty levels, duplicate highlighting, hints, and offline play.
- **Minesweeper for Android**: users expect difficulty presets, custom boards, zoom, fast controls, and good accuracy.

## What users praise
Common praise patterns from store pages/snippets:
- Clean, readable UI
- Fast gameplay and smooth controls
- Faithful “classic” rules with no weird gimmicks
- Offline play
- Good options/settings
- Helpful but optional assists (undo, hints, autocomplete, notes)
- “No nonsense” execution

## What users complain about
The complaints are extremely consistent across categories:
- **Ads interrupting mid-game or after every hand/puzzle**
- Bad or awkward touch input
- Missing dark mode / poor night use
- Repetitive or suspiciously bad deals
- Weak AI in card/board games
- Too much meta-progression clutter around a simple classic game
- “Ad-free” alternatives still missing basic convenience features

Concrete examples surfaced during research:
- MobilityWare Klondike review snippet complains that playable ads appear after every finished hand and can freeze the phone.
- MobilityWare FreeCell snippet complains about ads popping up mid-hand.
- Microsoft Klondike Collection snippet says the app is good and daily challenges/custom difficulties are nice, but ads have become obnoxious.
- Sudoku.com review response explicitly acknowledges user concern about ad volume and ad-removal price.
- A review snippet for **Sudoku without ads** praises the lack of ads but says it still misses quality-of-life features like a faster number-entry flow and auto-complete.
- Minesweeper reviews praise “just Minesweeper with no nonsense” and also ask for dark mode.
- 250+ Klondike Collection review snippet complains about repeat deals and unwinnable-feeling repetition.

## Must-have features by game
### Spider Klondike
- 1-suit, 2-suit, and 4-suit modes
- Unlimited undo
- Hint
- Tap-to-move + drag-and-drop
- Auto-complete when the game is effectively solved
- Restart current deal + new deal
- Stats per difficulty

### FreeCell
- Numbered/seeded deals
- Unlimited undo
- Smart auto-foundation (optional toggle)
- Tap-to-move
- Move legality previews / obvious target highlighting
- Restart/current deal replay
- Win rate, streak, time, moves

### Sudoku
- Pencil marks/notes
- Auto-clean notes after entry
- Difficulty levels
- One-solution puzzle generation
- Optional mistake highlighting (toggleable; some players dislike forced error checking)
- Hints without making the game play itself
- Save/resume
- Large touch targets and dark mode

### Minesweeper
- First tap never loses
- Beginner / Intermediate / Expert / Custom
- Dedicated flag mode and/or long-press flagging
- Chording / quick-open around numbered tiles
- Zoom/pan for bigger boards
- Fast restart
- Best times/stats
- Dark mode and strong visual clarity

### 2048
- Undo
- Restart
- Best score + current session stats
- Continue beyond 2048
- Swipe-anywhere controls
- Fast/smooth animations with no lag
- Optional larger boards later (5x5) but not required for launch

### Hearts (post-launch)
- Good AI that does not feel obviously dumb or rigged
- Clear passing UI and pass-direction indicator
- Moon-shoot rule options
- Fast play speed controls
- Auto-play dead tricks / obvious endgame cleanup
- Detailed stats

## Shared systems/components to build once and reuse
Classic Suite should win by having a strong shared shell, not by shipping a bloated pile of unrelated mini-apps.

Build/reuse these shared systems:
- **Game shell**: title, pause/new game/restart/settings/help hooks
- **Persistent save/resume per game**
- **Stats engine**: wins, streaks, best times, scores, moves, last played
- **History/undo snapshots** (already present in Klondike; generalize the pattern)
- **Seeded RNG / daily challenge system** for games that support deterministic generation
- **Shared settings**: sound, haptics, dark mode, left-handed options, animation speed
- **Shared rules/help renderer** from lightweight local markdown/json
- **Common SVG icon set / minimal vector art**
- **Programmatic board drawing** where possible (Sudoku/Minesweeper/2048 especially) to keep assets tiny
- **Accessibility layer**: larger cards/tiles, color-safe palettes, reduced motion

Specific code reuse already visible in the repo:
- `playing_cards` dependency already in place
- Current Klondike already has card models, seeded/winnable deal concepts, undo history, settings dialog patterns, and shared launcher structure

## How Classic Suite can beat competitors
1. **Be the respectful alternative**
   - No ads, no interstitials, no fake currency, no daily-pressure junk.
   - Donation button only in About/Settings.

2. **Stay small by being intentional**
   - Use vector/programmatic rendering for grids and simple boards.
   - Reuse one polished card system across Klondike, Spider, FreeCell, and later Hearts.
   - Avoid giant content packs at launch.

3. **Polish the basics harder than bigger apps do**
   - Instant resume
   - Clean dark mode
   - Great touch accuracy
   - Strong undo/save behavior
   - Clear rules/help
   - Actually offline

4. **Include “premium” quality-of-life features anyway**
   - Players clearly notice when free/no-ad apps omit features.
   - Undo, stats, notes, custom difficulty, seed replay, and autocomplete/auto-foundation toggles should not be treated as upsell bait.

5. **Keep the suite coherent**
   - Better to have 6 polished classics than 20 mediocre ones.
   - Make each game feel like part of one product, with consistent settings, typography, transitions, and interaction language.

## Final recommendation
**Initial public launch: 6 total games**
- Existing: **Klondike Klondike**
- Add next: **Spider Klondike, FreeCell, Sudoku, Minesweeper, 2048**

**First post-launch addition:** **Hearts**

That lineup gives the app:
- a strong card core,
- two broadly recognizable puzzle classics,
- one ultra-light swipe puzzler,
- and enough variety to feel like a true suite without becoming bloated.
