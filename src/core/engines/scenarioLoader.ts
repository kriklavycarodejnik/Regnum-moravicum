// Regnum Moravicum v2.1 - Scenario Loader (Core Loop M3)
//
// Builds on generateInitialState (src/core/utils/generators.ts) rather than
// replacing it: a StartScenarioConfig only overrides the starting year/tick,
// resources, zupa loyalties and religion axis on top of the same canon 11
// zupy / Mojmírovci / faction roster. generateInitialState's own call path
// (useGame.ts newGame) is untouched.
import type { GameState } from '../types/gameState';
import type { GameEvent } from '../types/events';
import type { StartScenarioConfig } from '../types/scenario';
import { generateInitialState } from '../utils/generators';
import { SCENARIOS, DEFAULT_SCENARIO_ID } from '../../data/scenarios';

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function getAvailableScenarios(): StartScenarioConfig[] {
  return Object.values(SCENARIOS);
}

export function getScenarioConfig(scenarioId: string): StartScenarioConfig | undefined {
  return SCENARIOS[scenarioId];
}

/** Basic structural/range sanity check for a scenario config. */
export function validateScenarioConfig(config: StartScenarioConfig): boolean {
  if (!config.id || !config.name) return false;
  if (config.startYear < 902 || config.startYear > 1300) return false;
  if (config.startTick < 0) return false;
  if (config.religionAxisStart < -100 || config.religionAxisStart > 100) return false;
  return true;
}

/**
 * Builds a GameState for the given start scenario. Falls back to the 902
 * default scenario for an unknown/invalid id rather than throwing, so a
 * corrupt or future-removed scenario id in an old save never hard-crashes
 * game start.
 */
export function loadScenario(scenarioId: string, seed: string): GameState {
  const config = SCENARIOS[scenarioId] && validateScenarioConfig(SCENARIOS[scenarioId])
    ? SCENARIOS[scenarioId]
    : SCENARIOS[DEFAULT_SCENARIO_ID];

  let state = generateInitialState(config.victoryScenario, seed);

  state = {
    ...state,
    year: config.startYear,
    tick: config.startTick,
    startScenarioId: config.id,
    resources: { ...state.resources, ...config.initialResourceOverrides },
    religion: { value: clamp(config.religionAxisStart, -100, 100) },
  };

  const loyaltyOverrides = Object.entries(config.zupaLoyaltyOverrides);
  if (loyaltyOverrides.length > 0) {
    const zupy = { ...state.zupy };
    for (const [zupaName, loyalty] of loyaltyOverrides) {
      const zupa = Object.values(zupy).find((z) => z.name === zupaName);
      if (zupa) {
        zupy[zupa.id] = { ...zupa, loyalty: clamp(loyalty, 0, 100) };
      }
    }
    state = { ...state, zupy };
  }

  if (config.activeThreats.length > 0) {
    const threatEvent: GameEvent = {
      id: `scenario_threats_${config.id}`,
      type: 'military',
      title: `Stav ríše pri nástupe: ${config.name}`,
      description: config.activeThreats.join(' '),
      conditions: [],
      choices: [],
      triggered: true,
      triggeredTick: state.tick,
    };
    state = { ...state, events: [...state.events, threatEvent] };
  }

  return state;
}

export default {
  loadScenario,
  getAvailableScenarios,
  getScenarioConfig,
  validateScenarioConfig,
};
