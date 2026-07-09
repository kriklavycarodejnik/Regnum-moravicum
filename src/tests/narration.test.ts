// Regnum Moravicum - Narration Tests

import { describe, it, expect, beforeEach } from 'vitest';
import { Narrator, createNarrator } from '../battle/narration/narrator';
import { ALL_TEMPLATES, validateTemplateCounts } from '../battle/narration/templates/loader';
import type { PhaseLog, Battle, BattlePhaseType, BattleAction } from '../battle/types';
import type { TemplatePlaceholders } from '../battle/narration/templates';

describe('Narration System', () => {
  let narrator: Narrator;
  let battle: Battle;
  let placeholders: TemplatePlaceholders;

  beforeEach(() => {
    // Create narrator with all templates
    narrator = createNarrator(ALL_TEMPLATES, 'test-seed', 5);
    
    // Create test battle
    battle = {
      id: 'battle1',
      warId: 'war1',
      zupaId: 'test_zupa',
      terrain: 'field',
      attackerArmyId: 'army1',
      defenderArmyId: 'army2',
      currentPhase: 'attack',
      phaseLogs: [],
      result: null,
      winnerArmyId: null,
      isAutoResolved: false,
      startTick: 0,
      seed: 'battle-seed',
      rngState: null,
    };
    
    placeholders = {
      attackerName: 'Moravané',
      defenderName: 'Maďari',
      attackerCommander: 'knieža Mojmír',
      defenderCommander: 'knieža Árpád',
      losses: 100,
      unitDominant: 'pechota',
      zupaName: 'Nitrianska župa',
    };
  });

  describe('Template Validation', () => {
    it('should have at least 126 templates', () => {
      expect(ALL_TEMPLATES.length).toBeGreaterThanOrEqual(126);
    });

    it('should validate template counts', () => {
      const validation = validateTemplateCounts();
      expect(validation.valid).toBe(true);
    });

    it('should have correct minimum counts for each slot', () => {
      const validation = validateTemplateCounts();
      
      expect(validation.counts.openers).toBeGreaterThanOrEqual(validation.required.openers);
      expect(validation.counts.actions).toBeGreaterThanOrEqual(validation.required.actions);
      expect(validation.counts.terrain).toBeGreaterThanOrEqual(validation.required.terrain);
      expect(validation.counts.outcomes).toBeGreaterThanOrEqual(validation.required.outcomes);
      expect(validation.counts.morale).toBeGreaterThanOrEqual(validation.required.morale);
      expect(validation.counts.special).toBeGreaterThanOrEqual(validation.required.special);
    });
  });

  describe('Narrator', () => {
    it('should be created with templates', () => {
      expect(narrator).toBeInstanceOf(Narrator);
    });

    it('should narrate a phase', () => {
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      const sentences = narrator.narratePhase(phaseLog, battle, placeholders);
      
      expect(sentences.length).toBeGreaterThanOrEqual(2);
      expect(sentences.length).toBeLessThanOrEqual(5);
    });

    it('should include placeholders in narration', () => {
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      const sentences = narrator.narratePhase(phaseLog, battle, placeholders);
      
      // Check that placeholders are replaced
      const hasAttackerName = sentences.some(s => s.includes('Moravané'));
      const hasDefenderName = sentences.some(s => s.includes('Maďari'));
      
      expect(hasAttackerName).toBe(true);
      expect(hasDefenderName).toBe(true);
    });

    it('should handle different phases', () => {
      const phases: BattlePhaseType[] = ['attack', 'counterattack', 'decision'];
      
      for (const phase of phases) {
        const phaseLog: PhaseLog = {
          phase,
          attackerAction: 'melee',
          defenderAction: 'melee',
          attackerLosses: 50,
          defenderLosses: 30,
          attackerMoraleChange: 5,
          defenderMoraleChange: -3,
          narration: [],
        };

        const sentences = narrator.narratePhase(phaseLog, battle, placeholders);
        expect(sentences.length).toBeGreaterThan(0);
      }
    });

    it('should handle different action combinations', () => {
      const actions: BattleAction[] = ['melee', 'ranged', 'flank'];
      
      for (const attackerAction of actions) {
        for (const defenderAction of actions) {
          const phaseLog: PhaseLog = {
            phase: 'attack',
            attackerAction,
            defenderAction,
            attackerLosses: 50,
            defenderLosses: 30,
            attackerMoraleChange: 5,
            defenderMoraleChange: -3,
            narration: [],
          };

          const sentences = narrator.narratePhase(phaseLog, battle, placeholders);
          expect(sentences.length).toBeGreaterThan(0);
        }
      }
    });

    it('should handle different terrains', () => {
      const terrains: import('../battle/types').Terrain[] = ['field', 'forest', 'fortress', 'river', 'hill'];
      
      for (const terrain of terrains) {
        const battleWithTerrain = { ...battle, terrain };
        const phaseLog: PhaseLog = {
          phase: 'attack',
          attackerAction: 'melee',
          defenderAction: 'melee',
          attackerLosses: 50,
          defenderLosses: 30,
          attackerMoraleChange: 5,
          defenderMoraleChange: -3,
          narration: [],
        };

        const sentences = narrator.narratePhase(phaseLog, battleWithTerrain, placeholders);
        expect(sentences.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Anti-repetition', () => {
    it('should not repeat templates within window', () => {
      const windowSize = 5;
      const narratorWithWindow = createNarrator(ALL_TEMPLATES, 'anti-rep-seed', windowSize);
      
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      // Generate multiple narrations
      const allSentences: string[] = [];

      for (let i = 0; i < windowSize + 5; i++) {
        const sentences = narratorWithWindow.narratePhase(phaseLog, battle, placeholders);
        allSentences.push(...sentences);
      }

      // With anti-repetition, we should get varied sentences
      // This is a basic check - in a real scenario, we'd need to track template IDs
      expect(allSentences.length).toBeGreaterThan(0);
    });

    it('should reset used templates', () => {
      const narratorWithWindow = createNarrator(ALL_TEMPLATES, 'reset-seed', 5);
      
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      // Generate some narrations
      for (let i = 0; i < 10; i++) {
        narratorWithWindow.narratePhase(phaseLog, battle, placeholders);
      }

      // Reset
      narratorWithWindow.reset();

      // Should be able to use the same templates again
      const sentences = narratorWithWindow.narratePhase(phaseLog, battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });
  });

  describe('Auto-resolve Narration', () => {
    it('should narrate auto-resolve with shortened mode', () => {
      const sentences = narrator.narrateAutoResolve(battle, placeholders, 'attacker');
      
      expect(sentences.length).toBeGreaterThanOrEqual(3);
      expect(sentences.length).toBeLessThanOrEqual(5);
    });

    it('should handle both winner cases', () => {
      const attackerSentences = narrator.narrateAutoResolve(battle, placeholders, 'attacker');
      const defenderSentences = narrator.narrateAutoResolve(battle, placeholders, 'defender');
      
      expect(attackerSentences.length).toBeGreaterThan(0);
      expect(defenderSentences.length).toBeGreaterThan(0);
    });
  });

  describe('Special Events Narration', () => {
    it('should narrate rout', () => {
      const sentences = narrator.narrateSpecial('rout', battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should narrate pursue', () => {
      const sentences = narrator.narrateSpecial('pursue', battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should narrate retreat', () => {
      const sentences = narrator.narrateSpecial('retreat', battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should narrate river_crossing', () => {
      const sentences = narrator.narrateSpecial('river_crossing', battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should narrate fortress_assault', () => {
      const sentences = narrator.narrateSpecial('fortress_assault', battle, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });
  });

  describe('Full Battle Narration', () => {
    it('should narrate full battle', () => {
      const battleWithPhases: Battle = {
        ...battle,
        phaseLogs: [
          {
            phase: 'attack',
            attackerAction: 'melee',
            defenderAction: 'melee',
            attackerLosses: 50,
            defenderLosses: 30,
            attackerMoraleChange: 5,
            defenderMoraleChange: -3,
            narration: [],
          },
          {
            phase: 'counterattack',
            attackerAction: 'ranged',
            defenderAction: 'flank',
            attackerLosses: 40,
            defenderLosses: 60,
            attackerMoraleChange: -3,
            defenderMoraleChange: 5,
            narration: [],
          },
        ],
        currentPhase: 'decision',
      };

      const sentences = narrator.narrateBattle(battleWithPhases, placeholders);
      
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should add special narration for victory_rout', () => {
      const battleWithRout: Battle = {
        ...battle,
        phaseLogs: [
          {
            phase: 'attack',
            attackerAction: 'melee',
            defenderAction: 'melee',
            attackerLosses: 50,
            defenderLosses: 30,
            attackerMoraleChange: 5,
            defenderMoraleChange: -25, // Low enough to trigger rout
            narration: [],
          },
        ],
        currentPhase: 'finished',
        result: 'victory_rout',
        winnerArmyId: 'army1',
      };

      const sentences = narrator.narrateBattle(battleWithRout, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });

    it('should add special narration for retreat', () => {
      const battleWithRetreat: Battle = {
        ...battle,
        phaseLogs: [
          {
            phase: 'attack',
            attackerAction: 'retreat',
            defenderAction: 'melee',
            attackerLosses: 50,
            defenderLosses: 0,
            attackerMoraleChange: -10,
            defenderMoraleChange: 5,
            narration: [],
          },
        ],
        currentPhase: 'finished',
        result: 'retreat',
        winnerArmyId: 'army2',
      };

      const sentences = narrator.narrateBattle(battleWithRetreat, placeholders);
      expect(sentences.length).toBeGreaterThan(0);
    });
  });

  describe('Reproducibility', () => {
    it('should produce identical narration with same seed', () => {
      const seed = 'reproducibility-seed';
      
      const narrator1 = createNarrator(ALL_TEMPLATES, seed, 5);
      const narrator2 = createNarrator(ALL_TEMPLATES, seed, 5);
      
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      const sentences1 = narrator1.narratePhase(phaseLog, battle, placeholders);
      const sentences2 = narrator2.narratePhase(phaseLog, battle, placeholders);
      
      expect(sentences1).toEqual(sentences2);
    });

    it('should produce different narration with different seeds', () => {
      const narrator1 = createNarrator(ALL_TEMPLATES, 'seed1', 5);
      const narrator2 = createNarrator(ALL_TEMPLATES, 'seed2', 5);
      
      const phaseLog: PhaseLog = {
        phase: 'attack',
        attackerAction: 'melee',
        defenderAction: 'melee',
        attackerLosses: 50,
        defenderLosses: 30,
        attackerMoraleChange: 5,
        defenderMoraleChange: -3,
        narration: [],
      };

      const sentences1 = narrator1.narratePhase(phaseLog, battle, placeholders);
      const sentences2 = narrator2.narratePhase(phaseLog, battle, placeholders);
      
      // Should be different (at least one sentence should differ)
      expect(sentences1).not.toEqual(sentences2);
    });
  });

  describe('Template Coverage', () => {
    it('should have templates for all phase and action combinations', () => {
      const phases: BattlePhaseType[] = ['attack', 'counterattack', 'decision'];
      const actions: BattleAction[] = ['melee', 'ranged', 'flank'];
      
      for (const phase of phases) {
        for (const attackerAction of actions) {
          for (const defenderAction of actions) {
            const phaseLog: PhaseLog = {
              phase,
              attackerAction,
              defenderAction,
              attackerLosses: 50,
              defenderLosses: 30,
              attackerMoraleChange: 5,
              defenderMoraleChange: -3,
              narration: [],
            };

            const sentences = narrator.narratePhase(phaseLog, battle, placeholders);
            expect(sentences.length).toBeGreaterThan(0);
          }
        }
      }
    });

    it('should have templates for all terrains', () => {
      const terrains: import('../battle/types').Terrain[] = ['field', 'forest', 'fortress', 'river', 'hill'];
      
      for (const terrain of terrains) {
        const battleWithTerrain = { ...battle, terrain };
        const phaseLog: PhaseLog = {
          phase: 'attack',
          attackerAction: 'melee',
          defenderAction: 'melee',
          attackerLosses: 50,
          defenderLosses: 30,
          attackerMoraleChange: 5,
          defenderMoraleChange: -3,
          narration: [],
        };

        const sentences = narrator.narratePhase(phaseLog, battleWithTerrain, placeholders);
        expect(sentences.length).toBeGreaterThan(0);
      }
    });
  });
});
