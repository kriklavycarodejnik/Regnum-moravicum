import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { decayReligionAxis, growPrestige, checkVictoryConditions } from '../src/core/engines/victoryEngine';
import type { GameState } from '../src/core/types';

describe('Victory Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('victory-test-seed');
    initialState = generateInitialState('prežitie', 'victory-test-seed');
  });

  describe('decayReligionAxis', () => {
    it('drifts a positive value down toward 0', () => {
      const state: GameState = { ...initialState, religion: { value: 30 } };
      const newState = decayReligionAxis(state);
      expect(newState.religion.value).toBe(28);
    });

    it('drifts a negative value up toward 0', () => {
      const state: GameState = { ...initialState, religion: { value: -30 } };
      const newState = decayReligionAxis(state);
      expect(newState.religion.value).toBe(-28);
    });

    it('does not overshoot past 0', () => {
      const state: GameState = { ...initialState, religion: { value: 1 } };
      const newState = decayReligionAxis(state);
      expect(newState.religion.value).toBe(0);
    });

    it('is a no-op at exactly 0', () => {
      const state: GameState = { ...initialState, religion: { value: 0 } };
      const newState = decayReligionAxis(state);
      expect(newState).toBe(state);
    });
  });

  describe('growPrestige', () => {
    it('grants prestige proportional to average zupa loyalty, synced to resources', () => {
      const zupy = Object.fromEntries(
        Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, loyalty: 100 }])
      );
      const state: GameState = { ...initialState, zupy };
      const before = state.player.prestige;
      const beforeResources = state.resources.prestige;

      const newState = growPrestige(state);
      expect(newState.player.prestige).toBe(before + 4);
      expect(newState.resources.prestige).toBe(beforeResources + 4);
    });

    it('is a no-op when average loyalty is too low to grant any prestige', () => {
      const zupy = Object.fromEntries(
        Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, loyalty: 10 }])
      );
      const state: GameState = { ...initialState, zupy };
      const newState = growPrestige(state);
      expect(newState).toBe(state);
    });
  });

  describe('checkVictoryConditions', () => {
    it('is a no-op once gameOver is already set', () => {
      const state: GameState = { ...initialState, gameOver: true, gameOverReason: 'already over' };
      const newState = checkVictoryConditions(state);
      expect(newState).toBe(state);
    });

    it('declares defeat when the dynasty has no living noble', () => {
      const state: GameState = {
        ...initialState,
        nobles: initialState.nobles.map((n) => (n.familyId === initialState.player.dynasty ? { ...n, status: 'dead' as const } : n)),
      };
      const newState = checkVictoryConditions(state);
      expect(newState.gameOver).toBe(true);
      expect(newState.gameOverVictory).toBe(false);
    });

    it('declares defeat when the dynasty owns no zupy', () => {
      const zupy = Object.fromEntries(
        Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, owner: 'someone-else' }])
      );
      const state: GameState = { ...initialState, zupy };
      const newState = checkVictoryConditions(state);
      expect(newState.gameOver).toBe(true);
      expect(newState.gameOverVictory).toBe(false);
    });

    it('declares victory once the target year is reached while still ruling', () => {
      const state: GameState = { ...initialState, year: 1000 };
      const newState = checkVictoryConditions(state);
      expect(newState.gameOver).toBe(true);
      expect(newState.gameOverVictory).toBe(true);
    });

    it('is a no-op mid-game with the dynasty alive and in control', () => {
      const state: GameState = { ...initialState, year: 950 };
      const newState = checkVictoryConditions(state);
      expect(newState).toBe(state);
    });
  });
});
