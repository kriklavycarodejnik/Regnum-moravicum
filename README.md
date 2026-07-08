# Regnum Moravicum v2.1

A text-based strategy game set in an alternate history where Great Moravia never fell. Rule as Mojmír II. in 902 AD and guide your kingdom through the challenges of medieval Europe.

## Game Overview

Regnum Moravicum is a turn-based strategy game where you take on the role of the ruler of Great Moravia. Manage your 11 župy (provinces), balance relations with 6 factions, command armies, negotiate treaties, and navigate the complex political and religious landscape of 10th century Europe.

## Features

- **Historical Setting**: Start in 902 AD as Mojmír II. of the Mojmírovci dynasty
- **11 Župy**: Nitra, Devín, Bratislava, Trnava, Zvolen, Banská Bystrica, Košice, Prešov, Žilina, Poprad, Bardejov
- **6 Factions**: Župani, Cyrilometodskí Kňazi, Byzantskí Poslovia, Nemeckí Kolonisti, Maďarské zvyšky, Kumáni
- **Resource Management**: Gold, Food, Wood, Stone, Iron, Prestige
- **Religion Axis**: Balance between Rome and Constantinople
- **Military System**: Recruit units, form armies, engage in battles
- **Diplomacy**: Negotiate treaties, form alliances, manage relations
- **Event System**: Random and historical events with choices and consequences

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
│   │   │   ├── tickEngine.ts     # Main game loop (11 phases)
│   │   │   ├── battleEngine.ts   # Battle resolution
│   │   │   ├── warEngine.ts      # War management
│   │   │   ├── diplomacyEngine.ts # Diplomacy system
│   │   │   ├── successionEngine.ts # Succession and inheritance
│   │   │   ├── eventEngine.ts    # Event processing
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
│   ├── tickEngine.test.ts     # Tick engine tests
│   └── saveLoad.test.ts       # Save/load tests
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
  version: string;
  seed: string;
  tick: number;
  year: number;
  month: number;
  player: Player;
  nobles: Noble[];
  families: Family[];
  factions: Faction[];
  zupas: Zupa[];
  armies: Army[];
  wars: War[];
  treaties: Treaty[];
  events: GameEvent[];
  resources: Resources;
  religionAxis: number;
  scenario: ScenarioType;
}
```

### Tick Engine

The main game loop processes 11 phases each tick (month):

1. **incrementYear** - Advance month/year
2. **ageNobles** - Age all living nobles
3. **decayMoods** - Reduce faction relations slightly
4. **growProsperity** - Increase zupa prosperity
5. **addRecruitmentPool** - Add recruitment points to zupas
6. **payUpkeep** - Deduct army upkeep from resources
7. **checkRebellions** - Check for zupa rebellions
8. **processSuccession** - Handle noble deaths and succession
9. **processDiplomacy** - Process diplomatic actions
10. **processWars** - Process ongoing wars
11. **processEvents** - Process random and historical events

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
- **Sidebar Navigation**: Switch between Map, Armies, Diplomacy, Events, and other panels

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
