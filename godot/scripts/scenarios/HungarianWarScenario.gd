# scripts/scenarios/HungarianWarScenario.gd
class_name HungarianWarScenario
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")

var game_state
var war_manager
var battle_manager
var rng: RandomNumberGenerator


func _init(
	state: RefCounted = null,
	war_mgr = null,
	battle_mgr = null,
	rng_ref: RandomNumberGenerator = null
) -> void:
	if state != null:
		game_state = state
	if war_mgr != null:
		war_manager = war_mgr
	if battle_mgr != null:
		battle_manager = battle_mgr
	if rng_ref != null:
		rng = rng_ref


const PROVINCE_DEVIN := "bratislava"
const TERRAIN_DEVIN := "river"
const HUNGARIAN_MAIN_ARMY_SIZE := 12000
const MORAVIAN_MAIN_ARMY_SIZE := 8000
const HUNGARIAN_REINFORCEMENTS_SIZE := 3000
const MORAVIAN_REINFORCEMENTS_SIZE := 2000


func create_initial_armies() -> Dictionary:
	var hungarian_main: Dictionary = {
		"faction_id": "hungary",
		"size": HUNGARIAN_MAIN_ARMY_SIZE,
		"morale": 85.0,
		"composition": {"infantry": 0.4, "cavalry": 0.5, "archers": 0.1},
		"commander": {"skill": 8}
	}
	var moravian_main: Dictionary = {
		"faction_id": "moravia",
		"size": MORAVIAN_MAIN_ARMY_SIZE,
		"morale": 90.0,
		"composition": {"infantry": 0.6, "cavalry": 0.2, "archers": 0.2},
		"commander": {"skill": 9}
	}
	var hungarian_reinforcements: Dictionary = {
		"faction_id": "hungary",
		"size": HUNGARIAN_REINFORCEMENTS_SIZE,
		"morale": 70.0,
		"composition": {"infantry": 0.5, "cavalry": 0.4, "archers": 0.1},
		"commander": {"skill": 6}
	}
	var moravian_reinforcements: Dictionary = {
		"faction_id": "moravia",
		"size": MORAVIAN_REINFORCEMENTS_SIZE,
		"morale": 75.0,
		"composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
		"commander": {"skill": 7}
	}

	return {
		"hungarian_main": hungarian_main,
		"moravian_main": moravian_main,
		"hungarian_reinforcements": hungarian_reinforcements,
		"moravian_reinforcements": moravian_reinforcements
	}


func resolve_devine_battle() -> Dictionary:
	var armies: Dictionary = create_initial_armies()
	var hungarian: Dictionary = armies["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies["moravian_main"].duplicate(true)

	# Apply terrain modifiers (river)
	var tm: Dictionary = C.TERRAIN_MODIFIERS.get(TERRAIN_DEVIN, C.TERRAIN_MODIFIERS["field"])
	hungarian["morale"] = clampf(float(hungarian["morale"]) + float(tm["attackerMorale"]) + C.HUNGARIAN_RIVER_MORALE, 0.0, 100.0)
	moravian["morale"] = clampf(float(moravian["morale"]) + float(tm["defenderMorale"]), 0.0, 100.0)

	# Apply Greek fire bonus (defender morale ×1.15)
	moravian["morale"] = clampf(float(moravian["morale"]) * 1.15, 0.0, 100.0)

	# Auto-resolve
	var outcome: Dictionary = battle_manager.auto_resolve(hungarian, moravian, TERRAIN_DEVIN)

	# Apply rewards if defender wins
	if outcome.get("winner", "") == "defender":
		var rewards: Dictionary = {
			"prestige": 5,
			"gold": 1000,
			"loyalty_bonus": 10
		}
		var resources: Dictionary = game_state.get("resources") or {}
		resources["prestige"] = int(resources.get("prestige", 50)) + rewards["prestige"]
		resources["gold"] = int(resources.get("gold", 1000)) + rewards["gold"]
		game_state.set("resources", resources)
		
		var provinces: Dictionary = game_state.get("provinces") or {}
		for province_id in ["nitra", "bratislava"]:
			if provinces.has(province_id):
				var province: Dictionary = provinces[province_id]
				province["loyalty"] = int(province.get("loyalty", 50)) + rewards["loyalty_bonus"]
				provinces[province_id] = province
		game_state.set("provinces", provinces)
		
		outcome["rewards_applied"] = rewards

	# Clear occupation if defender wins
	if war_manager.set_occupier(PROVINCE_DEVIN, ""):
		outcome["occupation_applied"] = false

	return outcome