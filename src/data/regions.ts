// Regnum Moravicum v2.1 - Region Data Definitions
import type { RegionType, ResourcePool } from '../types/gameTypes';

// Base resource production by region type
export const BASE_REGION_RESOURCES: Record<RegionType, ResourcePool> = {
  plains: {
    gold: 2,
    wood: 2,
    stone: 1,
    food: 8,
    iron: 0,
    faith: 0,
    knowledge: 0,
    influence: 0
  },
  forest: {
    gold: 1,
    wood: 8,
    stone: 1,
    food: 3,
    iron: 0,
    faith: 0,
    knowledge: 1,
    influence: 0
  },
  mountains: {
    gold: 1,
    wood: 2,
    stone: 6,
    food: 1,
    iron: 3,
    faith: 0,
    knowledge: 0,
    influence: 0
  },
  river: {
    gold: 3,
    wood: 2,
    stone: 2,
    food: 6,
    iron: 0,
    faith: 0,
    knowledge: 0,
    influence: 1
  },
  city: {
    gold: 10,
    wood: 5,
    stone: 5,
    food: 15,
    iron: 2,
    faith: 2,
    knowledge: 3,
    influence: 2
  },
  village: {
    gold: 4,
    wood: 3,
    stone: 2,
    food: 8,
    iron: 1,
    faith: 1,
    knowledge: 1,
    influence: 1
  },
  fortress: {
    gold: 2,
    wood: 3,
    stone: 8,
    food: 4,
    iron: 4,
    faith: 0,
    knowledge: 0,
    influence: 0
  }
};

// Region development modifiers
export const REGION_DEVELOPMENT_MODIFIERS: Record<RegionType, number> = {
  plains: 1.0,
  forest: 0.9,
  mountains: 0.8,
  river: 1.1,
  city: 1.5,
  village: 1.0,
  fortress: 1.2
};

// Region defense modifiers
export const REGION_DEFENSE_MODIFIERS: Record<RegionType, number> = {
  plains: 0.8,
  forest: 1.0,
  mountains: 1.5,
  river: 0.9,
  city: 1.2,
  village: 0.8,
  fortress: 2.0
};

// Region loyalty modifiers
export const REGION_LOYALTY_MODIFIERS: Record<RegionType, number> = {
  plains: 1.0,
  forest: 0.9,
  mountains: 0.8,
  river: 1.1,
  city: 1.3,
  village: 1.0,
  fortress: 1.2
};

// Region population modifiers
export const REGION_POPULATION_MODIFIERS: Record<RegionType, { min: number, max: number }> = {
  plains: { min: 2000, max: 8000 },
  forest: { min: 1000, max: 4000 },
  mountains: { min: 500, max: 3000 },
  river: { min: 1500, max: 6000 },
  city: { min: 5000, max: 15000 },
  village: { min: 800, max: 3000 },
  fortress: { min: 1000, max: 5000 }
};

// Historical Moravian regions (for Phase 1+)
export const MORAVIAN_REGIONS = [
  {
    id: 'moravia_brno',
    name: 'Brno',
    type: 'city' as const,
    description: 'The capital of Great Moravia under Rastislav',
    historicalSignificance: 'Primary political and administrative center'
  },
  {
    id: 'moravia_olomouc',
    name: 'Olomouc',
    type: 'city' as const,
    description: 'Important religious center',
    historicalSignificance: 'Seat of the Archbishopric of Moravia'
  },
  {
    id: 'moravia_stare_mesto',
    name: 'Staré Město',
    type: 'village' as const,
    description: 'Ancient settlement in Moravia',
    historicalSignificance: 'Early Slavic settlement'
  },
  {
    id: 'moravia_mikulcice',
    name: 'Mikulčice',
    type: 'fortress' as const,
    description: 'Fortified settlement on the Morava River',
    historicalSignificance: 'Important archaeological site'
  },
  {
    id: 'moravia_pozvadov',
    name: 'Pozvadov',
    type: 'village' as const,
    description: 'Settlement in western Moravia',
    historicalSignificance: 'Trade route location'
  },
  {
    id: 'moravia_velehrad',
    name: 'Velehrad',
    type: 'city' as const,
    description: 'Great Moravian center',
    historicalSignificance: 'Possible location of the Great Moravian capital'
  },
  {
    id: 'moravia_uherske_hradiste',
    name: 'Uherské Hradiště',
    type: 'fortress' as const,
    description: 'Fortified settlement',
    historicalSignificance: 'Military stronghold'
  },
  {
    id: 'moravia_znojmo',
    name: 'Znojmo',
    type: 'city' as const,
    description: 'Southern Moravian city',
    historicalSignificance: 'Border fortress against the Franks'
  }
];

// Region connection rules
export const REGION_CONNECTION_RULES = {
  // Region types that can connect to each other
  compatibleTypes: [
    ['plains', 'forest'],
    ['plains', 'river'],
    ['plains', 'village'],
    ['forest', 'mountains'],
    ['forest', 'village'],
    ['mountains', 'river'],
    ['river', 'city'],
    ['river', 'village'],
    ['city', 'village'],
    ['city', 'fortress'],
    ['village', 'fortress']
  ] as [RegionType, RegionType][],
  
  // Maximum connections by region type
  maxConnections: {
    plains: 4,
    forest: 3,
    mountains: 2,
    river: 4,
    city: 5,
    village: 3,
    fortress: 2
  } as Record<RegionType, number>
};
