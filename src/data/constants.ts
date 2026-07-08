// Regnum Moravicum v2.1 - Game Constants

export const GAME_VERSION = '2.1.0';
export const GAME_PHASE = 0; // Phase 0: Foundations

// Starting date: January 1, 830 AD (Rastislav's era)
export const START_YEAR = 830;
export const START_MONTH = 1;
export const START_DAY = 1;

// Game configuration
export const MONTHS_PER_TURN = 1;
export const DEFAULT_DIFFICULTY = 'normal';

// Resource configuration
export const RESOURCE_TYPES = [
  'gold',
  'wood',
  'stone',
  'food',
  'iron',
  'faith',
  'knowledge',
  'influence'
] as const;

export const REGION_TYPES = [
  'plains',
  'forest',
  'mountains',
  'river',
  'city',
  'village',
  'fortress'
] as const;

export const FACTION_TYPES = [
  'player',
  'noble',
  'church',
  'merchants',
  'rebels',
  'foreign'
] as const;

export const EVENT_TYPES = [
  'harvest',
  'revolt',
  'trade',
  'diplomacy',
  'disaster',
  'blessing',
  'quest'
] as const;

export const DECISION_TYPES = [
  'tax',
  'construction',
  'diplomacy',
  'military',
  'religion',
  'trade'
] as const;

// Game balance constants
export const BASE_REGION_DEVELOPMENT = 30;
export const BASE_REGION_LOYALTY = 70;
export const BASE_REGION_DEFENSE = 10;

export const MIN_POPULATION = 1000;
export const MAX_POPULATION = 5000;

export const MIN_RELATIONS = -100;
export const MAX_RELATIONS = 100;

export const MIN_STRENGTH = 0;
export const MAX_STRENGTH = 100;

export const MIN_INFLUENCE = 0;
export const MAX_INFLUENCE = 100;

// Event generation
export const BASE_EVENT_CHANCE = 0.5;
export const MAX_EVENTS_PER_TURN = 3;

// Turn phases
export const TURN_PHASES = [
  'start',
  'income',
  'events',
  'decisions',
  'upkeep',
  'end'
] as const;

// Month names
export const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
] as const;

// Difficulty modifiers
export const DIFFICULTY_MODIFIERS = {
  easy: {
    eventFrequency: 0.7,
    resourceBonus: 1.2,
    upkeepReduction: 0.8
  },
  normal: {
    eventFrequency: 1.0,
    resourceBonus: 1.0,
    upkeepReduction: 1.0
  },
  hard: {
    eventFrequency: 1.3,
    resourceBonus: 0.8,
    upkeepReduction: 1.2
  },
  ironman: {
    eventFrequency: 1.5,
    resourceBonus: 0.7,
    upkeepReduction: 1.5
  }
} as const;
