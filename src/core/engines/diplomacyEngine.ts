// Regnum Moravicum v2.1 - Diplomacy Engine (Phase 3 M3)
import type { GameState } from '../types/gameState';
import type { Faction, FactionPersonality, TreatyType, Treaty, Noble } from '../types/entities';
import { rngChance } from '../utils/rng';

export type DiplomaticActionType = 'gift' | 'threat' | 'proposeTrade' | 'proposeNonAggression' | 'proposeMilitaryPact';

const GIFT_COST = 50;

const TREATY_TYPE_BY_ACTION: Partial<Record<DiplomaticActionType, TreatyType>> = {
  proposeTrade: 'trade',
  proposeNonAggression: 'nonAggression',
  proposeMilitaryPact: 'military',
};

const TREATY_DURATION_TICKS: Record<TreatyType, number> = {
  trade: 36,
  nonAggression: 60,
  military: 60,
  marriage: 9999,
  vassal: 9999,
};

const PERSONALITY_ACCEPTANCE_BONUS: Record<FactionPersonality, number> = {
  loyal: 0.15,
  opportunist: 0.05,
  aggressive: -0.15,
  traitor: -0.05,
};

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function updateFaction(state: GameState, factionId: string, updater: (f: Faction) => Faction): GameState {
  return {
    ...state,
    factions: state.factions.map((f) => (f.id === factionId ? updater(f) : f)),
  };
}

/**
 * Spend gold to raise a faction's trust and loyalty. No-op if the treasury
 * can't cover the cost.
 */
function applyGift(state: GameState, faction: Faction): GameState {
  if (state.resources.gold < GIFT_COST) return state;

  let newState: GameState = {
    ...state,
    resources: { ...state.resources, gold: state.resources.gold - GIFT_COST },
  };
  newState = updateFaction(newState, faction.id, (f) => ({
    ...f,
    moods: { ...f.moods, trust: clamp(f.moods.trust + 10, 0, 100), loyalty: clamp(f.moods.loyalty + 5, 0, 100) },
  }));
  return newState;
}

/**
 * Intimidate a faction: reliably raises fear, but risks a backfire that
 * spikes anger and tanks trust.
 */
function applyThreat(state: GameState, faction: Faction): GameState {
  const backfires = rngChance(0.25);
  return updateFaction(state, faction.id, (f) => ({
    ...f,
    moods: {
      ...f.moods,
      fear: clamp(f.moods.fear + 15, 0, 100),
      trust: clamp(f.moods.trust - (backfires ? 15 : 5), 0, 100),
      anger: clamp(f.moods.anger + (backfires ? 15 : 0), 0, 100),
    },
  }));
}

function proposeTreaty(state: GameState, faction: Faction, action: DiplomaticActionType): GameState {
  const treatyType = TREATY_TYPE_BY_ACTION[action];
  if (!treatyType) return state;

  const acceptanceChance = clamp(
    faction.moods.trust / 100 + PERSONALITY_ACCEPTANCE_BONUS[faction.personality],
    0.05,
    0.95
  );

  if (!rngChance(acceptanceChance)) {
    return updateFaction(state, faction.id, (f) => ({
      ...f,
      moods: { ...f.moods, trust: clamp(f.moods.trust - 5, 0, 100) },
    }));
  }

  const treaty: Treaty = {
    id: `treaty_${treatyType}_${state.tick}_${faction.id}`,
    type: treatyType,
    parties: [state.player.currentRuler, faction.id],
    startTick: state.tick,
    endTick: state.tick + TREATY_DURATION_TICKS[treatyType],
    terms: {},
  };

  let newState: GameState = { ...state, treaties: [...state.treaties, treaty] };
  newState = updateFaction(newState, faction.id, (f) => ({
    ...f,
    currentTreaties: [...f.currentTreaties, treaty.id],
    moods: { ...f.moods, trust: clamp(f.moods.trust + 10, 0, 100) },
  }));
  return newState;
}

/**
 * Perform a player-initiated diplomatic action toward a faction.
 */
export function performDiplomaticAction(
  state: GameState,
  factionId: string,
  action: DiplomaticActionType
): GameState {
  const faction = state.factions.find((f) => f.id === factionId);
  if (!faction) return state;

  switch (action) {
    case 'gift':
      return applyGift(state, faction);
    case 'threat':
      return applyThreat(state, faction);
    case 'proposeTrade':
    case 'proposeNonAggression':
    case 'proposeMilitaryPact':
      return proposeTreaty(state, faction, action);
    default:
      return state;
  }
}

/**
 * Marry two eligible living nobles (age >= 16, unmarried). Creates a
 * marriage treaty between their families when they belong to different ones.
 */
export function performMarriage(state: GameState, nobleId1: string, nobleId2: string): GameState {
  if (nobleId1 === nobleId2) return state;

  const n1 = state.nobles.find((n) => n.id === nobleId1);
  const n2 = state.nobles.find((n) => n.id === nobleId2);
  if (!n1 || !n2) return state;
  if (n1.status !== 'alive' || n2.status !== 'alive') return state;
  if (n1.spouse || n2.spouse) return state;
  if (n1.age < 16 || n2.age < 16) return state;

  const nobles: Noble[] = state.nobles.map((n) => {
    if (n.id === n1.id) return { ...n, spouse: n2.id };
    if (n.id === n2.id) return { ...n, spouse: n1.id };
    return n;
  });

  let treaties = state.treaties;
  if (n1.familyId !== n2.familyId) {
    const treaty: Treaty = {
      id: `treaty_marriage_${state.tick}_${n1.id}_${n2.id}`,
      type: 'marriage',
      parties: [n1.familyId, n2.familyId],
      startTick: state.tick,
      endTick: state.tick + TREATY_DURATION_TICKS.marriage,
      terms: {},
    };
    treaties = [...state.treaties, treaty];
  }

  return { ...state, nobles, treaties };
}

/**
 * Passive per-tick AI drift, driven by each faction's personality archetype.
 */
export function processDiplomacy(state: GameState): GameState {
  let newState = state;

  for (const faction of state.factions) {
    switch (faction.personality) {
      case 'loyal':
        newState = updateFaction(newState, faction.id, (f) => ({
          ...f,
          moods: { ...f.moods, loyalty: clamp(f.moods.loyalty + 1, 0, 100) },
        }));
        break;
      case 'opportunist':
        if (state.player.prestige > 70) {
          newState = updateFaction(newState, faction.id, (f) => ({
            ...f,
            moods: { ...f.moods, trust: clamp(f.moods.trust + 2, 0, 100) },
          }));
        }
        break;
      case 'traitor':
        if (rngChance(0.05) && state.player.prestige < 40) {
          newState = updateFaction(newState, faction.id, (f) => ({
            ...f,
            moods: { ...f.moods, loyalty: clamp(f.moods.loyalty - 5, 0, 100), anger: clamp(f.moods.anger + 5, 0, 100) },
          }));
        }
        break;
      case 'aggressive':
        if (rngChance(0.05)) {
          newState = updateFaction(newState, faction.id, (f) => ({
            ...f,
            moods: { ...f.moods, anger: clamp(f.moods.anger + 5, 0, 100) },
          }));
        }
        break;
    }
  }

  return newState;
}

export default {
  processDiplomacy,
  performDiplomaticAction,
  performMarriage,
};
