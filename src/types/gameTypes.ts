// Regnum Moravicum v2.1 - Game Core Types

export type GamePhase = 0 | 1 | 2 | 3 | 4; // Phase 0: Foundations, Phase 1: Regions, etc.

export interface GameConfig {
  version: string;
  phase: GamePhase;
  startDate: GameDate;
  monthsPerTurn: number;
  maxTurns: number | null;
  difficulty: Difficulty;
}

export type Difficulty = 'easy' | 'normal' | 'hard' | 'ironman';

export interface GameDate {
  year: number;
  month: number; // 1-12
  day: number; // 1-31
}

// Resource Types
export type ResourceType = 
  | 'gold'
  | 'wood'
  | 'stone'
  | 'food'
  | 'iron'
  | 'faith'
  | 'knowledge'
  | 'influence';

// Region Types
export type RegionType = 
  | 'plains'
  | 'forest'
  | 'mountains'
  | 'river'
  | 'city'
  | 'village'
  | 'fortress';

// Faction Types
export type FactionType = 
  | 'player'
  | 'noble'
  | 'church'
  | 'merchants'
  | 'rebels'
  | 'foreign';

// Event Types
export type EventType = 
  | 'harvest'
  | 'revolt'
  | 'trade'
  | 'diplomacy'
  | 'disaster'
  | 'blessing'
  | 'quest';

// Decision Types
export type DecisionType = 
  | 'tax'
  | 'construction'
  | 'diplomacy'
  | 'military'
  | 'religion'
  | 'trade';

// Game State Interfaces
export interface ResourcePool {
  [key: string]: number;
}

export interface Region {
  id: string;
  name: string;
  type: RegionType;
  baseResources: ResourcePool;
  currentResources: ResourcePool;
  ownerId: string | null;
  development: number; // 0-100
  loyalty: number; // 0-100
  defense: number;
  population: number;
  connectedRegions: string[];
}

export interface Faction {
  id: string;
  name: string;
  type: FactionType;
  strength: number; // 0-100
  influence: number; // 0-100
  wealth: number;
  relations: Record<string, number>; // -100 to 100
  goals: Goal[];
  traits: string[];
}

export interface Goal {
  id: string;
  type: string;
  target: string;
  progress: number;
  required: number;
  reward: string;
  penalty: string;
}

export interface Player {
  id: string;
  factionId: string;
  resources: ResourcePool;
  achievements: string[];
  decisions: Decision[];
  reputation: number;
  piety: number;
  power: number;
}

export interface Decision {
  id: string;
  type: DecisionType;
  title: string;
  description: string;
  choices: Choice[];
  consequences: string;
  madeAtTurn: number;
  chosenIndex: number | null;
}

export interface Choice {
  text: string;
  effects: Effect[];
  locked: boolean;
  hidden: boolean;
}

export interface Effect {
  type: string;
  target: string;
  value: number | string;
  duration: number | null;
}

export interface GameEvent {
  id: string;
  type: EventType;
  title: string;
  description: string;
  turn: number;
  priority: number;
  data: Record<string, unknown>;
  resolved: boolean;
  resolution: string | null;
}

// Game Loop Types
export interface GameLoop {
  start(): void;
  stop(): void;
  pause(): void;
  resume(): void;
  tick(): void;
  advanceTurn(): void;
  processEvents(): void;
  getCurrentTurn(): number;
  getCurrentDate(): GameDate;
  isRunning(): boolean;
}

export interface TurnPhase {
  name: string;
  order: number;
  process(game: Game): void;
}

export interface Game {
  config: GameConfig;
  state: GameState;
  loop: GameLoop;
  rng: import('./rngTypes').RNGInstance;
  saveManager: import('./saveTypes').SaveManager;
  
  initialize(seed: string): void;
  start(): void;
  stop(): void;
  getRegion(id: string): Region | null;
  getFaction(id: string): Faction | null;
  getPlayer(): Player;
  addEvent(event: GameEvent): void;
  resolveEvent(eventId: string, resolution: string): void;
  makeDecision(decision: Decision, choiceIndex: number): void;
}

export interface GameState {
  turn: number;
  date: GameDate;
  regions: Record<string, Region>;
  factions: Record<string, Faction>;
  player: Player;
  events: GameEvent[];
  decisions: Decision[];
  history: TurnHistory[];
}

export interface TurnHistory {
  turn: number;
  date: GameDate;
  events: EventType[];
  decisions: DecisionType[];
  summary: string;
}
