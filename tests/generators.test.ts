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
import { ZUPA_NAMES, FACTION_NAMES, INITIAL_RULER } from '../src/data/initialState';
import type { GameState, Noble, Family, Faction, Zupa, Army, Attributes } from '../src/core/types';

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

    it('should generate IDs with correct prefix', () => {
      const id = generateId();
      expect(id.startsWith('id_')).toBe(true);
    });

    it('should generate IDs of consistent length', () => {
      const id = generateId();
      // id_ + 8 hex characters = 11 total
      expect(id.length).toBe(11);
    });

    it('should be deterministic with same seed', () => {
      initRNG('id-deterministic');
      const sequence1 = Array.from({ length: 5 }, () => generateId());
      
      initRNG('id-deterministic');
      const sequence2 = Array.from({ length: 5 }, () => generateId());
      
      expect(sequence1).toEqual(sequence2);
    });
  });

  describe('generateAttributes', () => {
    it('should generate attributes with all required properties', () => {
      const attrs = generateAttributes();
      expect(attrs).toHaveProperty('strength');
      expect(attrs).toHaveProperty('intelligence');
      expect(attrs).toHaveProperty('charisma');
      expect(attrs).toHaveProperty('piety');
      expect(attrs).toHaveProperty('luck');
    });

    it('should generate attributes within valid range', () => {
      const attrs = generateAttributes();
      expect(attrs.strength).toBeGreaterThanOrEqual(1);
      expect(attrs.strength).toBeLessThanOrEqual(20);
      expect(attrs.intelligence).toBeGreaterThanOrEqual(1);
      expect(attrs.intelligence).toBeLessThanOrEqual(20);
      expect(attrs.charisma).toBeGreaterThanOrEqual(1);
      expect(attrs.charisma).toBeLessThanOrEqual(20);
      expect(attrs.piety).toBeGreaterThanOrEqual(1);
      expect(attrs.piety).toBeLessThanOrEqual(20);
      expect(attrs.luck).toBeGreaterThanOrEqual(1);
      expect(attrs.luck).toBeLessThanOrEqual(20);
    });

    it('should be deterministic with same seed', () => {
      initRNG('attrs-deterministic');
      const attrs1 = generateAttributes();
      
      initRNG('attrs-deterministic');
      const attrs2 = generateAttributes();
      
      expect(attrs1).toEqual(attrs2);
    });
  });

  describe('generateNoble', () => {
    it('should generate noble with all required properties', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble).toHaveProperty('id');
      expect(noble).toHaveProperty('name');
      expect(noble).toHaveProperty('familyId');
      expect(noble).toHaveProperty('gender');
      expect(noble).toHaveProperty('age');
      expect(noble).toHaveProperty('attributes');
      expect(noble).toHaveProperty('traits');
      expect(noble).toHaveProperty('alive');
      expect(noble).toHaveProperty('health');
      expect(noble).toHaveProperty('isRuler');
    });

    it('should generate noble with correct familyId', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble.familyId).toBe('Mojmírovci');
    });

    it('should generate noble with correct gender', () => {
      const maleNoble = generateNoble('Mojmírovci', 'male', 20);
      const femaleNoble = generateNoble('Mojmírovci', 'female', 20);
      expect(maleNoble.gender).toBe('male');
      expect(femaleNoble.gender).toBe('female');
    });

    it('should generate noble with correct age', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble.age).toBe(20);
    });

    it('should generate noble with valid health', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble.health).toBeGreaterThanOrEqual(0);
      expect(noble.health).toBeLessThanOrEqual(100);
    });

    it('should generate alive noble by default', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble.alive).toBe(true);
    });

    it('should generate noble with isRuler false by default', () => {
      const noble = generateNoble('Mojmírovci', 'male', 20);
      expect(noble.isRuler).toBe(false);
    });

    it('should be deterministic with same seed', () => {
      initRNG('noble-deterministic');
      const noble1 = generateNoble('Mojmírovci', 'male', 20);
      
      initRNG('noble-deterministic');
      const noble2 = generateNoble('Mojmírovci', 'male', 20);
      
      expect(noble1).toEqual(noble2);
    });
  });

  describe('generateFamily', () => {
    it('should generate family with all required properties', () => {
      const family = generateFamily('Mojmírovci', 'player');
      expect(family).toHaveProperty('id');
      expect(family).toHaveProperty('name');
      expect(family).toHaveProperty('factionId');
      expect(family).toHaveProperty('type');
      expect(family).toHaveProperty('prestige');
      expect(family).toHaveProperty('wealth');
      expect(family).toHaveProperty('influence');
      expect(family).toHaveProperty('motto');
      expect(family).toHaveProperty('coatOfArms');
    });

    it('should generate family with correct name', () => {
      const family = generateFamily('Mojmírovci', 'player');
      expect(family.name).toBe('Mojmírovci');
    });

    it('should generate family with correct factionId', () => {
      const family = generateFamily('Mojmírovci', 'player');
      expect(family.factionId).toBe('player');
    });

    it('should generate family with correct type', () => {
      const family = generateFamily('Mojmírovci', 'player');
      expect(family.type).toBe('player');
    });

    it('should generate family with valid prestige', () => {
      const family = generateFamily('Mojmírovci', 'player');
      expect(family.prestige).toBeGreaterThanOrEqual(0);
      expect(family.prestige).toBeLessThanOrEqual(100);
    });

    it('should be deterministic with same seed', () => {
      initRNG('family-deterministic');
      const family1 = generateFamily('Mojmírovci', 'player');
      
      initRNG('family-deterministic');
      const family2 = generateFamily('Mojmírovci', 'player');
      
      // Note: id will be different due to counter, so compare other properties
      expect(family1.name).toBe(family2.name);
      expect(family1.factionId).toBe(family2.factionId);
      expect(family1.type).toBe(family2.type);
      expect(family1.prestige).toBe(family2.prestige);
    });
  });

  describe('generateFaction', () => {
    it('should generate faction with all required properties', () => {
      const faction = generateFaction('Župani');
      expect(faction).toHaveProperty('id');
      expect(faction).toHaveProperty('name');
      expect(faction).toHaveProperty('description');
      expect(faction).toHaveProperty('color');
      expect(faction).toHaveProperty('strength');
      expect(faction).toHaveProperty('influence');
      expect(faction).toHaveProperty('relationToPlayer');
    });

    it('should generate faction with correct name', () => {
      const faction = generateFaction('Župani');
      expect(faction.name).toBe('Župani');
    });

    it('should generate faction with valid strength', () => {
      const faction = generateFaction('Župani');
      expect(faction.strength).toBeGreaterThanOrEqual(0);
      expect(faction.strength).toBeLessThanOrEqual(100);
    });

    it('should generate faction with valid relationToPlayer', () => {
      const faction = generateFaction('Župani');
      expect(faction.relationToPlayer).toBeGreaterThanOrEqual(-100);
      expect(faction.relationToPlayer).toBeLessThanOrEqual(100);
    });

    it('should be deterministic with same seed', () => {
      initRNG('faction-deterministic');
      const faction1 = generateFaction('Župani');
      
      initRNG('faction-deterministic');
      const faction2 = generateFaction('Župani');
      
      expect(faction1).toEqual(faction2);
    });
  });

  describe('generateZupa', () => {
    it('should generate zupa with all required properties', () => {
      const zupa = generateZupa('Nitra', 'player', 0, 0);
      expect(zupa).toHaveProperty('id');
      expect(zupa).toHaveProperty('name');
      expect(zupa).toHaveProperty('factionId');
      expect(zupa).toHaveProperty('x');
      expect(zupa).toHaveProperty('y');
      expect(zupa).toHaveProperty('prosperity');
      expect(zupa).toHaveProperty('loyalty');
      expect(zupa).toHaveProperty('garrison');
      expect(zupa).toHaveProperty('taxLevel');
      expect(zupa).toHaveProperty('recruitmentPool');
      expect(zupa).toHaveProperty('connectedZupas');
    });

    it('should generate zupa with correct name', () => {
      const zupa = generateZupa('Nitra', 'player', 0, 0);
      expect(zupa.name).toBe('Nitra');
    });

    it('should generate zupa with correct coordinates', () => {
      const zupa = generateZupa('Nitra', 'player', 10, 20);
      expect(zupa.x).toBe(10);
      expect(zupa.y).toBe(20);
    });

    it('should generate zupa with valid prosperity', () => {
      const zupa = generateZupa('Nitra', 'player', 0, 0);
      expect(zupa.prosperity).toBeGreaterThanOrEqual(0);
      expect(zupa.prosperity).toBeLessThanOrEqual(100);
    });

    it('should generate zupa with valid loyalty', () => {
      const zupa = generateZupa('Nitra', 'player', 0, 0);
      expect(zupa.loyalty).toBeGreaterThanOrEqual(0);
      expect(zupa.loyalty).toBeLessThanOrEqual(100);
    });

    it('should be deterministic with same seed', () => {
      initRNG('zupa-deterministic');
      const zupa1 = generateZupa('Nitra', 'player', 0, 0);
      
      initRNG('zupa-deterministic');
      const zupa2 = generateZupa('Nitra', 'player', 0, 0);
      
      expect(zupa1).toEqual(zupa2);
    });
  });

  describe('generateArmy', () => {
    it('should generate army with all required properties', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army).toHaveProperty('id');
      expect(army).toHaveProperty('name');
      expect(army).toHaveProperty('factionId');
      expect(army).toHaveProperty('zupaId');
      expect(army).toHaveProperty('status');
      expect(army).toHaveProperty('units');
      expect(army).toHaveProperty('morale');
      expect(army).toHaveProperty('experience');
      expect(army).toHaveProperty('formation');
      expect(army).toHaveProperty('commanderId');
    });

    it('should generate army with correct name', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army.name).toBe('Army1');
    });

    it('should generate army with correct factionId', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army.factionId).toBe('player');
    });

    it('should generate army with correct zupaId', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army.zupaId).toBe('Nitra');
    });

    it('should generate army with correct status', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army.status).toBe('active');
    });

    it('should generate army with valid morale', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(army.morale).toBeGreaterThanOrEqual(0);
      expect(army.morale).toBeLessThanOrEqual(100);
    });

    it('should generate army with empty units array', () => {
      const army = generateArmy('Army1', 'player', 'Nitra', 'active');
      expect(Array.isArray(army.units)).toBe(true);
      expect(army.units.length).toBe(0);
    });

    it('should be deterministic with same seed', () => {
      initRNG('army-deterministic');
      const army1 = generateArmy('Army1', 'player', 'Nitra', 'active');
      
      initRNG('army-deterministic');
      const army2 = generateArmy('Army1', 'player', 'Nitra', 'active');
      
      expect(army1).toEqual(army2);
    });
  });

  describe('generateInitialState', () => {
    it('should generate GameState with all required properties', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state).toHaveProperty('version');
      expect(state).toHaveProperty('seed');
      expect(state).toHaveProperty('tick');
      expect(state).toHaveProperty('year');
      expect(state).toHaveProperty('month');
      expect(state).toHaveProperty('player');
      expect(state).toHaveProperty('nobles');
      expect(state).toHaveProperty('families');
      expect(state).toHaveProperty('factions');
      expect(state).toHaveProperty('zupas');
      expect(state).toHaveProperty('armies');
      expect(state).toHaveProperty('wars');
      expect(state).toHaveProperty('treaties');
      expect(state).toHaveProperty('events');
      expect(state).toHaveProperty('resources');
      expect(state).toHaveProperty('religionAxis');
      expect(state).toHaveProperty('scenario');
    });

    it('should generate state with correct seed', () => {
      const state = generateInitialState('my-seed', 'standard');
      expect(state.seed).toBe('my-seed');
    });

    it('should generate state with correct scenario', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.scenario).toBe('standard');
    });

    it('should generate state with initial tick 0', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.tick).toBe(0);
    });

    it('should generate state with correct initial year', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.year).toBe(902);
    });

    it('should generate state with correct initial month', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.month).toBe(1);
    });

    it('should generate state with player object', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.player).toHaveProperty('factionId');
      expect(state.player).toHaveProperty('familyId');
      expect(state.player.factionId).toBe('player');
      expect(state.player.familyId).toBe('Mojmírovci');
    });

    it('should generate state with 11 zupas', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.zupas.length).toBe(11);
    });

    it('should generate state with all 11 zupa names', () => {
      const state = generateInitialState('test-seed', 'standard');
      const zupaNames = state.zupas.map(z => z.name);
      ZUPA_NAMES.forEach(name => {
        expect(zupaNames).toContain(name);
      });
    });

    it('should generate state with 6 factions', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.factions.length).toBe(6);
    });

    it('should generate state with all 6 faction names', () => {
      const state = generateInitialState('test-seed', 'standard');
      const factionNames = state.factions.map(f => f.name);
      FACTION_NAMES.forEach(name => {
        expect(factionNames).toContain(name);
      });
    });

    it('should generate state with initial ruler', () => {
      const state = generateInitialState('test-seed', 'standard');
      const ruler = state.nobles.find(n => n.isRuler);
      expect(ruler).toBeDefined();
      expect(ruler?.name).toBe(INITIAL_RULER.name);
    });

    it('should generate state with initial resources', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.resources).toHaveProperty('gold');
      expect(state.resources).toHaveProperty('food');
      expect(state.resources).toHaveProperty('wood');
      expect(state.resources).toHaveProperty('stone');
      expect(state.resources).toHaveProperty('iron');
      expect(state.resources.gold).toBeGreaterThan(0);
      expect(state.resources.food).toBeGreaterThan(0);
    });

    it('should generate state with religionAxis', () => {
      const state = generateInitialState('test-seed', 'standard');
      expect(state.religionAxis).toBeGreaterThanOrEqual(-100);
      expect(state.religionAxis).toBeLessThanOrEqual(100);
    });

    it('should be deterministic with same seed', () => {
      const state1 = generateInitialState('deterministic-seed', 'standard');
      const state2 = generateInitialState('deterministic-seed', 'standard');
      
      // Remove potentially non-deterministic fields
      const { tick: t1, ...rest1 } = state1;
      const { tick: t2, ...rest2 } = state2;
      
      expect(rest1).toEqual(rest2);
    });

    it('should generate different states with different seeds', () => {
      const state1 = generateInitialState('seed-1', 'standard');
      const state2 = generateInitialState('seed-2', 'standard');
      
      // At least some fields should be different
      expect(state1.seed).not.toBe(state2.seed);
    });
  });
});
