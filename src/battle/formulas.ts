// Regnum Moravicum - Battle Formulas

import type { Army, BattlePhaseType, BattleAction, Terrain } from './types';
import { BATTLE_CONFIG, TERRAIN_MODIFIERS, UNIT_TERRAIN_MULTIPLIERS, ACTION_COUNTER_MATRIX, FACTION_TRAITS } from './config';
import { BattleRNG } from './rng';

// 6.1 Efektívna sila
export function calculateEffectiveStrength(
  army: Army,
  isAttacker: boolean,
  terrain: Terrain,
  rng?: BattleRNG
): number {
  // Base size
  let es = army.size;
  
  // Morale factor (0-1)
  es *= army.morale / 100;
  
  // Terrain bonus
  const terrainBonus = isAttacker 
    ? TERRAIN_MODIFIERS[terrain].attackBonus 
    : TERRAIN_MODIFIERS[terrain].defenseBonus;
  es *= (1 + terrainBonus);
  
  // Composition factor
  let compositionFactor = 0;
  for (const [unitType, ratio] of Object.entries(army.composition)) {
    compositionFactor += ratio * UNIT_TERRAIN_MULTIPLIERS[unitType as Terrain][terrain];
  }
  es *= compositionFactor;
  
  // Commander skill bonus
  es *= (1 + army.commander.skill * BATTLE_CONFIG.commanderStrengthPerSkill);
  
  // Faction traits
  // Hungarian cavalry bonus on field: cavalry multiplier is 1.40 instead of 1.20
  if (army.factionId === 'hungarian' && terrain === 'field') {
    // Adjust composition factor for cavalry
    const cavalryRatio = army.composition['cavalry'] || 0;
    if (cavalryRatio > 0) {
      const baseCavalryMultiplier = UNIT_TERRAIN_MULTIPLIERS['cavalry']['field'];
      const hungarianMultiplier = 1.40;
      // Replace the base multiplier with Hungarian multiplier in composition factor
      const baseContribution = cavalryRatio * baseCavalryMultiplier;
      const hungarianContribution = cavalryRatio * hungarianMultiplier;
      compositionFactor = compositionFactor - baseContribution + hungarianContribution;
      // Recalculate ES with adjusted composition factor
      es = army.size * (army.morale / 100) * (1 + terrainBonus) * compositionFactor * (1 + army.commander.skill * BATTLE_CONFIG.commanderStrengthPerSkill);
    }
  }
  
  // Moravian fortress defense bonus: defense factor on fortress x 1.30
  if (army.factionId === 'moravian' && terrain === 'fortress' && !isAttacker) {
    // The fortress defense multiplier applies to the terrain defense bonus
    // terrainBonus for fortress defender is 0.6, multiplied by 1.3 = 0.78
    // So we need to adjust the terrain bonus
    const adjustedTerrainBonus = terrainBonus * FACTION_TRAITS['moravian'].fortressDefenseMultiplier!;
    es = army.size * (army.morale / 100) * (1 + adjustedTerrainBonus) * compositionFactor * (1 + army.commander.skill * BATTLE_CONFIG.commanderStrengthPerSkill);
  }
  
  return Math.max(0, es);
}

// Get action modifier from counter matrix
export function getActionModifier(
  myAction: BattleAction,
  enemyAction: BattleAction
): number {
  return ACTION_COUNTER_MATRIX[myAction][enemyAction];
}

// 6.3 Vyhodnotenie fázy 1 a 2
export interface PhaseResult {
  attackerLosses: number;
  defenderLosses: number;
  attackerMoraleChange: number;
  defenderMoraleChange: number;
  ratio: number;
}

export function evaluatePhase(
  attacker: Army,
  defender: Army,
  phase: BattlePhaseType,
  attackerAction: BattleAction,
  defenderAction: BattleAction,
  terrain: Terrain,
  rng: BattleRNG
): PhaseResult {
  // Calculate effective strengths
  const esAttacker = calculateEffectiveStrength(attacker, true, terrain, rng);
  const esDefender = calculateEffectiveStrength(defender, false, terrain, rng);
  
  // Get action modifiers
  const attackerActionMod = getActionModifier(attackerAction, defenderAction);
  const defenderActionMod = getActionModifier(defenderAction, attackerAction);
  
  // Apply RNG
  const attackerRng = rng.range(BATTLE_CONFIG.rngRange.phase[0], BATTLE_CONFIG.rngRange.phase[1]);
  const defenderRng = rng.range(BATTLE_CONFIG.rngRange.phase[0], BATTLE_CONFIG.rngRange.phase[1]);
  
  const powerA = esAttacker * attackerActionMod * attackerRng;
  const powerB = esDefender * defenderActionMod * defenderRng;
  
  const ratio = powerA / powerB;
  
  // Calculate losses
  const baseLossRate = BATTLE_CONFIG.baseLossRate[phase];
  const clampedRatio = clamp(ratio, BATTLE_CONFIG.lossRatioClamp[0], BATTLE_CONFIG.lossRatioClamp[1]);
  const clampedInverseRatio = clamp(1 / ratio, BATTLE_CONFIG.lossRatioClamp[0], BATTLE_CONFIG.lossRatioClamp[1]);
  
  const defenderLosses = Math.round(defender.size * baseLossRate * clampedRatio);
  const attackerLosses = Math.round(attacker.size * baseLossRate * clampedInverseRatio);
  
  // Calculate morale changes
  let attackerMoraleChange = 0;
  let defenderMoraleChange = 0;
  
  if (ratio > 1.1) {
    // Attacker wins
    attackerMoraleChange = BATTLE_CONFIG.moraleWinBonus;
    const moraleLoss = Math.round(
      BATTLE_CONFIG.moraleLossBase * Math.min(ratio, 2) * 
      (1 - defender.commander.skill * BATTLE_CONFIG.commanderMoraleMitigation)
    );
    defenderMoraleChange = -moraleLoss;
  } else if (ratio < 0.9) {
    // Defender wins
    defenderMoraleChange = BATTLE_CONFIG.moraleWinBonus;
    const moraleLoss = Math.round(
      BATTLE_CONFIG.moraleLossBase * Math.min(1 / ratio, 2) * 
      (1 - attacker.commander.skill * BATTLE_CONFIG.commanderMoraleMitigation)
    );
    attackerMoraleChange = -moraleLoss;
  } else {
    // Draw (0.9 <= ratio <= 1.1)
    attackerMoraleChange = -BATTLE_CONFIG.moraleDrawPenalty;
    defenderMoraleChange = -BATTLE_CONFIG.moraleDrawPenalty;
  }
  
  return {
    attackerLosses,
    defenderLosses,
    attackerMoraleChange,
    defenderMoraleChange,
    ratio,
  };
}

// 6.7 Fáza 3 — Rozhodnutie
export function evaluateDecisionPhase(
  attacker: Army,
  defender: Army,
  attackerAction: BattleAction,
  defenderAction: BattleAction,
  terrain: Terrain,
  rng: BattleRNG
): { winner: 'attacker' | 'defender'; ratio: number } {
  const esAttacker = calculateEffectiveStrength(attacker, true, terrain, rng);
  const esDefender = calculateEffectiveStrength(defender, false, terrain, rng);
  
  const attackerActionMod = getActionModifier(attackerAction, defenderAction);
  const defenderActionMod = getActionModifier(defenderAction, attackerAction);
  
  const attackerRng = rng.range(BATTLE_CONFIG.rngRange.decision[0], BATTLE_CONFIG.rngRange.decision[1]);
  const defenderRng = rng.range(BATTLE_CONFIG.rngRange.decision[0], BATTLE_CONFIG.rngRange.decision[1]);
  
  const decisionPowerAttacker = esAttacker * Math.sqrt(attacker.morale / 100) * attackerActionMod * attackerRng;
  const decisionPowerDefender = esDefender * Math.sqrt(defender.morale / 100) * defenderActionMod * defenderRng;
  
  const ratio = decisionPowerAttacker / decisionPowerDefender;
  
  // Pri presnej rovnosti vyhráva obranca
  if (decisionPowerAttacker > decisionPowerDefender) {
    return { winner: 'attacker', ratio };
  } else {
    return { winner: 'defender', ratio };
  }
}

// Helper function to clamp value
export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

// Apply terrain morale modifiers at battle start
export function applyTerrainMoraleModifiers(
  attacker: Army,
  defender: Army,
  terrain: Terrain
): { attackerMorale: number; defenderMorale: number } {
  let attackerMorale = attacker.morale + TERRAIN_MODIFIERS[terrain].attackerMorale;
  let defenderMorale = defender.morale + TERRAIN_MODIFIERS[terrain].defenderMorale;
  
  // Faction-specific morale modifiers
  // Hungarian river penalty
  if (attacker.factionId === 'hungarian' && terrain === 'river') {
    attackerMorale += FACTION_TRAITS['hungarian'].riverMoralePenalty || 0;
  }
  
  // Clamp to 0-100
  attackerMorale = clamp(attackerMorale, 0, 100);
  defenderMorale = clamp(defenderMorale, 0, 100);
  
  return { attackerMorale, defenderMorale };
}

// Check for rout condition
export function checkRout(morale: number): boolean {
  return morale <= BATTLE_CONFIG.routThreshold;
}

// Apply rout losses
export function applyRoutLosses(
  armySize: number,
  action: import('./types').PostRoutAction
): number {
  const lossPercentage = action === 'pursue' 
    ? BATTLE_CONFIG.routExtraLosses.pursue 
    : BATTLE_CONFIG.routExtraLosses.regroup;
  return Math.round(armySize * lossPercentage);
}

// Apply retreat losses
export function applyRetreatLosses(armySize: number): number {
  return Math.round(armySize * BATTLE_CONFIG.retreatLosses);
}

// Apply decision phase losses
export function applyDecisionLosses(armySize: number): number {
  return Math.round(armySize * BATTLE_CONFIG.decisionLoserLosses);
}
