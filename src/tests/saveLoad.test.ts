n// Define QuotaExceededError for Node.js environment
class QuotaExceededError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "QuotaExceededError";
  }
}

// Regnum Moravicum - Save/Load Tests

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { saveGame, loadGame, hasSave, clearSave, getSaveMetadata, SAVE_KEY, GAME_VERSION } from '../save/storage';
import { IncompatibleSaveError } from '../save/types';
import type { War, ZupaWarState, Battle } from '../war/types';
import type { Army } from '../battle/types';

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => { store[key] = value; }),
    removeItem: vi.fn((key: string) => { delete store[key]; }),
    clear: vi.fn(() => { store = {}; }),
  };
})();

// Set up global localStorage
Object.defineProperty(global, 'localStorage', {
  value: localStorageMock,
});

const testData = {
  tick: 10,
  wars: [
    {
      id: 'war1',
      attackerFactionId: 'faction1',
      defenderFactionId: 'faction2',
      objectives: [],
      startTick: 0,
      timeoutTicks: 60,
      result: 'ongoing' as const,
    },
  ],
  battles: [
    {
      id: 'battle1',
      warId: 'war1',
      zupaId: 'zupa1',
      terrain: 'field' as const,
      attackerArmyId: 'army1',
      defenderArmyId: 'army2',
      currentPhase: 'attack' as const,
      phaseLogs: [],
      result: null,
      winnerArmyId: null,
      isAutoResolved: false,
      startTick: 0,
      seed: 'battle-seed',
      rngState: null,
    },
  ],
  armies: [
    {
      id: 'army1',
      factionId: 'faction1',
      size: 1000,
      morale: 80,
      commander: { id: 'cmd1', name: 'Commander 1', skill: 5 },
      composition: { infantry: 0.5, cavalry: 0.3, archers: 0.2 },
      locationZupaId: 'zupa1',
    },
  ],
  zupyWarState: [
    {
      zupaId: 'zupa1',
      controllerFactionId: 'faction1',
      occupierFactionId: null,
    },
  ],
  playerResources: { gold: 1000, prestige: 50 },
};

beforeEach(() => {
  // Clear any existing save
  clearSave();
  localStorageMock.clear();
});

afterEach(() => {
  // Clear save after each test
  clearSave();
  localStorageMock.clear();
});

describe('Save/Load System', () => {
  describe('saveGame', () => {
    it('should save game state to localStorage', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      expect(hasSave()).toBe(true);
    });

    it('should save with correct structure', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      const saved = localStorage.getItem(SAVE_KEY);
      expect(saved).not.toBeNull();

      const parsed = JSON.parse(saved!);
      expect(parsed.version).toBe(1);
      expect(parsed.gameVersion).toBe(GAME_VERSION);
      expect(parsed.data.tick).toBe(testData.tick);
      expect(parsed.data.wars.length).toBe(testData.wars.length);
      expect(parsed.data.battles.length).toBe(testData.battles.length);
      expect(parsed.data.armies.length).toBe(testData.armies.length);
      expect(parsed.data.zupyWarState.length).toBe(testData.zupyWarState.length);
    });

    it('should save with timestamp', () => {
      const beforeSave = Date.now();
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );
      const afterSave = Date.now();

      const saved = localStorage.getItem(SAVE_KEY);
      const parsed = JSON.parse(saved!);
      
      expect(parsed.timestamp).toBeGreaterThanOrEqual(beforeSave);
      expect(parsed.timestamp).toBeLessThanOrEqual(afterSave);
    });

    it('should throw error on QuotaExceededError', () => {
      // Mock localStorage to throw QuotaExceededError
      const originalSetItem = localStorage.setItem;
      localStorage.setItem = vi.fn(() => {
        throw new DOMException('Quota exceeded', 'QuotaExceededError');
      });

      expect(() => {
        saveGame(
          testData.tick,
          testData.wars as War[],
          testData.battles as Battle[],
          testData.armies as Army[],
          testData.zupyWarState as ZupaWarState[],
          testData.playerResources
        );
      }).toThrow('LocalStorage quota exceeded');

      // Restore original
      localStorage.setItem = originalSetItem;
    });
  });

  describe('loadGame', () => {
    it('should load saved game', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      const loaded = loadGame();
      
      expect(loaded.version).toBe(1);
      expect(loaded.gameVersion).toBe(GAME_VERSION);
      expect(loaded.data.tick).toBe(testData.tick);
      expect(loaded.data.wars.length).toBe(testData.wars.length);
      expect(loaded.data.battles.length).toBe(testData.battles.length);
      expect(loaded.data.armies.length).toBe(testData.armies.length);
      expect(loaded.data.zupyWarState.length).toBe(testData.zupyWarState.length);
      expect(loaded.data.playerResources.gold).toBe(testData.playerResources.gold);
      expect(loaded.data.playerResources.prestige).toBe(testData.playerResources.prestige);
    });

    it('should throw error when no save exists', () => {
      expect(() => loadGame()).toThrow('No saved game found');
    });

    it('should throw error for invalid JSON', () => {
      localStorage.setItem(SAVE_KEY, 'invalid json');
      
      expect(() => loadGame()).toThrow('Invalid save file format');
    });

    it('should throw error for invalid structure', () => {
      localStorage.setItem(SAVE_KEY, JSON.stringify({ version: 2 }));
      
      expect(() => loadGame()).toThrow('Invalid save file structure');
    });

    it('should throw IncompatibleSaveError for different version', () => {
      const saveData = {
        version: 1,
        timestamp: Date.now(),
        gameVersion: '0.2.0', // Different version
        data: { ...testData },
      };
      
      localStorage.setItem(SAVE_KEY, JSON.stringify(saveData));
      
      expect(() => loadGame()).toThrow(IncompatibleSaveError);
    });
  });

  describe('hasSave', () => {
    it('should return true when save exists', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      expect(hasSave()).toBe(true);
    });

    it('should return false when no save exists', () => {
      expect(hasSave()).toBe(false);
    });
  });

  describe('clearSave', () => {
    it('should clear save', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      expect(hasSave()).toBe(true);
      
      clearSave();
      
      expect(hasSave()).toBe(false);
    });
  });

  describe('getSaveMetadata', () => {
    it('should return metadata when save exists', () => {
      saveGame(
        testData.tick,
        testData.wars as War[],
        testData.battles as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      const metadata = getSaveMetadata();
      expect(metadata.hasSave).toBe(true);
      expect(metadata.timestamp).toBeDefined();
    });

    it('should return hasSave false when no save exists', () => {
      const metadata = getSaveMetadata();
      expect(metadata.hasSave).toBe(false);
      expect(metadata.timestamp).toBeUndefined();
    });

    it('should return hasSave true even for invalid JSON', () => {
      localStorage.setItem(SAVE_KEY, 'invalid json');
      
      const metadata = getSaveMetadata();
      expect(metadata.hasSave).toBe(true);
      expect(metadata.timestamp).toBeUndefined();
    });
  });

  describe('Round-trip Test', () => {
    it('should save and load data identically', () => {
      const originalData = {
        tick: 42,
        wars: [
          {
            id: 'war1',
            attackerFactionId: 'faction1',
            defenderFactionId: 'faction2',
            objectives: [{ zupaId: 'zupa1', type: 'expel' as const, completed: false }],
            startTick: 0,
            timeoutTicks: 60,
            result: 'ongoing' as const,
          },
        ],
        battles: [
          {
            id: 'battle1',
            warId: 'war1',
            zupaId: 'zupa1',
            terrain: 'field' as const,
            attackerArmyId: 'army1',
            defenderArmyId: 'army2',
            currentPhase: 'attack' as const,
            phaseLogs: [
              {
                phase: 'attack' as const,
                attackerAction: 'melee' as const,
                defenderAction: 'melee' as const,
                attackerLosses: 50,
                defenderLosses: 30,
                attackerMoraleChange: 5,
                defenderMoraleChange: -3,
                narration: ['Test sentence'],
              },
            ],
            result: null,
            winnerArmyId: null,
            isAutoResolved: false,
            startTick: 0,
            seed: 'battle-seed',
            rngState: { some: 'state' },
          },
        ],
        armies: [
          {
            id: 'army1',
            factionId: 'faction1',
            size: 1000,
            morale: 80,
            commander: { id: 'cmd1', name: 'Commander 1', skill: 5 },
            composition: { infantry: 0.5, cavalry: 0.3, archers: 0.2 },
            locationZupaId: 'zupa1',
          },
        ],
        zupyWarState: [
          {
            zupaId: 'zupa1',
            controllerFactionId: 'faction1',
            occupierFactionId: null,
          },
        ],
        playerResources: { gold: 1000, prestige: 50 },
      };

      saveGame(
        originalData.tick,
        originalData.wars as War[],
        originalData.battles as Battle[],
        originalData.armies as Army[],
        originalData.zupyWarState as ZupaWarState[],
        originalData.playerResources
      );

      const loaded = loadGame();
      
      expect(loaded.data.tick).toBe(originalData.tick);
      expect(loaded.data.wars).toEqual(originalData.wars);
      expect(loaded.data.battles).toEqual(originalData.battles);
      expect(loaded.data.armies).toEqual(originalData.armies);
      expect(loaded.data.zupyWarState).toEqual(originalData.zupyWarState);
      expect(loaded.data.playerResources).toEqual(originalData.playerResources);
    });
  });

  describe('Battle RNG State Test', () => {
    it('should save and restore battle with RNG state', () => {
      const battleWithState: Battle = {
        id: 'battle1',
        warId: 'war1',
        zupaId: 'zupa1',
        terrain: 'field' as const,
        attackerArmyId: 'army1',
        defenderArmyId: 'army2',
        currentPhase: 'counterattack' as const,
        phaseLogs: [
          {
            phase: 'attack' as const,
            attackerAction: 'melee' as const,
            defenderAction: 'melee' as const,
            attackerLosses: 50,
            defenderLosses: 30,
            attackerMoraleChange: 5,
            defenderMoraleChange: -3,
            narration: ['Test'],
          },
        ],
        result: null,
        winnerArmyId: null,
        isAutoResolved: false,
        startTick: 0,
        seed: 'battle-seed',
        rngState: { state: 'test-state', counter: 10 },
      };

      saveGame(
        10,
        testData.wars as War[],
        [battleWithState] as Battle[],
        testData.armies as Army[],
        testData.zupyWarState as ZupaWarState[],
        testData.playerResources
      );

      const loaded = loadGame();
      const loadedBattle = loaded.data.battles[0];
      
      expect(loadedBattle.rngState).toEqual(battleWithState.rngState);
    });
  });
});
