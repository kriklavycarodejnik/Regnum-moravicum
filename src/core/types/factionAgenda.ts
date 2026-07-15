// Regnum Moravicum v2.1 - Faction Agenda Automaton Types (Core Loop M4)
//
// A second, independent layer on top of the existing Faction.moods system
// (loyalty/fear/trust/anger, see entities.ts) - moods react to individual
// diplomatic actions, while the agenda automaton tracks whether a faction's
// underlying goal is currently being met at all, and escalates from quiet
// dissatisfaction to open rebellion if it never is.

export type FactionGoalType = 'territory' | 'church' | 'trade' | 'raiding' | 'power';
export type FactionAgendaStateType = 'CALM' | 'DEMANDING' | 'THREATENING' | 'ACTING';

export interface FactionAgendaState {
  goalType: FactionGoalType;
  satisfaction: number; // 0-100
  state: FactionAgendaStateType;
}
