import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { saveGame, loadGame, hasSave, deleteSave, getSaveVersion, migrateSaveData } from '../src/core/utils/saveLoad';
import type { GameState } from '../src/core/types';

// Mock localStorage and IndexedDB
const mockLocalStorage = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => { store[key] = value; }),
    removeItem: vi.fn((key: string) => { delete store[key]; }),
    clear: vi.fn(() => { store = {}; }),
    get store() { return store; }
  };
})();

const mockIndexedDB = {
  open: vi.fn(),
  deleteDatabase: vi.fn(),
};

// Mock the global objects
vi.stubGlobal('localStorage', mockLocalStorage);
vi.stubGlobal('indexedDB', mockIndexedDB);

describe('Save/Load Utilities', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('save-test-seed');
    initialState = generateInitialState('save-test-seed', 'standard');
    // Clear mock storage before each test
    mockLocalStorage.clear();
    vi.clearAllMocks();
  });

  afterEach(() => {
    // Clean up any open databases
    vi.clearAllMocks();
  });

  describe('saveGame', () => {
    it('should save game state to localStorage', () => {
      saveGame(initialState);
      
      expect(mockLocalStorage.setItem).toHaveBeenCalled();
      expect(mockLocalStorage.setItem.mock.calls[0][0]).toBe('regnum_moravicum_save');
    });

    it('should save compressed data', () => {
      saveGame(initialState);
      
      const savedData = mockLocalStorage.getItem('regnum_moravicum_save');
      expect(savedData).not.toBeNull();
      // Compressed data should be a string
      expect(typeof savedData).toBe('string');
      // Compressed data should be shorter than raw JSON
      const rawJson = JSON.stringify(initialState);
      expect(savedData!.length).toBeLessThan(rawJson.length);
    });

    it('should include version in saved data', () => {
      saveGame(initialState);
      
      const savedData = mockLocalStorage.getItem('regnum_moravicum_save');
      expect(savedData).toContain('version');
    });

    it('should handle save errors gracefully', () => {
      // Make localStorage throw an error
      mockLocalStorage.setItem.mockImplementationOnce(() => {
        throw new Error('Storage full');
      });
      
      // Should not throw
      expect(() => saveGame(initialState)).not.toThrow();
    });
  });

  describe('loadGame', () => {
    it('should return null when no save exists', () => {
      const result = loadGame();
      expect(result).toBeNull();
    });

    it('should load and decompress saved game', () => {
      // First save a game
      saveGame(initialState);
      
      // Then load it
      const loadedState = loadGame();
      
      expect(loadedState).not.toBeNull();
      expect(loadedState).toHaveProperty('version');
      expect(loadedState).toHaveProperty('seed');
      expect(loadedState).toHaveProperty('tick');
    });

    it('should return null for corrupted save data', () => {
      // Save corrupted data
      mockLocalStorage.setItem('regnum_moravicum_save', 'invalid-data');
      
      const result = loadGame();
      expect(result).toBeNull();
    });

    it('should handle load errors gracefully', () => {
      // Make localStorage throw an error
      mockLocalStorage.getItem.mockImplementationOnce(() => {
        throw new Error('Storage error');
      });
      
      // Should not throw
      expect(() => loadGame()).not.toThrow();
      expect(loadGame()).toBeNull();
    });

    it('should load data with correct structure', () => {
      saveGame(initialState);
      const loadedState = loadGame();
      
      expect(loadedState).toHaveProperty('version');
      expect(loadedState).toHaveProperty('seed');
      expect(loadedState).toHaveProperty('tick');
      expect(loadedState).toHaveProperty('year');
      expect(loadedState).toHaveProperty('month');
      expect(loadedState).toHaveProperty('player');
      expect(loadedState).toHaveProperty('nobles');
      expect(loadedState).toHaveProperty('families');
      expect(loadedState).toHaveProperty('factions');
      expect(loadedState).toHaveProperty('zupas');
      expect(loadedState).toHaveProperty('armies');
      expect(loadedState).toHaveProperty('wars');
      expect(loadedState).toHaveProperty('treaties');
      expect(loadedState).toHaveProperty('events');
      expect(loadedState).toHaveProperty('resources');
      expect(loadedState).toHaveProperty('religionAxis');
    });
  });

  describe('hasSave', () => {
    it('should return false when no save exists', () => {
      expect(hasSave()).toBe(false);
    });

    it('should return true when save exists', () => {
      saveGame(initialState);
      expect(hasSave()).toBe(true);
    });

    it('should return false for empty save', () => {
      mockLocalStorage.setItem('regnum_moravicum_save', '');
      expect(hasSave()).toBe(false);
    });
  });

  describe('deleteSave', () => {
    it('should remove save from localStorage', () => {
      saveGame(initialState);
      expect(hasSave()).toBe(true);
      
      deleteSave();
      expect(hasSave()).toBe(false);
    });

    it('should handle delete errors gracefully', () => {
      // Make localStorage throw an error
      mockLocalStorage.removeItem.mockImplementationOnce(() => {
        throw new Error('Storage error');
      });
      
      // Should not throw
      expect(() => deleteSave()).not.toThrow();
    });
  });

  describe('getSaveVersion', () => {
    it('should return null when no save exists', () => {
      expect(getSaveVersion()).toBeNull();
    });

    it('should return version from saved data', () => {
      saveGame(initialState);
      const version = getSaveVersion();
      
      expect(version).not.toBeNull();
      expect(typeof version).toBe('string');
    });

    it('should return null for corrupted save data', () => {
      mockLocalStorage.setItem('regnum_moravicum_save', 'invalid-data');
      expect(getSaveVersion()).toBeNull();
    });
  });

  describe('migrateSaveData', () => {
    it('should handle current version without migration', () => {
      const currentState = { version: '2.1', ...initialState };
      const migrated = migrateSaveData(currentState);
      
      expect(migrated.version).toBe('2.1');
    });

    it('should migrate from older version', () => {
      const oldState = { 
        version: '1.0',
        seed: 'test',
        tick: 0,
        year: 902,
        month: 1
      };
      const migrated = migrateSaveData(oldState);
      
      expect(migrated.version).toBe('2.1');
    });

    it('should handle missing version field', () => {
      const stateWithoutVersion = { 
        seed: 'test',
        tick: 0
      };
      const migrated = migrateSaveData(stateWithoutVersion as any);
      
      expect(migrated.version).toBe('2.1');
    });

    it('should preserve all data during migration', () => {
      const oldState = { 
        version: '1.0',
        seed: 'test-seed',
        tick: 10,
        year: 903,
        month: 5,
        customField: 'custom-value'
      };
      const migrated = migrateSaveData(oldState);
      
      expect(migrated.seed).toBe('test-seed');
      expect(migrated.tick).toBe(10);
      expect(migrated.year).toBe(903);
      expect(migrated.month).toBe(5);
      expect((migrated as any).customField).toBe('custom-value');
    });
  });

  describe('Round-trip Test', () => {
    it('should save and load state without data loss', () => {
      saveGame(initialState);
      const loadedState = loadGame();
      
      expect(loadedState).not.toBeNull();
      
      // Compare key properties
      expect(loadedState!.seed).toBe(initialState.seed);
      expect(loadedState!.tick).toBe(initialState.tick);
      expect(loadedState!.year).toBe(initialState.year);
      expect(loadedState!.month).toBe(initialState.month);
      expect(loadedState!.scenario).toBe(initialState.scenario);
      
      // Compare player
      expect(loadedState!.player.factionId).toBe(initialState.player.factionId);
      expect(loadedState!.player.familyId).toBe(initialState.player.familyId);
      
      // Compare resources
      expect(loadedState!.resources.gold).toBe(initialState.resources.gold);
      expect(loadedState!.resources.food).toBe(initialState.resources.food);
      
      // Compare zupas count
      expect(loadedState!.zupas.length).toBe(initialState.zupas.length);
      
      // Compare factions count
      expect(loadedState!.factions.length).toBe(initialState.factions.length);
      
      // Compare nobles count
      expect(loadedState!.nobles.length).toBe(initialState.nobles.length);
    });

    it('should handle multiple save/load cycles', () => {
      for (let i = 0; i < 5; i++) {
        saveGame(initialState);
        const loadedState = loadGame();
        expect(loadedState).not.toBeNull();
        expect(loadedState!.seed).toBe(initialState.seed);
      }
    });
  });

  describe('Compression Test', () => {
    it('should compress large game states', () => {
      // Create a larger game state
      const largeState: GameState = {
        ...initialState,
        nobles: Array.from({ length: 100 }, (_, i) => ({
          id: `noble-${i}`,
          name: `Noble ${i}`,
          familyId: 'Mojmírovci',
          gender: i % 2 === 0 ? 'male' : 'female',
          age: 20 + i,
          attributes: { strength: 10, intelligence: 10, charisma: 10, piety: 10, luck: 10 },
          traits: [],
          alive: true,
          health: 100,
          isRuler: false
        })),
        armies: Array.from({ length: 20 }, (_, i) => ({
          id: `army-${i}`,
          name: `Army ${i}`,
          factionId: 'player',
          zupaId: 'Nitra',
          status: 'active',
          units: [{ type: 'peasant', count: 100, experience: 0 }],
          morale: 100,
          experience: 0,
          formation: 'shieldWall',
          commanderId: 'noble-0'
        }))
      };
      
      saveGame(largeState);
      const savedData = mockLocalStorage.getItem('regnum_moravicum_save');
      
      expect(savedData).not.toBeNull();
      
      // Compressed data should be significantly shorter than raw JSON
      const rawJson = JSON.stringify(largeState);
      const compressionRatio = savedData!.length / rawJson.length;
      
      // Should achieve at least some compression
      expect(compressionRatio).toBeLessThan(1);
    });
  });
});
