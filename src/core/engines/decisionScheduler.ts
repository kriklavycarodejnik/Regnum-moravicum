// Regnum Moravicum v2.1 - Decision Scheduler (Core Loop M2)
//
// Guarantees at least one player decision surfaces every tick, addressing
// the "empty tick" gameplay gap. Priority order per tick:
//   1. an event already pending (unresolved) in state.events
//   2. a faction demand opportunity (M4 hook, see generateFactionDemandEvent)
//   3. an investment opportunity (a zupa with a startable, affordable track)
//   4. the fallback pool (src/data/fallbackEvents.ts), cooldown-gated with a
//      last-resort ignore-cooldown fallback so this step can never be empty.
import type { GameState } from '../types/gameState';
import type { GameEvent } from '../types/events';
import type { ZupaInvestmentState } from '../types/investments';
import { rngWeighted } from '../utils/rng';
import { FALLBACK_EVENTS } from '../../data/fallbackEvents';
import { INVESTMENT_TRACKS } from '../../data/investments';
import { findInvestmentOpportunities, getInvestmentDuration } from './investmentEngine';
import { generateFactionDemandEvent } from './factionEngine';

export { generateFactionDemandEvent };

function hasPendingDecision(state: GameState): boolean {
  return state.events.some((e) => !e.triggered);
}

/**
 * Offers to start an investment on a zupa that can currently afford one.
 * Restricted to economy/fortification (church needs a rite choice, which
 * doesn't fit this 2-choice opportunity format) - church investments stay a
 * deliberate player action from the zupa panel.
 */
export function generateInvestmentOpportunityEvent(state: GameState): GameEvent | null {
  const opportunities = findInvestmentOpportunities(state).filter((o) => o.track !== 'church');
  const picked = rngWeighted(opportunities, () => 1);
  if (!picked) return null;

  const trackInfo = INVESTMENT_TRACKS[picked.track];
  const zupa = state.zupy[picked.zupaId];
  const duration = getInvestmentDuration(picked.currentLevel);
  const currentInvestment = state.investments[picked.zupaId];

  const startedInvestment: ZupaInvestmentState = {
    ...currentInvestment,
    active: { track: picked.track, startTick: state.tick, completeTick: state.tick + duration },
  };

  return {
    id: `decision_investment_${picked.zupaId}_${picked.track}_${state.tick}`,
    type: 'historical',
    title: `Príležitosť: ${trackInfo.name} v župe ${zupa.name}`,
    description: `Radcovia upozorňujú, že župa ${zupa.name} má prostriedky na rozvoj dráhy ${trackInfo.name.toLowerCase()} (${picked.cost} zlata, ${duration} mesiacov).`,
    conditions: [],
    choices: [
      {
        text: `Investovať do dráhy ${trackInfo.name.toLowerCase()}`,
        effects: { investments: { ...state.investments, [picked.zupaId]: startedInvestment } },
        resourceChanges: { gold: -picked.cost },
      },
      {
        text: 'Nechať zlato v pokladnici',
        effects: {},
      },
    ],
    triggered: false,
    triggeredTick: state.tick,
  };
}

function priorFallbackInstances(state: GameState, templateId: string): GameEvent[] {
  return state.events.filter((e) => e.id === templateId || e.id.startsWith(`${templateId}_`));
}

function isFallbackEligible(template: GameEvent, state: GameState): boolean {
  const prior = priorFallbackInstances(state, template.id);
  if (!template.cooldownTicks || prior.length === 0) return true;
  const lastTick = prior.reduce((max, e) => Math.max(max, e.triggeredTick ?? -Infinity), -Infinity);
  return lastTick === -Infinity || state.tick - lastTick >= template.cooldownTicks;
}

/**
 * Picks a fallback flavor event, respecting cooldowns. If every entry in the
 * (small, static) pool happens to be on cooldown simultaneously, cooldown is
 * ignored rather than returning null - the scheduler's guarantee always wins.
 */
export function pickFallbackEvent(state: GameState): GameEvent {
  const eligible = FALLBACK_EVENTS.filter((t) => isFallbackEligible(t, state));
  const pool = eligible.length > 0 ? eligible : FALLBACK_EVENTS;
  const picked = rngWeighted(pool, (t) => t.weight ?? 10)!;

  return {
    ...picked,
    id: `${picked.id}_${state.tick}`,
    triggered: false,
    triggeredTick: state.tick,
  };
}

/**
 * Ensures the current tick has at least one decision pending for the player.
 * No-op if one already exists; otherwise tries each source in priority
 * order and always finds one by the time it falls through to the pool.
 */
export function ensureDecision(state: GameState): GameState {
  if (hasPendingDecision(state)) return state;

  const factionDemand = generateFactionDemandEvent(state);
  if (factionDemand) {
    return { ...state, events: [...state.events, factionDemand] };
  }

  const investmentOpportunity = generateInvestmentOpportunityEvent(state);
  if (investmentOpportunity) {
    return { ...state, events: [...state.events, investmentOpportunity] };
  }

  const fallback = pickFallbackEvent(state);
  return { ...state, events: [...state.events, fallback] };
}

export default {
  ensureDecision,
  generateFactionDemandEvent,
  generateInvestmentOpportunityEvent,
  pickFallbackEvent,
};
