# scripts/managers/EventManager.gd
class_name EventManager
extends RefCounted

## Minimal event system — first real player decision (gameplay milestone).
## Full event engine (conditions, weights, historical chains) comes later (M2+/M3).

var game_state
var rng: RandomNumberGenerator
var _months_since_choice: int = 0


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref


func process_events() -> Dictionary:
	# If player already has a pending choice, do not raise another
	if game_state.pending_event != null:
		return {"type": "event", "raised": false, "waiting": true}

	_months_since_choice += 1
	# First real decision around month 3, then occasionally
	var should_raise := false
	if _months_since_choice == 3:
		should_raise = true
	elif _months_since_choice > 12 and rng.randf() < 0.08:
		should_raise = true

	if not should_raise:
		return {"type": "event", "raised": false}

	var ev := _build_council_event()
	game_state.pending_event = ev
	_months_since_choice = 0
	return {
		"type": "event",
		"raised": true,
		"id": ev["id"],
		"title": ev["title"]
	}


func _build_council_event() -> Dictionary:
	return {
		"id": "council_gift_or_fortify",
		"title": "Rada županov",
		"body": "Župani žiadajú tvoje slovo: poslať dary na upokojenie hraníc, alebo opevniť kľúčové hradištia?",
		"choices": [
			{
				"id": "gifts",
				"label": "Poslať dary (zlato -30, lojalita +5)",
				"effects": {"gold": -30, "loyalty_all": 5}
			},
			{
				"id": "fortify",
				"label": "Opevniť hradištia (zlato -20, drevo -10, prosperita +3)",
				"effects": {"gold": -20, "wood": -10, "prosperity_all": 3}
			}
		]
	}


func resolve_choice(choice_id: String) -> Dictionary:
	if game_state.pending_event == null:
		return {"ok": false, "error": "no_pending_event"}

	var ev: Dictionary = game_state.pending_event
	var chosen: Dictionary = {}
	for c in ev.get("choices", []):
		if str(c.get("id", "")) == choice_id:
			chosen = c
			break
	if chosen.is_empty():
		return {"ok": false, "error": "unknown_choice"}

	var effects: Dictionary = chosen.get("effects", {})
	_apply_effects(effects)
	game_state.pending_event = null

	var line := "Rozhodnutie: %s — %s" % [ev.get("title", "Udalosť"), chosen.get("label", choice_id)]
	game_state.chronicle.append({
		"year": game_state.year,
		"month": game_state.month,
		"text": line
	})

	return {"ok": true, "choice": choice_id, "effects": effects, "chronicle": line}


func _apply_effects(effects: Dictionary) -> void:
	if effects.has("gold"):
		game_state.resources["gold"] = maxi(0, int(game_state.resources.get("gold", 0)) + int(effects["gold"]))
	if effects.has("wood"):
		game_state.resources["wood"] = maxi(0, int(game_state.resources.get("wood", 0)) + int(effects["wood"]))
	if effects.has("loyalty_all"):
		var d: int = int(effects["loyalty_all"])
		for pid in game_state.provinces:
			var p = game_state.provinces[pid]
			if typeof(p) == TYPE_DICTIONARY:
				p["loyalty"] = clampi(int(p.get("loyalty", 50)) + d, 0, 100)
	if effects.has("prosperity_all"):
		var d2: int = int(effects["prosperity_all"])
		for pid2 in game_state.provinces:
			var p2 = game_state.provinces[pid2]
			if typeof(p2) == TYPE_DICTIONARY:
				p2["prosperity"] = clampi(int(p2.get("prosperity", 50)) + d2, 0, 100)
