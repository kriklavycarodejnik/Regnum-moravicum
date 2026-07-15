// Regnum Moravicum v2.1 - Start Scenario Types (Core Loop M3)
//
// Distinct from `ScenarioType` in gameState.ts, which selects a *victory
// condition* for an otherwise-fixed 902 start. A StartScenarioConfig selects
// the *starting situation* (year, resources, zupa loyalties, religion axis,
// active threats) - AoH2-style "pick a start date" rather than a building
// tree. See src/core/engines/scenarioLoader.ts.
import type { ScenarioType, Resources } from './gameState';

export interface StartScenarioConfig {
  id: string;
  name: string;
  description: string;
  startYear: number;
  startTick: number;
  victoryScenario: ScenarioType;
  initialResourceOverrides: Partial<Resources>;
  /** Zupa loyalty overrides keyed by canon zupa name (e.g. "Devín"), not id - ids are runtime-generated slugs. */
  zupaLoyaltyOverrides: Record<string, number>;
  religionAxisStart: number;
  activeThreats: string[];
}
