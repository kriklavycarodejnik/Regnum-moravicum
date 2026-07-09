// Regnum Moravicum - Battle Engine

import type {
  Army,
  Battle,
  BattleAction,
  BattlePhaseType,
  BattleResult,
  Commander,
  PhaseLog,
  PostRoutAction,
  Terrain,
} from './types';
import { BATTLE_CONFIG } from './config';
import { BattleRNG } from './rng';
import {
  calculateEffectiveStrength,
  evaluatePhase,
  evaluateDecisionPhase,
  applyTerrainMoraleModifiers,
  checkRout,
  applyRoutLosses,
  applyRetreatLosses,
  applyDecisionLosses,
} from './formulas';

// AI action selection (6.6)
function selectAIAction(army: Army, rng: BattleRNG): BattleAction {
  // AI volí akciu podľa zloženia armády
  const weights: Record<BattleAction, number> = {
    melee: 1.0,
    ranged: 1.0,
    flank: 1.0,
    retreat: 0,
  };

  // Jazda > 40% → preferuje flank váhou 2×
  if ((army.composition['cavalry'] || 0) > 0.4) {
    weights.flank = 2.0;
  }

  // Lukostrelci > 30% → ranged 2×
  if ((army.composition['archers'] || 0) > 0.3) {
    weights.ranged = 2.0;
  }

  // AI zvolí retreat, ak morale < 35 a size < 50% pôvodného stavu
  // Note: We don't have original size here, so we'll handle this in the engine

  const actions: { value: BattleAction; weight: number }[] = Object.entries(weights)
    .map(([action, weight]) => ({ value: action as BattleAction, weight }));

  return rng.weighted(actions);
}

// Check if AI should retreat
function shouldAIRetreat(army: Army, originalSize: number): boolean {
  return army.morale < 35 && army.size < originalSize * 0.5;
}

// Create a deep copy of an army
function cloneArmy(army: Army): Army {
  return {
    ...army,
    commander: { ...army.commander },
    composition: { ...army.composition },
  };
}

// Battle Engine
export class BattleEngine {
  private battle: Battle;
  private attacker: Army;
  private defender: Army;
  private rng: BattleRNG;
  private originalAttackerSize: number;
  private originalDefenderSize: number;

  constructor(battle: Battle, attacker: Army, defender: Army) {
    this.battle = { ...battle };
    this.attacker = cloneArmy(attacker);
    this.defender = cloneArmy(defender);
    this.originalAttackerSize = attacker.size;
    this.originalDefenderSize = defender.size;
    
    // Initialize RNG
    this.rng = new BattleRNG(battle.seed, battle.rngState || undefined);
    
    // Apply terrain morale modifiers at battle start
    const moraleModifiers = applyTerrainMoraleModifiers(
      this.attacker,
      this.defender,
      battle.terrain
    );
    this.attacker.morale = moraleModifiers.attackerMorale;
    this.defender.morale = moraleModifiers.defenderMorale;
  }

  // Get current battle state
  getBattle(): Battle {
    return { ...this.battle };
  }

  // Get current armies
  getArmies(): { attacker: Army; defender: Army } {
    return { attacker: cloneArmy(this.attacker), defender: cloneArmy(this.defender) };
  }

  // Get RNG state for saving
  getRNGState(): object {
    return this.rng.getState();
  }

  // Set RNG state for loading
  setRNGState(state: object): void {
    this.rng = new BattleRNG(this.battle.seed, state);
  }

  // Select action for AI
  selectAIAction(isAttacker: boolean): BattleAction {
    const army = isAttacker ? this.attacker : this.defender;
    const originalSize = isAttacker ? this.originalAttackerSize : this.originalDefenderSize;
    
    // Check if AI should retreat
    if (shouldAIRetreat(army, originalSize)) {
      return 'retreat';
    }
    
    return selectAIAction(army, this.rng);
  }

  // Execute a single phase
  executePhase(
    phase: BattlePhaseType,
    attackerAction: BattleAction,
    defenderAction: BattleAction
  ): PhaseLog {
    // Handle retreat
    if (attackerAction === 'retreat' || defenderAction === 'retreat') {
      return this.handleRetreat(phase, attackerAction, defenderAction);
    }

    // Evaluate phase
    const result = evaluatePhase(
      this.attacker,
      this.defender,
      phase,
      attackerAction,
      defenderAction,
      this.battle.terrain,
      this.rng
    );

    // Apply losses
    this.attacker.size -= result.attackerLosses;
    this.defender.size -= result.defenderLosses;
    
    // Ensure size doesn't go below 0
    this.attacker.size = Math.max(0, this.attacker.size);
    this.defender.size = Math.max(0, this.defender.size);

    // Apply morale changes
    this.attacker.morale += result.attackerMoraleChange;
    this.defender.morale += result.defenderMoraleChange;
    
    // Clamp morale to 0-100
    this.attacker.morale = Math.max(0, Math.min(100, this.attacker.morale));
    this.defender.morale = Math.max(0, Math.min(100, this.defender.morale));

    // Check for rout after this phase
    const attackerRout = checkRout(this.attacker.morale);
    const defenderRout = checkRout(this.defender.morale);

    if (attackerRout || defenderRout) {
      return this.handleRout(phase, attackerAction, defenderAction, attackerRout, defenderRout);
    }

    // Create phase log
    const phaseLog: PhaseLog = {
      phase,
      attackerAction,
      defenderAction,
      attackerLosses: result.attackerLosses,
      defenderLosses: result.defenderLosses,
      attackerMoraleChange: result.attackerMoraleChange,
      defenderMoraleChange: result.defenderMoraleChange,
      narration: [], // Will be filled by narration system
    };

    return phaseLog;
  }

  // Handle retreat
  private handleRetreat(
    phase: BattlePhaseType,
    attackerAction: BattleAction,
    defenderAction: BattleAction
  ): PhaseLog {
    const isAttackerRetreating = attackerAction === 'retreat';
    const retreatingArmy = isAttackerRetreating ? this.attacker : this.defender;
    const otherArmy = isAttackerRetreating ? this.defender : this.attacker;

    // Apply retreat losses
    const retreatLosses = applyRetreatLosses(retreatingArmy.size);
    retreatingArmy.size -= retreatLosses;
    retreatingArmy.size = Math.max(0, retreatingArmy.size);

    // Apply morale penalty
    retreatingArmy.morale -= BATTLE_CONFIG.retreatMoralePenalty;
    retreatingArmy.morale = Math.max(0, Math.min(100, retreatingArmy.morale));

    // Determine post-retreat action (pursue or regroup)
    // For now, we'll assume the other side pursues (AI decision would go here)
    const postRoutAction: PostRoutAction = 'pursue'; // TODO: Make this configurable
    
    if (postRoutAction === 'pursue') {
      // Additional losses for retreating army
      const additionalLosses = applyRoutLosses(retreatingArmy.size, 'pursue');
      retreatingArmy.size -= additionalLosses;
      retreatingArmy.size = Math.max(0, retreatingArmy.size);
      
      // Morale bonus for pursuer
      otherArmy.morale += 5; // Half of pursueMoraleBonus
      otherArmy.morale = Math.max(0, Math.min(100, otherArmy.morale));
    }

    // Battle ends with retreat
    const winnerArmyId = isAttackerRetreating ? this.battle.defenderArmyId : this.battle.attackerArmyId;
    
    this.battle.currentPhase = 'finished';
    this.battle.result = 'retreat';
    this.battle.winnerArmyId = winnerArmyId;

    const phaseLog: PhaseLog = {
      phase,
      attackerAction,
      defenderAction,
      attackerLosses: isAttackerRetreating ? retreatLosses + (postRoutAction === 'pursue' ? applyRoutLosses(this.attacker.size, 'pursue') : 0) : 0,
      defenderLosses: !isAttackerRetreating ? retreatLosses + (postRoutAction === 'pursue' ? applyRoutLosses(this.defender.size, 'pursue') : 0) : 0,
      attackerMoraleChange: isAttackerRetreating ? -BATTLE_CONFIG.retreatMoralePenalty : (postRoutAction === 'pursue' ? 5 : 0),
      defenderMoraleChange: !isAttackerRetreating ? -BATTLE_CONFIG.retreatMoralePenalty : (postRoutAction === 'pursue' ? 5 : 0),
      narration: [],
    };

    return phaseLog;
  }

  // Handle rout
  private handleRout(
    phase: BattlePhaseType,
    attackerAction: BattleAction,
    defenderAction: BattleAction,
    attackerRout: boolean,
    defenderRout: boolean
  ): PhaseLog {
    // If both rout in the same phase, the one with lower morale routs
    // If morale is equal, attacker routs
    if (attackerRout && defenderRout) {
      if (this.attacker.morale <= this.defender.morale) {
        defenderRout = false; // Only attacker routs
      } else {
        attackerRout = false; // Only defender routs
      }
    }

    const routingArmy = attackerRout ? this.attacker : this.defender;
    const winningArmy = attackerRout ? this.defender : this.attacker;
    const isAttackerRouting = attackerRout;

    // Determine post-rout action (pursue or regroup)
    // For now, we'll assume the winner pursues (AI decision would go here)
    const postRoutAction: PostRoutAction = 'pursue'; // TODO: Make this configurable

    // Apply rout losses
    const routLosses = applyRoutLosses(routingArmy.size, postRoutAction);
    routingArmy.size -= routLosses;
    routingArmy.size = Math.max(0, routingArmy.size);

    // Apply morale bonus for pursuer
    if (postRoutAction === 'pursue') {
      winningArmy.morale += BATTLE_CONFIG.pursueMoraleBonus;
      winningArmy.morale = Math.max(0, Math.min(100, winningArmy.morale));
    }

    // Battle ends with victory_rout
    const winnerArmyId = isAttackerRouting ? this.battle.defenderArmyId : this.battle.attackerArmyId;

    this.battle.currentPhase = 'finished';
    this.battle.result = 'victory_rout';
    this.battle.winnerArmyId = winnerArmyId;

    const phaseLog: PhaseLog = {
      phase,
      attackerAction,
      defenderAction,
      attackerLosses: isAttackerRouting ? routLosses : 0,
      defenderLosses: !isAttackerRouting ? routLosses : 0,
      attackerMoraleChange: isAttackerRouting ? 0 : (postRoutAction === 'pursue' ? BATTLE_CONFIG.pursueMoraleBonus : 0),
      defenderMoraleChange: !isAttackerRouting ? 0 : (postRoutAction === 'pursue' ? BATTLE_CONFIG.pursueMoraleBonus : 0),
      narration: [],
    };

    return phaseLog;
  }

  // Execute decision phase (phase 3)
  executeDecisionPhase(
    attackerAction: BattleAction,
    defenderAction: BattleAction
  ): PhaseLog {
    // Evaluate decision
    const result = evaluateDecisionPhase(
      this.attacker,
      this.defender,
      attackerAction,
      defenderAction,
      this.battle.terrain,
      this.rng
    );

    const winner = result.winner;
    const loser = winner === 'attacker' ? 'defender' : 'attacker';

    // Apply losses to loser
    const loserArmy = loser === 'attacker' ? this.attacker : this.defender;
    const winnerArmy = winner === 'attacker' ? this.attacker : this.defender;

    const loserLosses = applyDecisionLosses(loserArmy.size);
    loserArmy.size -= loserLosses;
    loserArmy.size = Math.max(0, loserArmy.size);

    // Apply morale changes
    loserArmy.morale += BATTLE_CONFIG.decisionLoserMorale;
    winnerArmy.morale += BATTLE_CONFIG.decisionWinnerMorale;
    
    // Clamp morale
    loserArmy.morale = Math.max(0, Math.min(100, loserArmy.morale));
    winnerArmy.morale = Math.max(0, Math.min(100, winnerArmy.morale));

    // Battle ends with victory_decision
    const winnerArmyId = winner === 'attacker' ? this.battle.attackerArmyId : this.battle.defenderArmyId;

    this.battle.currentPhase = 'finished';
    this.battle.result = 'victory_decision';
    this.battle.winnerArmyId = winnerArmyId;

    const phaseLog: PhaseLog = {
      phase: 'decision',
      attackerAction,
      defenderAction,
      attackerLosses: loser === 'attacker' ? loserLosses : 0,
      defenderLosses: loser === 'defender' ? loserLosses : 0,
      attackerMoraleChange: winner === 'attacker' ? BATTLE_CONFIG.decisionWinnerMorale : BATTLE_CONFIG.decisionLoserMorale,
      defenderMoraleChange: winner === 'defender' ? BATTLE_CONFIG.decisionWinnerMorale : BATTLE_CONFIG.decisionLoserMorale,
      narration: [],
    };

    return phaseLog;
  }

  // Execute full battle (all 3 phases)
  executeFullBattle(
    attackerActions: BattleAction[],
    defenderActions: BattleAction[]
  ): PhaseLog[] {
    const phaseLogs: PhaseLog[] = [];

    // Phase 1: Attack
    if (this.battle.currentPhase === 'attack' || this.battle.currentPhase === null || this.battle.currentPhase === undefined) {
      const phaseLog = this.executePhase('attack', attackerActions[0], defenderActions[0]);
      phaseLogs.push(phaseLog);
      this.battle.phaseLogs = [...this.battle.phaseLogs, phaseLog];
      
      if (this.battle.currentPhase === 'finished') {
        return phaseLogs;
      }
    }

    // Phase 2: Counterattack
    if (this.battle.currentPhase === 'counterattack' || this.battle.currentPhase === 'attack') {
      this.battle.currentPhase = 'counterattack';
      const phaseLog = this.executePhase('counterattack', attackerActions[1], defenderActions[1]);
      phaseLogs.push(phaseLog);
      this.battle.phaseLogs = [...this.battle.phaseLogs, phaseLog];
      
      if (this.battle.currentPhase === 'finished') {
        return phaseLogs;
      }
    }

    // Phase 3: Decision
    if (this.battle.currentPhase === 'decision' || this.battle.currentPhase === 'counterattack') {
      this.battle.currentPhase = 'decision';
      const phaseLog = this.executeDecisionPhase(attackerActions[2], defenderActions[2]);
      phaseLogs.push(phaseLog);
      this.battle.phaseLogs = [...this.battle.phaseLogs, phaseLog];
    }

    return phaseLogs;
  }

  // Execute next phase (for turn-based gameplay)
  executeNextPhase(attackerAction: BattleAction, defenderAction: BattleAction): PhaseLog | null {
    if (this.battle.currentPhase === 'finished') {
      return null;
    }

    const currentPhase = this.battle.currentPhase as BattlePhaseType || 'attack';

    if (currentPhase === 'attack' || currentPhase === 'counterattack') {
      const phaseLog = this.executePhase(currentPhase, attackerAction, defenderAction);
      this.battle.phaseLogs = [...this.battle.phaseLogs, phaseLog];
      
      // Move to next phase
      if (this.battle.currentPhase !== 'finished') {
        if (currentPhase === 'attack') {
          this.battle.currentPhase = 'counterattack';
        } else if (currentPhase === 'counterattack') {
          this.battle.currentPhase = 'decision';
        }
      }
      
      return phaseLog;
    } else if (currentPhase === 'decision') {
      const phaseLog = this.executeDecisionPhase(attackerAction, defenderAction);
      this.battle.phaseLogs = [...this.battle.phaseLogs, phaseLog];
      return phaseLog;
    }

    return null;
  }

  // Get current phase
  getCurrentPhase(): BattlePhaseType | 'finished' {
    return this.battle.currentPhase;
  }

  // Check if battle is finished
  isFinished(): boolean {
    return this.battle.currentPhase === 'finished';
  }

  // Get battle result
  getResult(): BattleResult {
    return this.battle.result;
  }

  // Get winner army ID
  getWinnerArmyId(): string | null {
    return this.battle.winnerArmyId;
  }
}

// Helper to create a new battle
export function createBattle(
  warId: string,
  zupaId: string,
  terrain: Terrain,
  attackerArmyId: string,
  defenderArmyId: string,
  startTick: number,
  seed?: string
): Battle {
  const battleSeed = seed || `${warId}:${attackerArmyId}:${defenderArmyId}:${startTick}`;
  
  return {
    id: `${warId}:${zupaId}:${startTick}`,
    warId,
    zupaId,
    terrain,
    attackerArmyId,
    defenderArmyId,
    currentPhase: 'attack',
    phaseLogs: [],
    result: null,
    winnerArmyId: null,
    isAutoResolved: false,
    startTick,
    seed: battleSeed,
    rngState: null,
  };
}
