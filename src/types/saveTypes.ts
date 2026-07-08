// Regnum Moravicum v2.1 - Save/Load Types

export interface Serializable {
  serialize(): string;
  deserialize(data: string): void;
}

export interface SaveData {
  version: string;
  timestamp: number;
  gameState: any; // GameState from gameTypes
  metadata: SaveMetadata;
}

export interface SaveMetadata {
  seed: string;
  turn: number;
  playtime: number;
  modHashes: Record<string, string>;
}



export interface SaveSystem {
  save(state: any, metadata: Partial<SaveMetadata>): Promise<SaveData>;
  load(saveData: SaveData): Promise<any>;
  compress(data: string): Promise<string>;
  decompress(data: string): Promise<string>;
  validate(saveData: SaveData): boolean;
  getSaveVersion(): string;
}

export interface SaveSlot {
  id: string;
  name: string;
  timestamp: number;
  preview: SaveData;
}

export interface SaveManager {
  saveToSlot(slotId: string, state: any): Promise<void>;
  loadFromSlot(slotId: string): Promise<any | null>;
  listSlots(): Promise<SaveSlot[]>;
  deleteSlot(slotId: string): Promise<void>;
  getAutoSave(): Promise<any | null>;
  saveAutoSave(state: any): Promise<void>;
}
