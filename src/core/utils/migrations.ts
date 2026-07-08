// Regnum Moravicum v2.1 - Migrations
import type { GameState } from '../types/gameState';

const SAVE_VERSION = '2.1.0';

/**
 * Migration function type
 */
type MigrationFunction = (state: any) => GameState;

/**
 * Available migrations
 */
const migrations: Record<string, MigrationFunction> = {
  // Add migrations here as needed for future versions
  // Example: '1.0.0': (state) => migrateFrom1_0_0(state)
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
