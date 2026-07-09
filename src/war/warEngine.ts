// Regnum Moravicum - War Engine

import type { War, ZupaWarState } from './types';
import type { Army, Battle } from '../battle/types';
import { createBattle, BattleEngine } from '../battle/engine';
import { autoResolveAIvsAI, shouldAutoResolve } from '../battle/autoResolve';
import { ZUPA_ADJACENCY } from './adjacency';

// War Engine
export class WarEngine {
  private wars: Map<string, War>;
  private armies: Map<string, Army>;
  private zupyWarState: Map<string, ZupaWarState>;
  private battles: Map<string, Battle>;
  private currentTick: number;

  constructor() {
    this.wars = new Map();
    this.armies = new Map();
    this.zupyWarState = new Map();
    this.battles = new Map();
    this.currentTick = 0;
  }

  // Initialize with existing data
  initialize(
    wars: War[],
    armies: Army[],
    zupyWarState: ZupaWarState[],
    battles: Battle[],
    currentTick: number
  ): void {
    this.wars.clear();
    this.armies.clear();
    this.zupyWarState.clear();
    this.battles.clear();
    
    for (const war of wars) {
      this.wars.set(war.id, { ...war });
    }
    for (const army of armies) {
      this.armies.set(army.id, { ...army });
    }
    for (const state of zupyWarState) {
      this.zupyWarState.set(state.zupaId, { ...state });
    }
    for (const battle of battles) {
      this.battles.set(battle.id, { ...battle });
    }
    this.currentTick = currentTick;
  }

  // Get current tick
  getCurrentTick(): number {
    return this.currentTick;
  }

  // Set current tick
  setCurrentTick(tick: number): void {
    this.currentTick = tick;
  }

  // Get war by ID
  getWar(warId: string): War | null {
    return this.wars.get(warId) || null;
  }

  // Get all wars
  getAllWars(): War[] {
    return Array.from(this.wars.values());
  }

  // Get army by ID
  getArmy(armyId: string): Army | null {
    return this.armies.get(armyId) || null;
  }

  // Get all armies
  getAllArmies(): Army[] {
    return Array.from(this.armies.values());
  }

  // Get zupa war state
  getZupaWarState(zupaId: string): ZupaWarState | null {
    return this.zupyWarState.get(zupaId) || null;
  }

  // Get all zupa war states
  getAllZupaWarStates(): ZupaWarState[] {
    return Array.from(this.zupyWarState.values());
  }

  // Get battle by ID
  getBattle(battleId: string): Battle | null {
    return this.battles.get(battleId) || null;
  }

  // Get all battles
  getAllBattles(): Battle[] {
    return Array.from(this.battles.values());
  }

  // Add war
  addWar(war: War): void {
    this.wars.set(war.id, { ...war });
  }

  // Add army
  addArmy(army: Army): void {
    this.armies.set(army.id, { ...army });
  }

  // Add zupa war state
  addZupaWarState(state: ZupaWarState): void {
    this.zupyWarState.set(state.zupaId, { ...state });
  }

  // Add battle
  addBattle(battle: Battle): void {
    this.battles.set(battle.id, { ...battle });
  }

  // Update war
  updateWar(warId: string, updates: Partial<War>): void {
    const war = this.wars.get(warId);
    if (war) {
      this.wars.set(warId, { ...war, ...updates });
    }
  }

  // Update army
  updateArmy(armyId: string, updates: Partial<Army>): void {
    const army = this.armies.get(armyId);
    if (army) {
      this.armies.set(armyId, { ...army, ...updates });
    }
  }

  // Update zupa war state
  updateZupaWarState(zupaId: string, updates: Partial<ZupaWarState>): void {
    const state = this.zupyWarState.get(zupaId);
    if (state) {
      this.zupyWarState.set(zupaId, { ...state, ...updates });
    }
  }

  // Update battle
  updateBattle(battleId: string, updates: Partial<Battle>): void {
    const battle = this.battles.get(battleId);
    if (battle) {
      this.battles.set(battleId, { ...battle, ...updates });
    }
  }

  // Remove army
  removeArmy(armyId: string): void {
    this.armies.delete(armyId);
  }

  // Remove battle
  removeBattle(battleId: string): void {
    this.battles.delete(battleId);
  }

  // 9.1 Check if zupa is liberated (objective expel completed)
  checkZupaLiberated(zupaId: string, warId: string): boolean {
    const war = this.wars.get(warId);
    if (!war) return false;

    const zupaState = this.zupyWarState.get(zupaId);
    if (!zupaState) return false;

    // Check if there are any enemy armies in the zupa
    const enemyFactionId = war.attackerFactionId === zupaState.controllerFactionId 
      ? war.defenderFactionId 
      : war.attackerFactionId;

    const hasEnemyArmy = Array.from(this.armies.values()).some(
      army => army.locationZupaId === zupaId && army.factionId === enemyFactionId
    );

    // If no enemy armies, zupa is liberated
    if (!hasEnemyArmy && zupaState.occupierFactionId === enemyFactionId) {
      // Update objective
      const objective = war.objectives.find(o => o.zupaId === zupaId && o.type === 'expel');
      if (objective) {
        objective.completed = true;
        this.updateWar(warId, { objectives: [...war.objectives] });
      }
      
      // Update zupa state
      this.updateZupaWarState(zupaId, { occupierFactionId: null });
      
      return true;
    }

    return false;
  }

  // 9.2 Retreat of defeated army
  retreatArmy(armyId: string, warId: string): boolean {
    const army = this.armies.get(armyId);
    if (!army) return false;

    const war = this.wars.get(warId);
    if (!war) return false;

    // Find adjacent zupy controlled or occupied by the same faction
    const adjacentZupy = ZUPA_ADJACENCY[army.locationZupaId] || [];
    const friendlyZupy = adjacentZupy.filter(zupaId => {
      const state = this.zupyWarState.get(zupaId);
      if (!state) return false;
      return state.controllerFactionId === army.factionId || 
             state.occupierFactionId === army.factionId;
    });

    if (friendlyZupy.length > 0) {
      // Move to first friendly zupa
      const targetZupa = friendlyZupy[0];
      this.updateArmy(armyId, { locationZupaId: targetZupa });
      return true;
    }

    // No friendly zupa available - army is destroyed
    this.removeArmy(armyId);
    return false;
  }

  // 9.3 Plienenie (looting during occupation)
  applyOccupationEffects(warId: string): void {
    const war = this.wars.get(warId);
    if (!war) return;

    // For each zupa, check if it's occupied
    for (const [, state] of this.zupyWarState) {
      if (state.occupierFactionId) {
        // TODO: Apply loyalty and gold penalties
        // This would be integrated with the main game state
        // For now, we'll just track that occupation is happening
      }
    }
  }

  // 9.4 Check war end conditions
  checkWarEnd(warId: string): { ended: boolean; result: 'victory' | 'defeat' | null } {
    const war = this.wars.get(warId);
    if (!war) return { ended: false, result: null };

    // Check if all objectives are completed
    const allObjectivesCompleted = war.objectives.every(o => o.completed);
    if (allObjectivesCompleted) {
      this.updateWar(warId, { result: 'victory' });
      return { ended: true, result: 'victory' };
    }

    // Check if player's army is destroyed
    const playerArmy = Array.from(this.armies.values()).find(
      a => a.factionId === war.defenderFactionId // Assuming player is defender
    );
    if (!playerArmy) {
      this.updateWar(warId, { result: 'defeat' });
      return { ended: true, result: 'defeat' };
    }

    // Check timeout
    if (this.currentTick >= war.startTick + war.timeoutTicks) {
      this.updateWar(warId, { result: 'defeat' });
      return { ended: true, result: 'defeat' };
    }

    return { ended: false, result: null };
  }

  // Start a new battle
  startBattle(
    warId: string,
    zupaId: string,
    terrain: import('../battle/types').Terrain,
    attackerArmyId: string,
    defenderArmyId: string
  ): Battle | null {
    const war = this.wars.get(warId);
    if (!war) return null;

    const attacker = this.armies.get(attackerArmyId);
    const defender = this.armies.get(defenderArmyId);
    if (!attacker || !defender) return null;

    // Check if auto-resolve should trigger
    if (shouldAutoResolve(attacker, defender, terrain)) {
      // For AI vs AI, always auto-resolve
      const isAIvsAI = true; // TODO: Check if both are AI
      if (isAIvsAI) {
        const battle = autoResolveAIvsAI(attacker, defender, terrain, warId, zupaId, this.currentTick);
        this.addBattle(battle);
        return battle;
      }
    }

    // Create new battle
    const battle = createBattle(
      warId,
      zupaId,
      terrain,
      attackerArmyId,
      defenderArmyId,
      this.currentTick
    );
    
    this.addBattle(battle);
    return battle;
  }

  // Resolve a battle
  resolveBattle(battleId: string, attackerActions: import('../battle/types').BattleAction[], defenderActions: import('../battle/types').BattleAction[]): Battle | null {
    const battle = this.battles.get(battleId);
    if (!battle) return null;

    const attacker = this.armies.get(battle.attackerArmyId);
    const defender = this.armies.get(battle.defenderArmyId);
    if (!attacker || !defender) return null;

    // Create battle engine
    const engine = new BattleEngine(battle, attacker, defender);
    
    // Execute full battle
    const phaseLogs = engine.executeFullBattle(attackerActions, defenderActions);
    
    // Update battle
    const updatedBattle = engine.getBattle();
    updatedBattle.phaseLogs = [...updatedBattle.phaseLogs, ...phaseLogs];
    updatedBattle.rngState = engine.getRNGState();
    
    this.updateBattle(battleId, updatedBattle);
    
    // Update armies based on battle result
    this.updateArmiesAfterBattle(battleId, engine);
    
    return updatedBattle;
  }

  // Update armies after battle
  private updateArmiesAfterBattle(battleId: string, engine: BattleEngine): void {
    const battle = this.battles.get(battleId);
    if (!battle) return;

    const attacker = this.armies.get(battle.attackerArmyId);
    const defender = this.armies.get(battle.defenderArmyId);
    if (!attacker || !defender) return;

    const { attacker: updatedAttacker, defender: updatedDefender } = engine.getArmies();
    
    // Update army sizes and morale
    this.updateArmy(battle.attackerArmyId, {
      size: updatedAttacker.size,
      morale: updatedAttacker.morale,
    });
    
    this.updateArmy(battle.defenderArmyId, {
      size: updatedDefender.size,
      morale: updatedDefender.morale,
    });

    // Handle retreat or destruction
    if (battle.result === 'retreat') {
      const loserArmyId = battle.winnerArmyId === battle.attackerArmyId 
        ? battle.defenderArmyId 
        : battle.attackerArmyId;
      this.retreatArmy(loserArmyId, battle.warId);
    } else if (battle.result === 'victory_rout' || battle.result === 'victory_decision') {
      const loserArmyId = battle.winnerArmyId === battle.attackerArmyId 
        ? battle.defenderArmyId 
        : battle.attackerArmyId;
      
      // Check if army is destroyed (size <= 0)
      const loserArmy = this.armies.get(loserArmyId);
      if (loserArmy && loserArmy.size <= 0) {
        this.removeArmy(loserArmyId);
      } else {
        this.retreatArmy(loserArmyId, battle.warId);
      }
    }

    // Check if zupa is liberated
    this.checkZupaLiberated(battle.zupaId, battle.warId);
    
    // Check war end conditions
    this.checkWarEnd(battle.warId);
  }

  // Get adjacent zupy
  getAdjacentZupy(zupaId: string): string[] {
    return ZUPA_ADJACENCY[zupaId] || [];
  }

  // Get zupa adjacency matrix
  getAdjacencyMatrix(): Record<string, string[]> {
    return { ...ZUPA_ADJACENCY };
  }
}

// Singleton instance
export const warEngine = new WarEngine();
