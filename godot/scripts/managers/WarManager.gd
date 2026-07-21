# scripts/managers/WarManager.gd
class_name WarManager
extends RefCounted

## M3 skeleton — adjacency + occupation stubs.
## Full battle resolution ports Phase 2 React battle engine later.

var game_state
var rng: RandomNumberGenerator


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref


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
	## Provinces owned by faction that border a different owner/occupier.
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


func process_wars() -> Dictionary:
	## Placeholder monthly war tick — no auto battles yet.
	var frontiers := list_frontiers("moravia")
	return {
		"type": "war",
		"frontier_count": frontiers.size(),
		"frontiers_sample": frontiers.slice(0, mini(3, frontiers.size())),
		"placeholder": true
	}
