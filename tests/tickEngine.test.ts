import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { processTick } from '../src/core/engines/tickEngine';
import type { GameState } from '../src/core/types';

describe('Tick Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('tick-test-seed');
    initialState = generateInitialState('tick-test-seed', 'standard');
  });

  describe('processTick', () => {
    it('should increment tick by 1', () => {
      const newState = processTick(initialState);
      expect(newState.tick).toBe(initialState.tick + 1);
    });

    it('should increment month correctly', () => {
      const newState = processTick(initialState);
      expect(newState.month).toBe(initialState.month + 1);
    });

    it('should reset month to 1 and increment year when month exceeds 12', () => {
      // Create a state with month 12
      const decemberState: GameState = {
        ...initialState,
        month: 12,
        year: 902
      };
      
      const newState = processTick(decemberState);
      expect(newState.month).toBe(1);
      expect(newState.year).toBe(903);
    });

    it('should not increment year when month is less than 12', () => {
      const newState = processTick(initialState);
      expect(newState.year).toBe(initialState.year);
    });

    it('should age nobles by 1 month', () => {
      const newState = processTick(initialState);
      
      initialState.nobles.forEach((noble, index) => {
        const newNoble = newState.nobles.find(n => n.id === noble.id);
        expect(newNoble).toBeDefined();
        if (newNoble) {
          expect(newNoble.age).toBe(noble.age + 1);
        }
      });
    });

    it('should not age dead nobles', () => {
      // Create a state with a dead noble
      const stateWithDeadNoble: GameState = {
        ...initialState,
        nobles: [
          ...initialState.nobles,
          {
            id: 'dead-noble',
            name: 'Dead Noble',
            familyId: 'Mojmírovci',
            gender: 'male',
            age: 50,
            attributes: { strength: 10, intelligence: 10, charisma: 10, piety: 10, luck: 10 },
            traits: [],
            alive: false,
            health: 0,
            isRuler: false
          }
        ]
      };
      
      const newState = processTick(stateWithDeadNoble);
      const deadNoble = newState.nobles.find(n => n.id === 'dead-noble');
      expect(deadNoble).toBeDefined();
      expect(deadNoble?.age).toBe(50); // Age should not increase
    });

    it('should decay faction moods', () => {
      // Create a state with a faction that has high relation
      const stateWithHighRelation: GameState = {
        ...initialState,
        factions: initialState.factions.map(f => 
          f.id === 'player' ? { ...f, relationToPlayer: 100 } : f
        )
      };
      
      const newState = processTick(stateWithHighRelation);
      const playerFaction = newState.factions.find(f => f.id === 'player');
      
      expect(playerFaction).toBeDefined();
      // Mood should decay (decrease) slightly
      expect(playerFaction!.relationToPlayer).toBeLessThan(100);
    });

    it('should grow zupa prosperity', () => {
      // Create a state with a zupa that has low prosperity
      const stateWithLowProsperity: GameState = {
        ...initialState,
        zupas: initialState.zupas.map(z => 
          z.id === 'Nitra' ? { ...z, prosperity: 10 } : z
        )
      };
      
      const newState = processTick(stateWithLowProsperity);
      const nitra = newState.zupas.find(z => z.id === 'Nitra');
      
      expect(nitra).toBeDefined();
      // Prosperity should grow (increase) slightly
      expect(nitra!.prosperity).toBeGreaterThan(10);
    });

    it('should cap prosperity at 100', () => {
      // Create a state with a zupa that has max prosperity
      const stateWithMaxProsperity: GameState = {
        ...initialState,
        zupas: initialState.zupas.map(z => 
          z.id === 'Nitra' ? { ...z, prosperity: 100 } : z
        )
      };
      
      const newState = processTick(stateWithMaxProsperity);
      const nitra = newState.zupas.find(z => z.id === 'Nitra');
      
      expect(nitra).toBeDefined();
      // Prosperity should not exceed 100
      expect(nitra!.prosperity).toBeLessThanOrEqual(100);
    });

    it('should add recruitment pool to zupas', () => {
      const newState = processTick(initialState);
      
      initialState.zupas.forEach((zupa, index) => {
        const newZupa = newState.zupas.find(z => z.id === zupa.id);
        expect(newZupa).toBeDefined();
        if (newZupa) {
          // Recruitment pool should increase
          expect(newZupa.recruitmentPool).toBeGreaterThanOrEqual(zupa.recruitmentPool);
        }
      });
    });

    it('should pay upkeep for armies', () => {
      // Create a state with an army
      const stateWithArmy: GameState = {
        ...initialState,
        armies: [
          {
            id: 'army-1',
            name: 'Test Army',
            factionId: 'player',
            zupaId: 'Nitra',
            status: 'active',
            units: [
              { type: 'peasant', count: 100, experience: 0 }
            ],
            morale: 100,
            experience: 0,
            formation: 'shieldWall',
            commanderId: initialState.nobles[0].id
          }
        ]
      };
      
      const initialGold = stateWithArmy.resources.gold;
      const newState = processTick(stateWithArmy);
      
      // Gold should decrease due to upkeep
      expect(newState.resources.gold).toBeLessThan(initialGold);
    });

    it('should check for rebellions', () => {
      // Create a state with a zupa that has very low loyalty
      const stateWithLowLoyalty: GameState = {
        ...initialState,
        zupas: initialState.zupas.map(z => 
          z.id === 'Nitra' ? { ...z, loyalty: 10 } : z
        )
      };
      
      const newState = processTick(stateWithLowLoyalty);
      
      // The engine should process rebellion checks
      // (The actual rebellion logic is probabilistic, so we just verify the state is valid)
      expect(newState).toBeDefined();
      expect(newState.zupas.length).toBe(initialState.zupas.length);
    });

    it('should not modify original state', () => {
      const originalTick = initialState.tick;
      const originalMonth = initialState.month;
      const originalYear = initialState.year;
      
      processTick(initialState);
      
      // Original state should be unchanged
      expect(initialState.tick).toBe(originalTick);
      expect(initialState.month).toBe(originalMonth);
      expect(initialState.year).toBe(originalYear);
    });

    it('should handle multiple ticks correctly', () => {
      let state = initialState;
      
      for (let i = 0; i < 12; i++) {
        state = processTick(state);
      }
      
      expect(state.tick).toBe(12);
      expect(state.month).toBe(1);
      expect(state.year).toBe(903); // 902 + 1 year
    });

    it('should handle 24 ticks (2 years) correctly', () => {
      let state = initialState;
      
      for (let i = 0; i < 24; i++) {
        state = processTick(state);
      }
      
      expect(state.tick).toBe(24);
      expect(state.month).toBe(1);
      expect(state.year).toBe(904); // 902 + 2 years
    });

    it('should maintain all game state properties', () => {
      const newState = processTick(initialState);
      
      // All top-level properties should be present
      expect(newState).toHaveProperty('version');
      expect(newState).toHaveProperty('seed');
      expect(newState).toHaveProperty('tick');
      expect(newState).toHaveProperty('year');
      expect(newState).toHaveProperty('month');
      expect(newState).toHaveProperty('player');
      expect(newState).toHaveProperty('nobles');
      expect(newState).toHaveProperty('families');
      expect(newState).toHaveProperty('factions');
      expect(newState).toHaveProperty('zupas');
      expect(newState).toHaveProperty('armies');
      expect(newState).toHaveProperty('wars');
      expect(newState).toHaveProperty('treaties');
      expect(newState).toHaveProperty('events');
      expect(newState).toHaveProperty('resources');
      expect(newState).toHaveProperty('religionAxis');
      expect(newState).toHaveProperty('scenario');
    });

    it('should be deterministic with same seed', () => {
      initRNG('deterministic-tick');
      const state1 = generateInitialState('deterministic-tick', 'standard');
      
      initRNG('deterministic-tick');
      const state2 = generateInitialState('deterministic-tick', 'standard');
      
      const newState1 = processTick(state1);
      
      initRNG('deterministic-tick');
      const newState2 = processTick(state2);
      
      // The states should be identical
      expect(newState1.tick).toBe(newState2.tick);
      expect(newState1.month).toBe(newState2.month);
      expect(newState1.year).toBe(newState2.year);
    });
  });

  describe('Edge Cases', () => {
    it('should handle empty armies array', () => {
      const stateWithNoArmies: GameState = {
        ...initialState,
        armies: []
      };
      
      const newState = processTick(stateWithNoArmies);
      expect(newState.armies).toEqual([]);
    });

    it('should handle empty nobles array', () => {
      const stateWithNoNobles: GameState = {
        ...initialState,
        nobles: []
      };
      
      const newState = processTick(stateWithNoNobles);
      expect(newState.nobles).toEqual([]);
    });

    it('should handle empty zupas array', () => {
      const stateWithNoZupas: GameState = {
        ...initialState,
        zupas: []
      };
      
      const newState = processTick(stateWithNoZupas);
      expect(newState.zupas).toEqual([]);
    });

    it('should handle negative resources gracefully', () => {
      const stateWithNegativeResources: GameState = {
        ...initialState,
        resources: {
          ...initialState.resources,
          gold: -100
        }
      };
      
      const newState = processTick(stateWithNegativeResources);
      // Should not crash, resources might be more negative due to upkeep
      expect(newState.resources.gold).toBeLessThanOrEqual(-100);
    });

    it('should handle very old nobles', () => {
      const stateWithOldNoble: GameState = {
        ...initialState,
        nobles: [
          ...initialState.nobles,
          {
            id: 'old-noble',
            name: 'Old Noble',
            familyId: 'Mojmírovci',
            gender: 'male',
            age: 150, // Very old
            attributes: { strength: 1, intelligence: 1, charisma: 1, piety: 1, luck: 1 },
            traits: [],
            alive: true,
            health: 10,
            isRuler: false
          }
        ]
      };
      
      const newState = processTick(stateWithOldNoble);
      const oldNoble = newState.nobles.find(n => n.id === 'old-noble');
      expect(oldNoble).toBeDefined();
      expect(oldNoble?.age).toBe(151);
    });
  });
});
