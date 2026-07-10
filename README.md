# Regnum Moravicum v2.1

A text-based strategy game set in an alternate history where Great Moravia never fell. Rule as Mojmír II. in 902 AD and guide your kingdom through the challenges of medieval Europe.

## Game Overview

Regnum Moravicum is a turn-based strategy game where you take on the role of the ruler of Great Moravia. Manage your 11 župy (provinces), balance relations with 6 factions, command armies, negotiate treaties, and navigate the complex political and religious landscape of 10th century Europe.

## Features

- **Historical Setting**: Start in 902 AD as Mojmír II. of the Mojmírovci dynasty
- **11 Župy**: Nitra, Devín, Bratislava, Trnava, Zvolen, Banská Bystrica, Košice, Prešov, Žilina, Poprad, Bardejov
- **6 Factions**: Župani, Cyrilometodskí Kňazi, Byzantskí Poslovia, Nemeckí Kolonisti, Maďarské zvyšky, Bogatovci
- **Resource Management**: Gold, Food, Wood, Stone, Iron, Prestige
- **Religion Axis**: Balance between Rome and Constantinople, slowly drifting back to neutral over time
- **Military System**: Recruit units, form armies, and fight the scripted Hungarian invasion
  (Bitka pri Devíne, 907) phase-by-phase - melee/ranged/flank/retreat choices each round, or
  auto-resolve a front instantly
- **Diplomacy**: Gift, threaten, or propose trade/non-aggression/military-pact treaties with each
  faction; AI factions also drift on their own each tick based on their personality archetype
- **Event System**: Random and historical events with choices that affect prestige, religion,
  resources, faction moods, and zupa loyalty
- **Victory/Defeat**: Survive as a dynasty to the year 1000 for victory; lose if the dynasty goes
  extinct or loses its last župa

## Installation

```bash
npm install
```

## Running the Game

### Development

```bash
npm run dev
```

Opens the game in development mode with hot reloading.

### Production Build

```bash
npm run build
npm run preview
```

### Testing

```bash
npm test
```

Runs all unit tests using Vitest.

## Project Structure

```
regnum-moravicum/
├── public/
│   └── favicon.svg
├── src/
│   ├── core/
│   │   ├── types/
│   │   │   ├── entities.ts      # Noble, Family, Faction, Zupa, Army, War, Treaty
│   │   │   ├── gameState.ts     # GameState, Resources, Player, ScenarioType
│   │   │   ├── events.ts        # EventType, EventCondition, EventChoice, GameEvent
│   │   │   └── index.ts         # Type exports
│   │   ├── engines/
│   │   │   ├── tickEngine.ts     # Main game loop (12 phases)
│   │   │   ├── warCampaign.ts    # Bridges core state to the battle/war layer
│   │   │   ├── diplomacyEngine.ts # Diplomacy system (gift/threat/treaties, AI drift)
│   │   │   ├── eventEngine.ts    # Event conditions, generation, choice resolution
│   │   │   ├── victoryEngine.ts  # Religion decay, prestige growth, victory/defeat
│   │   │   ├── successionEngine.ts # Succession and inheritance (stub)
│   │   │   └── index.ts         # Engine exports
│   │   └── utils/
│   │       ├── rng.ts           # Reproducible RNG (seedrandom wrapper)
│   │       ├── generators.ts    # State and entity generators
│   │       ├── saveLoad.ts      # Save/load with lz-string compression
│   │       ├── migrations.ts    # Save data migrations
│   │       └── index.ts         # Utility exports
│   ├── data/
│   │   ├── units.ts            # Unit definitions and stats
│   │   ├── formations.ts       # Military formations
│   │   ├── terrains.ts         # Terrain types and bonuses
│   │   ├── initialState.ts     # Initial game state constants
│   │   ├── historicalEvents.ts  # Historical event definitions
│   │   └── index.ts            # Data exports
│   ├── ui/
│   │   ├── components/
│   │   │   ├── StatusBar.tsx    # Game status display
│   │   │   ├── MapView.tsx      # Interactive map of župy
│   │   │   ├── EventPanel.tsx   # Event display and choices
│   │   │   ├── DiplomacyPanel.tsx # Diplomacy interface
│   │   │   ├── ArmyPanel.tsx    # Army management
│   │   │   ├── BattleView.tsx   # Battle visualization
│   │   │   └── index.ts        # Component exports
│   │   ├── pages/
│   │   │   ├── MainMenu.tsx    # Main menu and scenario selection
│   │   │   ├── GameScreen.tsx   # Main game interface
│   │   │   ├── LoadingScreen.tsx # Loading screen
│   │   │   ├── GameOverScreen.tsx # Victory/defeat screen
│   │   │   └── index.ts        # Page exports
│   │   └── index.ts            # UI exports
│   ├── hooks/
│   │   └── useGame.ts          # Main game hook
│   ├── styles/
│   │   ├── global.css          # Global styles and CSS variables
│   │   ├── App.module.css      # App styles
│   │   ├── MainMenu.module.css # Main menu styles
│   │   ├── LoadingScreen.module.css
│   │   ├── StatusBar.module.css
│   │   ├── MapView.module.css
│   │   ├── GameScreen.module.css
│   │   ├── EventPanel.module.css
│   │   ├── DiplomacyPanel.module.css
│   │   ├── ArmyPanel.module.css
│   │   └── BattleView.module.css
│   ├── App.tsx                 # Main app component
│   └── main.tsx               # React entry point
├── tests/
│   ├── rng.test.ts            # RNG utility tests
│   ├── generators.test.ts     # Generator tests
│   ├── tickEngine.test.ts     # Tick engine tests (incl. full-run victory integration)
│   ├── saveLoad.test.ts       # Save/load tests
│   ├── warCampaign.test.ts    # War campaign bridge / battle engine tests
│   ├── eventEngine.test.ts    # Event condition/generation/resolution tests
│   ├── diplomacyEngine.test.ts # Diplomacy action and AI drift tests
│   └── victoryEngine.test.ts  # Religion decay, prestige growth, victory/defeat tests
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tsconfig.app.json
└── tsconfig.node.json
```

## Core Concepts

### GameState

The central data structure containing all game information. Fully JSON-serializable with no classes, methods, Maps, or Sets.

```typescript
interface GameState {
  tick: number;               // 1 tick = 1 month
  year: number;                // 902-1300
  seed: string;
  scenario: ScenarioType;
  player: Player;               // dynasty, currentRuler, prestige, religionAxis
  nobles: Noble[];
  families: Family[];
  factions: Faction[];
  zupy: Record<ZupaId, Zupa>;
  armies: Army[];
  wars: War[];
  treaties: Treaty[];
  events: GameEvent[];
  resources: Resources;         // gold/food/wood/stone/iron/prestige
  religion: ReligionAxis;       // { value: -100..100, Rím..Konštantínopol }
  gameOver: boolean;
  gameOverReason?: string;
  gameOverVictory?: boolean;
  saveVersion: string;
  warCampaign: WarCampaignState | null; // scripted Hungarian-invasion campaign, see warCampaign.ts
}
```

### Tick Engine

The main game loop processes 12 phases each tick (month):

1. **incrementYear** - Advance month/year
2. **ageNobles** - Age all living nobles
3. **decayMoods** - Reduce faction relations slightly
3b. **decayReligionAxis** - Drift the Rím/Konštantínopol axis back toward neutral
4. **growProsperity** - Increase zupa prosperity
4b. **growPrestige** - Passive prestige trickle tied to average zupa loyalty
5. **addRecruitmentPool** - Add recruitment points to zupas
6. **payUpkeep** - Deduct army upkeep from resources
7. **checkRebellions** - Check for zupa rebellions
8. **processSuccession** - Handle noble deaths and succession (stub)
9. **processDiplomacy** - Passive AI mood drift by faction personality
10. **processWars** - Scripted war campaign events, occupation looting, liberation checks
11. **processEvents** - Spawn due historical events and roll random events
12. **checkVictoryConditions** - Dynasty extinction/territory-loss defeat, year-1000 survival victory

Battles themselves are not auto-resolved during the tick - the player triggers and plays
(or auto-resolves) them from the Battle panel once a war has started.

### RNG System

All random operations use `seedrandom` for reproducible results. The RNG wrapper provides:

- `initRNG(seed)` - Initialize with a seed
- `rng(min, max)` - Integer in range [min, max]
- `rngFloat(min, max)` - Float in range [min, max)
- `rngChance(probability)` - Boolean with given probability
- `getRNGState()` / `setRNGState(state)` - Save/restore RNG state

### Save/Load

- Uses `lz-string` for compression
- Primary storage: `localStorage`
- Fallback: `IndexedDB` (for larger saves)
- Auto-save with debounce (500ms)
- Version tracking with migration support

## Gameplay

### Starting a New Game

1. Select a scenario (Standard, Historical, Random)
2. Enter a seed (optional, for reproducible games)
3. Click "Start Game"

### Main Game Interface

- **Status Bar**: Year, tick, resources, prestige, religion axis, Next Month button
- **Map View**: Interactive map showing all 11 župy with loyalty, prosperity, and garrison info
- **Events Panel**: Shows the current pending event (if any) with selectable choices and their
  effects, plus a history of resolved events
- **Diplomacy Panel**: Faction cards with a computed relation badge and mood stats; select a
  faction to see its active treaties and send a gift/threat/treaty proposal
- **Army Panel**: Overview of raised armies
- **Battle Panel**: Once the Hungarian invasion starts (year >= 905), lists available battle
  fronts; start a battle to play it phase-by-phase (melee/ranged/flank/retreat) or auto-resolve it
  instantly
- **Game Over Screen**: Shown once the dynasty wins (survives to year 1000) or loses (extinction
  or total loss of territory)
- **Sidebar Navigation**: Switch between Map, Events, Diplomacy, Armies, and Battle panels

### Controls

- **Next Month**: Advance the game by one tick (month)
- **Save Game**: Save current state to localStorage
- **Load Game**: Load saved state from localStorage
- **Delete Save**: Remove saved game

## Technical Requirements

- **TypeScript**: Strict mode, all types defined
- **React**: Functional components with hooks
- **No Math.random()**: All RNG through seedrandom wrapper
- **Pure Functions**: Engine functions are pure: `(state: GameState) => GameState`
- **No Real-time**: Only explicit player action via "Next Month" button
- **JSON-serializable**: GameState contains only plain objects, arrays, and primitives

## Dependencies

- **React 19.2.7** - UI framework
- **Vite 8.1.1** - Build tool
- **TypeScript 6.0.2** - Type system
- **seedrandom 3.0.5** - Reproducible RNG
- **lz-string** - Save compression
- **vitest** - Testing framework
- **@testing-library/react** - React testing utilities

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## License

MIT License

## Credits

- Historical research and inspiration from various sources on Great Moravia
- Game design inspired by classic strategy games

---

**Regnum Moravicum v2.1** - A strategy game of alternate history
