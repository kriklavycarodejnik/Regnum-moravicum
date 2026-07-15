// Regnum Moravicum v2.1 - Faction Agenda Automaton (Core Loop M4)
//
// Each faction tracks {goalType, satisfaction, state}. Satisfaction drifts
// each tick towards a goal-specific target (see computeSatisfactionTarget);
// the state machine (CALM -> DEMANDING -> THREATENING -> ACTING) escalates
// or de-escalates with a hysteresis band so it doesn't flicker right at a
// threshold. ACTING triggers a rebellion resolved through the existing
// battle-layer engine (src/battle) using core-scale (garrison-sized) armies,
// per the loosely-coupled core/battle-layer split documented in
// src/core/types/warCampaign.ts - not the scripted campaign system, which is
// purpose-built for one specific scenario.
import type { GameState } from '../types/gameState';
import type { Faction, FactionId, Zupa, ZupaId } from '../types/entities';
import type { GameEvent } from '../types/events';
import type { FactionAgendaState, FactionAgendaStateType, FactionGoalType } from '../types/factionAgenda';
import { GOAL_LABELS, resolveGoalType } from '../../data/factionAgendas';
import {
  BALANCE_FACTION_SATISFACTION_DRIFT,
  BALANCE_FACTION_DEMANDING_THRESHOLD,
  BALANCE_FACTION_THREATENING_THRESHOLD,
  BALANCE_FACTION_ACTING_THRESHOLD,
  BALANCE_FACTION_HYSTERESIS,
  BALANCE_FACTION_DEMAND_GRANTED_BONUS,
  BALANCE_FACTION_DEMAND_REFUSED_PENALTY,
} from '../../data/balance';
import type { Army as BattleArmy, Terrain } from '../../battle/types';
import { autoResolveAIvsAI } from '../../battle/autoResolve';

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** Backfills a CALM/50 agenda for any faction that doesn't have one yet. */
export function ensureFactionAgendas(state: GameState): GameState {
  const factionAgendas = { ...state.factionAgendas };
  let changed = false;
  for (const faction of state.factions) {
    if (!factionAgendas[faction.id]) {
      factionAgendas[faction.id] = { goalType: resolveGoalType(faction.name), satisfaction: 50, state: 'CALM' };
      changed = true;
    }
  }
  return changed ? { ...state, factionAgendas } : state;
}

function averageZupaLoyalty(state: GameState): number {
  const zupy = Object.values(state.zupy);
  if (zupy.length === 0) return 50;
  return zupy.reduce((sum, z) => sum + z.loyalty, 0) / zupy.length;
}

function averageInvestmentLevel(state: GameState, track: 'church' | 'economy' | 'fortification'): number {
  const values = Object.values(state.investments);
  if (values.length === 0) return 0;
  return values.reduce((sum, i) => sum + i[track], 0) / values.length;
}

/** Where a faction's satisfaction drifts towards, based on its goal and current world state. */
export function computeSatisfactionTarget(goalType: FactionGoalType, state: GameState): number {
  switch (goalType) {
    case 'territory':
      return clamp(averageZupaLoyalty(state), 0, 100);
    case 'church':
      return clamp(averageInvestmentLevel(state, 'church') * 20, 0, 100);
    case 'trade':
      return clamp(averageInvestmentLevel(state, 'economy') * 20, 0, 100);
    case 'raiding':
      return clamp(100 - averageInvestmentLevel(state, 'fortification') * 20, 0, 100);
    case 'power':
      return clamp(100 - state.player.prestige, 0, 100);
    default:
      return 50;
  }
}

function stepAgendaState(current: FactionAgendaStateType, satisfaction: number): FactionAgendaStateType {
  const H = BALANCE_FACTION_HYSTERESIS;
  const D = BALANCE_FACTION_DEMANDING_THRESHOLD;
  const T = BALANCE_FACTION_THREATENING_THRESHOLD;
  const A = BALANCE_FACTION_ACTING_THRESHOLD;

  switch (current) {
    case 'ACTING':
      return satisfaction > A + H ? 'THREATENING' : 'ACTING';
    case 'THREATENING':
      if (satisfaction < A) return 'ACTING';
      return satisfaction > T + H ? 'DEMANDING' : 'THREATENING';
    case 'DEMANDING':
      if (satisfaction < T) return 'THREATENING';
      return satisfaction > D + H ? 'CALM' : 'DEMANDING';
    case 'CALM':
    default:
      return satisfaction < D ? 'DEMANDING' : 'CALM';
  }
}

/** Applies stepAgendaState repeatedly so a large satisfaction jump (e.g. a rebellion outcome) can cross more than one boundary in a single call. */
export function computeNextAgendaState(current: FactionAgendaStateType, satisfaction: number): FactionAgendaStateType {
  let state = current;
  for (let i = 0; i < 4; i++) {
    const next = stepAgendaState(state, satisfaction);
    if (next === state) break;
    state = next;
  }
  return state;
}

function narrateTransition(state: GameState, faction: Faction, from: FactionAgendaStateType, to: FactionAgendaStateType): GameEvent {
  const escalating = ['CALM', 'DEMANDING', 'THREATENING', 'ACTING'].indexOf(to) > ['CALM', 'DEMANDING', 'THREATENING', 'ACTING'].indexOf(from);
  const descriptions: Record<FactionAgendaStateType, string> = {
    CALM: `Frakcia ${faction.name} sa upokojila a jej požiadavky na dvor ustali.`,
    DEMANDING: `Frakcia ${faction.name} začína otvorene žiadať pozornosť dvora.`,
    THREATENING: `Frakcia ${faction.name} vydáva dvoru ultimátum. Ich trpezlivosť dochádza.`,
    ACTING: `Frakcia ${faction.name} stráca trpezlivosť a chystá sa na otvorený odpor.`,
  };
  return {
    id: `faction_agenda_${faction.id}_${to}_${state.tick}`,
    type: 'diplomatic',
    title: `${faction.name}: ${escalating ? 'napätie rastie' : 'napätie klesá'}`,
    description: descriptions[to],
    conditions: [],
    choices: [],
    triggered: true,
    triggeredTick: state.tick,
  };
}

function isPlayerOwnedZupa(state: GameState, zupa: Zupa): boolean {
  const owner = state.nobles.find((n) => n.id === zupa.owner);
  return owner?.familyId === state.player.dynasty;
}

function pickRebellionTargetZupa(state: GameState): ZupaId | null {
  const playerZupy = Object.entries(state.zupy).filter(([, zupa]) => isPlayerOwnedZupa(state, zupa));
  if (playerZupy.length === 0) return null;
  playerZupy.sort((a, b) => a[1].loyalty - b[1].loyalty);
  return playerZupy[0][0];
}

function buildRebelArmy(faction: Faction, zupa: Zupa, tick: number): BattleArmy {
  return {
    id: `rebel_army_${faction.id}_${tick}`,
    factionId: faction.id,
    size: Math.round(80 + (100 - zupa.loyalty) * 4),
    morale: 60,
    commander: { id: `rebel_cmd_${faction.id}_${tick}`, name: `Vodca vzbury (${faction.name})`, skill: 4 },
    composition: { infantry: 0.7, cavalry: 0.1, archers: 0.2 },
    locationZupaId: zupa.id,
  };
}

function buildGarrisonArmy(zupa: Zupa, tick: number): BattleArmy {
  return {
    id: `garrison_army_${zupa.id}_${tick}`,
    factionId: 'moravian',
    size: Math.max(50, zupa.garrison * 5 + zupa.defense * 3),
    morale: 60 + Math.round(zupa.loyalty / 5),
    commander: { id: `garrison_cmd_${zupa.id}_${tick}`, name: 'Veliteľ posádky', skill: 5 },
    composition: { infantry: 0.6, cavalry: 0.2, archers: 0.2 },
    locationZupaId: zupa.id,
  };
}

/**
 * ACTING factions rebel: a garrison-scale rebel army spawns in the
 * player's weakest-loyalty zupa and is immediately auto-resolved against
 * that zupa's garrison via the existing battle engine (src/battle). Loss
 * hits the zupa's loyalty/defense; a suppressed rebellion restores some
 * loyalty and de-escalates the faction back to THREATENING either way (the
 * outburst vents pressure, but doesn't fully resolve the underlying goal).
 */
export function triggerRebellion(state: GameState, factionId: FactionId): GameState {
  const faction = state.factions.find((f) => f.id === factionId);
  const agenda = state.factionAgendas[factionId];
  if (!faction || !agenda) return state;

  const targetZupaId = pickRebellionTargetZupa(state);
  if (!targetZupaId) return state;
  const zupa = state.zupy[targetZupaId];

  const rebelArmy = buildRebelArmy(faction, zupa, state.tick);
  const garrisonArmy = buildGarrisonArmy(zupa, state.tick);
  const fortificationLevel = state.investments[targetZupaId]?.fortification ?? 0;
  const terrain: Terrain = fortificationLevel >= 2 ? 'fortress' : 'field';
  const warId = `rebellion_${faction.id}_${state.tick}`;

  const battle = autoResolveAIvsAI(rebelArmy, garrisonArmy, terrain, warId, zupa.id, state.tick);
  const rebelsWon = battle.winnerArmyId === rebelArmy.id;

  const updatedZupa: Zupa = rebelsWon
    ? { ...zupa, loyalty: clamp(zupa.loyalty - 15, 0, 100), garrison: Math.max(0, zupa.garrison - 5), defense: Math.max(0, zupa.defense - 10) }
    : { ...zupa, loyalty: clamp(zupa.loyalty + 5, 0, 100) };

  const nextSatisfaction = rebelsWon ? 30 : 45;
  const description = rebelsWon
    ? `Vzbura frakcie ${faction.name} v župe ${zupa.name} uspela — posádka bola porazená a kráľovská autorita v kraji oslabla.`
    : `Vzbura frakcie ${faction.name} v župe ${zupa.name} bola potlačená kráľovskou posádkou.`;

  const event: GameEvent = {
    id: `rebellion_${faction.id}_${zupa.id}_${state.tick}`,
    type: 'military',
    title: `Vzbura: ${faction.name} v župe ${zupa.name}`,
    description,
    conditions: [],
    choices: [],
    triggered: true,
    triggeredTick: state.tick,
  };

  return {
    ...state,
    zupy: { ...state.zupy, [targetZupaId]: updatedZupa },
    factionAgendas: {
      ...state.factionAgendas,
      [factionId]: { ...agenda, satisfaction: nextSatisfaction, state: computeNextAgendaState('ACTING', nextSatisfaction) },
    },
    events: [...state.events, event],
  };
}

/**
 * Per-tick pass: drift each faction's satisfaction towards its goal target,
 * step the state machine, narrate any transition, then resolve any faction
 * that just reached ACTING with a rebellion.
 */
export function processFactionAgendas(state: GameState): GameState {
  let newState = ensureFactionAgendas(state);
  const events: GameEvent[] = [];
  const nextAgendas: Record<FactionId, FactionAgendaState> = { ...newState.factionAgendas };
  const justActed: FactionId[] = [];

  for (const faction of newState.factions) {
    const agenda = nextAgendas[faction.id];
    if (!agenda) continue;

    const target = computeSatisfactionTarget(agenda.goalType, newState);
    const delta = Math.sign(target - agenda.satisfaction) * BALANCE_FACTION_SATISFACTION_DRIFT;
    const satisfaction = clamp(agenda.satisfaction + delta, 0, 100);
    const nextStateType = computeNextAgendaState(agenda.state, satisfaction);

    nextAgendas[faction.id] = { ...agenda, satisfaction, state: nextStateType };

    if (nextStateType !== agenda.state) {
      events.push(narrateTransition(newState, faction, agenda.state, nextStateType));
      if (nextStateType === 'ACTING') justActed.push(faction.id);
    }
  }

  newState = { ...newState, factionAgendas: nextAgendas };
  if (events.length > 0) {
    newState = { ...newState, events: [...newState.events, ...events] };
  }

  for (const factionId of justActed) {
    newState = triggerRebellion(newState, factionId);
  }

  return newState;
}

/**
 * Decision-scheduler hook (fills the M2 stub): surfaces the unhappiest
 * DEMANDING/THREATENING faction as a grant-or-refuse decision when nothing
 * else is pending for the tick.
 */
export function generateFactionDemandEvent(state: GameState): GameEvent | null {
  const candidates = Object.entries(state.factionAgendas ?? {}).filter(
    ([, agenda]) => agenda.state === 'DEMANDING' || agenda.state === 'THREATENING'
  );
  if (candidates.length === 0) return null;

  candidates.sort((a, b) => a[1].satisfaction - b[1].satisfaction);
  const [factionId, agenda] = candidates[0];
  const faction = state.factions.find((f) => f.id === factionId);
  if (!faction) return null;

  const goalLabel = GOAL_LABELS[agenda.goalType];
  const isThreatening = agenda.state === 'THREATENING';

  const grantedAgendas = {
    ...state.factionAgendas,
    [factionId]: { ...agenda, satisfaction: clamp(agenda.satisfaction + BALANCE_FACTION_DEMAND_GRANTED_BONUS, 0, 100) },
  };
  const refusedAgendas = {
    ...state.factionAgendas,
    [factionId]: { ...agenda, satisfaction: clamp(agenda.satisfaction - BALANCE_FACTION_DEMAND_REFUSED_PENALTY, 0, 100) },
  };

  return {
    id: `faction_demand_${factionId}_${state.tick}`,
    type: 'diplomatic',
    title: `${isThreatening ? 'Ultimátum' : 'Žiadosť'}: ${faction.name}`,
    description: `Frakcia ${faction.name} žiada pozornosť dvora ohľadom ${goalLabel}. ${
      isThreatening ? 'Ich trpezlivosť dochádza.' : 'Zatiaľ len naznačujú nespokojnosť.'
    }`,
    conditions: [],
    choices: [
      {
        text: 'Vyhovieť požiadavke',
        effects: { factionAgendas: grantedAgendas },
        moodChanges: { [faction.name]: { trust: 5 } },
      },
      {
        text: 'Odmietnuť požiadavku',
        effects: { factionAgendas: refusedAgendas },
        moodChanges: { [faction.name]: { anger: 5 } },
      },
    ],
    triggered: false,
    triggeredTick: state.tick,
  };
}

export default {
  ensureFactionAgendas,
  computeSatisfactionTarget,
  computeNextAgendaState,
  processFactionAgendas,
  triggerRebellion,
  generateFactionDemandEvent,
};
