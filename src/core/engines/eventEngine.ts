// Regnum Moravicum v2.1 - Event Engine (Phase 3 M1)
import type { GameState, Resources } from '../types/gameState';
import type { GameEvent, EventCondition } from '../types/events';
import type { Faction, FactionMoods, ZupaId } from '../types/entities';
import { rngChance, rngWeighted } from '../utils/rng';
import { HISTORICAL_EVENTS } from '../../data/historicalEvents';

const RANDOM_EVENT_CHANCE = 0.15;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function findFaction(state: GameState, key: string): Faction | undefined {
  return state.factions.find((f) => f.id === key || f.name === key);
}

function isAtWar(state: GameState): boolean {
  return state.wars.some((w) => w.status === 'ongoing') || state.warCampaign?.war.result === 'ongoing';
}

function conditionMatches(condition: EventCondition, state: GameState): boolean {
  if (condition.year !== undefined && state.year !== condition.year) return false;
  if (condition.yearMin !== undefined && state.year < condition.yearMin) return false;
  if (condition.yearMax !== undefined && state.year > condition.yearMax) return false;

  if (condition.factionMood) {
    const { factionId, mood, min, max } = condition.factionMood;
    const faction = findFaction(state, factionId);
    if (!faction) return false;
    const value = faction.moods[mood];
    if (min !== undefined && value < min) return false;
    if (max !== undefined && value > max) return false;
  }

  if (condition.nobleAttribute) {
    const { nobleId, attribute, min, max } = condition.nobleAttribute;
    const noble = state.nobles.find((n) => n.id === nobleId);
    if (!noble) return false;
    const value = noble.attributes[attribute];
    if (min !== undefined && value < min) return false;
    if (max !== undefined && value > max) return false;
  }

  if (condition.playerPrestige) {
    const { min, max } = condition.playerPrestige;
    if (min !== undefined && state.player.prestige < min) return false;
    if (max !== undefined && state.player.prestige > max) return false;
  }

  if (condition.zupaLoyalty) {
    const { zupaId, min, max } = condition.zupaLoyalty;
    const zupa = state.zupy[zupaId];
    if (!zupa) return false;
    if (min !== undefined && zupa.loyalty < min) return false;
    if (max !== undefined && zupa.loyalty > max) return false;
  }

  if (condition.zupaOwner) {
    const zupa = state.zupy[condition.zupaOwner.zupaId];
    if (!zupa) return false;
    if (condition.zupaOwner.owner !== undefined && zupa.owner !== condition.zupaOwner.owner) return false;
  }

  if (condition.atWar !== undefined && isAtWar(state) !== condition.atWar) return false;

  if (condition.hasTreaty) {
    const { factionId1, factionId2, type } = condition.hasTreaty;
    const has = state.treaties.some(
      (t) =>
        t.parties.includes(factionId1) &&
        t.parties.includes(factionId2) &&
        (!type || t.type === type)
    );
    if (!has) return false;
  }

  return true;
}

/**
 * Check whether all of an event's conditions currently hold (AND across the array).
 * An event with no conditions is always eligible.
 */
export function checkEventConditions(event: GameEvent, state: GameState): boolean {
  return event.conditions.every((condition) => conditionMatches(condition, state));
}

function priorInstances(state: GameState, templateId: string): GameEvent[] {
  return state.events.filter((e) => e.id === templateId || e.id.startsWith(`${templateId}_`));
}

function isEligible(template: GameEvent, state: GameState): boolean {
  if (!checkEventConditions(template, state)) return false;

  const prior = priorInstances(state, template.id);
  if (template.once && prior.length > 0) return false;

  if (template.cooldownTicks) {
    const lastTick = prior.reduce((max, e) => Math.max(max, e.triggeredTick ?? -Infinity), -Infinity);
    if (lastTick !== -Infinity && state.tick - lastTick < template.cooldownTicks) return false;
  }

  return true;
}

/**
 * Pick and instantiate a single eligible non-historical event, weighted by
 * `weight` (default 10). Returns null when no candidate is eligible.
 */
export function generateRandomEvent(state: GameState): GameEvent | null {
  const candidates = HISTORICAL_EVENTS.filter((t) => t.type !== 'historical' && isEligible(t, state));
  const picked = rngWeighted(candidates, (t) => t.weight ?? 10);
  if (!picked) return null;

  return {
    ...picked,
    id: `${picked.id}_${state.tick}`,
    triggered: false,
    triggeredTick: state.tick,
  };
}

/**
 * Apply the chosen EventChoice's effects to state and mark the event resolved.
 */
export function resolveEventChoice(state: GameState, eventId: string, choiceIndex: number): GameState {
  const eventIndex = state.events.findIndex((e) => e.id === eventId);
  if (eventIndex === -1) return state;

  const event = state.events[eventIndex];
  if (event.triggered) return state;

  const choice = event.choices[choiceIndex];
  if (!choice) return state;

  let newState: GameState = { ...state, ...choice.effects };
  newState.events = state.events.map((e, i) => (i === eventIndex ? { ...e, triggered: true } : e));

  if (choice.prestigeChange) {
    newState.player = { ...newState.player, prestige: Math.max(0, newState.player.prestige + choice.prestigeChange) };
  }

  if (choice.resourceChanges) {
    const resources: Resources = { ...newState.resources };
    (Object.keys(choice.resourceChanges) as Array<keyof Resources>).forEach((key) => {
      const delta = choice.resourceChanges?.[key] ?? 0;
      resources[key] = Math.max(0, resources[key] + delta);
    });
    newState.resources = resources;
  }

  if (choice.religionChange) {
    newState.religion = { value: clamp(newState.religion.value + choice.religionChange, -100, 100) };
  }

  if (choice.zupaLoyaltyChanges) {
    const zupy = { ...newState.zupy };
    (Object.keys(choice.zupaLoyaltyChanges) as ZupaId[]).forEach((zupaId) => {
      const zupa = zupy[zupaId];
      const delta = choice.zupaLoyaltyChanges?.[zupaId] ?? 0;
      if (zupa) {
        zupy[zupaId] = { ...zupa, loyalty: clamp(zupa.loyalty + delta, 0, 100) };
      }
    });
    newState.zupy = zupy;
  }

  if (choice.moodChanges) {
    const moodChanges = choice.moodChanges;
    newState.factions = newState.factions.map((f) => {
      const delta = moodChanges[f.id] ?? moodChanges[f.name];
      if (!delta) return f;
      const moods: FactionMoods = { ...f.moods };
      (Object.keys(delta) as Array<keyof FactionMoods>).forEach((key) => {
        const d = delta[key];
        if (d !== undefined) {
          moods[key] = clamp(moods[key] + d, 0, 100);
        }
      });
      return { ...f, moods };
    });
  }

  if (choice.armyChanges) {
    const armyChanges = choice.armyChanges;
    newState.armies = newState.armies.map((a) => {
      const changes = armyChanges[a.id];
      return changes ? { ...a, ...changes } : a;
    });
  }

  if (choice.nextEvent) {
    const alreadyPresent = newState.events.some((e) => e.id === choice.nextEvent);
    const template = HISTORICAL_EVENTS.find((t) => t.id === choice.nextEvent);
    if (!alreadyPresent && template) {
      newState.events = [...newState.events, { ...template, triggered: false, triggeredTick: newState.tick }];
    }
  }

  return newState;
}

/**
 * Spawn newly-due historical events and, if the player has no pending
 * unresolved event, roll a chance to spawn a random one.
 */
export function processEvents(state: GameState): GameState {
  const newState: GameState = { ...state, events: [...state.events] };

  for (const template of HISTORICAL_EVENTS) {
    if (template.type !== 'historical') continue;
    if (newState.events.some((e) => e.id === template.id)) continue;
    if (!checkEventConditions(template, newState)) continue;
    newState.events.push({ ...template, triggered: false, triggeredTick: newState.tick });
  }

  const hasPending = newState.events.some((e) => !e.triggered);
  if (!hasPending && rngChance(RANDOM_EVENT_CHANCE)) {
    const generated = generateRandomEvent(newState);
    if (generated) {
      newState.events.push(generated);
    }
  }

  return newState;
}

export default {
  processEvents,
  checkEventConditions,
  generateRandomEvent,
  resolveEventChoice,
};
