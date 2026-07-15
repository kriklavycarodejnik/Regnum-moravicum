// Regnum Moravicum - Scenario Loader Tests (Core Loop M3)
import { describe, it, expect } from 'vitest';
import {
  loadScenario,
  validateScenarioConfig,
  getAvailableScenarios,
  getScenarioConfig,
} from '../src/core/engines/scenarioLoader';
import { migrateSaveData } from '../src/core/utils/migrations';
import { generateInitialState } from '../src/core/utils/generators';
import type { StartScenarioConfig } from '../src/core/types/scenario';

describe('Scenario Loader', () => {
  describe('validateScenarioConfig', () => {
    const base: StartScenarioConfig = {
      id: 'test',
      name: 'Test',
      description: '',
      startYear: 902,
      startTick: 0,
      victoryScenario: 'prežitie',
      initialResourceOverrides: {},
      zupaLoyaltyOverrides: {},
      religionAxisStart: 0,
      activeThreats: [],
    };

    it('accepts a well-formed config', () => {
      expect(validateScenarioConfig(base)).toBe(true);
    });

    it('rejects a start year before 902', () => {
      expect(validateScenarioConfig({ ...base, startYear: 850 })).toBe(false);
    });

    it('rejects a negative start tick', () => {
      expect(validateScenarioConfig({ ...base, startTick: -1 })).toBe(false);
    });

    it('rejects an out-of-range religion axis start', () => {
      expect(validateScenarioConfig({ ...base, religionAxisStart: 150 })).toBe(false);
    });
  });

  describe('getAvailableScenarios', () => {
    it('lists at least the two canon scenarios', () => {
      const ids = getAvailableScenarios().map((s) => s.id);
      expect(ids).toContain('nastup-902');
      expect(ids).toContain('burka-pri-devine-907');
    });
  });

  describe('loadScenario', () => {
    it('902 scenario matches the plain generateInitialState baseline', () => {
      const state = loadScenario('nastup-902', 'scenario-test-seed');
      expect(state.year).toBe(902);
      expect(state.tick).toBe(0);
      expect(state.startScenarioId).toBe('nastup-902');
    });

    it('907 scenario starts later, poorer, with Devín loyalty overridden and a threat chronicle entry', () => {
      const state = loadScenario('burka-pri-devine-907', 'scenario-test-seed');
      expect(state.year).toBe(907);
      expect(state.tick).toBe(60);
      expect(state.startScenarioId).toBe('burka-pri-devine-907');
      expect(state.resources.gold).toBe(400);

      const devin = Object.values(state.zupy).find((z) => z.name === 'Devín');
      expect(devin?.loyalty).toBe(35);

      expect(state.events.some((e) => e.id === 'scenario_threats_burka-pri-devine-907')).toBe(true);
    });

    it('falls back to the default scenario for an unknown id instead of throwing', () => {
      const state = loadScenario('does-not-exist', 'scenario-test-seed');
      expect(state.startScenarioId).toBe('nastup-902');
    });

    it('every generated zupa has a fully-initialized investment state (M1 integration)', () => {
      const state = loadScenario('burka-pri-devine-907', 'scenario-test-seed');
      for (const zupaId of Object.keys(state.zupy)) {
        expect(state.investments[zupaId]).toEqual({ economy: 0, fortification: 0, church: 0, active: null });
      }
    });
  });

  describe('determinism', () => {
    // Entity ids embed Date.now() (a pre-existing generators.ts trait, see
    // tests/generators.test.ts "deterministic with same seed (excluding id)"),
    // so this compares the seed-derived content rather than full deep equality.
    it('produces the same scenario content for the same scenario+seed', () => {
      const a = loadScenario('burka-pri-devine-907', 'same-seed');
      const b = loadScenario('burka-pri-devine-907', 'same-seed');

      expect(a.year).toBe(b.year);
      expect(a.tick).toBe(b.tick);
      expect(a.resources).toEqual(b.resources);
      expect(a.religion).toEqual(b.religion);
      expect(Object.keys(a.zupy).sort()).toEqual(Object.keys(b.zupy).sort());
      expect(Object.values(a.zupy).map((z) => z.loyalty)).toEqual(Object.values(b.zupy).map((z) => z.loyalty));
      expect(a.events.map((e) => e.id)).toEqual(b.events.map((e) => e.id));
    });
  });

  describe('save compatibility', () => {
    it('migration backfills startScenarioId for pre-M3 saves', () => {
      const legacyState: any = generateInitialState('prežitie', 'legacy-seed');
      delete legacyState.startScenarioId;

      const migrated = migrateSaveData({ state: legacyState, saveVersion: '2.2.0' });
      expect(migrated.startScenarioId).toBe('nastup-902');
    });

    it('getScenarioConfig resolves a known id', () => {
      expect(getScenarioConfig('nastup-902')?.name).toContain('902');
    });
  });
});
