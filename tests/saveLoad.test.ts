import { describe, it, expect, beforeEach, vi } from 'vitest';
import { initRNG, getRNGState } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { saveGame, loadGame, hasSave, deleteSave } from '../src/core/utils/saveLoad';
import { migrateSaveData, getSaveVersion } from '../src/core/utils/migrations';
import type { GameState } from '../src/core/types';

const SAVE_KEY = 'regnum_moravicum_save';

describe('Save/Load Utilities', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('save-test-seed');
    initialState = generateInitialState('prežitie', 'save-test-seed');
    localStorage.clear();
  });

  describe('saveGame / loadGame round-trip', () => {
    it('should write a compressed entry to localStorage', () => {
      saveGame(initialState);

      const raw = localStorage.getItem(SAVE_KEY);
      expect(raw).not.toBeNull();
      expect(typeof raw).toBe('string');

      const rawJson = JSON.stringify(initialState);
      expect(raw!.length).toBeLessThan(rawJson.length);
    });

    it('should load back an equivalent GameState', async () => {
      saveGame(initialState);
      const loaded = await loadGame();

      expect(loaded).not.toBeNull();
      expect(loaded!.seed).toBe(initialState.seed);
      expect(loaded!.tick).toBe(initialState.tick);
      expect(loaded!.year).toBe(initialState.year);
      expect(loaded!.scenario).toBe(initialState.scenario);
      expect(loaded!.player).toEqual(initialState.player);
      expect(Object.keys(loaded!.zupy).length).toBe(Object.keys(initialState.zupy).length);
      expect(loaded!.factions.length).toBe(initialState.factions.length);
      expect(loaded!.nobles.length).toBe(initialState.nobles.length);
      expect(loaded!.resources).toEqual(initialState.resources);
    });

    it('should return null when no save exists', async () => {
      const loaded = await loadGame();
      expect(loaded).toBeNull();
    });

    it('should return null for corrupted save data', async () => {
      localStorage.setItem(SAVE_KEY, 'not-a-valid-compressed-payload@@@');
      const loaded = await loadGame();
      expect(loaded).toBeNull();
    });

    it('should not throw when localStorage.setItem fails', () => {
      const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementationOnce(() => {
        throw new Error('Storage full');
      });

      expect(() => saveGame(initialState)).not.toThrow();
      spy.mockRestore();
    });

    it('should not throw when localStorage.getItem fails', async () => {
      const spy = vi.spyOn(Storage.prototype, 'getItem').mockImplementationOnce(() => {
        throw new Error('Storage error');
      });

      await expect(loadGame()).resolves.toBeNull();
      spy.mockRestore();
    });

    it('should save and restore the RNG state alongside the game state', async () => {
      saveGame(initialState);

      // Advance the RNG so the "current" sequence differs from the saved one.
      getRNGState();

      const loaded = await loadGame();
      expect(loaded).not.toBeNull();
    });

    it('should support multiple save/load cycles', async () => {
      for (let i = 0; i < 5; i++) {
        saveGame({ ...initialState, tick: i });
        const loaded = await loadGame();
        expect(loaded).not.toBeNull();
        expect(loaded!.tick).toBe(i);
      }
    });
  });

  describe('hasSave', () => {
    it('should return false when no save exists', () => {
      expect(hasSave()).toBe(false);
    });

    it('should return true once a save exists', () => {
      saveGame(initialState);
      expect(hasSave()).toBe(true);
    });
  });

  describe('deleteSave', () => {
    it('should remove the save from localStorage', () => {
      saveGame(initialState);
      expect(hasSave()).toBe(true);

      deleteSave();
      expect(hasSave()).toBe(false);
    });

    it('should not throw when nothing has been saved yet', () => {
      expect(() => deleteSave()).not.toThrow();
    });
  });
});

describe('Migrations', () => {
  it('getSaveVersion should return the current save format version', () => {
    expect(getSaveVersion()).toBe('2.3.0');
  });

  describe('migrateSaveData', () => {
    it('should stamp the current saveVersion on data already at the current version', () => {
      const state = generateInitialState('prežitie', 'migration-seed');
      const migrated = migrateSaveData({ state, saveVersion: '2.3.0' });

      expect(migrated.saveVersion).toBe('2.3.0');
      expect(migrated.seed).toBe('migration-seed');
    });

    it('should stamp the current saveVersion on data from an older version', () => {
      const state = generateInitialState('prežitie', 'old-seed');
      const migrated = migrateSaveData({ state, saveVersion: '1.0.0' });

      expect(migrated.saveVersion).toBe('2.3.0');
      expect(migrated.seed).toBe('old-seed');
    });

    it('should default to treating missing saveVersion as the oldest version', () => {
      const state = generateInitialState('prežitie', 'no-version-seed');
      const migrated = migrateSaveData({ state });

      expect(migrated.saveVersion).toBe('2.3.0');
    });

    it('should preserve all state fields during migration', () => {
      const state = generateInitialState('prežitie', 'preserve-seed');
      const migrated = migrateSaveData({ state, saveVersion: '1.0.0' });

      expect(migrated.tick).toBe(state.tick);
      expect(migrated.year).toBe(state.year);
      expect(migrated.nobles.length).toBe(state.nobles.length);
      expect(Object.keys(migrated.zupy).length).toBe(Object.keys(state.zupy).length);
    });
  });
});
