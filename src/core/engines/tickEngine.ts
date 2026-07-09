// Regnum Moravicum v2.1 - Tick Engine
import type { GameState } from '../types/gameState';
import { rngChance } from '../utils/rng';
import { processWarCampaignTick } from './warCampaign';
import { processEvents } from './eventEngine';

/**
 * Increment year every 12 ticks (1 tick = 1 month)
 */
export function incrementYear(state: GameState): GameState {
  const newState = { ...state };
  const newTick = state.tick + 1;

  newState.tick = newTick;
  if (newTick % 12 === 0) {
    newState.year = state.year + 1;
  }

  return newState;
}

/**
 * Age nobles and handle death
 */
export function ageNobles(state: GameState): GameState {
  const newState = { ...state };

  // This runs after incrementYear, so state.tick is already the post-increment
  // tick; a year just elapsed exactly when it lands on a multiple of 12.
  const yearChanged = state.tick % 12 === 0;

  if (yearChanged) {
    newState.nobles = state.nobles.map(noble => {
      if (noble.status !== 'alive') {
        return noble;
      }

      const newNoble = { ...noble };
      newNoble.age += 1;

      // Death check: 10% chance if age >= 80
      if (newNoble.age >= 80 && rngChance(0.1)) {
        newNoble.status = 'dead';
        newNoble.deathTick = state.tick;
      }

      return newNoble;
    });
  }

  return newState;
}

/**
 * Decay moods and morale towards 50
 */
export function decayMoods(state: GameState): GameState {
  const newState = { ...state };
  
  newState.factions = state.factions.map(faction => {
    const newFaction = { ...faction };
    newFaction.moods = { ...faction.moods };
    
    // Decay each mood towards 50 by 5 points
    (Object.keys(newFaction.moods) as Array<keyof typeof newFaction.moods>).forEach(key => {
      if (newFaction.moods[key] > 50) {
        newFaction.moods[key] = Math.max(50, newFaction.moods[key] - 5);
      } else if (newFaction.moods[key] < 50) {
        newFaction.moods[key] = Math.min(50, newFaction.moods[key] + 5);
      }
    });
    
    return newFaction;
  });
  
  newState.armies = state.armies.map(army => {
    const newArmy = { ...army };
    // Decay morale towards 50 by 5 points
    if (newArmy.morale > 50) {
      newArmy.morale = Math.max(50, newArmy.morale - 5);
    } else if (newArmy.morale < 50) {
      newArmy.morale = Math.min(50, newArmy.morale + 5);
    }
    return newArmy;
  });
  
  return newState;
}

/**
 * Grow prosperity if food is sufficient
 */
export function growProsperity(state: GameState): GameState {
  const newState = { ...state };
  
  newState.zupy = { ...state.zupy };
  
  Object.entries(state.zupy).forEach(([zupaId, zupa]) => {
    const newZupa = { ...zupa };
    
    // Check if food >= prosperity * 0.5
    if (zupa.food >= zupa.prosperity * 0.5) {
      newZupa.prosperity = Math.min(100, zupa.prosperity + 1);
    } else {
      // Decrease prosperity if not enough food
      newZupa.prosperity = Math.max(0, zupa.prosperity - 1);
    }
    
    newState.zupy[zupaId] = newZupa;
  });
  
  return newState;
}

/**
 * Add recruitment pool
 */
export function addRecruitmentPool(state: GameState): GameState {
  const newState = { ...state };
  
  newState.zupy = { ...state.zupy };
  
  Object.entries(state.zupy).forEach(([zupaId, zupa]) => {
    const newZupa = { ...zupa };
    newZupa.recruitmentPool += 5;
    newState.zupy[zupaId] = newZupa;
  });
  
  return newState;
}

/**
 * Pay army upkeep from resources
 */
export function payUpkeep(state: GameState): GameState {
  const newState = { ...state };
  
  // Calculate total upkeep
  const totalUpkeep = state.armies.reduce((sum, army) => sum + army.upkeep, 0);
  
  // Deduct from gold
  newState.resources = { ...state.resources };
  newState.resources.gold = Math.max(0, state.resources.gold - totalUpkeep);
  
  // If not enough gold, reduce army morale
  if (state.resources.gold < totalUpkeep) {
    newState.armies = state.armies.map(army => {
      const newArmy = { ...army };
      newArmy.morale = Math.max(0, army.morale - 10);
      return newArmy;
    });
  }
  
  return newState;
}

/**
 * Check for rebellions in zupy with low loyalty
 */
export function checkRebellions(state: GameState): GameState {
  const newState = { ...state };
  
  newState.zupy = { ...state.zupy };
  
  Object.entries(state.zupy).forEach(([zupaId, zupa]) => {
    if (zupa.loyalty < 20 && rngChance(0.3)) {
      const newZupa = { ...zupa };
      newZupa.prosperity = Math.max(0, zupa.prosperity - 10);
      newZupa.loyalty = Math.min(100, zupa.loyalty + 5); // Rebellion suppressed for now
      newState.zupy[zupaId] = newZupa;
      
      // Add rebellion event to state
      newState.events.push({
        id: `rebellion_${state.tick}_${zupaId}`,
        type: 'random',
        title: 'Rebellion in ' + zupa.name,
        description: 'The people of ' + zupa.name + ' are rebelling against your rule!',
        conditions: [],
        choices: [
          {
            text: 'Suppress the rebellion',
            effects: {},
            prestigeChange: -5,
            moodChanges: {},
            armyChanges: {}
          }
        ],
        triggered: false,
        once: true,
        cooldownTicks: 24,
        weight: 100
      });
    }
  });
  
  return newState;
}

// Stub functions for other engines (Phase 1+)
// These are no-ops in Phase 0 but maintain stable API

/**
 * Process succession (Phase 1)
 */
export function processSuccessionPhase(state: GameState): GameState {
  // Stub for Phase 1
  return { ...state };
}

/**
 * Process diplomacy (Phase 3)
 */
export function processDiplomacyPhase(state: GameState): GameState {
  // Stub for Phase 3
  return { ...state };
}

/**
 * Process wars: scripted war campaign events (raids, reinforcements,
 * occupation looting, liberation/war-end checks). Battles themselves are
 * player-triggered from the UI, not auto-run during the tick.
 */
export function processWarsPhase(state: GameState): GameState {
  return processWarCampaignTick(state);
}

/**
 * Process events: spawn newly-due historical events and roll for random
 * flavor events, per src/core/engines/eventEngine.ts.
 */
export function processEventsPhase(state: GameState): GameState {
  return processEvents(state);
}

/**
 * Main tick processing function
 * Processes all phases in order
 */
export function processTick(state: GameState): GameState {
  let newState = { ...state };
  
  // Phase 1: Increment tick and year
  newState = incrementYear(newState);
  
  // Phase 2: Age nobles
  newState = ageNobles(newState);
  
  // Phase 3: Decay moods and morale
  newState = decayMoods(newState);
  
  // Phase 4: Grow prosperity
  newState = growProsperity(newState);
  
  // Phase 5: Add recruitment pool
  newState = addRecruitmentPool(newState);
  
  // Phase 6: Pay upkeep
  newState = payUpkeep(newState);
  
  // Phase 7: Check rebellions
  newState = checkRebellions(newState);
  
  // Phase 8: Process succession (stub)
  newState = processSuccessionPhase(newState);
  
  // Phase 9: Process diplomacy (stub)
  newState = processDiplomacyPhase(newState);
  
  // Phase 10: Process wars
  newState = processWarsPhase(newState);

  // Phase 11: Process events
  newState = processEventsPhase(newState);
  
  return newState;
}

export default {
  processTick,
  incrementYear,
  ageNobles,
  decayMoods,
  growProsperity,
  addRecruitmentPool,
  payUpkeep,
  checkRebellions,
  processSuccessionPhase,
  processDiplomacyPhase,
  processWarsPhase,
  processEventsPhase
};
