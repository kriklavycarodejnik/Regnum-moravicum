// Regnum Moravicum - Investment Engine Tests (Core Loop M1)
import { describe, it, expect, beforeEach } from 'vitest';
import type { GameState } from '../src/core/types/gameState';
import type { Noble, Zupa } from '../src/core/types/entities';
import { initRNG } from '../src/core/utils/rng';
import { migrateSaveData } from '../src/core/utils/migrations';
import {
  getInvestmentCost,
  getInvestmentDuration,
  startInvestment,
  processInvestmentsTick,
  processEconomyIncome,
  findInvestmentOpportunities,
} from '../src/core/engines/investmentEngine';
import { MAX_INVESTMENT_LEVEL } from '../src/data/balance';

function makeNoble(overrides: Partial<Noble> = {}): Noble {
  return {
    id: 'noble_ruler',
    name: 'Mojmír II.',
    familyId: 'family_mojmirovci',
    title: 'Kráľ',
    attributes: {
      combat: 50, diplomacy: 50, intelligence: 50, piety: 50, charisma: 50,
      ambition: 50, education: 50, reputation: 50,
    },
    loyalty: 80,
    location: 'zupa_nitra',
    armyIds: [],
    children: [],
    coatOfArms: '',
    age: 35,
    status: 'alive',
    birthTick: 0,
    ...overrides,
  };
}

function makeZupa(id: string, overrides: Partial<Zupa> = {}): Zupa {
  return {
    id,
    name: 'Nitra',
    prosperity: 50,
    food: 100,
    defense: 30,
    loyalty: 60,
    owner: 'noble_ruler',
    neighbors: [],
    specialization: ['agriculture'],
    population: 60,
    recruitmentPool: 20,
    recruitmentRate: 5,
    garrison: 10,
    ...overrides,
  };
}

function makeState(overrides: Partial<GameState> = {}): GameState {
  return {
    tick: 0,
    year: 902,
    seed: 'test-seed',
    scenario: 'prežitie',
    player: { dynasty: 'family_mojmirovci', currentRuler: 'noble_ruler', prestige: 50, religionAxis: 0 },
    nobles: [makeNoble()],
    families: [],
    factions: [],
    zupy: { zupa_nitra: makeZupa('zupa_nitra') },
    armies: [],
    wars: [],
    treaties: [],
    events: [],
    resources: { gold: 1000, food: 100, wood: 50, stone: 50, iron: 30, prestige: 10 },
    religion: { value: 0 },
    gameOver: false,
    saveVersion: '2.2.0',
    warCampaign: null,
    investments: { zupa_nitra: { economy: 0, fortification: 0, church: 0, active: null } },
    ...overrides,
  };
}

describe('Investment Engine', () => {
  beforeEach(() => {
    initRNG('investment-test-seed');
  });

  describe('cost/duration curve', () => {
    it('grows cost and duration with level', () => {
      const cost0 = getInvestmentCost(0);
      const cost1 = getInvestmentCost(1);
      const cost4 = getInvestmentCost(4);
      expect(cost1).toBeGreaterThan(cost0);
      expect(cost4).toBeGreaterThan(cost1);

      const dur0 = getInvestmentDuration(0);
      const dur4 = getInvestmentDuration(4);
      expect(dur4).toBeGreaterThan(dur0);
    });
  });

  describe('startInvestment', () => {
    it('deducts gold and sets an active investment', () => {
      const state = makeState();
      const cost = getInvestmentCost(0);
      const next = startInvestment(state, 'zupa_nitra', 'economy');

      expect(next.resources.gold).toBe(1000 - cost);
      expect(next.investments.zupa_nitra.active?.track).toBe('economy');
      expect(next.investments.zupa_nitra.active?.completeTick).toBe(getInvestmentDuration(0));
    });

    it('is a no-op if a zupa is not owned by the player', () => {
      const state = makeState({
        nobles: [makeNoble(), makeNoble({ id: 'noble_rival', familyId: 'family_rival' })],
        zupy: { zupa_nitra: makeZupa('zupa_nitra', { owner: 'noble_rival' }) },
      });
      const next = startInvestment(state, 'zupa_nitra', 'economy');
      expect(next).toBe(state);
    });

    it('is a no-op if a zupa already has an active investment', () => {
      const state = makeState();
      const withActive = startInvestment(state, 'zupa_nitra', 'economy');
      const attempted = startInvestment(withActive, 'zupa_nitra', 'fortification');
      expect(attempted).toBe(withActive);
    });

    it('is a no-op if the treasury cannot cover the cost', () => {
      const state = makeState({ resources: { gold: 1, food: 0, wood: 0, stone: 0, iron: 0, prestige: 0 } });
      const next = startInvestment(state, 'zupa_nitra', 'economy');
      expect(next).toBe(state);
    });

    it('requires a rite for the church track', () => {
      const state = makeState();
      const next = startInvestment(state, 'zupa_nitra', 'church');
      expect(next).toBe(state);
    });

    it('refuses to start past the max level', () => {
      const state = makeState({
        investments: { zupa_nitra: { economy: MAX_INVESTMENT_LEVEL, fortification: 0, church: 0, active: null } },
      });
      const next = startInvestment(state, 'zupa_nitra', 'economy');
      expect(next).toBe(state);
    });
  });

  describe('processInvestmentsTick', () => {
    it('advances but does not complete before completeTick', () => {
      let state = startInvestment(makeState(), 'zupa_nitra', 'economy');
      state = { ...state, tick: state.investments.zupa_nitra.active!.completeTick - 1 };
      const next = processInvestmentsTick(state);
      expect(next.investments.zupa_nitra.active).not.toBeNull();
      expect(next.investments.zupa_nitra.economy).toBe(0);
    });

    it('completes at completeTick, bumps level, clears active, and applies effects', () => {
      let state = startInvestment(makeState(), 'zupa_nitra', 'fortification');
      const completeTick = state.investments.zupa_nitra.active!.completeTick;
      state = { ...state, tick: completeTick };

      const next = processInvestmentsTick(state);
      expect(next.investments.zupa_nitra.active).toBeNull();
      expect(next.investments.zupa_nitra.fortification).toBe(1);
      expect(next.zupy.zupa_nitra.defense).toBeGreaterThan(state.zupy.zupa_nitra.defense);
    });

    it('emits a chronicle event on completion', () => {
      let state = startInvestment(makeState(), 'zupa_nitra', 'economy');
      const completeTick = state.investments.zupa_nitra.active!.completeTick;
      state = { ...state, tick: completeTick };

      const next = processInvestmentsTick(state);
      expect(next.events.length).toBe(1);
      expect(next.events[0].triggered).toBe(true);
      expect(next.events[0].title).toContain('Hospodárstvo');
    });

    it('applies religion axis shift signed by the chosen rite', () => {
      let roman = startInvestment(makeState(), 'zupa_nitra', 'church', 'roman');
      let completeTick = roman.investments.zupa_nitra.active!.completeTick;
      roman = { ...roman, tick: completeTick };
      const romanResult = processInvestmentsTick(roman);
      expect(romanResult.religion.value).toBeLessThan(0);

      let byz = startInvestment(makeState(), 'zupa_nitra', 'church', 'byzantine');
      completeTick = byz.investments.zupa_nitra.active!.completeTick;
      byz = { ...byz, tick: completeTick };
      const byzResult = processInvestmentsTick(byz);
      expect(byzResult.religion.value).toBeGreaterThan(0);
    });
  });

  describe('processEconomyIncome', () => {
    it('adds no income at level 0', () => {
      const state = makeState();
      const next = processEconomyIncome(state);
      expect(next.resources.gold).toBe(state.resources.gold);
    });

    it('adds gold proportional to economy level', () => {
      const state = makeState({
        investments: { zupa_nitra: { economy: 3, fortification: 0, church: 0, active: null } },
      });
      const next = processEconomyIncome(state);
      expect(next.resources.gold).toBeGreaterThan(state.resources.gold);
    });
  });

  describe('findInvestmentOpportunities', () => {
    it('lists affordable, unowned-track opportunities for player zupy', () => {
      const state = makeState();
      const opportunities = findInvestmentOpportunities(state);
      expect(opportunities.length).toBeGreaterThan(0);
      expect(opportunities.every((o) => o.zupaId === 'zupa_nitra')).toBe(true);
    });

    it('excludes zupy with an active investment', () => {
      const state = startInvestment(makeState(), 'zupa_nitra', 'economy');
      expect(findInvestmentOpportunities(state)).toHaveLength(0);
    });
  });

  describe('save migration', () => {
    it('backfills default investment state for saves missing the field', () => {
      const legacyState: any = makeState();
      delete legacyState.investments;

      const migrated = migrateSaveData({ state: legacyState, saveVersion: '2.1.0' });
      expect(migrated.investments.zupa_nitra).toEqual({ economy: 0, fortification: 0, church: 0, active: null });
    });
  });

  describe('determinism', () => {
    it('produces identical results for the same starting state', () => {
      const stateA = startInvestment(makeState(), 'zupa_nitra', 'economy');
      const stateB = startInvestment(makeState(), 'zupa_nitra', 'economy');
      expect(stateA).toEqual(stateB);
    });
  });
});
