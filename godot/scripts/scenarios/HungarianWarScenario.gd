# scripts/scenarios/HungarianWarScenario.gd
class_name HungarianWarScenario
extends RefCounted

## Bitka pri Devíne 907 — kánonický scenár M3.
## Port src/scenarios/hungarianWar.ts → Godot.

const C := preload("res://scripts/battle/BattleConfig.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")

var game_state
var war_manager
var battle_manager
var rng: RandomNumberGenerator

# Kánonické konštanty
const HUNGARIAN_ARMY_SIZE := 12000
const MORAVIAN_ARMY_SIZE := 8000
const HUNGARIAN_REINFORCEMENTS := 3000
const HUNGARIAN_RAID_SIZE := 4000
const RAID_TICK := 3
const REINFORCEMENT_TICK := 12
const TIMEOUT_TICKS := 60
const LOYALTY_PENALTY_PER_TICK := 1
const GOLD_PENALTY_PER_TICK := 50

# Rewards
const REWARD_LIBERATED_DEVIN := {"prestige": 5, "gold": 1000, "loyalty_bonus": 10}
const REWARD_LIBERATED_NITRA := {"prestige": 7, "gold": 1500, "loyalty_bonus": 15}
const PENALTY_WAR_DEFEAT := {"prestige": -5, "loyalty_penalty": -15}

# Faction IDs
const FACTION_HUNGARIAN := "madari"
const FACTION_MORAVIAN := "moravia"

# Province IDs
const PROVINCE_DEVIN := "devin"
const PROVINCE_NITRA := "nitra"

# Terrain
const TERRAIN_DEVIN := "river"
const TERRAIN_NITRA := "field"

# Commanders
const COMMANDER_ARPAD := {"id": "arpad", "name": "Árpád", "skill": 8}
const COMMANDER_RADOMIR := {"id": "radomir", "name": "Radomír", "skill": 9}


func _init(state, war_mgr, battle_mgr, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	war_manager = war_mgr
	battle_manager = battle_mgr
	rng = rng_ref


func create_initial_armies() -> Dictionary:
	return {
		"hungarian_main": battle_manager.make_army(
			"hungarian_main", FACTION_HUNGARIAN, HUNGARIAN_ARMY_SIZE, 80.0,
			{"infantry": 0.25, "cavalry": 0.60, "archers": 0.15},
			COMMANDER_ARPAD["skill"], COMMANDER_ARPAD["name"]
		),
		"moravian_main": battle_manager.make_army(
			"moravian_main", FACTION_MORAVIAN, MORAVIAN_ARMY_SIZE, 75.0,
			{"infantry": 0.65, "cavalry": 0.15, "archers": 0.20},
			COMMANDER_RADOMIR["skill"], COMMANDER_RADOMIR["name"]
		)
	}


func resolve_devine_battle() -> Dictionary:
	var armies: Dictionary = create_initial_armies()
	var hungarian: Dictionary = armies["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies["moravian_main"].duplicate(true)

	# Terén: rieka → Maďari −10 morálky
	var tm: Dictionary = C.TERRAIN_MODIFIERS.get(TERRAIN_DEVIN, C.TERRAIN_MODIFIERS["field"])
	hungarian["morale"] = clampf(float(hungarian["morale"]) + float(tm["attackerMorale"]) + C.HUNGARIAN_RIVER_MORALE, 0.0, 100.0)
	moravian["morale"] = clampf(float(moravian["morale"]) + float(tm["defenderMorale"]), 0.0, 100.0)

	# Grécky oheň: +15 % ES pre obrancu (Morava)
	var es_moravian: float = Formulas.calculate_effective_strength(moravian, false, TERRAIN_DEVIN) * 1.15

	# Auto-resolve
	var outcome: Dictionary = battle_manager.auto_resolve(hungarian, moravian, TERRAIN_DEVIN)
	outcome["scenario"] = "devine_907"
	outcome["terrain"] = TERRAIN_DEVIN
	outcome["armies"] = armies

	# Apply occupation if hungarian win
	if outcome.get("winner", "") == "attacker":
		war_manager.set_occupier(PROVINCE_DEVIN, FACTION_HUNGARIAN)
		outcome["occupation_applied"] = true
	else:
		# Moravian victory → remove occupation, apply rewards
		war_manager.clear_occupation(PROVINCE_DEVIN)
		game_state.resources["prestige"] = int(game_state.resources.get("prestige", 0)) + REWARD_LIBERATED_DEVIN["prestige"]
		game_state.resources["gold"] = int(game_state.resources.get("gold", 0)) + REWARD_LIBERATED_DEVIN["gold"]
		var devin_province = game_state.provinces.get(PROVINCE_DEVIN)
		if devin_province != null and typeof(devin_province) == TYPE_DICTIONARY:
			devin_province["loyalty"] = int(devin_province.get("loyalty", 50)) + REWARD_LIBERATED_DEVIN["loyalty_bonus"]
		var nitra_province = game_state.provinces.get(PROVINCE_NITRA)
		if nitra_province != null and typeof(nitra_province) == TYPE_DICTIONARY:
			nitra_province["loyalty"] = int(nitra_province.get("loyalty", 50)) + REWARD_LIBERATED_DEVIN["loyalty_bonus"]
		outcome["rewards_applied"] = REWARD_LIBERATED_DEVIN

	return outcome


func process_war_tick(tick_count: int) -> Dictionary:
	var report := {"type": "war_scenario", "scenario": "hungarian_war", "tick": tick_count}

	# Raid at tick 3
	if tick_count == RAID_TICK:
		var raid_army = battle_manager.make_army(
			"hungarian_raid", FACTION_HUNGARIAN, HUNGARIAN_RAID_SIZE, 70.0,
			{"infantry": 0.30, "cavalry": 0.55, "archers": 0.15},
			6, "Maďarský náčelník"
		)
		var raid_outcome = battle_manager.auto_resolve(
			raid_army,
			battle_manager.make_army(
				"moravian_defense", FACTION_MORAVIAN, 3000, 65.0,
				{"infantry": 0.70, "cavalry": 0.10, "archers": 0.20},
				7, "Moravský župan"
			),
			TERRAIN_NITRA
		)
		report["raid"] = raid_outcome

	# Reinforcements at tick 12
	if tick_count == REINFORCEMENT_TICK:
		var hungarian_main = battle_manager.make_army(
			"hungarian_main", FACTION_HUNGARIAN, HUNGARIAN_ARMY_SIZE + HUNGARIAN_REINFORCEMENTS, 75.0,
			{"infantry": 0.25, "cavalry": 0.60, "archers": 0.15},
			8, "Árpád"
		)
		report["reinforcements"] = {"size": HUNGARIAN_REINFORCEMENTS}

	# Timeout at tick 60
	if tick_count >= TIMEOUT_TICKS:
		war_manager.clear_occupation(PROVINCE_DEVIN)
		war_manager.clear_occupation(PROVINCE_NITRA)
		game_state.resources["prestige"] = int(game_state.resources.get("prestige", 0)) + PENALTY_WAR_DEFEAT["prestige"]
		var devin_province = game_state.provinces.get(PROVINCE_DEVIN)
		if devin_province != null and typeof(devin_province) == TYPE_DICTIONARY:
			devin_province["loyalty"] = int(devin_province.get("loyalty", 50)) + PENALTY_WAR_DEFEAT["loyalty_penalty"]
		report["timeout"] = true

	return report