# scripts/managers/DiplomacyManager.gd
class_name DiplomacyManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref
	if game_state != null:
		_ensure_default_factions()


func _ensure_default_factions() -> void:
	if typeof(game_state.factions) != TYPE_DICTIONARY:
		game_state.factions = {}
	var default_factions: Dictionary = {
		"moravia": {"name": "Veľká Morava", "mood": 100.0, "relations": {}},
		"franks": {"name": "Franská ríša", "mood": 50.0, "relations": {}},
		"bavaria": {"name": "Bavorsko", "mood": 40.0, "relations": {}},
		"hungary": {"name": "Maďari", "mood": 20.0, "relations": {}},
		"poland": {"name": "Poľsko", "mood": 30.0, "relations": {}},
		"bohemia": {"name": "Čechy", "mood": 60.0, "relations": {}}
	}

	var factions: Dictionary = game_state.factions
	for faction_id in default_factions:
		if factions.get(faction_id) == null:
			factions[faction_id] = default_factions[faction_id].duplicate(true)
	game_state.factions = factions


func process_diplomacy() -> Dictionary:
	var report := {"type": "diplomacy", "mood_changes": {}}
	var factions: Dictionary = game_state.factions

	for faction_id in factions:
		var mood: float = float(factions[faction_id].get("mood", 50.0))
		mood = clampf(mood + rng.randf_range(-2.0, 2.0), 0.0, 100.0)
		factions[faction_id]["mood"] = mood
		report.mood_changes[faction_id] = mood

	game_state.factions = factions
	return report