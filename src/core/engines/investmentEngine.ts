// Regnum Moravicum v2.1 - Investment Engine (Core Loop M1)
//
// Each zupa has 3 shallow-but-wide investment tracks (economy/fortification/
// church, levels 0-5) instead of a building tree or tech tree. At most one
// investment can be in progress per zupa at a time. Completions push a
// GameEvent narration entry into state.events, following the same pattern
// ChronicleView already renders for historical/random events (see
// src/core/engines/eventEngine.ts and src/ui/components/ChronicleView.tsx).
import type { GameState } from '../types/gameState';
import type { Zupa, ZupaId } from '../types/entities';
import type { GameEvent } from '../types/events';
import type { ActiveInvestment, InvestmentTrack, ReligiousRite, ZupaInvestmentState } from '../types/investments';
import { INVESTMENT_TRACKS } from '../../data/investments';
import {
  MAX_INVESTMENT_LEVEL,
  BALANCE_INVESTMENT_BASE_COST,
  BALANCE_INVESTMENT_COST_GROWTH,
  BALANCE_INVESTMENT_BASE_DURATION,
  BALANCE_INVESTMENT_DURATION_GROWTH,
  BALANCE_ECONOMY_INCOME_PER_LEVEL,
  BALANCE_FORTIFICATION_DEFENSE_PER_LEVEL,
  BALANCE_CHURCH_LOYALTY_PER_LEVEL,
  BALANCE_CHURCH_RELIGION_AXIS_PER_LEVEL,
} from '../../data/balance';

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function createEmptyInvestmentState(): ZupaInvestmentState {
  return { economy: 0, fortification: 0, church: 0, active: null };
}

/** Ensures every zupa has an investment state, without touching existing entries. */
export function ensureInvestmentStates(state: GameState): GameState {
  const investments = { ...state.investments };
  let changed = false;
  for (const zupaId of Object.keys(state.zupy)) {
    if (!investments[zupaId]) {
      investments[zupaId] = createEmptyInvestmentState();
      changed = true;
    }
  }
  return changed ? { ...state, investments } : state;
}

/** Gold cost to advance a track from `currentLevel` to `currentLevel + 1`. */
export function getInvestmentCost(currentLevel: number): number {
  return Math.round(BALANCE_INVESTMENT_BASE_COST * Math.pow(BALANCE_INVESTMENT_COST_GROWTH, currentLevel));
}

/** Ticks required to advance a track from `currentLevel` to `currentLevel + 1`. */
export function getInvestmentDuration(currentLevel: number): number {
  return Math.round(BALANCE_INVESTMENT_BASE_DURATION * Math.pow(BALANCE_INVESTMENT_DURATION_GROWTH, currentLevel));
}

function isPlayerZupa(state: GameState, zupa: Zupa): boolean {
  const owner = state.nobles.find((n) => n.id === zupa.owner);
  return owner?.familyId === state.player.dynasty;
}

export interface InvestmentAvailability {
  zupaId: ZupaId;
  track: InvestmentTrack;
  cost: number;
  currentLevel: number;
}

/**
 * A zupa is eligible for a new investment if the player owns it, it has no
 * investment already running, and at least one track hasn't hit the level cap.
 */
export function getAvailableTracks(state: GameState, zupaId: ZupaId): InvestmentAvailability[] {
  const zupa = state.zupy[zupaId];
  const investment = state.investments[zupaId];
  if (!zupa || !investment || !isPlayerZupa(state, zupa) || investment.active) return [];

  return (Object.keys(INVESTMENT_TRACKS) as InvestmentTrack[])
    .filter((track) => investment[track] < MAX_INVESTMENT_LEVEL)
    .map((track) => ({
      zupaId,
      track,
      cost: getInvestmentCost(investment[track]),
      currentLevel: investment[track],
    }));
}

/** All zupy across the realm with at least one startable investment the player can afford. */
export function findInvestmentOpportunities(state: GameState): InvestmentAvailability[] {
  const opportunities: InvestmentAvailability[] = [];
  for (const zupaId of Object.keys(state.zupy)) {
    for (const option of getAvailableTracks(state, zupaId)) {
      if (option.cost <= state.resources.gold) {
        opportunities.push(option);
      }
    }
  }
  return opportunities;
}

/**
 * Start a new investment on a zupa's track. No-op (returns state unchanged)
 * if the zupa isn't owned by the player, already has an active investment,
 * the track is maxed out, or the treasury can't cover the cost.
 */
export function startInvestment(
  state: GameState,
  zupaId: ZupaId,
  track: InvestmentTrack,
  rite?: ReligiousRite
): GameState {
  const zupa = state.zupy[zupaId];
  const investment = state.investments[zupaId];
  if (!zupa || !investment) return state;
  if (!isPlayerZupa(state, zupa)) return state;
  if (investment.active) return state;
  if (investment[track] >= MAX_INVESTMENT_LEVEL) return state;
  if (track === 'church' && !rite) return state;

  const cost = getInvestmentCost(investment[track]);
  if (state.resources.gold < cost) return state;

  const duration = getInvestmentDuration(investment[track]);
  const active: ActiveInvestment = {
    track,
    startTick: state.tick,
    completeTick: state.tick + duration,
    rite,
  };

  return {
    ...state,
    resources: { ...state.resources, gold: state.resources.gold - cost },
    investments: {
      ...state.investments,
      [zupaId]: { ...investment, active },
    },
  };
}

function narrateCompletion(state: GameState, zupa: Zupa, track: InvestmentTrack, newLevel: number, rite?: ReligiousRite): GameEvent {
  const trackInfo = INVESTMENT_TRACKS[track];
  const riteText = track === 'church' ? (rite === 'byzantine' ? ' podľa byzantského rítu' : ' podľa rímskeho rítu') : '';
  return {
    id: `investment_${zupa.id}_${track}_${newLevel}_${state.tick}`,
    type: track === 'church' ? 'religious' : 'historical',
    title: `${trackInfo.name} v župe ${zupa.name} — úroveň ${newLevel}`,
    description: `Dráha ${trackInfo.name.toLowerCase()} v župe ${zupa.name} dosiahla úroveň ${newLevel}${riteText}. ${trackInfo.description}`,
    conditions: [],
    choices: [],
    triggered: true,
    triggeredTick: state.tick,
  };
}

function applyCompletionEffects(state: GameState, zupaId: ZupaId, track: InvestmentTrack, rite: ReligiousRite | undefined): GameState {
  let newState = state;

  if (track === 'fortification') {
    const zupa = newState.zupy[zupaId];
    newState = {
      ...newState,
      zupy: {
        ...newState.zupy,
        [zupaId]: { ...zupa, defense: clamp(zupa.defense + BALANCE_FORTIFICATION_DEFENSE_PER_LEVEL, 0, 100) },
      },
    };
  } else if (track === 'church') {
    const zupa = newState.zupy[zupaId];
    const religionDelta = rite === 'byzantine' ? BALANCE_CHURCH_RELIGION_AXIS_PER_LEVEL : -BALANCE_CHURCH_RELIGION_AXIS_PER_LEVEL;
    newState = {
      ...newState,
      zupy: {
        ...newState.zupy,
        [zupaId]: { ...zupa, loyalty: clamp(zupa.loyalty + BALANCE_CHURCH_LOYALTY_PER_LEVEL, 0, 100) },
      },
      religion: { value: clamp(newState.religion.value + religionDelta, -100, 100) },
    };
  }
  // economy: no immediate effect, feeds processEconomyIncome every subsequent tick.

  return newState;
}

/**
 * Advance every zupa's active investment by one tick; complete any that have
 * reached their completeTick (level+1, apply effects, emit a chronicle entry).
 */
export function processInvestmentsTick(state: GameState): GameState {
  let newState = ensureInvestmentStates(state);
  const events: GameEvent[] = [];

  for (const zupaIdKey of Object.keys(newState.investments)) {
    const investment = newState.investments[zupaIdKey];
    const active = investment.active;
    if (!active || newState.tick < active.completeTick) continue;

    const newLevel = investment[active.track] + 1;
    newState = {
      ...newState,
      investments: {
        ...newState.investments,
        [zupaIdKey]: { ...investment, [active.track]: newLevel, active: null },
      },
    };

    newState = applyCompletionEffects(newState, zupaIdKey, active.track, active.rite);
    events.push(narrateCompletion(newState, newState.zupy[zupaIdKey], active.track, newLevel, active.rite));
  }

  if (events.length > 0) {
    newState = { ...newState, events: [...newState.events, ...events] };
  }

  return newState;
}

/** Monthly gold income from economy-track levels. Fills the "empty tick" income gap. */
export function processEconomyIncome(state: GameState): GameState {
  let totalIncome = 0;
  for (const investment of Object.values(state.investments)) {
    totalIncome += investment.economy * BALANCE_ECONOMY_INCOME_PER_LEVEL;
  }
  if (totalIncome <= 0) return state;

  return {
    ...state,
    resources: { ...state.resources, gold: state.resources.gold + totalIncome },
  };
}

export default {
  createEmptyInvestmentState,
  ensureInvestmentStates,
  getInvestmentCost,
  getInvestmentDuration,
  getAvailableTracks,
  findInvestmentOpportunities,
  startInvestment,
  processInvestmentsTick,
  processEconomyIncome,
};
