# scripts/managers/NobilityManager.gd
class_name NobilityManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func process_nobility() -> Dictionary:
	var report := {"type": "nobility", "deaths": [], "births": [], "prestige_changes": {}}
	var current_year: int = game_state.year
	var nobles: Dictionary = game_state.nobles

	# Aging and death
	var nobles_to_remove: Array = []
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		var age: int = current_year - int(noble.get("birth_year", 850))
		if age >= 60 and rng.randf_range(0.0, 1.0) < 0.05:
			nobles_to_remove.append(noble_id)
			report.deaths.append({
				"noble_id": noble_id,
				"name": noble.get("name", "?"),
				"age": age
			})
		else:
			# Prestige decay
			noble["prestige"] = int(noble.get("prestige", 10)) - 1
			report.prestige_changes[noble_id] = -1

	for noble_id in nobles_to_remove:
		nobles.erase(noble_id)

	# Births (simplified)
	if rng.randf_range(0.0, 1.0) < 0.1:
		var new_noble_id: String = "noble_" + str(nobles.size() + 1)
		nobles[new_noble_id] = {
			"id": new_noble_id,
			"name": "Nový šľachtic",
			"birth_year": current_year,
			"is_ruler": false,
			"dynasty_id": "mojmir",
			"prestige": 5
		}
		report.births.append({
			"noble_id": new_noble_id,
			"name": "Nový šľachtic",
			"dynasty": "mojmir"
		})

	game_state.nobles = nobles
	return report