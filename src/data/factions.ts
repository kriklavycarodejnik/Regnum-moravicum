// Regnum Moravicum v2.1 - Faction Data Definitions
import type { FactionType } from '../types/gameTypes';

// Base faction stats by type
export const BASE_FACTION_STATS: Record<FactionType, { strength: number, influence: number, wealth: number }> = {
  player: { strength: 60, influence: 50, wealth: 200 },
  noble: { strength: 40, influence: 60, wealth: 150 },
  church: { strength: 30, influence: 70, wealth: 100 },
  merchants: { strength: 20, influence: 40, wealth: 300 },
  rebels: { strength: 25, influence: 20, wealth: 50 },
  foreign: { strength: 50, influence: 30, wealth: 250 }
};

// Faction traits
export type FactionTrait = 
  | 'wealthy'
  | 'militaristic'
  | 'religious'
  | 'diplomatic'
  | 'expansionist'
  | 'defensive'
  | 'aggressive'
  | 'loyal'
  | 'rebellious'
  | 'trade-focused'
  | 'knowledgeable';

// Faction trait effects
export const FACTION_TRAIT_EFFECTS: Record<FactionTrait, Partial<Record<FactionType, number>>> = {
  wealthy: { merchants: 0.2, noble: 0.1 },
  militaristic: { player: 0.15, noble: 0.15, foreign: 0.1 },
  religious: { church: 0.2, player: 0.05 },
  diplomatic: { player: 0.1, noble: 0.15, church: 0.1 },
  expansionist: { player: 0.15, foreign: 0.2 },
  defensive: { player: 0.1, noble: 0.1 },
  aggressive: { rebels: 0.2, foreign: 0.15 },
  loyal: { player: 0.2, noble: 0.1 },
  rebellious: { rebels: 0.3 },
  'trade-focused': { merchants: 0.25, player: 0.05 },
  knowledgeable: { church: 0.15, player: 0.1 }
};

// Historical Moravian factions (for Phase 0)
export const MORAVIAN_FACTIONS = [
  {
    id: 'faction_rastislav',
    name: "Rastislav's Court",
    type: 'player' as const,
    description: 'The ruling dynasty of Great Moravia',
    historicalContext: 'Rastislav (846-870) was the second known ruler of Moravia, who sought to reduce Frankish influence',
    startingRegions: ['moravia_brno', 'moravia_velehrad'],
    traits: ['diplomatic', 'expansionist', 'loyal'] as FactionTrait[]
  },
  {
    id: 'faction_mojmir',
    name: "Mojmír's Line",
    type: 'noble' as const,
    description: 'The original ruling dynasty before Rastislav',
    historicalContext: 'Mojmír I established the first known Moravian state in 830s',
    startingRegions: ['moravia_stare_mesto'],
    traits: ['loyal', 'defensive'] as FactionTrait[]
  },
  {
    id: 'faction_church',
    name: 'Great Moravian Church',
    type: 'church' as const,
    description: 'The Christian church in Moravia',
    historicalContext: 'Established through Byzantine mission, competing with Frankish clergy',
    startingRegions: ['moravia_olomouc'],
    traits: ['religious', 'knowledgeable', 'diplomatic'] as FactionTrait[]
  },
  {
    id: 'faction_frankish',
    name: 'Frankish Merchants',
    type: 'merchants' as const,
    description: 'Frankish traders and clergy',
    historicalContext: 'Representing East Frankish influence in Moravian affairs',
    startingRegions: ['moravia_znojmo'],
    traits: ['wealthy', 'trade-focused'] as FactionTrait[]
  },
  {
    id: 'faction_pagan',
    name: 'Pagan Rebels',
    type: 'rebels' as const,
    description: 'Traditional Slavic pagan factions',
    historicalContext: 'Resisting Christianization and foreign influence',
    startingRegions: ['moravia_mikulcice'],
    traits: ['rebellious', 'aggressive'] as FactionTrait[]
  },
  {
    id: 'faction_bulgarian',
    name: 'Bulgarian Allies',
    type: 'foreign' as const,
    description: 'Allies from the Bulgarian Empire',
    historicalContext: 'Byzantine-aligned Slavic state that supported Moravian independence',
    startingRegions: ['moravia_uherske_hradiste'],
    traits: ['militaristic', 'expansionist'] as FactionTrait[]
  }
];

// Faction relation modifiers
export const FACTION_RELATION_MODIFIERS = {
  // Same type factions have slight positive relations
  sameType: 10,
  // Opposing types have negative relations
  opposingTypes: {
    player: ['rebels'] as FactionType[],
    noble: ['rebels'] as FactionType[],
    church: ['rebels'] as FactionType[],
    merchants: [] as FactionType[],
    rebels: ['player', 'noble', 'church'] as FactionType[],
    foreign: [] as FactionType[]
  } as Record<FactionType, FactionType[]>,
  // Historical relations
  historical: {
    'faction_rastislav': {
      'faction_mojmir': 20, // Allied dynasties
      'faction_church': 30, // Supported by church
      'faction_frankish': -40, // Opposed Frankish influence
      'faction_pagan': -20, // Christian vs pagan
      'faction_bulgarian': 50 // Strong allies
    },
    'faction_church': {
      'faction_frankish': 10, // Both Christian, but different allegiances
      'faction_pagan': -50 // Strong opposition
    },
    'faction_frankish': {
      'faction_pagan': -30,
      'faction_bulgarian': -40 // Rival Christian missions
    }
  } as Record<string, Record<string, number>>
};

// Faction goals
export type FactionGoalType = 
  | 'expand_territory'
  | 'increase_influence'
  | 'accumulate_wealth'
  | 'spread_faith'
  | 'maintain_power'
  | 'overthrow_ruler'
  | 'secure_trade_routes';

// Available goals by faction type
export const FACTION_GOALS_BY_TYPE: Record<FactionType, FactionGoalType[]> = {
  player: ['expand_territory', 'increase_influence', 'accumulate_wealth', 'maintain_power'],
  noble: ['expand_territory', 'increase_influence', 'maintain_power'],
  church: ['spread_faith', 'increase_influence', 'accumulate_wealth'],
  merchants: ['accumulate_wealth', 'secure_trade_routes', 'increase_influence'],
  rebels: ['overthrow_ruler', 'expand_territory', 'increase_influence'],
  foreign: ['expand_territory', 'increase_influence', 'accumulate_wealth']
};
