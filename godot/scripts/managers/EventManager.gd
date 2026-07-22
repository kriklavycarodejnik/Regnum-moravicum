# scripts/managers/EventManager.gd
class_name EventManager
extends RefCounted

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func process_events() -> Dictionary:
	var pending_event: Variant = game_state.pending_event if "pending_event" in game_state else null
	if pending_event != null and typeof(pending_event) == TYPE_DICTIONARY:
		return {
			"type": "event",
			"text": str(pending_event.get("text", "")),
			"choices": pending_event.get("choices", {}),
		}

	if rng != null and rng.randf_range(0.0, 1.0) < 0.08:
		var new_event: Dictionary = _build_council_event()
		game_state.pending_event = new_event
		return {
			"type": "event",
			"text": str(new_event.get("text", "")),
			"choices": new_event.get("choices", {}),
		}

	return {"type": "event", "text": "", "choices": []}


func resolve_choice(choice_id: String) -> Dictionary:
	var pending_event: Variant = game_state.pending_event if "pending_event" in game_state else null
	if pending_event == null or typeof(pending_event) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_choice"}
	var choices_v = pending_event.get("choices", {})
	if typeof(choices_v) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_choice"}
	var choices: Dictionary = choices_v
	if not choices.has(choice_id):
		return {"ok": false, "error": "invalid_choice"}
	var choice_v = choices[choice_id]
	if typeof(choice_v) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_choice"}
	var choice: Dictionary = choice_v
	var effect_v = choice.get("effect", {})
	var effect: Dictionary = effect_v if typeof(effect_v) == TYPE_DICTIONARY else {}
	var resources: Dictionary = game_state.resources

	if effect.has("gold"):
		resources["gold"] = int(resources.get("gold", 1000)) + int(effect.get("gold", 0))
	if effect.has("prestige"):
		resources["prestige"] = int(resources.get("prestige", 50)) + int(effect.get("prestige", 0))
	game_state.resources = resources

	game_state.pending_event = null
	return {
		"ok": true,
		"effect": effect,
		"chronicle": str(choice.get("text", choice_id)),
	}


func _build_council_event() -> Dictionary:
	return {
		"title": "Rada županov",
		"text": "Rada županov: Ako chcete posilniť ríšu?",
		"art_id": "moravian_court_interior",
		"choices": {
			"gifts": {
				"text": "Rozdať dary (500 zlata, +10 prestíž)",
				"effect": {"gold": -500, "prestige": 10},
			},
			"fortify": {
				"text": "Postaviť opevnenie (300 zlata, +5 prestíž)",
				"effect": {"gold": -300, "prestige": 5},
			},
		},
	}
