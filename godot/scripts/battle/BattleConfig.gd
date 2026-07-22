# scripts/battle/BattleConfig.gd
class_name BattleConfig
extends RefCounted

## Port of src/battle/config.ts — source of truth from Phase 2 React spec.

const TERRAIN_MODIFIERS := {
	"field": {"attackBonus": 0.0, "defenseBonus": 0.0, "attackerMorale": 0, "defenderMorale": 0},
	"forest": {"attackBonus": -0.20, "defenseBonus": 0.30, "attackerMorale": -10, "defenderMorale": 0},
	"fortress": {"attackBonus": -0.40, "defenseBonus": 0.60, "attackerMorale": 0, "defenderMorale": 15},
	"river": {"attackBonus": -0.15, "defenseBonus": 0.20, "attackerMorale": -5, "defenderMorale": 0},
	"hill": {"attackBonus": 0.0, "defenseBonus": 0.20, "attackerMorale": 0, "defenderMorale": 5},
}

const UNIT_TERRAIN := {
	"infantry": {"field": 1.00, "forest": 1.05, "fortress": 1.15, "river": 1.00, "hill": 1.05},
	"cavalry": {"field": 1.20, "forest": 0.70, "fortress": 0.60, "river": 0.80, "hill": 0.90},
	"archers": {"field": 1.00, "forest": 1.10, "fortress": 1.10, "river": 1.05, "hill": 1.15},
}

# melee > ranged > flank > melee
const ACTION_COUNTER := {
	"melee": {"melee": 1.00, "ranged": 1.15, "flank": 0.85, "retreat": 1.00},
	"ranged": {"melee": 0.85, "ranged": 1.00, "flank": 1.15, "retreat": 1.00},
	"flank": {"melee": 1.15, "ranged": 0.85, "flank": 1.00, "retreat": 1.00},
	"retreat": {"melee": 1.00, "ranged": 1.00, "flank": 1.00, "retreat": 1.00},
}

const BASE_LOSS_RATE := {"attack": 0.06, "counterattack": 0.06, "decision": 0.10}
const RNG_PHASE := Vector2(0.85, 1.15)
const RNG_DECISION := Vector2(0.80, 1.20)
const LOSS_RATIO_CLAMP := Vector2(0.5, 2.0)

const MORALE_WIN_BONUS := 5
const MORALE_LOSS_BASE := 8
const MORALE_DRAW_PENALTY := 3
const ROUT_THRESHOLD := 20
const ROUT_EXTRA_REGROUP := 0.10
const ROUT_EXTRA_PURSUE := 0.20
const RETREAT_LOSSES := 0.05
const RETREAT_MORALE_PENALTY := 10
const DECISION_LOSER_LOSSES := 0.08
const DECISION_LOSER_MORALE := -15
const DECISION_WINNER_MORALE := 10
const COMMANDER_STRENGTH_PER_SKILL := 0.02
const COMMANDER_MORALE_MITIGATION := 0.02

const HUNGARIAN_CAVALRY_FIELD := 1.40
const MORAVIAN_FORTRESS_DEF := 1.30
const HUNGARIAN_RIVER_MORALE := -10
const GREEK_FIRE_BONUS := 1.15
