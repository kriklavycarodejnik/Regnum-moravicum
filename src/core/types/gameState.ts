// Regnum Moravicum v2.1 - Game State Types
import type {
  NobleId,
  FamilyId,
  ZupaId
} from './entities';
import type { Noble, Family, Faction, Zupa, Army, War, Treaty } from './entities';
import type { GameEvent } from './events';
import type { WarCampaignState } from './warCampaign';

export type { NobleId, FamilyId, ZupaId };
export type ScenarioType = 'prežitie' | 'konsolidácia' | 'zlatý_vek' | 'mongolská_skúška';

export interface Resources {
  gold: number;
  food: number;
  wood: number;
  stone: number;
  iron: number;
  prestige: number;
}

export interface ReligionAxis {
  value: number; // -100 (Rím) až +100 (Konštantínopol)
}

export interface Player {
  dynasty: FamilyId;
  currentRuler: NobleId;
  prestige: number;
  religionAxis: number;
}

export interface GameState {
  tick: number;              // 1 tick = 1 mesiac
  year: number;              // 902-1300
  seed: string;
  scenario: ScenarioType;
  player: Player;
  nobles: Noble[];
  families: Family[];
  factions: Faction[];
  zupy: Record<ZupaId, Zupa>;
  armies: Army[];
  wars: War[];
  treaties: Treaty[];
  events: GameEvent[];
  resources: Resources;
  religion: ReligionAxis;
  gameOver: boolean;
  gameOverReason?: string;
  gameOverVictory?: boolean;
  saveVersion: string;
  warCampaign: WarCampaignState | null;
}
