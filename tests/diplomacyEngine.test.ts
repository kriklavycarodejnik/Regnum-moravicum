import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { performDiplomaticAction, performMarriage, processDiplomacy } from '../src/core/engines/diplomacyEngine';
import type { GameState } from '../src/core/types';

describe('Diplomacy Engine', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('diplomacy-test-seed');
    initialState = generateInitialState('prežitie', 'diplomacy-test-seed');
  });

  describe('performDiplomaticAction', () => {
    it('gift: spends gold and raises trust/loyalty', () => {
      const faction = initialState.factions[0];
      const state: GameState = {
        ...initialState,
        resources: { ...initialState.resources, gold: 100 },
        factions: initialState.factions.map((f) =>
          f.id === faction.id ? { ...f, moods: { ...f.moods, trust: 50, loyalty: 50 } } : f
        ),
      };

      const newState = performDiplomaticAction(state, faction.id, 'gift');
      expect(newState.resources.gold).toBe(50);
      const updated = newState.factions.find((f) => f.id === faction.id)!;
      expect(updated.moods.trust).toBe(60);
      expect(updated.moods.loyalty).toBe(55);
    });

    it('gift: no-op when the treasury cannot afford it', () => {
      const faction = initialState.factions[0];
      const state: GameState = { ...initialState, resources: { ...initialState.resources, gold: 10 } };
      const newState = performDiplomaticAction(state, faction.id, 'gift');
      expect(newState).toBe(state);
    });

    it('threat: always raises fear', () => {
      const faction = initialState.factions[0];
      const state: GameState = {
        ...initialState,
        factions: initialState.factions.map((f) =>
          f.id === faction.id ? { ...f, moods: { ...f.moods, fear: 20 } } : f
        ),
      };
      const newState = performDiplomaticAction(state, faction.id, 'threat');
      const updated = newState.factions.find((f) => f.id === faction.id)!;
      expect(updated.moods.fear).toBe(35);
    });

    it('is a no-op for an unknown faction id', () => {
      const newState = performDiplomaticAction(initialState, 'nonexistent-faction', 'gift');
      expect(newState).toBe(initialState);
    });

    it('proposeNonAggression: creates a treaty and registers it on the faction when accepted', () => {
      const faction = initialState.factions.find((f) => f.personality === 'loyal')!;
      const state: GameState = {
        ...initialState,
        factions: initialState.factions.map((f) =>
          f.id === faction.id ? { ...f, moods: { ...f.moods, trust: 100 } } : f
        ),
      };

      const newState = performDiplomaticAction(state, faction.id, 'proposeNonAggression');
      const treaty = newState.treaties.find((t) => t.type === 'nonAggression' && t.parties.includes(faction.id));
      expect(treaty).toBeDefined();
      const updatedFaction = newState.factions.find((f) => f.id === faction.id)!;
      expect(updatedFaction.currentTreaties).toContain(treaty!.id);
    });
  });

  describe('performMarriage', () => {
    it('marries two eligible nobles and sets spouse both ways', () => {
      const n1 = { ...initialState.nobles[0], age: 20, spouse: undefined };
      const n2 = { ...initialState.nobles[0], id: 'noble_test_2', familyId: 'family_other', age: 22, spouse: undefined };
      const state: GameState = { ...initialState, nobles: [n1, n2, ...initialState.nobles.slice(1)] };

      const newState = performMarriage(state, n1.id, n2.id);
      const updated1 = newState.nobles.find((n) => n.id === n1.id)!;
      const updated2 = newState.nobles.find((n) => n.id === n2.id)!;
      expect(updated1.spouse).toBe(n2.id);
      expect(updated2.spouse).toBe(n1.id);
    });

    it('creates a marriage treaty between different families', () => {
      const n1 = { ...initialState.nobles[0], age: 20, spouse: undefined, familyId: 'family_a' };
      const n2 = { ...initialState.nobles[0], id: 'noble_test_2', familyId: 'family_b', age: 22, spouse: undefined };
      const state: GameState = { ...initialState, nobles: [n1, n2, ...initialState.nobles.slice(1)] };

      const newState = performMarriage(state, n1.id, n2.id);
      const treaty = newState.treaties.find((t) => t.type === 'marriage');
      expect(treaty).toBeDefined();
      expect(treaty!.parties).toEqual(expect.arrayContaining(['family_a', 'family_b']));
    });

    it('is a no-op when a noble is already married', () => {
      const n1 = { ...initialState.nobles[0], age: 20, spouse: 'someone-else' };
      const n2 = { ...initialState.nobles[0], id: 'noble_test_2', age: 22, spouse: undefined };
      const state: GameState = { ...initialState, nobles: [n1, n2, ...initialState.nobles.slice(1)] };

      const newState = performMarriage(state, n1.id, n2.id);
      expect(newState).toBe(state);
    });

    it('is a no-op for underage nobles', () => {
      const n1 = { ...initialState.nobles[0], age: 10, spouse: undefined };
      const n2 = { ...initialState.nobles[0], id: 'noble_test_2', age: 22, spouse: undefined };
      const state: GameState = { ...initialState, nobles: [n1, n2, ...initialState.nobles.slice(1)] };

      const newState = performMarriage(state, n1.id, n2.id);
      expect(newState).toBe(state);
    });
  });

  describe('processDiplomacy', () => {
    it('slowly raises loyalty for loyal-personality factions', () => {
      const faction = initialState.factions.find((f) => f.personality === 'loyal')!;
      const state: GameState = {
        ...initialState,
        factions: initialState.factions.map((f) =>
          f.id === faction.id ? { ...f, moods: { ...f.moods, loyalty: 50 } } : f
        ),
      };
      const newState = processDiplomacy(state);
      const updated = newState.factions.find((f) => f.id === faction.id)!;
      expect(updated.moods.loyalty).toBe(51);
    });

    it('is a pure function that does not mutate the input state', () => {
      const before = JSON.stringify(initialState);
      processDiplomacy(initialState);
      expect(JSON.stringify(initialState)).toBe(before);
    });
  });
});
