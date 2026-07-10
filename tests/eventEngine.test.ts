import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import {
  checkEventConditions,
  generateRandomEvent,
  resolveEventChoice,
  processEvents,
} from '../src/core/engines/eventEngine';
import { HISTORICAL_EVENTS } from '../src/data/historicalEvents';
import type { GameState } from '../src/core/types';
import type { GameEvent } from '../src/core/types/events';

describe('Event Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('event-test-seed');
    initialState = generateInitialState('prežitie', 'event-test-seed');
  });

  describe('checkEventConditions', () => {
    it('returns true for an event with no conditions', () => {
      const event: GameEvent = { ...HISTORICAL_EVENTS[0], conditions: [] };
      expect(checkEventConditions(event, initialState)).toBe(true);
    });

    it('matches an exact year condition', () => {
      const event = HISTORICAL_EVENTS.find((e) => e.id === 'hist_papal_legation_903')!;
      expect(checkEventConditions(event, { ...initialState, year: 903 })).toBe(true);
      expect(checkEventConditions(event, { ...initialState, year: 904 })).toBe(false);
    });

    it('respects yearMin/yearMax bounds', () => {
      const event: GameEvent = {
        ...HISTORICAL_EVENTS[0],
        conditions: [{ yearMin: 905, yearMax: 910 }],
      };
      expect(checkEventConditions(event, { ...initialState, year: 904 })).toBe(false);
      expect(checkEventConditions(event, { ...initialState, year: 907 })).toBe(true);
      expect(checkEventConditions(event, { ...initialState, year: 911 })).toBe(false);
    });

    it('matches zupaLoyalty conditions against real zupa ids', () => {
      const zupaId = Object.keys(initialState.zupy)[0];
      const event: GameEvent = {
        ...HISTORICAL_EVENTS[0],
        conditions: [{ zupaLoyalty: { zupaId, min: 0 } }],
      };
      expect(checkEventConditions(event, initialState)).toBe(true);

      const event2: GameEvent = {
        ...HISTORICAL_EVENTS[0],
        conditions: [{ zupaLoyalty: { zupaId, min: 999 } }],
      };
      expect(checkEventConditions(event2, initialState)).toBe(false);
    });

    it('matches factionMood conditions by faction name', () => {
      const faction = initialState.factions[0];
      const event: GameEvent = {
        ...HISTORICAL_EVENTS[0],
        conditions: [{ factionMood: { factionId: faction.name, mood: 'loyalty', min: 0 } }],
      };
      expect(checkEventConditions(event, initialState)).toBe(true);
    });
  });

  describe('generateRandomEvent', () => {
    it('returns a repeatable event instance with a unique tick-suffixed id', () => {
      const state: GameState = { ...initialState, year: 906, tick: 5 };
      const generated = generateRandomEvent(state);
      expect(generated).not.toBeNull();
      expect(generated!.type).not.toBe('historical');
      expect(generated!.id).toMatch(/_5$/);
      expect(generated!.triggered).toBe(false);
      expect(generated!.triggeredTick).toBe(5);
    });

    it('never returns a historical event', () => {
      for (let tick = 0; tick < 20; tick++) {
        const generated = generateRandomEvent({ ...initialState, year: 906, tick });
        expect(generated?.type).not.toBe('historical');
      }
    });
  });

  describe('resolveEventChoice', () => {
    it('marks the event triggered and applies prestigeChange', () => {
      const event = HISTORICAL_EVENTS.find((e) => e.id === 'hist_bogata_conspiracy_915')!;
      const state: GameState = { ...initialState, events: [{ ...event, triggered: false }] };
      const prestigeBefore = state.player.prestige;

      const newState = resolveEventChoice(state, event.id, 0);
      const resolved = newState.events.find((e) => e.id === event.id)!;

      expect(resolved.triggered).toBe(true);
      expect(newState.player.prestige).toBe(prestigeBefore + 5);
    });

    it('applies moodChanges keyed by faction name, clamped 0-100', () => {
      const event = HISTORICAL_EVENTS.find((e) => e.id === 'hist_german_ultimatum_910')!;
      const faction = initialState.factions.find((f) => f.name === 'Nemeckí Kolonisti')!;
      const state: GameState = {
        ...initialState,
        factions: initialState.factions.map((f) =>
          f.id === faction.id ? { ...f, moods: { ...f.moods, loyalty: 95 } } : f
        ),
        events: [{ ...event, triggered: false }],
      };

      const newState = resolveEventChoice(state, event.id, 0);
      const updatedFaction = newState.factions.find((f) => f.id === faction.id)!;
      // loyalty +20 from a base of 95 should clamp at 100, not overflow
      expect(updatedFaction.moods.loyalty).toBe(100);
    });

    it('applies religionChange clamped to -100..100', () => {
      const event = HISTORICAL_EVENTS.find((e) => e.id === 'hist_byzantine_envoy_904')!;
      const state: GameState = {
        ...initialState,
        religion: { value: 90 },
        events: [{ ...event, triggered: false }],
      };

      const newState = resolveEventChoice(state, event.id, 0);
      expect(newState.religion.value).toBe(100);
    });

    it('applies resourceChanges as deltas floored at 0', () => {
      const event = HISTORICAL_EVENTS.find((e) => e.id === 'rand_bad_harvest')!;
      const state: GameState = {
        ...initialState,
        resources: { ...initialState.resources, food: 5, gold: 5 },
        events: [{ ...event, triggered: false }],
      };

      const newState = resolveEventChoice(state, event.id, 0);
      expect(newState.resources.food).toBe(0);
      expect(newState.resources.gold).toBe(0);
    });

    it('is a no-op for an unknown eventId', () => {
      const newState = resolveEventChoice(initialState, 'nonexistent', 0);
      expect(newState).toBe(initialState);
    });

    it('is a no-op when the event is already triggered', () => {
      const event = HISTORICAL_EVENTS[0];
      const state: GameState = { ...initialState, events: [{ ...event, triggered: true }] };
      const newState = resolveEventChoice(state, event.id, 0);
      expect(newState).toBe(state);
    });

    it('queues a follow-up event via nextEvent', () => {
      const followUp = HISTORICAL_EVENTS[1];
      const event: GameEvent = {
        ...HISTORICAL_EVENTS[0],
        choices: [{ text: 'Continue', effects: {}, nextEvent: followUp.id }],
        triggered: false,
      };
      const state: GameState = { ...initialState, events: [event] };

      const newState = resolveEventChoice(state, event.id, 0);
      expect(newState.events.some((e) => e.id === followUp.id && !e.triggered)).toBe(true);
    });
  });

  describe('processEvents', () => {
    it('spawns a due historical event exactly once', () => {
      const state: GameState = { ...initialState, year: 903, events: [] };
      const afterFirst = processEvents(state);
      expect(afterFirst.events.some((e) => e.id === 'hist_papal_legation_903')).toBe(true);

      const afterSecond = processEvents(afterFirst);
      const matches = afterSecond.events.filter((e) => e.id === 'hist_papal_legation_903');
      expect(matches.length).toBe(1);
    });

    it('does not spawn a historical event before its year', () => {
      const state: GameState = { ...initialState, year: 902, events: [] };
      const newState = processEvents(state);
      expect(newState.events.some((e) => e.id === 'hist_papal_legation_903')).toBe(false);
    });

    it('does not spawn a random event while one is already pending', () => {
      const pending: GameEvent = { ...HISTORICAL_EVENTS[0], id: 'hist_papal_legation_903', triggered: false };
      const state: GameState = { ...initialState, year: 906, events: [pending] };

      let sawExtra = false;
      let s = state;
      for (let i = 0; i < 30; i++) {
        s = processEvents({ ...s, tick: s.tick + 1 });
        if (s.events.filter((e) => !e.triggered).length > 1) {
          sawExtra = true;
          break;
        }
      }
      expect(sawExtra).toBe(false);
    });
  });

  describe('chainOnly story events', () => {
    it('are never spawned by the automatic historical scan, even when their year is unconditioned', () => {
      let s: GameState = { ...initialState, year: 902, events: [] };
      for (let year = 902; year <= 920; year++) {
        s = processEvents({ ...s, year });
      }
      const chainOnlyIds = HISTORICAL_EVENTS.filter((e) => e.chainOnly).map((e) => e.id);
      for (const id of chainOnlyIds) {
        expect(s.events.some((e) => e.id === id)).toBe(false);
      }
    });

    it('are never returned by generateRandomEvent', () => {
      for (let tick = 0; tick < 50; tick++) {
        const generated = generateRandomEvent({ ...initialState, year: 910, tick });
        expect(generated?.chainOnly).not.toBe(true);
      }
    });

    it('accepting the Byzantine marriage proposal queues the wedding as the next event', () => {
      const proposal = HISTORICAL_EVENTS.find((e) => e.id === 'byz_bride_proposal_906')!;
      const state: GameState = { ...initialState, events: [{ ...proposal, triggered: false }] };

      const newState = resolveEventChoice(state, proposal.id, 0);
      expect(newState.events.some((e) => e.id === 'byz_bride_wedding_907' && !e.triggered)).toBe(true);
    });

    it('declining the Byzantine marriage proposal queues the insult event instead', () => {
      const proposal = HISTORICAL_EVENTS.find((e) => e.id === 'byz_bride_proposal_906')!;
      const state: GameState = { ...initialState, events: [{ ...proposal, triggered: false }] };

      const newState = resolveEventChoice(state, proposal.id, 1);
      expect(newState.events.some((e) => e.id === 'byz_bride_insult_907' && !e.triggered)).toBe(true);
      expect(newState.events.some((e) => e.id === 'byz_bride_wedding_907')).toBe(false);
    });

    it('arresting the Bogata conspirators queues their trial', () => {
      const conspiracy = HISTORICAL_EVENTS.find((e) => e.id === 'hist_bogata_conspiracy_915')!;
      const state: GameState = { ...initialState, events: [{ ...conspiracy, triggered: false }] };

      const newState = resolveEventChoice(state, conspiracy.id, 0);
      expect(newState.events.some((e) => e.id === 'bogata_trial_916' && !e.triggered)).toBe(true);
    });

    it('watching the Bogata conspirators queues the uprising instead', () => {
      const conspiracy = HISTORICAL_EVENTS.find((e) => e.id === 'hist_bogata_conspiracy_915')!;
      const state: GameState = { ...initialState, events: [{ ...conspiracy, triggered: false }] };

      const newState = resolveEventChoice(state, conspiracy.id, 1);
      expect(newState.events.some((e) => e.id === 'bogata_uprising_917' && !e.triggered)).toBe(true);
    });
  });
});
