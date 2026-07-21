# scripts/managers/EconomyManager.gd
class_name EconomyManager
extends RefCounted

var game_state: GameState


func _init(state: GameState) -> void:
	game_state = state


func grow_prosperity() -> void:
	for province_id in game_state.provinces:
		var p = game_state.provinces[province_id]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var prosperity: int = int(p.get("prosperity", 50))
		p["prosperity"] = clampi(prosperity + 1, 0, 100)


func add_recruitment_pool() -> void:
	# Placeholder — neskôr podľa prosperity a lojality
	pass


func pay_upkeep() -> void:
	var gold: int = int(game_state.resources.get("gold", 0))
	var upkeep: int = 5
	game_state.resources["gold"] = maxi(0, gold - upkeep)


func grow_prestige() -> void:
	var prestige: int = int(game_state.resources.get("prestige", 0))
	game_state.resources["prestige"] = prestige + 1


func process_economy() -> Dictionary:
	var gold_before: int = int(game_state.resources.get("gold", 0))
	var prestige_before: int = int(game_state.resources.get("prestige", 0))

	grow_prosperity()
	add_recruitment_pool()
	pay_upkeep()
	grow_prestige()

	return {
		"type": "economy",
		"gold_change": int(game_state.resources.get("gold", 0)) - gold_before,
		"prestige_change": int(game_state.resources.get("prestige", 0)) - prestige_before
	}
