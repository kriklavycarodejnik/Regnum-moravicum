// Regnum Moravicum v2.1 - Save/Load System Implementation
import type {
  SaveData,
  SaveMetadata,
  SaveSystem,
  SaveManager,
  SaveSlot
} from '../../types/saveTypes';

const SAVE_VERSION = '2.1.0';

/**
 * JSONSaveSystem - Implements save/load using JSON serialization
 */
export class JSONSaveSystem implements SaveSystem {
  constructor(/* compressionEnabled: boolean = false */) {
    // compressionEnabled parameter is reserved for future use
  }

  async save(state: any, metadata: Partial<SaveMetadata>): Promise<SaveData> {
    const saveData: SaveData = {
      version: SAVE_VERSION,
      timestamp: Date.now(),
      gameState: state,
      metadata: {
        seed: metadata.seed || '',
        turn: metadata.turn || state.turn,
        playtime: metadata.playtime || 0,
        modHashes: metadata.modHashes || {}
      }
    };
    return saveData;
  }

  async load(saveData: SaveData): Promise<any> {
    if (!this.validate(saveData)) {
      throw new Error(`Invalid save data: version mismatch or corrupted`);
    }
    return saveData.gameState;
  }

  async compress(data: string): Promise<string> {
    // Simple compression using btoa for now
    // In production, use pako or similar for gzip
    return btoa(encodeURIComponent(data));
  }

  async decompress(data: string): Promise<string> {
    try {
      return decodeURIComponent(atob(data));
    } catch {
      return data; // Return as-is if decompression fails
    }
  }

  validate(saveData: SaveData): boolean {
    // Check version compatibility
    if (saveData.version !== SAVE_VERSION) {
      console.warn(`Save version mismatch: expected ${SAVE_VERSION}, got ${saveData.version}`);
      // For now, we'll allow loading with warning
      // In production, implement proper version migration
    }
    
    // Check required fields
    if (!saveData.gameState || !saveData.timestamp) {
      return false;
    }
    
    return true;
  }

  getSaveVersion(): string {
    return SAVE_VERSION;
  }


}

/**
 * LocalStorageSaveManager - Manages save slots in browser localStorage
 */
export class LocalStorageSaveManager implements SaveManager {
  private saveSystem: SaveSystem;
  private prefix: string;

  constructor(prefix: string = 'regnum-moravicum') {
    this.saveSystem = new JSONSaveSystem();
    this.prefix = prefix;
  }

  async saveToSlot(slotId: string, state: any): Promise<void> {
    const saveData = await this.saveSystem.save(state, {
      seed: state.rngState?.seed || '',
      turn: state.turn
    });
    
    const slotKey = `${this.prefix}:slot:${slotId}`;
    const slotData: SaveSlot = {
      id: slotId,
      name: `Save ${slotId}`,
      timestamp: Date.now(),
      preview: saveData
    };
    
    localStorage.setItem(slotKey, JSON.stringify(slotData));
    this.updateSlotIndex(slotId);
  }

  async loadFromSlot(slotId: string): Promise<any | null> {
    const slotKey = `${this.prefix}:slot:${slotId}`;
    const slotData = localStorage.getItem(slotKey);
    
    if (!slotData) {
      return null;
    }
    
    try {
      const parsed = JSON.parse(slotData) as SaveSlot;
      return await this.saveSystem.load(parsed.preview);
    } catch {
      return null;
    }
  }

  async listSlots(): Promise<SaveSlot[]> {
    const indexKey = `${this.prefix}:slots`;
    const index = localStorage.getItem(indexKey);
    
    if (!index) {
      return [];
    }
    
    try {
      const slotIds = JSON.parse(index) as string[];
      const slots: SaveSlot[] = [];
      
      for (const slotId of slotIds) {
        const slotData = localStorage.getItem(`${this.prefix}:slot:${slotId}`);
        if (slotData) {
          try {
            slots.push(JSON.parse(slotData) as SaveSlot);
          } catch {
            // Skip corrupted slots
          }
        }
      }
      
      return slots.sort((a, b) => b.timestamp - a.timestamp);
    } catch {
      return [];
    }
  }

  async deleteSlot(slotId: string): Promise<void> {
    const slotKey = `${this.prefix}:slot:${slotId}`;
    localStorage.removeItem(slotKey);
    this.removeFromSlotIndex(slotId);
  }

  async getAutoSave(): Promise<any | null> {
    const autoSaveKey = `${this.prefix}:autosave`;
    const autoSave = localStorage.getItem(autoSaveKey);
    
    if (!autoSave) {
      return null;
    }
    
    try {
      const saveData = JSON.parse(autoSave) as SaveData;
      return await this.saveSystem.load(saveData);
    } catch {
      return null;
    }
  }

  async saveAutoSave(state: any): Promise<void> {
    const saveData = await this.saveSystem.save(state, {
      seed: state.rngState?.seed || '',
      turn: state.turn
    });
    
    const autoSaveKey = `${this.prefix}:autosave`;
    localStorage.setItem(autoSaveKey, JSON.stringify(saveData));
  }

  /**
   * Update the slot index in localStorage
   */
  private updateSlotIndex(slotId: string): void {
    const indexKey = `${this.prefix}:slots`;
    const index = localStorage.getItem(indexKey);
    const slotIds = index ? JSON.parse(index) as string[] : [];
    
    if (!slotIds.includes(slotId)) {
      slotIds.push(slotId);
      localStorage.setItem(indexKey, JSON.stringify(slotIds));
    }
  }

  /**
   * Remove a slot from the index
   */
  private removeFromSlotIndex(slotId: string): void {
    const indexKey = `${this.prefix}:slots`;
    const index = localStorage.getItem(indexKey);
    
    if (index) {
      const slotIds = JSON.parse(index) as string[];
      const updatedIds = slotIds.filter(id => id !== slotId);
      localStorage.setItem(indexKey, JSON.stringify(updatedIds));
    }
  }
}

/**
 * InMemorySaveManager - For testing and non-browser environments
 */
export class InMemorySaveManager implements SaveManager {
  private saveSystem: SaveSystem;
  private slots: Map<string, SaveSlot> = new Map();
  private autoSave: SaveData | null = null;

  constructor() {
    this.saveSystem = new JSONSaveSystem();
  }

  async saveToSlot(slotId: string, state: any): Promise<void> {
    const saveData = await this.saveSystem.save(state, {
      seed: state.rngState?.seed || '',
      turn: state.turn
    });
    
    this.slots.set(slotId, {
      id: slotId,
      name: `Save ${slotId}`,
      timestamp: Date.now(),
      preview: saveData
    });
  }

  async loadFromSlot(slotId: string): Promise<any | null> {
    const slot = this.slots.get(slotId);
    if (!slot) {
      return null;
    }
    return await this.saveSystem.load(slot.preview);
  }

  async listSlots(): Promise<SaveSlot[]> {
    return Array.from(this.slots.values())
      .sort((a, b) => b.timestamp - a.timestamp);
  }

  async deleteSlot(slotId: string): Promise<void> {
    this.slots.delete(slotId);
  }

  async getAutoSave(): Promise<any | null> {
    if (!this.autoSave) {
      return null;
    }
    return await this.saveSystem.load(this.autoSave);
  }

  async saveAutoSave(state: any): Promise<void> {
    this.autoSave = await this.saveSystem.save(state, {
      seed: state.rngState?.seed || '',
      turn: state.turn
    });
  }

  /**
   * Clear all saves (for testing)
   */
  clearAll(): void {
    this.slots.clear();
    this.autoSave = null;
  }
}

export default JSONSaveSystem;
