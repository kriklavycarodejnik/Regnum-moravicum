# scripts/managers/VictoryManager.gd
class_name VictoryManager
extends RefCounted

## M4 skeleton — victory conditions (prestige, provinces, religion).
## Full port from React victoryEngine later.

var game_state

# Victory conditions
const VICTORY_CONDITIONS := {
	"prestige": {"threshold": 100, "description": "Dosiahnuť 100 prestíž"},
	"provinces": {"threshold": 10, "description": "Ovládať 10 žúp"},
	"religion": {"threshold": 1.0, "description": "Konvertovať všetky župy na dominantné náboženstvo"}
}


func _init(state) -> void:
	game_state = state


func check_victory() -> Dictionary:
	var prestige: int = int(game_state.resources.get("prestige", 0))
	var owned_provinces: int = 0
	var dominant_religion: String = "pagan"  # Placeholder, should come from ReligionManager
	var converted_provinces: int = 0

	for province_id in game_state.provinces:
		var province: Dictionary = game_state.provinces[province_id]
		if typeof(province) == TYPE_DICTIONARY and str(province.get("owner_faction", "")) == "moravia":
			owned_provinces += 1
			# Placeholder: check religion
			if str(province.get("religion", "pagan")) == dominant_religion:
				converted_provinces += 1

	var conditions_met: Dictionary = {
		"prestige": prestige >= VICTORY_CONDITIONS["prestige"]["threshold"],
		"provinces": owned_provinces >= VICTORY_CONDITIONS["provinces"]["threshold"],
		"religion": float(converted_provinces) / float(game_state.provinces.size()) >= VICTORY_CONDITIONS["religion"]["threshold"]
	}

	var victory: bool = conditions_met["prestige"] and conditions_met["provinces"] and conditions_met["religion"]
	var victory_type: String = ""
	if victory:
		if conditions_met["prestige"]:
			victory_type = "prestige"
		elif conditions_met["provinces"]:
			victory_type = "provinces"
		else:
			victory_type = "religion"

	return {
		"victory": victory,
		"victory_type": victory_type,
		"conditions": conditions_met,
		"details": {
			"prestige": prestige,
			"owned_provinces": owned_provinces,
			"converted_provinces": converted_provinces,
			"total_provinces": game_state.provinces.size()
		}
	}