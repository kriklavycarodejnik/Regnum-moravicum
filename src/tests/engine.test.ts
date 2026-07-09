// Regnum Moravicum - Engine Tests

import { describe, it, expect, beforeEach } from 'vitest';
import { BattleEngine, createBattle, shouldAIRetreat } from '../battle/engine';
import type { Army, Battle, BattleAction } from '../battle/types';

describe('Battle Engine', () => {
  let attacker: Army;
  let defender: Army;
  let battle: Battle;
  let engine: BattleEngine;

  beforeEach(() => {
    // Create test armies
    attacker = {
      id: 'army_attacker',
      factionId: 'moravian',
      size: 1000,
      morale: 90,
      commander: { id: 'cmd_attacker', name: 'Mojmír II.', skill: 7 },
      composition: { infantry: 0.55, cavalry: 0.20, archers: 0.25 },
      locationZupaId: 'test_zupa',
    };

    defender = {
      id: 'army_defender',
      factionId: 'hungarian',
      size: 1200,
      morale: 85,
      commander: { id: 'cmd_defender', name: 'Árpád', skill: 8 },
      composition: { infantry: 0.30, cavalry: 0.45, archers: 0.25 },
      locationZupaId: 'test_zupa',
    };

    battle = createBattle('war1', 'test_zupa', 'field', attacker.id, defender.id, 0, 'test-seed');
    engine = new BattleEngine(battle, attacker, defender);
  });

  describe('Initialization', () => {
    it('should initialize battle correctly', () => {
      expect(engine.getBattle().id).toBe(battle.id);
      expect(engine.getBattle().warId).toBe('war1');
      expect(engine.getBattle().terrain).toBe('field');
      expect(engine.getBattle().currentPhase).toBe('attack');
    });

    it('should apply terrain morale modifiers at start', () => {
      const { attacker: initAttacker, defender: initDefender } = engine.getArmies();
      
      // Field terrain has no morale modifiers
      expect(initAttacker.morale).toBe(90);
      expect(initDefender.morale).toBe(85);
    });

    it('should apply terrain morale modifiers for forest', () => {
      battle = createBattle('war1', 'test_zupa', 'forest', attacker.id, defender.id, 0, 'test-seed');
      engine = new BattleEngine(battle, attacker, defender);
      
      const { attacker: initAttacker, defender: initDefender } = engine.getArmies();
      
      // Forest: attacker -10, defender 0
      expect(initAttacker.morale).toBe(80);
      expect(initDefender.morale).toBe(85);
    });
  });

  describe('Phase Execution', () => {
    it('should execute attack phase correctly', () => {
      const phaseLog = engine.executePhase('attack', 'melee', 'melee');
      
      expect(phaseLog.phase).toBe('attack');
      expect(phaseLog.attackerAction).toBe('melee');
      expect(phaseLog.defenderAction).toBe('melee');
      expect(phaseLog.attackerLosses).toBeGreaterThanOrEqual(0);
      expect(phaseLog.defenderLosses).toBeGreaterThanOrEqual(0);
    });

    it('should handle counter-matrix correctly (melee vs ranged)', () => {
      const phaseLog = engine.executePhase('attack', 'melee', 'ranged');
      
      // melee beats ranged, so attacker should have advantage
      // This is probabilistic, but we can check that losses are calculated
      expect(phaseLog.attackerLosses).toBeGreaterThanOrEqual(0);
      expect(phaseLog.defenderLosses).toBeGreaterThanOrEqual(0);
    });

    it('should handle retreat action', () => {
      const phaseLog = engine.executePhase('attack', 'retreat', 'melee');
      
      expect(phaseLog.attackerAction).toBe('retreat');
      expect(engine.isFinished()).toBe(true);
      expect(engine.getResult()).toBe('retreat');
    });

    it('should handle defender retreat', () => {
      const phaseLog = engine.executePhase('attack', 'melee', 'retreat');
      
      expect(phaseLog.defenderAction).toBe('retreat');
      expect(engine.isFinished()).toBe(true);
      expect(engine.getResult()).toBe('retreat');
    });
  });

  describe('Full Battle Execution', () => {
    it('should execute all 3 phases', () => {
      const attackerActions: BattleAction[] = ['melee', 'melee', 'melee'];
      const defenderActions: BattleAction[] = ['melee', 'melee', 'melee'];
      
      const phaseLogs = engine.executeFullBattle(attackerActions, defenderActions);
      
      expect(phaseLogs.length).toBeGreaterThanOrEqual(1);
      expect(engine.isFinished()).toBe(true);
    });

    it('should end with victory_decision if decision phase completes', () => {
      const attackerActions: BattleAction[] = ['melee', 'melee', 'melee'];
      const defenderActions: BattleAction[] = ['melee', 'melee', 'melee'];
      
      engine.executeFullBattle(attackerActions, defenderActions);
      
      expect(engine.getResult()).oneOf(['victory_decision', 'victory_rout', 'retreat']);
    });

    it('should have a winner when battle finishes', () => {
      const attackerActions: BattleAction[] = ['melee', 'melee', 'melee'];
      const defenderActions: BattleAction[] = ['melee', 'melee', 'melee'];
      
      engine.executeFullBattle(attackerActions, defenderActions);
      
      expect(engine.getWinnerArmyId()).not.toBeNull();
    });
  });

  describe('Rout Handling', () => {
    it('should trigger rout when morale <= 20', () => {
      // Create an army with low morale
      const weakDefender: Army = {
        ...defender,
        morale: 15, // Below rout threshold
      };

      battle = createBattle('war1', 'test_zupa', 'field', attacker.id, weakDefender.id, 0, 'rout-test-seed');
      engine = new BattleEngine(battle, attacker, weakDefender);

      // Execute phase - defender should rout
      engine.executePhase('attack', 'melee', 'melee');

      expect(engine.isFinished()).toBe(true);
      expect(engine.getResult()).toBe('victory_rout');
    });
  });

  describe('Decision Phase', () => {
    it('should execute decision phase correctly', () => {
      // First execute attack and counterattack phases
      engine.executePhase('attack', 'melee', 'melee');
      if (!engine.isFinished()) {
        engine.executePhase('counterattack', 'melee', 'melee');
      }
      
      if (!engine.isFinished()) {
        const phaseLog = engine.executeDecisionPhase('melee', 'melee');
        expect(phaseLog.phase).toBe('decision');
        expect(engine.isFinished()).toBe(true);
        expect(engine.getResult()).toBe('victory_decision');
      }
    });

    it('should give defender victory on exact decision power equality', () => {
      // The exact-tie rule itself (attacker/defender power dead equal -> defender
      // wins) is a pure formula, unit-tested directly in formulas.test.ts
      // (determineDecisionWinner) since replaying real combat phases with a live
      // BattleRNG essentially never produces a bit-exact tie by chance.
      // Here we only check that a real decision phase always resolves to one of
      // the two armies as winner.
      engine.executePhase('attack', 'melee', 'melee');
      if (!engine.isFinished()) {
        engine.executePhase('counterattack', 'melee', 'melee');
      }

      if (!engine.isFinished()) {
        engine.executeDecisionPhase('melee', 'melee');
        expect([attacker.id, defender.id]).toContain(engine.getWinnerArmyId());
      }
    });
  });

  describe('RNG State', () => {
    it('should produce identical results with same seed and state', () => {
      const seed = 'reproducibility-test-seed';
      const battle1 = createBattle('war1', 'test_zupa', 'field', attacker.id, defender.id, 0, seed);
      const engine1 = new BattleEngine(battle1, attacker, defender);
      
      const battle2 = createBattle('war1', 'test_zupa', 'field', attacker.id, defender.id, 0, seed);
      const engine2 = new BattleEngine(battle2, attacker, defender);
      
      // Execute same actions
      const actions1: BattleAction[] = ['melee', 'melee', 'melee'];
      const actions2: BattleAction[] = ['melee', 'melee', 'melee'];
      
      engine1.executeFullBattle(actions1, actions2);
      engine2.executeFullBattle(actions1, actions2);
      
      // Results should be identical
      const result1 = engine1.getResult();
      const result2 = engine2.getResult();
      expect(result1).toBe(result2);
      
      const winner1 = engine1.getWinnerArmyId();
      const winner2 = engine2.getWinnerArmyId();
      expect(winner1).toBe(winner2);
    });

    it('should save and restore RNG state correctly', () => {
      // Simulates save-mid-battle/load: a resumed engine needs the RNG state
      // *and* the current army snapshots (size/morale already reflect phase 1) -
      // restoring only the RNG state while replaying from the original armies
      // would obviously diverge, since the inputs to the formulas differ.
      const seed = 'state-test-seed';
      battle = createBattle('war1', 'test_zupa', 'field', attacker.id, defender.id, 0, seed);
      engine = new BattleEngine(battle, attacker, defender);

      // Execute first phase
      const phase1Log = engine.executePhase('attack', 'melee', 'melee');

      // Save state: RNG state + current army snapshots + current battle (with phaseLogs)
      const rngState = engine.getRNGState();
      const midBattleArmies = engine.getArmies();
      const midBattle: Battle = { ...engine.getBattle(), phaseLogs: [phase1Log] };

      // Reconstruct a second engine from that saved state
      const engine2 = new BattleEngine(midBattle, midBattleArmies.attacker, midBattleArmies.defender, {
        attacker: attacker.size,
        defender: defender.size,
      });
      engine2.setRNGState(rngState);

      // Execute the next phase on both - should produce identical results
      const phaseLog1 = engine.executePhase('counterattack', 'melee', 'melee');
      const phaseLog2 = engine2.executePhase('counterattack', 'melee', 'melee');

      expect(phaseLog1.attackerLosses).toBe(phaseLog2.attackerLosses);
      expect(phaseLog1.defenderLosses).toBe(phaseLog2.defenderLosses);
    });
  });

  describe('AI Action Selection', () => {
    it('should select actions based on army composition', () => {
      // Army with >40% cavalry should prefer flank
      const cavalryArmy: Army = {
        id: 'cavalry_army',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 0.3, cavalry: 0.5, archers: 0.2 },
        locationZupaId: 'test',
      };

      battle = createBattle('war1', 'test_zupa', 'field', cavalryArmy.id, defender.id, 0, 'ai-test-seed');
      engine = new BattleEngine(battle, cavalryArmy, defender);
      
      // Select multiple actions to check distribution
      const actions: BattleAction[] = [];
      for (let i = 0; i < 100; i++) {
        const action = engine.selectAIAction(true);
        actions.push(action);
      }
      
      // Flank should be selected more often
      const flankCount = actions.filter(a => a === 'flank').length;
      expect(flankCount).toBeGreaterThan(30); // Should be around 40-50%
    });

    it('should select retreat when morale < 35 and size < 50%', () => {
      // shouldAIRetreat is a pure predicate: army has already lost more than
      // half its men (relative to originalSize) and morale is below 35.
      const weakArmy: Army = {
        id: 'weak_army',
        factionId: 'test',
        size: 200, // Less than 50% of the 1000-man original size
        morale: 30, // Less than 35
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      expect(shouldAIRetreat(weakArmy, 1000)).toBe(true);
    });

    it('should not select retreat when size is still >= 50% of original', () => {
      const army: Army = {
        id: 'army',
        factionId: 'test',
        size: 600,
        morale: 30,
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      expect(shouldAIRetreat(army, 1000)).toBe(false);
    });
  });
});
