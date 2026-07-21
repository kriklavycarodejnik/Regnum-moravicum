# scripts/managers/EconomyManager.gd
class_name EconomyManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state


func process_economy() -> Dictionary:
	var report := {"type": "economy", "prosperity_growth": {}, "upkeep": {}}
	var provinces: Dictionary = game_state.get("provinces") or {}
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		var prosperity: float = float(province.get("prosperity", 50.0))
		prosperity = clampf(prosperity + 0.5, 0.0, 100.0)
		province["prosperity"] = prosperity
		report.prosperity_growth[province_id] = prosperity

	# Upkeep for nobles
	var total_upkeep: int = 0
	var nobles: Dictionary = game_state.get("nobles") or {}
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		var upkeep: int = int(noble.get("prestige", 10)) * 2
		total_upkeep += upkeep
	var resources: Dictionary = game_state.get("resources") or {}
	resources["gold"] = int(resources.get("gold", 1000)) - total_upkeep
	game_state.set("resources", resources)
	report.upkeep["nobles"] = total_upkeep

	return report