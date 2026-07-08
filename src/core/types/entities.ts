// Regnum Moravicum v2.1 - Entity Types

export type NobleId = string;
export type FamilyId = string;
export type FactionId = string;
export type ZupaId = string;
export type ArmyId = string;
export type WarId = string;
export type TreatyId = string;
export type EventId = string;
export type BattleId = string;

export type NobleTitle = 'Župan' | 'Magnát' | 'Palatín' | 'Kráľ' | 'Regent';
export type NobleStatus = 'alive' | 'dead' | 'exiled' | 'rebel';

export interface Attributes {
  combat: number;        // 1-10
  diplomacy: number;     // 1-10
  intelligence: number;  // 1-10
  piety: number;         // 1-10
  charisma: number;      // 1-10
}

// Bodové rozpočty podľa titulu:
// Župan: 15-20 | Magnát: 20-28 | Palatín: 28-38 | Kráľ: 40-50
export interface Noble {
  id: NobleId;
  name: string;
  familyId: FamilyId;
  title: NobleTitle;
  attributes: Attributes;
  loyalty: number;          // 0-100
  location: ZupaId;
  armyIds: ArmyId[];
  spouse?: NobleId;
  children: NobleId[];
  coatOfArms: string;       // SVG string
  age: number;
  status: NobleStatus;
  birthTick: number;
  deathTick?: number;
}

export interface Family {
  id: FamilyId;
  name: string;
  founder: NobleId;
  members: NobleId[];
  reputation: number;   // 0-100
  wealth: number;
  coatOfArms: string;
  history: string[];
}

export type FactionMoods = { loyalty: number; fear: number; trust: number; anger: number }; // všetko 0-100
export type FactionPersonality = 'aggressive' | 'opportunist' | 'loyal' | 'traitor';

export interface MoodHistoryEntry {
  tick: number;
  action: string;
  moodChange: Partial<FactionMoods>;
  weight: number; // 100/80/60/40/20 %
}

export interface Faction {
  id: FactionId;
  name: string;
  moods: FactionMoods;
  personality: FactionPersonality;
  currentTreaties: TreatyId[];
  moodHistory: MoodHistoryEntry[]; // posledných 5 interakcií
}

export type ZupaSpecialization = 'agriculture' | 'trade' | 'military' | 'religious';

export interface Zupa {
  id: ZupaId;
  name: string;
  prosperity: number;    // 0-100
  food: number;
  defense: number;       // 0-100
  loyalty: number;       // 0-100
  owner: NobleId;
  neighbors: ZupaId[];
  specialization: ZupaSpecialization[];
  population: number;    // 0-100 index
  recruitmentPool: number;
  recruitmentRate: number;
  garrison: number;
}

export type ArmyStance = 'idle' | 'marching' | 'besieging' | 'defending';

export interface ArmyUnits {
  lightInfantry: number;
  heavyInfantry: number;
  archers: number;
  lightCavalry: number;
  heavyCavalry: number;
}

export interface Army {
  id: ArmyId;
  commanderId: NobleId;
  units: ArmyUnits;
  morale: number;   // 0-100
  location: ZupaId;
  stance: ArmyStance;
  upkeep: number;   // zlato/mesiac
}

export type CasusBelli = 'borderDispute' | 'marriageClaim' | 'retaliation' | 'none';
export type WarGoal = 'conquerZupa' | 'conquerMultiple' | 'vassalize' | 'tribute';
export type WarStatus = 'ongoing' | 'victory' | 'defeat' | 'stalemate';

export interface War {
  id: WarId;
  attacker: FactionId;
  defender: FactionId;
  casusBelli: CasusBelli;
  goal: WarGoal;
  targetZupa?: ZupaId;
  targetZupas?: ZupaId[];
  tributeAmount?: number;
  startTick: number;
  battles: BattleId[];
  status: WarStatus;
}

export type TreatyType = 'trade' | 'military' | 'marriage' | 'nonAggression' | 'vassal';

export interface Treaty {
  id: TreatyId;
  type: TreatyType;
  parties: (FactionId | NobleId)[];
  startTick: number;
  endTick: number;
  terms: Record<string, any>;
  tributeAmount?: number;
  targetFaction?: FactionId;
}
