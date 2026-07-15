// Regnum Moravicum v2.1 - Faction Agenda Mapping (Core Loop M4)
//
// Faction ids are generated non-deterministically at runtime (see
// generators.ts), so - same convention as historicalEvents.ts moodChanges -
// this maps goal types by the canon faction NAME from data/initialState.ts.
import type { FactionGoalType } from '../core/types/factionAgenda';

export const DEFAULT_GOAL_TYPE: FactionGoalType = 'territory';

export const GOAL_TYPE_BY_FACTION_NAME: Record<string, FactionGoalType> = {
  'Župani': 'territory',
  'Cyrilometodskí Kňazi': 'church',
  'Byzantskí Poslovia': 'church',
  'Nemeckí Kolonisti': 'trade',
  'Maďarské zvyšky': 'raiding',
  'Bogatovci': 'power',
};

export const GOAL_LABELS: Record<FactionGoalType, string> = {
  territory: 'väčšej moci nad krajom',
  church: 'podpory cirkevných dráh',
  trade: 'obchodných výsad',
  raiding: 'pokoja na hraniciach',
  power: 'vplyvu na dvore',
};

export function resolveGoalType(factionName: string): FactionGoalType {
  return GOAL_TYPE_BY_FACTION_NAME[factionName] ?? DEFAULT_GOAL_TYPE;
}

export default GOAL_TYPE_BY_FACTION_NAME;
