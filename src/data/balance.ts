// Regnum Moravicum v2.1 - Balance Constants (Core Loop)
//
// Isolated from engine logic so numbers can be tuned from headless playtest
// simulations without touching engine code. Naming convention: BALANCE_*.

// Investment tracks (M1)
export const MAX_INVESTMENT_LEVEL = 5;
export const BALANCE_INVESTMENT_BASE_COST = 100; // gold cost to reach level 1
export const BALANCE_INVESTMENT_COST_GROWTH = 1.6; // cost(level) = base * growth^(level-1)
export const BALANCE_INVESTMENT_BASE_DURATION = 3; // ticks to reach level 1
export const BALANCE_INVESTMENT_DURATION_GROWTH = 1.4; // duration(level) = base * growth^(level-1)

export const BALANCE_ECONOMY_INCOME_PER_LEVEL = 8; // gold/tick added per economy level
export const BALANCE_FORTIFICATION_DEFENSE_PER_LEVEL = 6; // zupa.defense delta per level-up
export const BALANCE_CHURCH_LOYALTY_PER_LEVEL = 4; // zupa.loyalty delta per level-up
export const BALANCE_CHURCH_RELIGION_AXIS_PER_LEVEL = 5; // religion.value delta per level-up (signed by rite)

// Decision scheduler (M2)
export const BALANCE_RANDOM_EVENT_FALLBACK_COOLDOWN = 18; // ticks before a fallback event can repeat

// Faction agenda automaton (M4)
export const BALANCE_FACTION_SATISFACTION_DRIFT = 1; // passive drift per tick towards personality baseline
export const BALANCE_FACTION_DEMANDING_THRESHOLD = 60;
export const BALANCE_FACTION_THREATENING_THRESHOLD = 35;
export const BALANCE_FACTION_ACTING_THRESHOLD = 15;
export const BALANCE_FACTION_HYSTERESIS = 5; // prevents state flicker at threshold boundaries
export const BALANCE_FACTION_DEMAND_GRANTED_BONUS = 15;
export const BALANCE_FACTION_DEMAND_REFUSED_PENALTY = 12;
