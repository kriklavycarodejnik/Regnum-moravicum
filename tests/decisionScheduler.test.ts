// Regnum Moravicum - Decision Scheduler Tests (Core Loop M2)
import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { processTick } from '../src/core/engines/tickEngine';
import { resolveEventChoice } from '../src/core/engines/eventEngine';
import { ensureDecision, pickFallbackEvent, generateInvestmentOpportunityEvent } from '../src/core/engines/decisionScheduler';
import { FALLBACK_EVENTS } from '../src/data/fallbackEvents';
import type { GameState } from '../src/core/types';

describe('Decision Scheduler', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('decision-test-seed');
    initialState = generateInitialState('prežitie', 'decision-test-seed');
  });

  describe('ensureDecision', () => {
    it('does nothing if a decision is already pending', () => {
      const withPending: GameState = {
        ...initialState,
        events: [{ ...FALLBACK_EVENTS[0], triggered: false }],
      };
      const next = ensureDecision(withPending);
      expect(next).toBe(withPending);
    });

    it('guarantees at least one unresolved event when none is pending', () => {
      const state: GameState = { ...initialState, events: [] };
      const next = ensureDecision(state);
      expect(next.events.some((e) => !e.triggered)).toBe(true);
    });

    it('prefers an investment opportunity over the fallback pool when one is affordable', () => {
      const state: GameState = { ...initialState, events: [], resources: { ...initialState.resources, gold: 999999 } };
      const next = ensureDecision(state);
      const added = next.events[next.events.length - 1];
      expect(added.id.startsWith('decision_investment_')).toBe(true);
    });

    it('falls back to the flavor pool when there is nothing to invest in', () => {
      const state: GameState = { ...initialState, events: [], resources: { ...initialState.resources, gold: 0 } };
      const next = ensureDecision(state);
      const added = next.events[next.events.length - 1];
      const isFallback = FALLBACK_EVENTS.some((t) => added.id.startsWith(t.id));
      expect(isFallback).toBe(true);
    });
  });

  describe('generateInvestmentOpportunityEvent', () => {
    it('never offers the church track (needs a rite choice)', () => {
      const state: GameState = { ...initialState, resources: { ...initialState.resources, gold: 999999 } };
      for (let i = 0; i < 20; i++) {
        const event = generateInvestmentOpportunityEvent({ ...state, tick: state.tick + i });
        if (event) expect(event.id).not.toContain('_church_');
      }
    });

    it('returns null when the treasury cannot afford any track', () => {
      const state: GameState = { ...initialState, resources: { ...initialState.resources, gold: 0 } };
      expect(generateInvestmentOpportunityEvent(state)).toBeNull();
    });
  });

  describe('pickFallbackEvent cooldown', () => {
    it('avoids repeating the same fallback template within its cooldown window', () => {
      let state: GameState = { ...initialState, events: [] };
      const seenBaseIds = new Set<string>();

      for (let i = 0; i < 8; i++) {
        const event = pickFallbackEvent(state);
        const baseId = FALLBACK_EVENTS.find((t) => event.id.startsWith(t.id))!.id;
        expect(seenBaseIds.has(baseId)).toBe(false);
        seenBaseIds.add(baseId);
        state = { ...state, tick: state.tick + 1, events: [...state.events, event] };
      }
    });

    it('never returns null even if (hypothetically) every entry were on cooldown', () => {
      const allOnCooldown: GameState = {
        ...initialState,
        tick: 100,
        events: FALLBACK_EVENTS.map((t) => ({ ...t, id: `${t.id}_99`, triggered: true, triggeredTick: 99 })),
      };
      expect(pickFallbackEvent(allOnCooldown)).toBeTruthy();
    });
  });

  describe('determinism', () => {
    it('produces the same decision for the same seed and starting state', () => {
      initRNG('same-seed');
      const stateA: GameState = { ...generateInitialState('prežitie', 'same-seed'), events: [] };
      initRNG('same-seed');
      const stateB: GameState = { ...generateInitialState('prežitie', 'same-seed'), events: [] };

      const nextA = ensureDecision(stateA);
      const nextB = ensureDecision(stateB);
      expect(nextA.events).toEqual(nextB.events);
    });
  });

  describe('tick pipeline integration', () => {
    it('processTick always produces a fresh unresolved decision, even after the previous one is resolved', () => {
      let state: GameState = { ...initialState, events: [] };
      for (let i = 0; i < 10; i++) {
        state = processTick(state);
        const pending = state.events.filter((e) => !e.triggered);
        expect(pending.length).toBeGreaterThan(0);

        // Resolve every pending decision before advancing, mirroring real play.
        for (const event of pending) {
          state = resolveEventChoice(state, event.id, 0);
        }
      }
    });
  });
});
