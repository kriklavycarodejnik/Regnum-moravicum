// Regnum Moravicum v2.1 - Event Types
import type { FactionId, NobleId, ZupaId, ArmyId, EventId } from './entities';
import type { GameState } from './gameState';

export type EventType = 'historical' | 'random' | 'diplomatic' | 'military' | 'religious';

export interface EventCondition {
  year?: number;
  yearMin?: number;
  yearMax?: number;
  factionMood?: { factionId: FactionId; mood: keyof import('./entities').FactionMoods; min?: number; max?: number };
  nobleAttribute?: { nobleId: NobleId; attribute: keyof import('./entities').Attributes; min?: number; max?: number };
  playerPrestige?: { min?: number; max?: number };
  zupaLoyalty?: { zupaId: ZupaId; min?: number; max?: number };
  zupaOwner?: { zupaId: ZupaId; owner?: NobleId };
  atWar?: boolean;
  hasTreaty?: { factionId1: FactionId; factionId2: FactionId; type?: import('./entities').TreatyType };
}

export interface EventChoice {
  text: string;
  effects: Partial<GameState>;
  nextEvent?: EventId;
  prestigeChange?: number;
  moodChanges?: Record<FactionId, Partial<import('./entities').FactionMoods>>;
  armyChanges?: Record<ArmyId, Partial<import('./entities').Army>>;
}

export interface GameEvent {
  id: EventId;
  type: EventType;
  title: string;
  description: string;
  conditions: EventCondition[];
  choices: EventChoice[];
  triggered: boolean;
  once?: boolean;
  cooldownTicks?: number;
  weight?: number;
}
