# scripts/managers/WarManager.gd
class_name WarManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const BATTLE_MANAGER := preload("res://scripts/managers/BattleManager.gd")
const HUNGARIAN_WAR_SCENARIO := preload("res://scripts/scenarios/HungarianWarScenario.gd")

var game_state
var rng: RandomNumberGenerator
var battle_manager
var hungarian_war_scenario


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref
	battle_manager = BATTLE_MANAGER.new()
	battle_manager._init(state, rng_ref)
	hungarian_war_scenario = HUNGARIAN_WAR_SCENARIO.new()
	hungarian_war_scenario._init(state, self, battle_manager, rng_ref)


func process_wars() -> Dictionary:
	var report := {"type": "war", "battles": [], "occupations": []}
	var current_year: int = game_state.get("year") or 902
	var current_month: int = game_state.get("month") or 1

	# Check for Devín 907 scenario
	if current_year == 907 and current_month == 7:
		var outcome: Dictionary = hungarian_war_scenario.resolve_devine_battle()
		report.battles.append(outcome)

	return report


func resolve_skirmish(province_id: String, terrain: String = "field") -> Dictionary:
	var attacker: Dictionary = {
		"faction_id": "moravia",
		"size": 1000,
		"morale": 80.0,
		"composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
		"commander": {"skill": 5}
	}
	var defender: Dictionary = {
		"faction_id": "hungary",
		"size": 800,
		"morale": 70.0,
		"composition": {"infantry": 0.5, "cavalry": 0.4, "archers": 0.1},
		"commander": {"skill": 4}
	}
	return battle_manager.auto_resolve(attacker, defender, terrain)


func resolve_devine_battle() -> Dictionary:
	return hungarian_war_scenario.resolve_devine_battle()


func are_adjacent(province_a: String, province_b: String) -> bool:
	var provinces: Dictionary = game_state.get("provinces") or {}
	if not provinces.has(province_a) or not provinces.has(province_b):
		return false
	var neighbors_a: Array = provinces[province_a].get("neighbors", [])
	return neighbors_a.has(province_b)


func set_occupier(province_id: String, faction_id: String) -> bool:
	var provinces: Dictionary = game_state.get("provinces") or {}
	if not provinces.has(province_id):
		return false
	provinces[province_id]["occupier_faction"] = faction_id
	game_state.set("provinces", provinces)
	return true


func list_frontiers() -> Array:
	var frontiers: Array = []
	var provinces: Dictionary = game_state.get("provinces") or {}
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		var owner: String = province.get("owner_faction", "")
		var occupier: String = province.get("occupier_faction", "")
		if owner != occupier and occupier != "":
			frontiers.append({
				"province_id": province_id,
				"owner": owner,
				"occupier": occupier
			})
	return frontiers