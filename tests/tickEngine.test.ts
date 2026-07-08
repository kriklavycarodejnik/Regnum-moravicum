import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { processTick } from '../src/core/engines/tickEngine';
import type { GameState } from '../src/core/types';

describe('Tick Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('tick-test-seed');
    initialState = generateInitialState('prežitie', 'tick-test-seed');
  });

  describe('processTick', () => {
    it('should increment tick by 1', () => {
      const newState = processTick(initialState);
      expect(newState.tick).toBe(initialState.tick + 1);
    });

    it('should not increment year until 12 ticks have passed', () => {
      const newState = processTick(initialState);
      expect(newState.year).toBe(initialState.year);
    });

    it('should increment year exactly every 12th tick', () => {
      const stateAtMonth11: GameState = { ...initialState, tick: 11, year: 902 };

      const newState = processTick(stateAtMonth11);
      expect(newState.tick).toBe(12);
      expect(newState.year).toBe(903);
    });

    it('should keep tick monotonically increasing across year boundaries', () => {
      let state: GameState = { ...initialState, tick: 10, year: 902 };
      for (let i = 0; i < 5; i++) {
        state = processTick(state);
      }
      // 10 -> 11 -> 12 -> 13 -> 14 -> 15, never resets to 0
      expect(state.tick).toBe(15);
      expect(state.year).toBe(903);
    });

    it('should age nobles only when a year passes', () => {
      const stateAtMonth11: GameState = { ...initialState, tick: 11 };
      const ageBefore = stateAtMonth11.nobles[0].age;

      const newState = processTick(stateAtMonth11);
      const aged = newState.nobles.find(n => n.id === stateAtMonth11.nobles[0].id);

      expect(aged?.age).toBe(ageBefore + 1);
    });

    it('should not age nobles mid-year', () => {
      const stateAtMonth0: GameState = { ...initialState, tick: 0 };
      const ageBefore = stateAtMonth0.nobles[0].age;

      const newState = processTick(stateAtMonth0);
      const notAged = newState.nobles.find(n => n.id === stateAtMonth0.nobles[0].id);

      expect(notAged?.age).toBe(ageBefore);
    });

    it('should not age dead nobles', () => {
      const stateWithDeadNoble: GameState = {
        ...initialState,
        tick: 11,
        nobles: [
          ...initialState.nobles,
          {
            id: 'dead-noble',
            name: 'Dead Noble',
            familyId: initialState.families[0].id,
            title: 'Magnát',
            attributes: { combat: 5, diplomacy: 5, intelligence: 5, piety: 5, charisma: 5 },
            loyalty: 50,
            location: Object.keys(initialState.zupy)[0],
            armyIds: [],
            children: [],
            coatOfArms: '',
            age: 90,
            status: 'dead',
            birthTick: 0,
            deathTick: 5
          }
        ]
      };

      const newState = processTick(stateWithDeadNoble);
      const deadNoble = newState.nobles.find(n => n.id === 'dead-noble');
      expect(deadNoble?.age).toBe(90);
    });

    it('should decay faction moods towards 50', () => {
      const stateWithExtremeMood: GameState = {
        ...initialState,
        factions: initialState.factions.map((f, i) =>
          i === 0 ? { ...f, moods: { loyalty: 100, fear: 100, trust: 100, anger: 100 } } : f
        )
      };

      const newState = processTick(stateWithExtremeMood);
      const faction = newState.factions[0];

      expect(faction.moods.loyalty).toBeLessThan(100);
      expect(faction.moods.fear).toBeLessThan(100);
      expect(faction.moods.trust).toBeLessThan(100);
      expect(faction.moods.anger).toBeLessThan(100);
    });

    it('should grow zupa prosperity when food is sufficient', () => {
      const firstZupaId = Object.keys(initialState.zupy)[0];
      const stateWithFood: GameState = {
        ...initialState,
        zupy: {
          ...initialState.zupy,
          [firstZupaId]: { ...initialState.zupy[firstZupaId], prosperity: 10, food: 100 }
        }
      };

      const newState = processTick(stateWithFood);
      expect(newState.zupy[firstZupaId].prosperity).toBeGreaterThan(10);
    });

    it('should shrink zupa prosperity when food is insufficient', () => {
      const firstZupaId = Object.keys(initialState.zupy)[0];
      const stateWithoutFood: GameState = {
        ...initialState,
        zupy: {
          ...initialState.zupy,
          [firstZupaId]: { ...initialState.zupy[firstZupaId], prosperity: 50, food: 0 }
        }
      };

      const newState = processTick(stateWithoutFood);
      expect(newState.zupy[firstZupaId].prosperity).toBeLessThan(50);
    });

    it('should cap prosperity at 100', () => {
      const firstZupaId = Object.keys(initialState.zupy)[0];
      const stateWithMaxProsperity: GameState = {
        ...initialState,
        zupy: {
          ...initialState.zupy,
          [firstZupaId]: { ...initialState.zupy[firstZupaId], prosperity: 100, food: 1000 }
        }
      };

      const newState = processTick(stateWithMaxProsperity);
      expect(newState.zupy[firstZupaId].prosperity).toBeLessThanOrEqual(100);
    });

    it('should add 5 to the recruitment pool of every zupa', () => {
      const newState = processTick(initialState);

      Object.keys(initialState.zupy).forEach(zupaId => {
        expect(newState.zupy[zupaId].recruitmentPool).toBe(initialState.zupy[zupaId].recruitmentPool + 5);
      });
    });

    it('should pay upkeep for armies from gold', () => {
      const initialGold = initialState.resources.gold;
      expect(initialState.armies.length).toBeGreaterThan(0);

      const newState = processTick(initialState);

      expect(newState.resources.gold).toBeLessThan(initialGold);
    });

    it('should check for rebellions without crashing', () => {
      const firstZupaId = Object.keys(initialState.zupy)[0];
      const stateWithLowLoyalty: GameState = {
        ...initialState,
        zupy: {
          ...initialState.zupy,
          [firstZupaId]: { ...initialState.zupy[firstZupaId], loyalty: 10 }
        }
      };

      const newState = processTick(stateWithLowLoyalty);
      expect(newState).toBeDefined();
      expect(Object.keys(newState.zupy).length).toBe(Object.keys(initialState.zupy).length);
    });

    it('should not mutate the original state', () => {
      const originalTick = initialState.tick;
      const originalYear = initialState.year;
      const originalGold = initialState.resources.gold;

      processTick(initialState);

      expect(initialState.tick).toBe(originalTick);
      expect(initialState.year).toBe(originalYear);
      expect(initialState.resources.gold).toBe(originalGold);
    });

    it('should handle 12 ticks (1 year) correctly', () => {
      let state = initialState;

      for (let i = 0; i < 12; i++) {
        state = processTick(state);
      }

      expect(state.tick).toBe(12);
      expect(state.year).toBe(903);
    });

    it('should handle 24 ticks (2 years) correctly', () => {
      let state = initialState;

      for (let i = 0; i < 24; i++) {
        state = processTick(state);
      }

      expect(state.tick).toBe(24);
      expect(state.year).toBe(904);
    });

    it('should maintain all top-level GameState properties', () => {
      const newState = processTick(initialState);

      expect(newState).toHaveProperty('tick');
      expect(newState).toHaveProperty('year');
      expect(newState).toHaveProperty('seed');
      expect(newState).toHaveProperty('scenario');
      expect(newState).toHaveProperty('player');
      expect(newState).toHaveProperty('nobles');
      expect(newState).toHaveProperty('families');
      expect(newState).toHaveProperty('factions');
      expect(newState).toHaveProperty('zupy');
      expect(newState).toHaveProperty('armies');
      expect(newState).toHaveProperty('wars');
      expect(newState).toHaveProperty('treaties');
      expect(newState).toHaveProperty('events');
      expect(newState).toHaveProperty('resources');
      expect(newState).toHaveProperty('religion');
      expect(newState).toHaveProperty('gameOver');
      expect(newState).toHaveProperty('saveVersion');
    });

    it('should be a pure function: same input always yields the same output', () => {
      const newState1 = processTick(initialState);
      const newState2 = processTick(initialState);

      expect(newState1.tick).toBe(newState2.tick);
      expect(newState1.year).toBe(newState2.year);
      expect(newState1.resources).toEqual(newState2.resources);
    });
  });

  describe('Edge Cases', () => {
    it('should handle an empty armies array', () => {
      const stateWithNoArmies: GameState = { ...initialState, armies: [] };
      const newState = processTick(stateWithNoArmies);
      expect(newState.armies).toEqual([]);
    });

    it('should handle an empty nobles array', () => {
      const stateWithNoNobles: GameState = { ...initialState, nobles: [] };
      const newState = processTick(stateWithNoNobles);
      expect(newState.nobles).toEqual([]);
    });

    it('should handle an empty zupy map', () => {
      const stateWithNoZupy: GameState = { ...initialState, zupy: {} };
      const newState = processTick(stateWithNoZupy);
      expect(newState.zupy).toEqual({});
    });

    it('should not go below zero gold when upkeep exceeds funds', () => {
      const stateWithNoGold: GameState = {
        ...initialState,
        resources: { ...initialState.resources, gold: 0 }
      };

      const newState = processTick(stateWithNoGold);
      expect(newState.resources.gold).toBeGreaterThanOrEqual(0);
    });

    it('should reduce army morale when upkeep cannot be fully paid', () => {
      const stateWithNoGold: GameState = {
        ...initialState,
        resources: { ...initialState.resources, gold: 0 }
      };
      const moraleBefore = stateWithNoGold.armies[0].morale;

      const newState = processTick(stateWithNoGold);
      expect(newState.armies[0].morale).toBeLessThan(moraleBefore);
    });

    it('should handle a noble at the death-check age threshold without crashing', () => {
      const stateWithOldNoble: GameState = {
        ...initialState,
        tick: 11,
        nobles: [
          ...initialState.nobles,
          {
            id: 'old-noble',
            name: 'Old Noble',
            familyId: initialState.families[0].id,
            title: 'Magnát',
            attributes: { combat: 1, diplomacy: 1, intelligence: 1, piety: 1, charisma: 1 },
            loyalty: 50,
            location: Object.keys(initialState.zupy)[0],
            armyIds: [],
            children: [],
            coatOfArms: '',
            age: 80,
            status: 'alive',
            birthTick: 0
          }
        ]
      };

      const newState = processTick(stateWithOldNoble);
      const oldNoble = newState.nobles.find(n => n.id === 'old-noble');
      expect(oldNoble).toBeDefined();
      expect(['alive', 'dead']).toContain(oldNoble?.status);
    });
  });
});
