# scripts/managers/WarManager.gd
class_name WarManager
extends RefCounted

const _BattleManager := preload("res://scripts/managers/BattleManager.gd")
const _HungarianWarScenario := preload("res://scripts/scenarios/HungarianWarScenario.gd")

var game_state
var rng: RandomNumberGenerator
var battle_manager
var hungarian_war_scenario


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref
	battle_manager = _BattleManager.new(state, rng_ref)
	hungarian_war_scenario = _HungarianWarScenario.new(state, self, battle_manager, rng_ref)


func get_neighbors(province_id: String) -> Array:
	var p = game_state.provinces.get(province_id)
	if p == null or typeof(p) != TYPE_DICTIONARY:
		return []
	return p.get("neighbors", [])


func are_adjacent(a: String, b: String) -> bool:
	return b in get_neighbors(a)


func get_owner(province_id: String) -> String:
	var p = game_state.provinces.get(province_id)
	if p == null or typeof(p) != TYPE_DICTIONARY:
		return ""
	return str(p.get("owner_faction", ""))


func set_occupier(province_id: String, faction_id: String) -> bool:
	if not game_state.provinces.has(province_id):
		return false
	var p = game_state.provinces[province_id]
	if typeof(p) != TYPE_DICTIONARY:
		return false
	p["occupier_faction"] = faction_id
	return true


func clear_occupation(province_id: String) -> void:
	var p = game_state.provinces.get(province_id)
	if p != null and typeof(p) == TYPE_DICTIONARY:
		p.erase("occupier_faction")


func list_frontiers(faction_id: String = "moravia") -> Array:
	var frontiers: Array = []
	for pid in game_state.provinces:
		var p = game_state.provinces[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var owner: String = str(p.get("owner_faction", ""))
		if owner != faction_id:
			continue
		for n in p.get("neighbors", []):
			var np = game_state.provinces.get(n)
			if np == null or typeof(np) != TYPE_DICTIONARY:
				continue
			var n_owner: String = str(np.get("occupier_faction", np.get("owner_faction", "")))
			if n_owner != faction_id:
				frontiers.append({"province": pid, "neighbor": n, "neighbor_control": n_owner})
	return frontiers


func resolve_skirmish(province_id: String, terrain: String = "field") -> Dictionary:
	return battle_manager.resolve_border_skirmish(province_id, terrain)


func resolve_devine_battle() -> Dictionary:
	return hungarian_war_scenario.resolve_devine_battle()


func process_war_scenario_tick(tick_count: int) -> Dictionary:
	return hungarian_war_scenario.process_war_tick(tick_count)


func process_wars() -> Dictionary:
	var frontiers: Array = list_frontiers("moravia")
	return {
		"type": "war",
		"frontier_count": frontiers.size(),
		"frontiers_sample": frontiers.slice(0, min(3, frontiers.size())),
		"placeholder": frontiers.is_empty()
	}