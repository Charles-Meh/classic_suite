# Classic Suite Roadmap

_Last updated: 2026-03-15_

## Product Vision

Classic Suite should be a respectful, lightweight home for classic games:

- **No ads of any kind**
  - no banners
  - no interstitials
  - no rewarded videos
- **Donation-only support**
  - optional donation link in About / Settings
- **Offline-first**
- **Fast, readable, low-friction UX**
- **Include reasonable quality-of-life features even though the app is free**
- **Keep app size and maintenance cost low** by reusing shared systems, assets, and scalable/programmatic rendering where practical

## Positioning

**Respectful classic games**

The app should stand apart from competitors by being:
- polished
- fully offline
- clean and fast
- free of ad clutter and fake urgency
- generous with QoL features players expect

## Launch Recommendation

Launch with **6 total games**:

1. **Klondike Klondike** (already in progress / existing)
2. **Spider Klondike**
3. **FreeCell**
4. **Sudoku**
5. **Minesweeper**
6. **2048**

### Why 6?

- 4 is too small for the promise of a multi-game classics app.
- There is a strong first tier of games with broad demand and good reuse.
- Going past 6 at launch likely reduces polish more than it increases appeal.
- **2048** is worth including because it is cheap to build, tiny, and adds variety.

## Game Priority Order

### Tier 1 — Core launch games

#### 1) Klondike Klondike
- flagship game
- establishes card engine, move history, win handling, stats, and game shell

#### 2) Spider Klondike
- highest-priority next addition
- strong demand
- best reuse from Klondike systems
- must-have modes: 1-suit / 2-suit / 4-suit

#### 3) FreeCell
- strong demand and card-engine reuse
- must feel fair and precise
- seeded deals matter here

#### 4) Sudoku
- broadens audience beyond card players
- great fit for offline, ad-free positioning
- low asset burden with scalable/programmatic UI

### Tier 2 — Strong launch additions

#### 5) Minesweeper
- classic, lightweight, offline-friendly
- very small footprint
- important for the “classic utilities/games” feel

#### 6) 2048
- lower demand than the top group
- extremely cheap to build
- adds genre variety and polish value per dev hour

### Tier 3 — Post-launch

#### 7) Hearts
- strong candidate after launch
- card-asset reuse is good
- quality depends heavily on AI and rules behavior

## Popularity Signals

These signals were used for prioritization:

- **Klondike (MobilityWare):** 100M+ downloads, 1.81M reviews
- **Spider Klondike (MobilityWare):** 50M+, 744K reviews
- **FreeCell (MobilityWare):** 10M+, 336K reviews
- **Sudoku.com (Easybrain):** 50M+, 2.34M reviews
- **Minesweeper for Android (Panu):** 5M+, 112K reviews
- **2048 (Solebon / similar):** 1M+, 31.7K reviews
- **Hearts (MobilityWare):** 1M+, 54.9K reviews

This suggests a clear first wave, then a drop-off where only cheap/high-leverage additions should make launch.

## Non-Negotiable Product Standards

Every shipped game should aim to include the obvious expected basics.

### Shared standards
- dark mode
- fast startup
- clean touch handling
- pause/save/resume
- stats
- restart / new game
- undo where genre-appropriate
- clear rules/help
- no nagging monetization surfaces

### Game-specific must-haves

#### Klondike / Spider / FreeCell
- undo
- hint
- tap-to-move where it feels natural
- obvious win handling
- fair/well-defined deal behavior
- autocomplete where appropriate
- stats

#### Sudoku
- pencil marks
- multiple difficulties
- one-solution generation
- optional mistake highlighting
- save/resume

#### Minesweeper
- first tap safe
- easy/medium/hard + custom
- flag mode
- chording
- zoom/pan if needed on smaller screens
- fast restart
- times / stats

#### 2048
- undo
- restart
- continue past 2048
- swipe-anywhere support
- smooth animation
- stats

#### Hearts
- solid AI
- clear passing flow
- standard rules support
- shoot-the-moon behavior
- speed controls if reasonable

## Shared Systems to Build Once

These systems should be reused aggressively across the app:

### App shell
- game list / library
- per-game launch card
- continue current game
- about / settings / donate

### Shared gameplay infrastructure
- save/resume per game
- stats + streak tracking
- undo/history snapshots
- seeded RNG / challenge plumbing where applicable
- shared win screen / result presentation
- shared help / rules renderer

### Shared settings
- dark mode / theme
- sound
- haptics
- animation speed
- left-handed options where useful

### Shared visual strategy
- reuse card assets/components across card games
- prefer scalable/programmatic or SVG-style assets where practical
- avoid multiple raster asset sets for screen sizes unless truly needed

## Suggested Development Phases

## Phase 0 — Stabilize the foundation
- finish polishing Klondike
- verify seed/win behavior
- keep analyzer/tests clean
- make sure emulator/device workflow stays smooth

## Phase 1 — Card engine expansion
### Build next:
1. Spider Klondike
2. FreeCell

### Before/while doing this:
- extract shared card-game systems
- standardize move history / undo
- standardize autocomplete / hint hooks
- standardize statistics/events

## Phase 2 — Broaden beyond cards
### Build next:
3. Sudoku
4. Minesweeper

### Supporting work:
- create reusable grid/puzzle scaffolding
- shared number/grid UI patterns
- reusable timers / score / best-time tracking

## Phase 3 — Add cheap variety
### Build next:
5. 2048

### Goal:
- finish the launch lineup with a low-complexity, high-variety game

## Phase 4 — Launch polish
- game selection UX
- onboarding / rules/help pass
- settings / donate / about
- iconography / final visual consistency
- performance pass
- offline validation
- QA on phones + tablet

## Phase 5 — First post-launch expansion
### Next game:
- Hearts

### Plus:
- daily challenges where appropriate
- better stats views
- quality-of-life improvements based on feedback

## What Competitors Get Wrong

Common pain points to avoid:
- ads between rounds
- bloated menus / currencies / events
- suspicious deal quality
- poor touch handling
- missing dark mode
- missing expected QoL despite “premium” or “ad-free” branding

Classic Suite should win by being the opposite of that.

## Practical Build Guidance

When choosing what to build next, favor:
1. **player demand**
2. **reuse of existing systems**
3. **low asset cost**
4. **strong offline experience**
5. **polish over sheer quantity**

If roadmap scope needs to be reduced, cut after:
- Spider
- FreeCell
- Sudoku
- Minesweeper

Then add **2048** only if schedule still looks healthy, since it is cheap and rounds out the lineup well.
