import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import {
  generateInitialState,
  generateNoble,
  generateFamily,
  generateFaction,
  generateZupa,
  generateArmy,
  generateAttributes,
  generateId
} from '../src/core/utils/generators';
import { MORAVIAN_ZUPY, INITIAL_FACTIONS, INITIAL_RULER_NAME, INITIAL_DYNASTY_NAME } from '../src/data/initialState';
import type { Noble } from '../src/core/types';

describe('Generators', () => {
  beforeEach(() => {
    initRNG('test-generators');
  });

  describe('generateId', () => {
    it('should generate unique IDs', () => {
      const id1 = generateId();
      const id2 = generateId();
      expect(id1).not.toBe(id2);
    });

    it('should generate IDs with the given prefix', () => {
      const id = generateId('army');
      expect(id.startsWith('army_')).toBe(true);
    });

    it('should default to the "id" prefix', () => {
      const id = generateId();
      expect(id.startsWith('id_')).toBe(true);
    });
  });

  describe('generateAttributes', () => {
    it('should generate all five attributes', () => {
      const attrs = generateAttributes('Magnát');
      expect(attrs).toHaveProperty('combat');
      expect(attrs).toHaveProperty('diplomacy');
      expect(attrs).toHaveProperty('intelligence');
      expect(attrs).toHaveProperty('piety');
      expect(attrs).toHaveProperty('charisma');
    });

    it('should respect the point budget for each title (1-10 per attribute)', () => {
      const attrs = generateAttributes('Kráľ');
      const sum = attrs.combat + attrs.diplomacy + attrs.intelligence + attrs.piety + attrs.charisma;
      expect(sum).toBeGreaterThanOrEqual(40);
      expect(sum).toBeLessThanOrEqual(50);
      for (const value of Object.values(attrs)) {
        expect(value).toBeGreaterThanOrEqual(1);
        expect(value).toBeLessThanOrEqual(10);
      }
    });

    it('should use a smaller budget for lower titles', () => {
      const attrs = generateAttributes('Župan');
      const sum = attrs.combat + attrs.diplomacy + attrs.intelligence + attrs.piety + attrs.charisma;
      expect(sum).toBeGreaterThanOrEqual(15);
      expect(sum).toBeLessThanOrEqual(20);
    });

    it('should be deterministic with same seed', () => {
      initRNG('attrs-deterministic');
      const attrs1 = generateAttributes('Palatín');

      initRNG('attrs-deterministic');
      const attrs2 = generateAttributes('Palatín');

      expect(attrs1).toEqual(attrs2);
    });
  });

  describe('generateNoble', () => {
    it('should generate noble with all required properties', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble).toHaveProperty('id');
      expect(noble).toHaveProperty('name');
      expect(noble).toHaveProperty('familyId');
      expect(noble).toHaveProperty('title');
      expect(noble).toHaveProperty('attributes');
      expect(noble).toHaveProperty('loyalty');
      expect(noble).toHaveProperty('location');
      expect(noble).toHaveProperty('armyIds');
      expect(noble).toHaveProperty('children');
      expect(noble).toHaveProperty('age');
      expect(noble).toHaveProperty('status');
      expect(noble).toHaveProperty('birthTick');
    });

    it('should generate noble with correct name and familyId', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble.name).toBe('Svätopluk');
      expect(noble.familyId).toBe('family_1');
    });

    it('should generate noble with correct title and age', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble.title).toBe('Magnát');
      expect(noble.age).toBe(20);
    });

    it('should generate noble with correct location', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble.location).toBe('zupa_nitra');
    });

    it('should generate an alive noble by default', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble.status).toBe('alive');
    });

    it('should generate noble with no children or armies by default', () => {
      const noble = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');
      expect(noble.children).toEqual([]);
      expect(noble.armyIds).toEqual([]);
    });

    it('should be deterministic with same seed (excluding id)', () => {
      initRNG('noble-deterministic');
      const noble1 = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');

      initRNG('noble-deterministic');
      const noble2 = generateNoble('Svätopluk', 'family_1', 'Magnát', 20, 'zupa_nitra');

      const { id: _id1, ...rest1 } = noble1;
      const { id: _id2, ...rest2 } = noble2;
      expect(rest1).toEqual(rest2);
    });
  });

  describe('generateFamily', () => {
    const founder: Noble = {
      id: 'noble_founder',
      name: 'Mojmír II.',
      familyId: '',
      title: 'Kráľ',
      attributes: { combat: 8, diplomacy: 8, intelligence: 8, piety: 8, charisma: 8 },
      loyalty: 100,
      location: 'zupa_nitra',
      armyIds: [],
      children: [],
      coatOfArms: '',
      age: 35,
      status: 'alive',
      birthTick: 0
    };

    it('should generate family with all required properties', () => {
      const family = generateFamily('Mojmírovci', founder);
      expect(family).toHaveProperty('id');
      expect(family).toHaveProperty('name');
      expect(family).toHaveProperty('founder');
      expect(family).toHaveProperty('members');
      expect(family).toHaveProperty('reputation');
      expect(family).toHaveProperty('wealth');
      expect(family).toHaveProperty('coatOfArms');
      expect(family).toHaveProperty('history');
    });

    it('should generate family with correct name and founder', () => {
      const family = generateFamily('Mojmírovci', founder);
      expect(family.name).toBe('Mojmírovci');
      expect(family.founder).toBe(founder.id);
      expect(family.members).toEqual([founder.id]);
    });

    it('should generate family with valid reputation', () => {
      const family = generateFamily('Mojmírovci', founder);
      expect(family.reputation).toBeGreaterThanOrEqual(0);
      expect(family.reputation).toBeLessThanOrEqual(100);
    });

    it('should be deterministic with same seed', () => {
      initRNG('family-deterministic');
      const family1 = generateFamily('Mojmírovci', founder);

      initRNG('family-deterministic');
      const family2 = generateFamily('Mojmírovci', founder);

      expect(family1.reputation).toBe(family2.reputation);
      expect(family1.wealth).toBe(family2.wealth);
    });
  });

  describe('generateFaction', () => {
    it('should generate faction with all required properties', () => {
      const faction = generateFaction('Župani', 'loyal');
      expect(faction).toHaveProperty('id');
      expect(faction).toHaveProperty('name');
      expect(faction).toHaveProperty('moods');
      expect(faction).toHaveProperty('personality');
      expect(faction).toHaveProperty('currentTreaties');
      expect(faction).toHaveProperty('moodHistory');
    });

    it('should generate faction with correct name and personality', () => {
      const faction = generateFaction('Župani', 'loyal');
      expect(faction.name).toBe('Župani');
      expect(faction.personality).toBe('loyal');
    });

    it('should generate faction with moods in valid range', () => {
      const faction = generateFaction('Župani', 'loyal');
      for (const value of Object.values(faction.moods)) {
        expect(value).toBeGreaterThanOrEqual(0);
        expect(value).toBeLessThanOrEqual(100);
      }
    });

    it('should be deterministic with same seed', () => {
      initRNG('faction-deterministic');
      const faction1 = generateFaction('Župani', 'loyal');

      initRNG('faction-deterministic');
      const faction2 = generateFaction('Župani', 'loyal');

      expect(faction1.moods).toEqual(faction2.moods);
    });
  });

  describe('generateZupa', () => {
    it('should generate zupa with all required properties', () => {
      const zupa = generateZupa('Nitra', 'noble_1');
      expect(zupa).toHaveProperty('id');
      expect(zupa).toHaveProperty('name');
      expect(zupa).toHaveProperty('prosperity');
      expect(zupa).toHaveProperty('food');
      expect(zupa).toHaveProperty('defense');
      expect(zupa).toHaveProperty('loyalty');
      expect(zupa).toHaveProperty('owner');
      expect(zupa).toHaveProperty('neighbors');
      expect(zupa).toHaveProperty('specialization');
      expect(zupa).toHaveProperty('population');
      expect(zupa).toHaveProperty('recruitmentPool');
      expect(zupa).toHaveProperty('recruitmentRate');
      expect(zupa).toHaveProperty('garrison');
    });

    it('should generate zupa with correct name and owner', () => {
      const zupa = generateZupa('Nitra', 'noble_1');
      expect(zupa.name).toBe('Nitra');
      expect(zupa.owner).toBe('noble_1');
    });

    it('should generate zupa with valid prosperity and loyalty', () => {
      const zupa = generateZupa('Nitra', 'noble_1');
      expect(zupa.prosperity).toBeGreaterThanOrEqual(0);
      expect(zupa.prosperity).toBeLessThanOrEqual(100);
      expect(zupa.loyalty).toBeGreaterThanOrEqual(0);
      expect(zupa.loyalty).toBeLessThanOrEqual(100);
    });

    it('should keep the given neighbors', () => {
      const zupa = generateZupa('Nitra', 'noble_1', ['zupa_devin', 'zupa_trnava']);
      expect(zupa.neighbors).toEqual(['zupa_devin', 'zupa_trnava']);
    });

    it('should be deterministic with same seed', () => {
      initRNG('zupa-deterministic');
      const zupa1 = generateZupa('Nitra', 'noble_1');

      initRNG('zupa-deterministic');
      const zupa2 = generateZupa('Nitra', 'noble_1');

      expect(zupa1).toEqual(zupa2);
    });
  });

  describe('generateArmy', () => {
    const units = { lightInfantry: 10, heavyInfantry: 5, archers: 5, lightCavalry: 2, heavyCavalry: 0 };

    it('should generate army with all required properties', () => {
      const army = generateArmy('noble_1', 'zupa_nitra', units);
      expect(army).toHaveProperty('id');
      expect(army).toHaveProperty('commanderId');
      expect(army).toHaveProperty('units');
      expect(army).toHaveProperty('morale');
      expect(army).toHaveProperty('location');
      expect(army).toHaveProperty('stance');
      expect(army).toHaveProperty('upkeep');
    });

    it('should generate army with correct commander and location', () => {
      const army = generateArmy('noble_1', 'zupa_nitra', units);
      expect(army.commanderId).toBe('noble_1');
      expect(army.location).toBe('zupa_nitra');
    });

    it('should generate army with idle stance by default', () => {
      const army = generateArmy('noble_1', 'zupa_nitra', units);
      expect(army.stance).toBe('idle');
    });

    it('should compute upkeep from unit counts', () => {
      const army = generateArmy('noble_1', 'zupa_nitra', units);
      // lightInfantry:1, heavyInfantry:2, archers:2, lightCavalry:3, heavyCavalry:4 (per unit, gold/month)
      const expectedUpkeep = 10 * 1 + 5 * 2 + 5 * 2 + 2 * 3;
      expect(army.upkeep).toBe(expectedUpkeep);
    });

    it('should default to zero units when none are given', () => {
      const army = generateArmy('noble_1', 'zupa_nitra');
      expect(army.units).toEqual({ lightInfantry: 0, heavyInfantry: 0, archers: 0, lightCavalry: 0, heavyCavalry: 0 });
      expect(army.upkeep).toBe(0);
    });

    it('should be deterministic with same seed', () => {
      initRNG('army-deterministic');
      const army1 = generateArmy('noble_1', 'zupa_nitra', units);

      initRNG('army-deterministic');
      const army2 = generateArmy('noble_1', 'zupa_nitra', units);

      expect(army1.morale).toBe(army2.morale);
      expect(army1.upkeep).toBe(army2.upkeep);
    });
  });

  describe('generateInitialState', () => {
    it('should generate GameState with all required properties', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(state).toHaveProperty('tick');
      expect(state).toHaveProperty('year');
      expect(state).toHaveProperty('seed');
      expect(state).toHaveProperty('scenario');
      expect(state).toHaveProperty('player');
      expect(state).toHaveProperty('nobles');
      expect(state).toHaveProperty('families');
      expect(state).toHaveProperty('factions');
      expect(state).toHaveProperty('zupy');
      expect(state).toHaveProperty('armies');
      expect(state).toHaveProperty('wars');
      expect(state).toHaveProperty('treaties');
      expect(state).toHaveProperty('events');
      expect(state).toHaveProperty('resources');
      expect(state).toHaveProperty('religion');
      expect(state).toHaveProperty('gameOver');
      expect(state).toHaveProperty('saveVersion');
    });

    it('should generate state with correct seed and scenario', () => {
      const state = generateInitialState('prežitie', 'my-seed');
      expect(state.seed).toBe('my-seed');
      expect(state.scenario).toBe('prežitie');
    });

    it('should generate state with initial tick 0 and year 902', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(state.tick).toBe(0);
      expect(state.year).toBe(902);
    });

    it('should generate state with Mojmír II. as ruler of the Mojmírovci dynasty', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      const ruler = state.nobles.find(n => n.id === state.player.currentRuler);
      const dynasty = state.families.find(f => f.id === state.player.dynasty);

      expect(ruler).toBeDefined();
      expect(ruler?.name).toBe(INITIAL_RULER_NAME);
      expect(dynasty).toBeDefined();
      expect(dynasty?.name).toBe(INITIAL_DYNASTY_NAME);
    });

    it('should generate state with exactly 11 zupy', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(Object.keys(state.zupy).length).toBe(11);
    });

    it('should generate state with all 11 named zupy', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      const zupaNames = Object.values(state.zupy).map(z => z.name);
      MORAVIAN_ZUPY.forEach(name => {
        expect(zupaNames).toContain(name);
      });
    });

    it('should generate state with 6 factions', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(state.factions.length).toBe(6);
    });

    it('should generate state with all 6 named factions', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      const factionNames = state.factions.map(f => f.name);
      INITIAL_FACTIONS.forEach(f => {
        expect(factionNames).toContain(f.name);
      });
    });

    it('should generate state with initial resources', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(state.resources.gold).toBe(1000);
      expect(state.resources.food).toBe(100);
    });

    it('should generate state with balanced religion axis', () => {
      const state = generateInitialState('prežitie', 'test-seed');
      expect(state.religion.value).toBe(0);
    });

    it('should be deterministic with same seed', () => {
      const state1 = generateInitialState('prežitie', 'deterministic-seed');
      const state2 = generateInitialState('prežitie', 'deterministic-seed');

      expect(state1.player.currentRuler.length).toBeGreaterThan(0);
      expect(Object.keys(state1.zupy).sort()).toEqual(Object.keys(state2.zupy).sort());
      expect(state1.resources).toEqual(state2.resources);
    });

    it('should generate the same seed value regardless of RNG output', () => {
      const state1 = generateInitialState('prežitie', 'seed-1');
      const state2 = generateInitialState('prežitie', 'seed-2');

      expect(state1.seed).toBe('seed-1');
      expect(state2.seed).toBe('seed-2');
    });
  });
});
