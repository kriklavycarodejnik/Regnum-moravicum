// Regnum Moravicum v2.1 - Migrations
import type { GameState } from '../types/gameState';

const SAVE_VERSION = '2.3.0';

/**
 * Migration function type
 */
type MigrationFunction = (state: any) => GameState;

/**
 * Core Loop M1: adds the per-zupa investment tracks (economy/fortification/
 * church). Old saves get level-0/no-active-investment defaults for every
 * zupa currently in state.zupy.
 */
function migrateTo2_2_0(state: any): GameState {
  if (state.investments) return state as GameState;

  const investments: GameState['investments'] = {};
  for (const zupaId of Object.keys(state.zupy ?? {})) {
    investments[zupaId] = { economy: 0, fortification: 0, church: 0, active: null };
  }

  return { ...state, investments } as GameState;
}

/**
 * Core Loop M3: adds startScenarioId, remembering which start scenario a
 * save began from. Old saves all began from the fixed 902 default, so they
 * backfill to that scenario's id.
 */
function migrateTo2_3_0(state: any): GameState {
  if (state.startScenarioId) return state as GameState;
  return { ...state, startScenarioId: 'nastup-902' } as GameState;
}

/**
 * Available migrations
 */
const migrations: Record<string, MigrationFunction> = {
  '2.2.0': migrateTo2_2_0,
  '2.3.0': migrateTo2_3_0,
};

/**
 * Migrate save data from an older version to current
 */
export function migrateSaveData(saveData: any): GameState {
  let state = saveData.state as GameState;
  const fromVersion = saveData.saveVersion || '1.0.0';
  
  // Apply migrations in order
  const versions = Object.keys(migrations).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  
  for (const version of versions) {
    if (fromVersion < version) {
      const migration = migrations[version];
      state = migration(state);
    }
  }
  
  // Update save version
  state.saveVersion = SAVE_VERSION;
  
  return state;
}

/**
 * Get current save version
 */
export function getSaveVersion(): string {
  return SAVE_VERSION;
}

export default {
  migrateSaveData,
  getSaveVersion
};
