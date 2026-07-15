// Regnum Moravicum v2.1 - Start Scenario Registry (Core Loop M3)
import type { StartScenarioConfig } from '../../core/types/scenario';
import { NASTUP_902 } from './nastup902';
import { BURKA_PRI_DEVINE_907 } from './burkaPriDevine907';

export const SCENARIOS: Record<string, StartScenarioConfig> = {
  [NASTUP_902.id]: NASTUP_902,
  [BURKA_PRI_DEVINE_907.id]: BURKA_PRI_DEVINE_907,
};

export const DEFAULT_SCENARIO_ID = NASTUP_902.id;

export default SCENARIOS;
