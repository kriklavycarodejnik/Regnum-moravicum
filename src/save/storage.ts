// Regnum Moravicum - Save/Load System

import type { SaveFile, IncompatibleSaveError } from './types';
import type { War, ZupaWarState } from '../war/types';
import type { Army, Battle } from '../battle/types';

const SAVE_KEY = 'regnum-moravicum-save-v1';
const GAME_VERSION = '0.1.0';

// Type guard for SaveFile
export function isSaveFile(obj: unknown): obj is SaveFile {
  if (typeof obj !== 'object' || obj === null) return false;
  
  const save = obj as Partial<SaveFile>;
  
  return (
    save.version === 1 &&
    typeof save.timestamp === 'number' &&
    typeof save.gameVersion === 'string' &&
    typeof save.data === 'object' &&
    save.data !== null &&
    typeof save.data.tick === 'number' &&
    Array.isArray(save.data.wars) &&
    Array.isArray(save.data.battles) &&
    Array.isArray(save.data.armies) &&
    Array.isArray(save.data.zupyWarState) &&
    typeof save.data.playerResources === 'object' &&
    save.data.playerResources !== null &&
    typeof save.data.playerResources.gold === 'number' &&
    typeof save.data.playerResources.prestige === 'number'
  );
}

// Save game state
export function saveGame(
  tick: number,
  wars: War[],
  battles: Battle[],
  armies: Army[],
  zupyWarState: ZupaWarState[],
  playerResources: { gold: number; prestige: number }
): void {
  try {
    const saveData: SaveFile = {
      version: 1,
      timestamp: Date.now(),
      gameVersion: GAME_VERSION,
      data: {
        tick,
        wars: wars.map(w => ({ ...w })),
        battles: battles.map(b => ({ ...b })),
        armies: armies.map(a => ({ ...a })),
        zupyWarState: zupyWarState.map(z => ({ ...z })),
        playerResources: { ...playerResources },
      },
    };

    // Validate before saving
    if (!isSaveFile(saveData)) {
      throw new Error('Invalid save data structure');
    }

    // Save to localStorage
    localStorage.setItem(SAVE_KEY, JSON.stringify(saveData));
  } catch (error) {
    if (error instanceof QuotaExceededError) {
      throw new Error('LocalStorage quota exceeded. Please clear some data and try again.');
    }
    throw error;
  }
}

// Load game state
export function loadGame(): SaveFile {
  const saved = localStorage.getItem(SAVE_KEY);
  
  if (!saved) {
    throw new Error('No saved game found');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(saved);
  } catch (error) {
    throw new Error('Invalid save file format');
  }

  // Validate
  if (!isSaveFile(parsed)) {
    throw new Error('Invalid save file structure');
  }

  // Check version compatibility
  if (parsed.gameVersion !== GAME_VERSION) {
    throw new IncompatibleSaveError(
      `Save file version ${parsed.gameVersion} is incompatible with current game version ${GAME_VERSION}`
    );
  }

  return parsed;
}

// Check if save exists
export function hasSave(): boolean {
  return localStorage.getItem(SAVE_KEY) !== null;
}

// Clear save
export function clearSave(): void {
  localStorage.removeItem(SAVE_KEY);
}

// Get save metadata (without loading full data)
export function getSaveMetadata(): { hasSave: boolean; timestamp?: number } {
  const saved = localStorage.getItem(SAVE_KEY);
  if (!saved) {
    return { hasSave: false };
  }

  try {
    const parsed = JSON.parse(saved) as Partial<SaveFile>;
    return { hasSave: true, timestamp: parsed.timestamp };
  } catch {
    return { hasSave: true };
  }
}

// Export for testing
export { SAVE_KEY, GAME_VERSION };
