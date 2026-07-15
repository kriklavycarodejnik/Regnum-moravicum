// Regnum Moravicum v2.1 - Save/Load Utility
import LZString from 'lz-string';
import type { GameState } from '../types/gameState';
import { setRNGState, getRNGState } from './rng';
import { SAVE_VERSION } from './generators';
import { migrateSaveData } from './migrations';

const SAVE_KEY = 'regnum_moravicum_save';
const INDEXED_DB_NAME = 'RegnumMoravicumDB';
const INDEXED_DB_STORE = 'saves';

/**
 * Compress data using lz-string
 */
function compressData(data: string): string {
  return LZString.compressToUTF16(data);
}

/**
 * Decompress data using lz-string
 */
function decompressData(compressed: string): string | null {
  try {
    return LZString.decompressFromUTF16(compressed);
  } catch {
    return null;
  }
}

/**
 * Save game state to localStorage
 */
export function saveGame(state: GameState): void {
  try {
    // Save RNG state
    const rngState = getRNGState();
    
    // Create save object
    const saveData = {
      state,
      rngState,
      saveVersion: SAVE_VERSION,
      timestamp: Date.now()
    };
    
    // Compress and save
    const serialized = JSON.stringify(saveData);
    const compressed = compressData(serialized);
    
    // Try localStorage first
    if (compressed.length <= 4 * 1024 * 1024) { // 4MB limit
      localStorage.setItem(SAVE_KEY, compressed);
    } else {
      // Fallback to IndexedDB for larger saves
      saveToIndexedDB(compressed);
    }
  } catch (error) {
    console.error('Failed to save game:', error);
  }
}

/**
 * Load game state from storage
 */
export async function loadGame(): Promise<GameState | null> {
  try {
    // Try localStorage first
    const compressed = localStorage.getItem(SAVE_KEY);
    
    if (compressed) {
      const serialized = decompressData(compressed);
      if (serialized) {
        const saveData = JSON.parse(serialized);
        
        // Restore RNG state
        if (saveData.rngState) {
          setRNGState(saveData.rngState);
        }

        if (saveData.saveVersion !== SAVE_VERSION) {
          return migrateSaveData(saveData);
        }

        return saveData.state as GameState;
      }
    }
    
    // Try IndexedDB
    return await loadFromIndexedDB();
  } catch (error) {
    console.error('Failed to load game:', error);
    return null;
  }
}

/**
 * Check if a save exists
 */
export function hasSave(): boolean {
  return localStorage.getItem(SAVE_KEY) !== null;
}

/**
 * Delete saved game
 */
export function deleteSave(): void {
  localStorage.removeItem(SAVE_KEY);
  deleteFromIndexedDB();
}

// IndexedDB fallback functions
let indexedDBPromise: Promise<IDBDatabase> | null = null;

function getIndexedDB(): Promise<IDBDatabase> {
  if (indexedDBPromise) {
    return indexedDBPromise;
  }
  
  indexedDBPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(INDEXED_DB_NAME, 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(INDEXED_DB_STORE)) {
        db.createObjectStore(INDEXED_DB_STORE);
      }
    };
  });
  
  return indexedDBPromise;
}

async function saveToIndexedDB(compressed: string): Promise<void> {
  try {
    const db = await getIndexedDB();
    const transaction = db.transaction(INDEXED_DB_STORE, 'readwrite');
    const store = transaction.objectStore(INDEXED_DB_STORE);
    
    store.put(compressed, SAVE_KEY);
    
    await new Promise<void>((resolve, reject) => {
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
    });
  } catch (error) {
    console.error('Failed to save to IndexedDB:', error);
  }
}

async function loadFromIndexedDB(): Promise<GameState | null> {
  try {
    const db = await getIndexedDB();
    const transaction = db.transaction(INDEXED_DB_STORE, 'readonly');
    const store = transaction.objectStore(INDEXED_DB_STORE);
    
    const request = store.get(SAVE_KEY);
    
    const compressed = await new Promise<string | undefined>((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    
    if (compressed) {
      const serialized = decompressData(compressed);
      if (serialized) {
        const saveData = JSON.parse(serialized);
        
        if (saveData.rngState) {
          setRNGState(saveData.rngState);
        }

        if (saveData.saveVersion !== SAVE_VERSION) {
          return migrateSaveData(saveData);
        }

        return saveData.state as GameState;
      }
    }

    return null;
  } catch (error) {
    console.error('Failed to load from IndexedDB:', error);
    return null;
  }
}

async function deleteFromIndexedDB(): Promise<void> {
  try {
    const db = await getIndexedDB();
    const transaction = db.transaction(INDEXED_DB_STORE, 'readwrite');
    const store = transaction.objectStore(INDEXED_DB_STORE);
    
    store.delete(SAVE_KEY);
    
    await new Promise<void>((resolve, reject) => {
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
    });
  } catch (error) {
    console.error('Failed to delete from IndexedDB:', error);
  }
}

export default {
  saveGame,
  loadGame,
  hasSave,
  deleteSave
};
