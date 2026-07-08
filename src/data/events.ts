// Regnum Moravicum v2.1 - Event Data Definitions
import type { EventType } from '../types/gameTypes';

// Event templates
export interface EventTemplate {
  id: string;
  type: EventType;
  title: string;
  description: string;
  baseChance: number; // 0-100
  minTurn: number;
  maxTurn: number | null;
  effects: EventEffect[];
  choices?: EventChoice[];
}

export interface EventEffect {
  type: string;
  target: string;
  value: number | string;
  duration?: number;
}

export interface EventChoice {
  text: string;
  effects: EventEffect[];
  weight?: number;
}

// Base events for Phase 0
export const BASE_EVENTS: EventTemplate[] = [
  {
    id: 'event_good_harvest',
    type: 'harvest',
    title: 'Bountiful Harvest',
    description: 'The fields have yielded an exceptional harvest this season.',
    baseChance: 20,
    minTurn: 0,
    maxTurn: null,
    effects: [
      { type: 'add_resource', target: 'food', value: 20 },
      { type: 'modify_loyalty', target: 'all_regions', value: 5 }
    ]
  },
  {
    id: 'event_poor_harvest',
    type: 'harvest',
    title: 'Poor Harvest',
    description: 'Drought and pests have ruined much of the harvest.',
    baseChance: 15,
    minTurn: 0,
    maxTurn: null,
    effects: [
      { type: 'add_resource', target: 'food', value: -15 },
      { type: 'modify_loyalty', target: 'all_regions', value: -5 }
    ]
  },
  {
    id: 'event_trade_caravan',
    type: 'trade',
    title: 'Trade Caravan Arrives',
    description: 'A Frankish trade caravan has arrived with valuable goods.',
    baseChance: 15,
    minTurn: 0,
    maxTurn: null,
    effects: [
      { type: 'add_resource', target: 'gold', value: 30 },
      { type: 'add_resource', target: 'influence', value: 5 }
    ],
    choices: [
      {
        text: 'Welcome the traders',
        effects: [
          { type: 'modify_relations', target: 'faction_frankish', value: 10 }
        ]
      },
      {
        text: 'Tax the caravan heavily',
        effects: [
          { type: 'add_resource', target: 'gold', value: 20 },
          { type: 'modify_relations', target: 'faction_frankish', value: -15 }
        ]
      }
    ]
  },
  {
    id: 'event_minor_revolt',
    type: 'revolt',
    title: 'Minor Unrest',
    description: 'The people in one of your regions are growing restless.',
    baseChance: 10,
    minTurn: 5,
    maxTurn: null,
    effects: [
      { type: 'modify_loyalty', target: 'random_region', value: -15 }
    ],
    choices: [
      {
        text: 'Send troops to suppress the revolt',
        effects: [
          { type: 'modify_loyalty', target: 'random_region', value: 10 },
          { type: 'add_resource', target: 'gold', value: -10 }
        ]
      },
      {
        text: 'Address their grievances',
        effects: [
          { type: 'modify_loyalty', target: 'random_region', value: 20 },
          { type: 'add_resource', target: 'food', value: -10 }
        ]
      }
    ]
  },
  {
    id: 'event_diplomatic_envoys',
    type: 'diplomacy',
    title: 'Foreign Envoys',
    description: 'Envoys from a neighboring realm seek an audience.',
    baseChance: 10,
    minTurn: 3,
    maxTurn: null,
    effects: [],
    choices: [
      {
        text: 'Receive them with honors',
        effects: [
          { type: 'modify_relations', target: 'random_faction', value: 15 },
          { type: 'add_resource', target: 'influence', value: 10 }
        ]
      },
      {
        text: 'Keep them waiting',
        effects: [
          { type: 'modify_relations', target: 'random_faction', value: -10 }
        ]
      }
    ]
  },
  {
    id: 'event_natural_disaster',
    type: 'disaster',
    title: 'Natural Disaster',
    description: 'A flood has damaged crops and buildings.',
    baseChance: 5,
    minTurn: 0,
    maxTurn: null,
    effects: [
      { type: 'add_resource', target: 'food', value: -10 },
      { type: 'add_resource', target: 'wood', value: -5 },
      { type: 'modify_development', target: 'random_region', value: -5 }
    ]
  },
  {
    id: 'event_divine_blessing',
    type: 'blessing',
    title: 'Divine Favor',
    description: 'The gods have smiled upon your rule.',
    baseChance: 5,
    minTurn: 0,
    maxTurn: null,
    effects: [
      { type: 'add_resource', target: 'faith', value: 15 },
      { type: 'modify_loyalty', target: 'all_regions', value: 10 },
      { type: 'modify_reputation', target: 'player', value: 5 }
    ]
  },
  {
    id: 'event_quest_offer',
    type: 'quest',
    title: 'Mysterious Offer',
    description: 'A stranger offers a quest with great rewards.',
    baseChance: 8,
    minTurn: 2,
    maxTurn: null,
    effects: [],
    choices: [
      {
        text: 'Accept the quest',
        effects: [
          { type: 'add_resource', target: 'knowledge', value: 10 },
          { type: 'add_resource', target: 'gold', value: 20 }
        ],
        weight: 70
      },
      {
        text: 'Decline the offer',
        effects: [
          { type: 'modify_reputation', target: 'player', value: -2 }
        ],
        weight: 30
      }
    ]
  }
];

// Event chance modifiers by faction type
export const EVENT_CHANCE_MODIFIERS: Record<string, Partial<Record<EventType, number>>> = {
  'faction_rastislav': {
    harvest: 5,
    trade: 10,
    diplomacy: 15,
    disaster: -5,
    blessing: 5
  },
  'faction_church': {
    harvest: -5,
    trade: -5,
    diplomacy: 10,
    disaster: -10,
    blessing: 20
  },
  'faction_frankish': {
    harvest: 0,
    trade: 20,
    diplomacy: 5,
    disaster: 0,
    blessing: -5
  },
  'faction_pagan': {
    harvest: 10,
    trade: -10,
    diplomacy: -10,
    disaster: 5,
    blessing: -10
  }
};

// Event effects on factions
export const EVENT_FACTION_EFFECTS: Record<EventType, Partial<Record<string, number>>> = {
  harvest: {
    'faction_rastislav': 2,
    'faction_mojmir': 2,
    'faction_church': 1,
    'faction_frankish': 1,
    'faction_pagan': 3,
    'faction_bulgarian': 1
  },
  revolt: {
    'faction_rastislav': -3,
    'faction_mojmir': -2,
    'faction_church': -1,
    'faction_frankish': 1,
    'faction_pagan': 2,
    'faction_bulgarian': -1
  },
  trade: {
    'faction_rastislav': 1,
    'faction_mojmir': 1,
    'faction_church': 0,
    'faction_frankish': 3,
    'faction_pagan': -1,
    'faction_bulgarian': 1
  },
  diplomacy: {
    'faction_rastislav': 2,
    'faction_mojmir': 1,
    'faction_church': 2,
    'faction_frankish': 1,
    'faction_pagan': -2,
    'faction_bulgarian': 2
  },
  disaster: {
    'faction_rastislav': -2,
    'faction_mojmir': -2,
    'faction_church': -1,
    'faction_frankish': 0,
    'faction_pagan': -1,
    'faction_bulgarian': -1
  },
  blessing: {
    'faction_rastislav': 3,
    'faction_mojmir': 2,
    'faction_church': 3,
    'faction_frankish': 1,
    'faction_pagan': -2,
    'faction_bulgarian': 2
  },
  quest: {
    'faction_rastislav': 1,
    'faction_mojmir': 1,
    'faction_church': 1,
    'faction_frankish': 0,
    'faction_pagan': 1,
    'faction_bulgarian': 1
  }
};
