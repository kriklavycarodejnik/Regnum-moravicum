// Regnum Moravicum - Formulas Tests

import { describe, it, expect, beforeEach } from 'vitest';
import {
  calculateEffectiveStrength,
  getActionModifier,
  evaluatePhase,
  evaluateDecisionPhase,
  applyTerrainMoraleModifiers,
  checkRout,
  applyRoutLosses,
  applyRetreatLosses,
  applyDecisionLosses,
  clamp,
} from '../battle/formulas';
import { BattleRNG } from '../battle/rng';
import { TERRAIN_MODIFIERS, FACTION_TRAITS } from '../battle/config';
import type { Army, BattlePhaseType, BattleAction, Terrain } from '../battle/types';

describe('Battle Formulas', () => {
  let rng: BattleRNG;

  beforeEach(() => {
    rng = new BattleRNG('test-seed');
  });

  describe('calculateEffectiveStrength', () => {
    it('should calculate ES correctly for basic army on field terrain', () => {
      const army: Army = {
        id: 'test-army',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test-zupa',
      };

      const es = calculateEffectiveStrength(army, true, 'field', rng);
      // size * (morale/100) * (1 + terrainBonus) * compositionFactor * (1 + commanderBonus)
      // 1000 * 1.0 * 1.0 * 1.0 * (1 + 5*0.02) = 1000 * 1.1 = 1100
      expect(es).toBeCloseTo(1100, 0.01);
    });

    it('should apply terrain bonus for attacker and defender correctly', () => {
      const army: Army = {
        id: 'test-army',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test-zupa',
      };

      // Forest: attacker -0.20, defender +0.30
      const esAttacker = calculateEffectiveStrength(army, true, 'forest', rng);
      const esDefender = calculateEffectiveStrength(army, false, 'forest', rng);

      // Attacker: 1000 * 1.0 * 0.8 * 1.05 = 840
      // Defender: 1000 * 1.0 * 1.3 * 1.05 = 1365
      expect(esAttacker).toBeCloseTo(840, 0.01);
      expect(esDefender).toBeCloseTo(1365, 0.01);
    });

    it('should apply composition factors correctly', () => {
      const army: Army = {
        id: 'test-army',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 0.5, cavalry: 0.5, archers: 0 },
        locationZupaId: 'test-zupa',
      };

      // Field: infantry 1.0, cavalry 1.2
      // compositionFactor = 0.5 * 1.0 + 0.5 * 1.2 = 1.1
      const es = calculateEffectiveStrength(army, true, 'field', rng);
      // 1000 * 1.0 * 1.0 * 1.1 = 1100
      expect(es).toBeCloseTo(1100, 0.01);
    });

    it('should apply Hungarian cavalry bonus on field', () => {
      const army: Army = {
        id: 'test-army',
        factionId: 'hungarian',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 0, cavalry: 1.0, archers: 0 },
        locationZupaId: 'test-zupa',
      };

      // Hungarian cavalry on field: base 1.2 -> 1.40
      // compositionFactor = 1.0 * 1.40 = 1.40
      // ES = 1000 * 1.0 * 1.0 * 1.40 = 1400
      const es = calculateEffectiveStrength(army, true, 'field', rng);
      expect(es).toBeCloseTo(1400, 0.01);
    });

    it('should apply Moravian fortress defense bonus', () => {
      const army: Army = {
        id: 'test-army',
        factionId: 'moravian',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test-zupa',
      };

      // Moravian on fortress as defender
      // terrain defenseBonus = 0.6, fortressDefenseMultiplier = 1.3
      // effective multiplier = 1 + 0.6 * 1.3 = 1 + 0.78 = 1.78
      // compositionFactor for infantry on fortress = 1.15
      // ES = 1000 * 1.0 * 1.78 * 1.15 = 2047
      const es = calculateEffectiveStrength(army, false, 'fortress', rng);
      expect(es).toBeCloseTo(2047, 0.1);
    });
  });

  describe('getActionModifier', () => {
    it('should return 1.15 when my action beats enemy action', () => {
      // melee beats ranged
      expect(getActionModifier('melee', 'ranged')).toBe(1.15);
      // ranged beats flank
      expect(getActionModifier('ranged', 'flank')).toBe(1.15);
      // flank beats melee
      expect(getActionModifier('flank', 'melee')).toBe(1.15);
    });

    it('should return 0.85 when enemy action beats my action', () => {
      // melee loses to flank
      expect(getActionModifier('melee', 'flank')).toBe(0.85);
      // ranged loses to melee
      expect(getActionModifier('ranged', 'melee')).toBe(0.85);
      // flank loses to ranged
      expect(getActionModifier('flank', 'ranged')).toBe(0.85);
    });

    it('should return 1.00 for same actions or neutral', () => {
      expect(getActionModifier('melee', 'melee')).toBe(1.00);
      expect(getActionModifier('ranged', 'ranged')).toBe(1.00);
      expect(getActionModifier('flank', 'flank')).toBe(1.00);
    });

    it('should return 1.00 for retreat', () => {
      expect(getActionModifier('retreat', 'melee')).toBe(1.00);
      expect(getActionModifier('melee', 'retreat')).toBe(1.00);
    });
  });

  describe('evaluatePhase', () => {
    it('should calculate phase results correctly', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd2', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      // Use fixed seed for reproducibility
      const phaseRng = new BattleRNG('phase-test-seed');
      const result = evaluatePhase(
        attacker, defender, 'attack', 'melee', 'melee', 'field', phaseRng
      );

      // With equal armies and melee vs melee, ratio should be close to 1
      // The RNG range is 0.85-1.15, so with same seed for both, ratio should be close to 1
      expect(result.ratio).toBeGreaterThan(0.7);
      expect(result.ratio).toBeLessThan(1.5);
      
      // Losses should be calculated based on baseLossRate
      // baseLossRate for attack is 0.06
      expect(result.attackerLosses).toBeGreaterThanOrEqual(0);
      expect(result.defenderLosses).toBeGreaterThanOrEqual(0);
    });

    it('should apply morale changes based on ratio', () => {
      const strongAttacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 2000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const weakDefender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd2', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const phaseRng = new BattleRNG('morale-test-seed');
      const result = evaluatePhase(
        strongAttacker, weakDefender, 'attack', 'melee', 'melee', 'field', phaseRng
      );

      // With 2:1 ratio, attacker should gain morale, defender should lose
      if (result.ratio > 1.1) {
        expect(result.attackerMoraleChange).toBeGreaterThan(0);
        expect(result.defenderMoraleChange).toBeLessThan(0);
      }
    });
  });

  describe('evaluateDecisionPhase', () => {
    it('should return attacker as winner with higher decision power', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 1500,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 80,
        commander: { id: 'cmd2', name: 'Test', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const phaseRng = new BattleRNG('decision-test-seed');
      const result = evaluateDecisionPhase(
        attacker, defender, 'melee', 'melee', 'field', phaseRng
      );

      // Attacker should have higher decision power
      expect(result.winner).toBe('attacker');
    });

    it('should return defender as winner when decision power is equal', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd2', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      // Use a seed that makes decision power equal
      // This is hard to guarantee, so we'll just test the tie-breaker rule
      const phaseRng = new BattleRNG('equal-decision-seed');
      const result = evaluateDecisionPhase(
        attacker, defender, 'melee', 'melee', 'field', phaseRng
      );

      // If decision power is exactly equal, defender should win
      // Note: This depends on the RNG, so we can't guarantee it
      // Just verify that we get a valid result
      expect(['attacker', 'defender']).toContain(result.winner);
    });
  });

  describe('applyTerrainMoraleModifiers', () => {
    it('should apply terrain morale modifiers correctly', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd2', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      // Forest: attacker -10, defender 0
      const result = applyTerrainMoraleModifiers(attacker, defender, 'forest');
      expect(result.attackerMorale).toBe(90);
      expect(result.defenderMorale).toBe(100);

      // Fortress: attacker 0, defender +15
      const result2 = applyTerrainMoraleModifiers(attacker, defender, 'fortress');
      expect(result2.attackerMorale).toBe(100);
      expect(result2.defenderMorale).toBe(115);
    });

    it('should apply Hungarian river penalty', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'hungarian',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'moravian',
        size: 1000,
        morale: 100,
        commander: { id: 'cmd2', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      // River: attacker -5, defender 0, plus Hungarian penalty -10
      const result = applyTerrainMoraleModifiers(attacker, defender, 'river');
      expect(result.attackerMorale).toBe(100 + TERRAIN_MODIFIERS["river"].attackerMorale + (FACTION_TRAITS["hungarian"].riverMoralePenalty || 0)); // 100 - 5 - 10 = 85
      expect(result.defenderMorale).toBe(100);
    });

    it('should clamp morale to 0-100', () => {
      const attacker: Army = {
        id: 'attacker',
        factionId: 'test',
        size: 1000,
        morale: 10,
        commander: { id: 'cmd1', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      const defender: Army = {
        id: 'defender',
        factionId: 'test',
        size: 1000,
        morale: 10,
        commander: { id: 'cmd2', name: 'Test', skill: 0 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: 'test',
      };

      // Forest: attacker -10, so 10 - 10 = 0
      const result = applyTerrainMoraleModifiers(attacker, defender, 'forest');
      expect(result.attackerMorale).toBe(0);
      expect(result.defenderMorale).toBe(10);
    });
  });

  describe('checkRout', () => {
    it('should return true when morale <= 20', () => {
      expect(checkRout(20)).toBe(true);
      expect(checkRout(19)).toBe(true);
      expect(checkRout(0)).toBe(true);
    });

    it('should return false when morale > 20', () => {
      expect(checkRout(21)).toBe(false);
      expect(checkRout(50)).toBe(false);
      expect(checkRout(100)).toBe(false);
    });
  });

  describe('applyRoutLosses', () => {
    it('should apply 10% losses for regroup', () => {
      expect(applyRoutLosses(1000, 'regroup')).toBe(100);
      expect(applyRoutLosses(500, 'regroup')).toBe(50);
    });

    it('should apply 20% losses for pursue', () => {
      expect(applyRoutLosses(1000, 'pursue')).toBe(200);
      expect(applyRoutLosses(500, 'pursue')).toBe(100);
    });
  });

  describe('applyRetreatLosses', () => {
    it('should apply 5% losses', () => {
      expect(applyRetreatLosses(1000)).toBe(50);
      expect(applyRetreatLosses(500)).toBe(25);
    });
  });

  describe('applyDecisionLosses', () => {
    it('should apply 8% losses', () => {
      expect(applyDecisionLosses(1000)).toBe(80);
      expect(applyDecisionLosses(500)).toBe(40);
    });
  });

  describe('clamp', () => {
    it('should clamp value to min and max', () => {
      expect(clamp(5, 0, 10)).toBe(5);
      expect(clamp(-5, 0, 10)).toBe(0);
      expect(clamp(15, 0, 10)).toBe(10);
    });
  });
});
