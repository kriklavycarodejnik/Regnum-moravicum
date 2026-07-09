import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import {
  canStartHungarianWar,
  startHungarianWar,
  getAvailableBattleFronts,
  startBattleOnFront,
  playBattlePhase,
  autoResolveBattleOnFront,
  processWarCampaignTick,
} from '../src/core/engines/warCampaign';
import type { GameState } from '../src/core/types';

describe('War Campaign Bridge Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('warcampaign-test-seed');
    initialState = generateInitialState('prežitie', 'warcampaign-test-seed');
  });

  describe('canStartHungarianWar', () => {
    it('is false before year 905', () => {
      expect(canStartHungarianWar({ ...initialState, year: 904 })).toBe(false);
    });

    it('is true from year 905 with no existing campaign', () => {
      expect(canStartHungarianWar({ ...initialState, year: 905 })).toBe(true);
    });

    it('is false once a campaign is already active', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      expect(canStartHungarianWar(state)).toBe(false);
    });
  });

  describe('startHungarianWar', () => {
    it('populates warCampaign with objectives, armies and an opening log entry', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      expect(state.warCampaign).not.toBeNull();
      expect(state.warCampaign!.war.objectives.length).toBeGreaterThan(0);
      expect(state.warCampaign!.armies.length).toBeGreaterThan(0);
      expect(state.warCampaign!.log.length).toBe(1);
    });

    it('is a no-op when a campaign already exists', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      const again = startHungarianWar(state);
      expect(again).toBe(state);
    });
  });

  describe('getAvailableBattleFronts', () => {
    it('lists the occupied objective zupy as fronts', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      const fronts = getAvailableBattleFronts(state);
      expect(fronts.length).toBeGreaterThan(0);
      for (const front of fronts) {
        expect(state.warCampaign!.war.objectives.some((o) => o.zupaId === front.zupaId)).toBe(true);
      }
    });

    it('is empty when there is no active campaign', () => {
      expect(getAvailableBattleFronts(initialState)).toEqual([]);
    });
  });

  describe('startBattleOnFront / playBattlePhase', () => {
    it('starts a battle and plays it through to conclusion via manual phases', () => {
      let state = startHungarianWar({ ...initialState, year: 905 });
      const [front] = getAvailableBattleFronts(state);
      expect(front).toBeDefined();

      state = startBattleOnFront(state, front);
      expect(state.warCampaign!.activeBattle).not.toBeNull();
      expect(state.warCampaign!.activeBattle!.battle.currentPhase).toBe('attack');

      let iterations = 0;
      while (state.warCampaign!.activeBattle && iterations < 10) {
        state = playBattlePhase(state, 'melee');
        iterations++;
      }

      expect(state.warCampaign!.activeBattle).toBeNull();
      expect(iterations).toBeLessThan(10);
      // The battle concluding should always leave a longer campaign log than the opener.
      expect(state.warCampaign!.log.length).toBeGreaterThan(1);
    });

    it('is a no-op starting a battle when one is already active', () => {
      let state = startHungarianWar({ ...initialState, year: 905 });
      const [front] = getAvailableBattleFronts(state);
      state = startBattleOnFront(state, front);
      const again = startBattleOnFront(state, front);
      expect(again).toBe(state);
    });

    it('is a no-op playing a phase when there is no active battle', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      const newState = playBattlePhase(state, 'melee');
      expect(newState).toBe(state);
    });
  });

  describe('autoResolveBattleOnFront', () => {
    it('resolves a front instantly without leaving an active battle', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      const [front] = getAvailableBattleFronts(state);
      const newState = autoResolveBattleOnFront(state, front);
      expect(newState.warCampaign!.activeBattle).toBeNull();
      expect(newState.warCampaign!.log.length).toBeGreaterThan(state.warCampaign!.log.length);
    });
  });

  describe('processWarCampaignTick', () => {
    it('is a no-op when there is no active campaign', () => {
      const newState = processWarCampaignTick(initialState);
      expect(newState).toBe(initialState);
    });

    it('applies occupation looting to occupied objective zupy each tick', () => {
      const state = startHungarianWar({ ...initialState, year: 905 });
      const [front] = getAvailableBattleFronts(state);
      const goldBefore = state.resources.gold;
      const loyaltyBefore = state.zupy[front.zupaId].loyalty;

      const newState = processWarCampaignTick(state);
      expect(newState.resources.gold).toBeLessThanOrEqual(goldBefore);
      expect(newState.zupy[front.zupaId].loyalty).toBeLessThanOrEqual(loyaltyBefore);
    });
  });
});
