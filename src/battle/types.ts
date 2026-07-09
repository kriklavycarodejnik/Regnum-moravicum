// Regnum Moravicum - Battle Types

export type Terrain = 'field' | 'forest' | 'fortress' | 'river' | 'hill';
export type UnitType = 'infantry' | 'cavalry' | 'archers';
export type BattlePhaseType = 'attack' | 'counterattack' | 'decision';
export type BattleAction = 'melee' | 'ranged' | 'flank' | 'retreat';
export type PostRoutAction = 'pursue' | 'regroup';
export type BattleResult =
  | 'victory_decision'
  | 'victory_rout'
  | 'retreat'
  | null;

export interface Commander {
  id: string;
  name: string;
  skill: number; // 0-10
}

export interface Army {
  id: string;
  factionId: string;
  size: number; // počet mužov
  morale: number; // 0-100, VŽDY v bodoch, nikdy v %
  commander: Commander;
  composition: Record<UnitType, number>; // podiely, súčet = 1.0
  locationZupaId: string;
}

export interface PhaseLog {
  phase: BattlePhaseType;
  attackerAction: BattleAction;
  defenderAction: BattleAction;
  attackerLosses: number;
  defenderLosses: number;
  attackerMoraleChange: number;
  defenderMoraleChange: number;
  narration: string[]; // vygenerované vety kroniky
}

export interface Battle {
  id: string;
  warId: string;
  zupaId: string;
  terrain: Terrain;
  attackerArmyId: string;
  defenderArmyId: string;
  currentPhase: BattlePhaseType | 'finished';
  phaseLogs: PhaseLog[];
  result: BattleResult;
  winnerArmyId: string | null;
  isAutoResolved: boolean;
  startTick: number;
  seed: string;
  rngState: object | null; // seedrandom state pre save/load uprostred bitky
}

// Faction traits for battle
export type FactionTrait = 'hungarian_cavalry' | 'moravian_fortifications' | 'danube_river';

// Battle context for narration
export interface BattleContext {
  attackerName: string;
  defenderName: string;
  attackerCommander: string;
  defenderCommander: string;
  zupaName: string;
  attackerFactionId: string;
  defenderFactionId: string;
}
