// Regnum Moravicum - Auto-resolve Tests

import { describe, it, expect, beforeEach } from 'vitest';
import { shouldAutoResolve, autoResolve, autoResolveAIvsAI } from '../battle/autoResolve';
import { createBattle } from '../battle/engine';
import { BattleRNG } from '../battle/rng';
import type { Army } from '../battle/types';

describe('Auto-resolve', () => {
  let strongAttacker: Army;
  let weakDefender: Army;
  let balancedAttacker: Army;
  let balancedDefender: Army;

  beforeEach(() => {
    // Strong attacker (ratio > 2.0)
    strongAttacker = {
      id: 'strong_attacker',
      factionId: 'moravian',
      size: 2000,
      morale: 100,
      commander: { id: 'cmd1', name: 'Strong', skill: 10 },
      composition: { infantry: 0.5, cavalry: 0.3, archers: 0.2 },
      locationZupaId: 'test',
    };

    weakDefender = {
      id: 'weak_defender',
      factionId: 'hungarian',
      size: 500,
      morale: 50,
      commander: { id: 'cmd2', name: 'Weak', skill: 0 },
      composition: { infantry: 1.0, cavalry: 0, archers: 0 },
      locationZupaId: 'test',
    };

    // Balanced armies (ratio ~1.0)
    balancedAttacker = {
      id: 'balanced_attacker',
      factionId: 'moravian',
      size: 1000,
      morale: 80,
      commander: { id: 'cmd3', name: 'Balanced', skill: 5 },
      composition: { infantry: 0.5, cavalry: 0.3, archers: 0.2 },
      locationZupaId: 'test',
    };

    balancedDefender = {
      id: 'balanced_defender',
      factionId: 'hungarian',
      size: 1000,
      morale: 80,
      commander: { id: 'cmd4', name: 'Balanced', skill: 5 },
      composition: { infantry: 0.5, cavalry: 0.3, archers: 0.2 },
      locationZupaId: 'test',
    };
  });

  describe('shouldAutoResolve', () => {
    it('should return true when attacker ES is >= 2x defender ES', () => {
      const result = shouldAutoResolve(strongAttacker, weakDefender, 'field');
      expect(result).toBe(true);
    });

    it('should return true when defender ES is >= 2x attacker ES', () => {
      const result = shouldAutoResolve(weakDefender, strongAttacker, 'field');
      expect(result).toBe(true);
    });

    it('should return false when ES ratio is between 0.5 and 2.0', () => {
      const result = shouldAutoResolve(balancedAttacker, balancedDefender, 'field');
      expect(result).toBe(false);
    });

    it('should return true exactly at ratio 2.0', () => {
      // Create armies with exactly 2.0 ratio
      const attacker2x: Army = {
        ...balancedAttacker,
        id: 'attacker_2x',
        size: 2000,
      };
      const defenderHalf: Army = {
        ...balancedDefender,
        id: 'defender_half',
        size: 1000,
      };

      const result = shouldAutoResolve(attacker2x, defenderHalf, 'field');
      expect(result).toBe(true);
    });

    it('should return true exactly at ratio 0.5', () => {
      // Create armies with exactly 0.5 ratio
      const attackerHalf: Army = {
        ...balancedAttacker,
        id: 'attacker_half',
        size: 500,
      };
      const defender2x: Army = {
        ...balancedDefender,
        id: 'defender_2x',
        size: 2000,
      };

      const result = shouldAutoResolve(attackerHalf, defender2x, 'field');
      expect(result).toBe(true);
    });
  });

  describe('autoResolve', () => {
    it('should return attacker as winner when attacker has higher ES', () => {
      const { result } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      expect(result.winnerArmyId).toBe(strongAttacker.id);
    });

    it('should return defender as winner when defender has higher ES', () => {
      const { result } = autoResolve(
        weakDefender, strongAttacker, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      expect(result.winnerArmyId).toBe(strongAttacker.id);
    });

    it('should apply correct loss percentages', () => {
      const { result } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      // Winner should lose 10-20%
      const winnerLosses = result.winnerArmyId === strongAttacker.id 
        ? result.attackerLosses 
        : result.defenderLosses;
      const winnerSize = result.winnerArmyId === strongAttacker.id 
        ? strongAttacker.size 
        : weakDefender.size;
      
      const winnerLossPercentage = winnerLosses / winnerSize;
      expect(winnerLossPercentage).toBeGreaterThanOrEqual(0.10);
      expect(winnerLossPercentage).toBeLessThanOrEqual(0.20);
      
      // Loser should lose 40-60%
      const loserLosses = result.winnerArmyId === strongAttacker.id 
        ? result.defenderLosses 
        : result.attackerLosses;
      const loserSize = result.winnerArmyId === strongAttacker.id 
        ? weakDefender.size 
        : strongAttacker.size;
      
      const loserLossPercentage = loserLosses / loserSize;
      expect(loserLossPercentage).toBeGreaterThanOrEqual(0.40);
      expect(loserLossPercentage).toBeLessThanOrEqual(0.60);
    });

    it('should apply correct morale changes', () => {
      const { result } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      // Winner should gain 10-20 morale
      const winnerMoraleChange = result.winnerArmyId === strongAttacker.id 
        ? result.attackerMoraleChange 
        : result.defenderMoraleChange;
      
      expect(winnerMoraleChange).toBeGreaterThanOrEqual(10);
      expect(winnerMoraleChange).toBeLessThanOrEqual(20);
      
      // Loser should lose 20-40 morale
      const loserMoraleChange = result.winnerArmyId === strongAttacker.id 
        ? result.defenderMoraleChange 
        : result.attackerMoraleChange;
      
      expect(loserMoraleChange).toBeLessThanOrEqual(-20);
      expect(loserMoraleChange).toBeGreaterThanOrEqual(-40);
    });

    it('should mark battle as auto-resolved', () => {
      const { battle } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      expect(battle.isAutoResolved).toBe(true);
    });

    it('should finish the battle', () => {
      const { battle } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      expect(battle.currentPhase).toBe('finished');
      expect(battle.result).toBe('victory_decision');
    });

    it('should save RNG state', () => {
      const { battle } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'test-seed'
      );
      
      expect(battle.rngState).not.toBeNull();
    });
  });

  describe('autoResolveAIvsAI', () => {
    it('should always auto-resolve for AI vs AI battles', () => {
      const battle = autoResolveAIvsAI(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0
      );
      
      expect(battle.isAutoResolved).toBe(true);
      expect(battle.currentPhase).toBe('finished');
    });

    it('should produce deterministic results with same seed', () => {
      const battle1 = autoResolveAIvsAI(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'deterministic-seed'
      );
      
      const battle2 = autoResolveAIvsAI(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'deterministic-seed'
      );
      
      expect(battle1.winnerArmyId).toBe(battle2.winnerArmyId);
    });
  });

  describe('Reproducibility', () => {
    it('should produce identical results with same seed', () => {
      const seed = 'reproducibility-seed';
      
      const { result: result1 } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, seed
      );
      
      const { result: result2 } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, seed
      );
      
      expect(result1.winnerArmyId).toBe(result2.winnerArmyId);
      expect(result1.attackerLosses).toBe(result2.attackerLosses);
      expect(result1.defenderLosses).toBe(result2.defenderLosses);
      expect(result1.attackerMoraleChange).toBe(result2.attackerMoraleChange);
      expect(result1.defenderMoraleChange).toBe(result2.defenderMoraleChange);
    });

    it('should produce different results with different seeds', () => {
      const { result: result1 } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'seed1'
      );
      
      const { result: result2 } = autoResolve(
        strongAttacker, weakDefender, 'field', 'war1', 'test_zupa', 0, 'seed2'
      );
      
      // Results should be different (at least one field should differ)
      expect(result1).not.toEqual(result2);
    });
  });
});
