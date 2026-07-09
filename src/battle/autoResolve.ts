// Regnum Moravicum - Auto-resolve

import type { Army, Battle, Terrain } from './types';
import { BATTLE_CONFIG } from './config';
import { BattleRNG } from './rng';
import { calculateEffectiveStrength, clamp } from './formulas';
import { createBattle } from './engine';

// Auto-resolve result
export interface AutoResolveResult {
  winnerArmyId: string;
  attackerLosses: number;
  defenderLosses: number;
  attackerMoraleChange: number;
  defenderMoraleChange: number;
  narration: string[];
}

// Check if auto-resolve should trigger
// ratio = ES_útočník / ES_obranca
export function shouldAutoResolve(attacker: Army, defender: Army, terrain: Terrain): boolean {
  const esAttacker = calculateEffectiveStrength(attacker, true, terrain);
  const esDefender = calculateEffectiveStrength(defender, false, terrain);
  const ratio = esAttacker / esDefender;
  
  return ratio >= BATTLE_CONFIG.autoResolveRatio || ratio <= (1 / BATTLE_CONFIG.autoResolveRatio);
}

// Perform auto-resolve
export function autoResolve(
  attacker: Army,
  defender: Army,
  terrain: Terrain,
  warId: string,
  zupaId: string,
  startTick: number,
  seed?: string
): { battle: Battle; result: AutoResolveResult } {
  const battle = createBattle(warId, zupaId, terrain, attacker.id, defender.id, startTick, seed);
  battle.isAutoResolved = true;
  
  const rng = new BattleRNG(battle.seed);
  
  const esAttacker = calculateEffectiveStrength(attacker, true, terrain, rng);
  const esDefender = calculateEffectiveStrength(defender, false, terrain, rng);
  const ratio = esAttacker / esDefender;
  
  // Determine winner
  const winnerArmyId = ratio >= 1 ? attacker.id : defender.id;
  const isAttackerWinner = winnerArmyId === attacker.id;
  
  // Calculate losses
  // Winner: 10-20% losses
  // Loser: 40-60% losses
  const winnerLossesPercent = rng.range(0.10, 0.20);
  const loserLossesPercent = rng.range(0.40, 0.60);
  
  const attackerLosses = isAttackerWinner 
    ? Math.round(attacker.size * winnerLossesPercent)
    : Math.round(attacker.size * loserLossesPercent);
  
  const defenderLosses = isAttackerWinner 
    ? Math.round(defender.size * loserLossesPercent)
    : Math.round(defender.size * winnerLossesPercent);
  
  // Calculate morale changes
  // Winner: +10 to +20
  // Loser: -20 to -40
  const winnerMoraleChange = rng.int(10, 20);
  const loserMoraleChange = -rng.int(20, 40);
  
  const attackerMoraleChange = isAttackerWinner ? winnerMoraleChange : loserMoraleChange;
  const defenderMoraleChange = isAttackerWinner ? loserMoraleChange : winnerMoraleChange;
  
  // Create result
  const result: AutoResolveResult = {
    winnerArmyId,
    attackerLosses,
    defenderLosses,
    attackerMoraleChange,
    defenderMoraleChange,
    narration: [], // Will be filled by narration system
  };
  
  // Update battle
  battle.result = isAttackerWinner ? 'victory_decision' : 'victory_decision';
  battle.winnerArmyId = winnerArmyId;
  battle.currentPhase = 'finished';
  battle.rngState = rng.getState();
  
  // Create a single phase log for auto-resolve
  battle.phaseLogs = [{
    phase: 'attack',
    attackerAction: 'melee',
    defenderAction: 'melee',
    attackerLosses,
    defenderLosses,
    attackerMoraleChange,
    defenderMoraleChange,
    narration: result.narration,
  }];
  
  return { battle, result };
}

// Quick auto-resolve for AI vs AI battles
export function autoResolveAIvsAI(
  attacker: Army,
  defender: Army,
  terrain: Terrain,
  warId: string,
  zupaId: string,
  startTick: number
): Battle {
  const { battle } = autoResolve(attacker, defender, terrain, warId, zupaId, startTick);
  return battle;
}
