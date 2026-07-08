// Regnum Moravicum v2.1 - Generators
import type { GameState, ScenarioType } from '../types/gameState';
import type {
  Noble,
  Family,
  Faction,
  Zupa,
  Army,
  NobleId,
  FamilyId,
  ZupaId,
  NobleTitle,
  Attributes,
  FactionMoods,
  FactionPersonality,
  ZupaSpecialization,
  ArmyUnits
} from '../types/entities';
import { rng, rngChance, initRNG } from './rng';

export const SAVE_VERSION = '2.1.0';

// Attribute point budgets by title
const ATTRIBUTE_BUDGETS: Record<NobleTitle, { min: number; max: number }> = {
  'Župan': { min: 15, max: 20 },
  'Magnát': { min: 20, max: 28 },
  'Palatín': { min: 28, max: 38 },
  'Kráľ': { min: 40, max: 50 },
  'Regent': { min: 30, max: 40 }
};

const ATTRIBUTE_NAMES: (keyof Attributes)[] = ['combat', 'diplomacy', 'intelligence', 'piety', 'charisma'];

/**
 * Generate attributes for a noble based on title
 */
export function generateAttributes(title: NobleTitle): Attributes {
  const budget = rng(ATTRIBUTE_BUDGETS[title].min, ATTRIBUTE_BUDGETS[title].max);
  const attributes: Attributes = {
    combat: 1,
    diplomacy: 1,
    intelligence: 1,
    piety: 1,
    charisma: 1
  };
  
  let remaining = budget - 5; // Start with 1 in each attribute
  
  // Distribute remaining points randomly
  while (remaining > 0) {
    const attrIndex = rng(0, ATTRIBUTE_NAMES.length - 1);
    const attr = ATTRIBUTE_NAMES[attrIndex];
    
    if (attributes[attr] < 10) {
      attributes[attr]++;
      remaining--;
    }
  }
  
  return attributes;
}

/**
 * Generate a noble
 */
export function generateNoble(
  name: string,
  familyId: FamilyId,
  title: NobleTitle,
  age: number,
  location: ZupaId,
  coatOfArms: string = ''
): Noble {
  return {
    id: `noble_${Date.now()}_${rng(1000, 9999)}`,
    name,
    familyId,
    title,
    attributes: generateAttributes(title),
    loyalty: rng(70, 90),
    location,
    armyIds: [],
    children: [],
    coatOfArms,
    age,
    status: 'alive',
    birthTick: 0
  };
}

/**
 * Generate a family
 */
export function generateFamily(
  name: string,
  founder: Noble,
  coatOfArms: string = ''
): Family {
  return {
    id: `family_${Date.now()}_${rng(1000, 9999)}`,
    name,
    founder: founder.id,
    members: [founder.id],
    reputation: rng(50, 80),
    wealth: rng(100, 500),
    coatOfArms,
    history: [`Founded by ${founder.name} in year 902`]
  };
}

/**
 * Generate faction moods
 */
function generateFactionMoods(): FactionMoods {
  return {
    loyalty: rng(40, 60),
    fear: rng(30, 50),
    trust: rng(40, 60),
    anger: rng(20, 40)
  };
}

/**
 * Generate a faction
 */
export function generateFaction(
  name: string,
  personality: FactionPersonality
): Faction {
  return {
    id: `faction_${Date.now()}_${rng(1000, 9999)}`,
    name,
    moods: generateFactionMoods(),
    personality,
    currentTreaties: [],
    moodHistory: []
  };
}

/**
 * Generate a zupa
 */
export function generateZupa(
  name: string,
  owner: NobleId,
  neighbors: ZupaId[] = [],
  specializations: ZupaSpecialization[] = []
): Zupa {
  return {
    id: `zupa_${name.toLowerCase().replace(/\s+/g, '_')}`,
    name,
    prosperity: rng(40, 70),
    food: rng(50, 150),
    defense: rng(30, 60),
    loyalty: rng(60, 85),
    owner,
    neighbors,
    specialization: specializations.length > 0 ? specializations : [rngChance(0.5) ? 'agriculture' : 'trade'],
    population: rng(50, 90),
    recruitmentPool: rng(20, 50),
    recruitmentRate: rng(3, 8),
    garrison: rng(5, 15)
  };
}

/**
 * Generate an army
 */
export function generateArmy(
  commanderId: NobleId,
  location: ZupaId,
  units: ArmyUnits = { lightInfantry: 0, heavyInfantry: 0, archers: 0, lightCavalry: 0, heavyCavalry: 0 }
): Army {
  const unitUpkeep = {
    lightInfantry: 1,
    heavyInfantry: 2,
    archers: 2,
    lightCavalry: 3,
    heavyCavalry: 4
  };
  
  let upkeep = 0;
  Object.entries(units).forEach(([unitType, count]) => {
    upkeep += count * (unitUpkeep as any)[unitType];
  });
  
  return {
    id: `army_${Date.now()}_${rng(1000, 9999)}`,
    commanderId,
    units: { ...units },
    morale: rng(70, 90),
    location,
    stance: 'idle',
    upkeep
  };
}

// Historical Moravian zupy (11 zup for scenario "prežitie")
const MORAVIAN_ZUPY = [
  'Nitra', 'Devín', 'Bratislava', 'Trnava', 'Zvolen',
  'Banská Bystrica', 'Košice', 'Prešov', 'Žilina', 'Poprad', 'Bardejov'
];

// Faction definitions for scenario "prežitie"
const INITIAL_FACTIONS = [
  { name: 'Župani', personality: 'loyal' as const },
  { name: 'Cyrilometodskí Kňazi', personality: 'opportunist' as const },
  { name: 'Byzantskí Poslovia', personality: 'opportunist' as const },
  { name: 'Nemeckí Kolonisti', personality: 'traitor' as const },
  { name: 'Maďarské zvyšky', personality: 'aggressive' as const },
  { name: 'Kumáni', personality: 'aggressive' as const }
];

/**
 * Generate initial state for scenario "prežitie" (902 AD)
 */
export function generateInitialState(scenario: ScenarioType, seed: string): GameState {
  initRNG(seed);
  
  // Create Mojmír II. (35 years old)
  const mojmir = generateNoble('Mojmír II.', '', 'Kráľ', 35, 'nitra');
  
  // Create Mojmírovci family
  const mojmirovci = generateFamily('Mojmírovci', mojmir);
  mojmir.familyId = mojmirovci.id;
  
  // Create 11 zupy
  const zupy: Record<ZupaId, Zupa> = {};
  const zupaIds: ZupaId[] = [];
  
  MORAVIAN_ZUPY.forEach((name) => {
    const zupa = generateZupa(name, mojmir.id);
    zupy[zupa.id] = zupa;
    zupaIds.push(zupa.id);
  });
  
  // Connect neighbors (simple ring topology)
  zupaIds.forEach((zupaId) => {
    const index = zupaIds.indexOf(zupaId);
    const prevIndex = (index - 1 + zupaIds.length) % zupaIds.length;
    const nextIndex = (index + 1) % zupaIds.length;
    zupy[zupaId].neighbors = [zupaIds[prevIndex], zupaIds[nextIndex]];
  });
  
  // Create factions
  const factions: Faction[] = INITIAL_FACTIONS.map(f => generateFaction(f.name, f.personality));
  
  // Create initial armies for Mojmír
  const armies: Army[] = [
    generateArmy(mojmir.id, 'nitra', { lightInfantry: 50, heavyInfantry: 30, archers: 20, lightCavalry: 10, heavyCavalry: 5 }),
    generateArmy(mojmir.id, 'devín', { lightInfantry: 40, heavyInfantry: 20, archers: 15, lightCavalry: 5, heavyCavalry: 0 })
  ];
  
  // Update Mojmír with army IDs
  mojmir.armyIds = armies.map(a => a.id);
  
  return {
    tick: 0,
    year: 902,
    seed,
    scenario,
    player: {
      dynasty: mojmirovci.id,
      currentRuler: mojmir.id,
      prestige: 50,
      religionAxis: 0
    },
    nobles: [mojmir],
    families: [mojmirovci],
    factions,
    zupy,
    armies,
    wars: [],
    treaties: [],
    events: [],
    resources: {
      gold: 1000,
      food: 100,
      wood: 50,
      stone: 50,
      iron: 30,
      prestige: 10
    },
    religion: { value: 0 },
    gameOver: false,
    saveVersion: SAVE_VERSION
  };
}

/**
 * Generate a unique ID
 */
export function generateId(prefix: string = 'id'): string {
  return `${prefix}_${Date.now()}_${rng(1000, 9999)}`;
}

export default {
  generateInitialState,
  generateNoble,
  generateFamily,
  generateFaction,
  generateZupa,
  generateArmy,
  generateAttributes,
  generateId,
  SAVE_VERSION
};
