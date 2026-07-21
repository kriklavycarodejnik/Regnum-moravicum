# scripts/managers/VictoryManager.gd
class_name VictoryManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state


func check_victory() -> Dictionary:
	var report := {"type": "victory", "victory": false, "victory_type": ""}
	var resources: Dictionary = game_state.get("resources") or {}
	var provinces: Dictionary = game_state.get("provinces") or {}

	# Prestige victory
	if int(resources.get("prestige", 0)) >= 100:
		report.victory = true
		report.victory_type = "prestige"
		return report

	# Province victory
	var owned_provinces: int = 0
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		if str(province.get("owner_faction", "")) == "moravia":
			owned_provinces += 1
	if owned_provinces >= 8:
		report.victory = true
		report.victory_type = "provinces"
		return report

	# Religion victory
	var christian_provinces: int = 0
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		if str(province.get("religion", "")) == "christian":
			christian_provinces += 1
	if christian_provinces >= 6:
		report.victory = true
		report.victory_type = "religion"
		return report

	return report