# scripts/managers/DiplomacyManager.gd
class_name DiplomacyManager
extends RefCounted

## M3 skeleton — faction moods + personality drift.
## Full treaty AI ports React diplomacyEngine later.

var game_state
var rng: RandomNumberGenerator

const PERSONALITY_DRIFT := {
	"aggressive": -1.5,
	"loyal": 0.5,
	"opportunist": -0.5,
	"traitor": -1.0,
	"diplomatic": 0.25
}


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref
	_ensure_default_factions()


func _ensure_default_factions() -> void:
	if not game_state.factions.is_empty():
		return
	# React INITIAL_FACTIONS parity (kánon v1.1 — bez Kumánov pri štarte 902)
	var defaults := [
		{"id": "zupani", "name": "Župani", "personality": "loyal", "mood": 70.0},
		{"id": "cyrilometodski", "name": "Cyrilometodskí Kňazi", "personality": "opportunist", "mood": 55.0},
		{"id": "byzantski", "name": "Byzantskí Poslovia", "personality": "opportunist", "mood": 50.0},
		{"id": "nemecki", "name": "Nemeckí Kolonisti", "personality": "traitor", "mood": 40.0},
		{"id": "madari", "name": "Maďarské zvyšky", "personality": "aggressive", "mood": 30.0},
		{"id": "bogatovci", "name": "Bogatovci", "personality": "opportunist", "mood": 45.0}
	]
	for f in defaults:
		game_state.factions[f["id"]] = f.duplicate(true)


func decay_moods() -> void:
	for fid in game_state.factions:
		var f = game_state.factions[fid]
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var personality: String = str(f.get("personality", "opportunist"))
		var drift: float = float(PERSONALITY_DRIFT.get(personality, -0.25))
		var mood: float = float(f.get("mood", 50.0))
		# Small noise from seeded RNG
		drift += rng.randf_range(-0.15, 0.15)
		f["mood"] = clampf(mood + drift, 0.0, 100.0)


func get_mood(faction_id: String) -> float:
	var f = game_state.factions.get(faction_id)
	if f == null or typeof(f) != TYPE_DICTIONARY:
		return 50.0
	return float(f.get("mood", 50.0))


func apply_gift(faction_id: String, gold_cost: int = 20) -> Dictionary:
	if int(game_state.resources.get("gold", 0)) < gold_cost:
		return {"ok": false, "error": "not_enough_gold"}
	game_state.resources["gold"] = int(game_state.resources.get("gold", 0)) - gold_cost
	var f = game_state.factions.get(faction_id)
	if f == null or typeof(f) != TYPE_DICTIONARY:
		return {"ok": false, "error": "unknown_faction"}
	f["mood"] = clampf(float(f.get("mood", 50.0)) + 8.0, 0.0, 100.0)
	return {"ok": true, "faction": faction_id, "mood": f["mood"]}


func process_diplomacy() -> Dictionary:
	decay_moods()
	var summary: Array = []
	for fid in game_state.factions:
		var f = game_state.factions[fid]
		if typeof(f) == TYPE_DICTIONARY:
			summary.append({
				"id": fid,
				"mood": f.get("mood", 50.0),
				"personality": f.get("personality", "")
			})
	return {
		"type": "diplomacy",
		"factions": summary,
		"placeholder": true
	}
