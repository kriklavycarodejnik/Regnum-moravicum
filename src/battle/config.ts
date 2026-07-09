// Regnum Moravicum - Battle Configuration

import type { Terrain, UnitType } from './types';

// 5.1 Terénové modifikátory
export const TERRAIN_MODIFIERS: Record<Terrain, {
  attackBonus: number;
  defenseBonus: number;
  attackerMorale: number;
  defenderMorale: number;
}> = {
  field: { attackBonus: 0.00, defenseBonus: 0.00, attackerMorale: 0, defenderMorale: 0 },
  forest: { attackBonus: -0.20, defenseBonus: 0.30, attackerMorale: -10, defenderMorale: 0 },
  fortress: { attackBonus: -0.40, defenseBonus: 0.60, attackerMorale: 0, defenderMorale: 15 },
  river: { attackBonus: -0.15, defenseBonus: 0.20, attackerMorale: -5, defenderMorale: 0 },
  hill: { attackBonus: 0.00, defenseBonus: 0.20, attackerMorale: 0, defenderMorale: 5 },
} as const;

// 5.2 Multiplikátory jednotiek podľa terénu
export const UNIT_TERRAIN_MULTIPLIERS: Record<UnitType, Record<Terrain, number>> = {
  infantry: { field: 1.00, forest: 1.05, fortress: 1.15, river: 1.00, hill: 1.05 },
  cavalry: { field: 1.20, forest: 0.70, fortress: 0.60, river: 0.80, hill: 0.90 },
  archers: { field: 1.00, forest: 1.10, fortress: 1.10, river: 1.05, hill: 1.15 },
} as const;

// 5.3 Counter-matica akcií
export type ActionModifier = 0.85 | 1.00 | 1.15;

// Kruhová prevaha: melee poráža ranged, ranged poráža flank, flank poráža melee
export const ACTION_COUNTER_MATRIX: Record<import('./types').BattleAction, Record<import('./types').BattleAction, ActionModifier>> = {
  melee: { melee: 1.00, ranged: 1.15, flank: 0.85, retreat: 1.00 },
  ranged: { melee: 0.85, ranged: 1.00, flank: 1.15, retreat: 1.00 },
  flank: { melee: 1.15, ranged: 0.85, flank: 1.00, retreat: 1.00 },
  retreat: { melee: 1.00, ranged: 1.00, flank: 1.00, retreat: 1.00 },
} as const;

// 5.4 Konštanty priebehu bitky
export const BATTLE_CONFIG = {
  baseLossRate: { attack: 0.06, counterattack: 0.06, decision: 0.10 } as const,
  rngRange: { phase: [0.85, 1.15] as const, decision: [0.80, 1.20] as const },
  lossRatioClamp: [0.5, 2.0] as const,
  moraleWinBonus: 5,
  moraleLossBase: 8, // × min(ratio, 2) → −8 až −16
  moraleDrawPenalty: 3, // obe strany pri remíze fázy
  routThreshold: 20, // morálka <= 20 → rout
  routExtraLosses: { regroup: 0.10, pursue: 0.20 } as const,
  pursueMoraleBonus: 10,
  retreatLosses: 0.05, // dobrovoľný ústup
  retreatMoralePenalty: 10,
  decisionLoserLosses: 0.08,
  decisionLoserMorale: -15,
  decisionWinnerMorale: 10,
  commanderStrengthPerSkill: 0.02, // +2 % ES za bod skillu
  commanderMoraleMitigation: 0.02, // −2 % straty morálky za bod skillu
  autoResolveRatio: 2.0,
} as const;

// Faction-specific traits
export const FACTION_TRAITS: Record<string, {
  cavalryFieldMultiplier?: number;
  fortressDefenseMultiplier?: number;
  riverMoralePenalty?: number;
}> = {
  // Maďarská jazda: multiplikátor cavalry na field = 1.40 namiesto 1.20
  hungarian: {
    cavalryFieldMultiplier: 1.40,
  },
  // Moravské opevnenia: obranný terénový faktor na fortress × 1.30
  moravian: {
    fortressDefenseMultiplier: 1.30,
  },
  // Rieka Dunaj: bitka na teréne river → Maďari −10 bodov morálky
  hungarian_danube: {
    riverMoralePenalty: -10,
  },
} as const;

// Helper to get unit composition factor for an army
export function getCompositionFactor(army: import('./types').Army, terrain: Terrain): number {
  let factor = 0;
  for (const [unitType, ratio] of Object.entries(army.composition)) {
    factor += ratio * UNIT_TERRAIN_MULTIPLIERS[unitType as UnitType][terrain];
  }
  return factor;
}

// Helper to get terrain bonus for a role (attacker or defender)
export function getTerrainBonus(terrain: Terrain, isAttacker: boolean): number {
  return isAttacker ? TERRAIN_MODIFIERS[terrain].attackBonus : TERRAIN_MODIFIERS[terrain].defenseBonus;
}

// Helper to get faction trait multiplier
export function getFactionTraitMultiplier(factionId: string, terrain: Terrain, isAttacker: boolean): number {
  const traits = FACTION_TRAITS[factionId];
  if (!traits) return 1.0;

  let multiplier = 1.0;
  
  // Hungarian cavalry bonus on field
  if (traits.cavalryFieldMultiplier && terrain === 'field' && !isAttacker) {
    // This is for cavalry units specifically, handled in composition factor
  }
  
  // Moravian fortress defense bonus
  if (traits.fortressDefenseMultiplier && terrain === 'fortress' && !isAttacker) {
    multiplier *= traits.fortressDefenseMultiplier;
  }
  
  return multiplier;
}

// Helper to get faction trait morale modifier
export function getFactionTraitMoraleModifier(factionId: string, terrain: Terrain, isAttacker: boolean): number {
  const traits = FACTION_TRAITS[factionId];
  if (!traits) return 0;

  let modifier = 0;
  
  // Hungarian river morale penalty
  if (traits.riverMoralePenalty && terrain === 'river' && isAttacker) {
    modifier += traits.riverMoralePenalty;
  }
  
  return modifier;
}
