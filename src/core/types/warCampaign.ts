// Regnum Moravicum v2.1 - War Campaign Bridge Types
//
// The battle/war layer (src/battle, src/war, src/scenarios) uses its own
// Army/War/Battle types, distinct from and incompatible with the core
// entities' Army/War (different scale - core armies are small standing
// garrisons of ~100-200 men with a 5-unit-type breakdown, battle-layer
// armies are campaign-scale field armies of thousands with a 3-type
// composition ratio; core Army references a commanderId, battle Army embeds
// a Commander directly). Rather than forcing the two data models together,
// scripted war campaigns (like the Hungarian invasion / Bitka pri Devíne)
// live in this separate, loosely-coupled slice of GameState. Campaign
// outcomes (victory/defeat, occupation) feed back into core resources and
// zupa loyalty; the core tick clock drives the campaign's scripted events.

import type { War as BattleLayerWar } from '../../war/types';
import type { ZupaWarState } from '../../war/types';
import type { Army as BattleArmy, Battle } from '../../battle/types';

export interface ActiveBattleState {
  battle: Battle;
  attackerArmy: BattleArmy;
  defenderArmy: BattleArmy;
  narrationLog: string[]; // accumulated narration sentences, this battle only
}

export interface WarCampaignState {
  war: BattleLayerWar;
  armies: BattleArmy[];
  zupyWarState: ZupaWarState[];
  activeBattle: ActiveBattleState | null;
  appliedEventTicks: number[]; // scripted scenario events already applied, by tick
  log: string[]; // narrative log of campaign-level events (start, liberation, end)
}
