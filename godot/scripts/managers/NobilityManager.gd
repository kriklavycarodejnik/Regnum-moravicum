# scripts/managers/NobilityManager.gd
class_name NobilityManager
extends RefCounted

var game_state: GameState
var rng: RandomNumberGenerator


func _init(state: GameState, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref


func age_nobles() -> Array:
	var deaths: Array = []
	for noble_id in game_state.nobles.keys():
		var n = game_state.nobles[noble_id]
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var birth_year: int = int(n.get("birth_year", 870))
		var age: int = game_state.year - birth_year
		if age >= 55:
			var death_chance: float = (age - 54) * 0.02
			if rng.randf() < death_chance:
				deaths.append(noble_id)
	return deaths


func handle_death(noble_id: String) -> Dictionary:
	var n = game_state.nobles.get(noble_id)
	if n == null or typeof(n) != TYPE_DICTIONARY:
		return {}

	var report := {
		"type": "succession",
		"dead_noble": str(n.get("name", noble_id)),
		"was_ruler": bool(n.get("is_ruler", false)),
		"prestige_loss": 0
	}

	if bool(n.get("is_ruler", false)):
		report["prestige_loss"] = 10
		var prestige: int = int(game_state.resources.get("prestige", 0))
		game_state.resources["prestige"] = maxi(0, prestige - 10)

	game_state.nobles.erase(noble_id)
	return report


func process_nobility() -> Dictionary:
	var deaths := age_nobles()
	var reports: Array = []
	for dead_id in deaths:
		reports.append(handle_death(str(dead_id)))
	return {
		"type": "nobility",
		"deaths": reports
	}
