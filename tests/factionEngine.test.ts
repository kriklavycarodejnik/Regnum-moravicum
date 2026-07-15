// Regnum Moravicum - Faction Agenda Automaton Tests (Core Loop M4)
import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG } from '../src/core/utils/rng';
import { generateInitialState } from '../src/core/utils/generators';
import { migrateSaveData } from '../src/core/utils/migrations';
import {
  computeNextAgendaState,
  computeSatisfactionTarget,
  processFactionAgendas,
  triggerRebellion,
  generateFactionDemandEvent,
} from '../src/core/engines/factionEngine';
import type { GameState } from '../src/core/types';

describe('Faction Agenda Automaton', () => {
  let initialState: GameState;

  beforeEach(() => {
    initRNG('faction-test-seed');
    initialState = generateInitialState('prežitie', 'faction-test-seed');
  });

  describe('initial state', () => {
    it('assigns every faction a CALM agenda at satisfaction 50', () => {
      for (const faction of initialState.factions) {
        expect(initialState.factionAgendas[faction.id]).toEqual({
          goalType: expect.any(String),
          satisfaction: 50,
          state: 'CALM',
        });
      }
    });

    it('maps canon faction names to their documented goal types', () => {
      const byName = Object.fromEntries(
        initialState.factions.map((f) => [f.name, initialState.factionAgendas[f.id].goalType])
      );
      expect(byName['Župani']).toBe('territory');
      expect(byName['Cyrilometodskí Kňazi']).toBe('church');
      expect(byName['Nemeckí Kolonisti']).toBe('trade');
      expect(byName['Maďarské zvyšky']).toBe('raiding');
      expect(byName['Bogatovci']).toBe('power');
    });
  });

  describe('computeNextAgendaState (hysteresis)', () => {
    it('escalates CALM -> DEMANDING exactly at the raw threshold', () => {
      expect(computeNextAgendaState('CALM', 61)).toBe('CALM');
      expect(computeNextAgendaState('CALM', 59)).toBe('DEMANDING');
    });

    it('does not de-escalate DEMANDING -> CALM until satisfaction clears threshold + hysteresis', () => {
      expect(computeNextAgendaState('DEMANDING', 61)).toBe('DEMANDING'); // 60 < 61 <= 65, still DEMANDING
      expect(computeNextAgendaState('DEMANDING', 66)).toBe('CALM');
    });

    it('does not flicker for small oscillations right at the boundary', () => {
      // Sitting exactly at the escalation threshold from DEMANDING should stay DEMANDING,
      // not bounce back to CALM.
      expect(computeNextAgendaState('DEMANDING', 60)).toBe('DEMANDING');
      expect(computeNextAgendaState('DEMANDING', 63)).toBe('DEMANDING');
    });

    it('escalates all the way down through multiple thresholds in one call if satisfaction craters', () => {
      expect(computeNextAgendaState('CALM', 5)).toBe('ACTING');
    });

    it('de-escalates ACTING -> THREATENING only once satisfaction clears threshold + hysteresis', () => {
      expect(computeNextAgendaState('ACTING', 18)).toBe('ACTING');
      expect(computeNextAgendaState('ACTING', 21)).toBe('THREATENING');
    });
  });

  describe('computeSatisfactionTarget', () => {
    it('territory target tracks average zupa loyalty', () => {
      const state: GameState = {
        ...initialState,
        zupy: Object.fromEntries(Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, loyalty: 80 }])),
      };
      expect(computeSatisfactionTarget('territory', state)).toBe(80);
    });

    it('church target tracks average church investment level', () => {
      const state: GameState = {
        ...initialState,
        investments: Object.fromEntries(
          Object.entries(initialState.investments).map(([id, inv]) => [id, { ...inv, church: 3 }])
        ),
      };
      expect(computeSatisfactionTarget('church', state)).toBe(60);
    });

    it('power target rises as player prestige falls', () => {
      const lowPrestige = computeSatisfactionTarget('power', { ...initialState, player: { ...initialState.player, prestige: 10 } });
      const highPrestige = computeSatisfactionTarget('power', { ...initialState, player: { ...initialState.player, prestige: 90 } });
      expect(lowPrestige).toBeGreaterThan(highPrestige);
    });
  });

  describe('processFactionAgendas', () => {
    it('drifts satisfaction by exactly the balance step per tick when below target', () => {
      const zupani = initialState.factions.find((f) => f.name === 'Župani')!;
      const lowLoyaltyState: GameState = {
        ...initialState,
        zupy: Object.fromEntries(Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, loyalty: 0 }])),
      };
      const next = processFactionAgendas(lowLoyaltyState);
      expect(next.factionAgendas[zupani.id].satisfaction).toBe(49);
    });

    it('emits a chronicle event when a faction crosses into DEMANDING', () => {
      const zupani = initialState.factions.find((f) => f.name === 'Župani')!;
      const almostDemanding: GameState = {
        ...initialState,
        events: [],
        zupy: Object.fromEntries(Object.entries(initialState.zupy).map(([id, z]) => [id, { ...z, loyalty: 0 }])),
        factionAgendas: {
          ...initialState.factionAgendas,
          [zupani.id]: { ...initialState.factionAgendas[zupani.id], satisfaction: 60 },
        },
      };
      const next = processFactionAgendas(almostDemanding);
      expect(next.factionAgendas[zupani.id].state).toBe('DEMANDING');
      expect(next.events.some((e) => e.id.includes(`faction_agenda_${zupani.id}_DEMANDING`))).toBe(true);
    });
  });

  describe('triggerRebellion', () => {
    it('resolves a battle via the existing battle engine and updates the target zupa', () => {
      const madari = initialState.factions.find((f) => f.name === 'Maďarské zvyšky')!;
      const weakestZupaId = Object.entries(initialState.zupy).sort((a, b) => a[1].loyalty - b[1].loyalty)[0][0];
      const beforeLoyalty = initialState.zupy[weakestZupaId].loyalty;

      const next = triggerRebellion(initialState, madari.id);

      expect(next.events.some((e) => e.id.startsWith(`rebellion_${madari.id}_`))).toBe(true);
      expect(next.zupy[weakestZupaId].loyalty).not.toBe(beforeLoyalty);
      expect(next.factionAgendas[madari.id].state).not.toBe('ACTING');
    });

    it('is a no-op for an unknown faction id', () => {
      const next = triggerRebellion(initialState, 'not-a-real-faction');
      expect(next).toBe(initialState);
    });
  });

  describe('generateFactionDemandEvent (M2 decision-scheduler hook)', () => {
    it('returns null when no faction is DEMANDING or THREATENING', () => {
      expect(generateFactionDemandEvent(initialState)).toBeNull();
    });

    it('offers the unhappiest demanding/threatening faction as a grant-or-refuse decision', () => {
      const zupani = initialState.factions.find((f) => f.name === 'Župani')!;
      const state: GameState = {
        ...initialState,
        factionAgendas: {
          ...initialState.factionAgendas,
          [zupani.id]: { ...initialState.factionAgendas[zupani.id], satisfaction: 40, state: 'DEMANDING' },
        },
      };
      const event = generateFactionDemandEvent(state);
      expect(event).not.toBeNull();
      expect(event!.choices).toHaveLength(2);
      expect(event!.id).toContain(zupani.id);
    });
  });

  describe('save migration', () => {
    it('backfills a CALM agenda per existing faction for pre-M4 saves', () => {
      const legacyState: any = generateInitialState('prežitie', 'legacy-faction-seed');
      delete legacyState.factionAgendas;

      const migrated = migrateSaveData({ state: legacyState, saveVersion: '2.3.0' });
      for (const faction of legacyState.factions) {
        expect(migrated.factionAgendas[faction.id]).toEqual({ goalType: expect.any(String), satisfaction: 50, state: 'CALM' });
      }
    });
  });

  describe('determinism', () => {
    it('produces the same agenda outcome for the same seed and starting state', () => {
      const stateA = processFactionAgendas(initialState);
      const stateB = processFactionAgendas(initialState);
      expect(stateA.factionAgendas).toEqual(stateB.factionAgendas);
    });
  });
});
