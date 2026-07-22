# scripts/managers/EventManager.gd
class_name EventManager
extends RefCounted

const _GameState := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func process_events() -> Dictionary:
	var pending_event: Variant = game_state.pending_event if "pending_event" in game_state else null
	if pending_event != null:
		return {"type": "event", "text": pending_event.text, "choices": pending_event.choices}

	if rng.randf_range(0.0, 1.0) < 0.08:
		var new_event: Dictionary = _build_council_event()
		game_state.set("pending_event", new_event)
		return {"type": "event", "text": new_event.text, "choices": new_event.choices}

	return {"type": "event", "text": "", "choices": []}


func resolve_choice(choice_id: String) -> Dictionary:
	var pending_event: Variant = game_state.pending_event if "pending_event" in game_state else null
	if pending_event == null or not pending_event.choices.has(choice_id):
		return {"ok": false, "error": "invalid_choice"}

	var choice: Dictionary = pending_event.choices[choice_id]
	var effect: Dictionary = choice.get("effect", {})
	var resources: Dictionary = game_state.resources

	if effect.has("gold"):
		resources["gold"] = int(resources.get("gold", 1000)) + int(effect.gold)
	if effect.has("prestige"):
		resources["prestige"] = int(resources.get("prestige", 50)) + int(effect.prestige)
	game_state.resources = resources

	game_state.set("pending_event", null)
	return {"ok": true, "effect": effect}


func _build_council_event() -> Dictionary:
	return {
		"text": "Rada županov: Ako chcete posilniť ríšu?",
		"choices": {
			"gifts": {
				"text": "Rozdať dary (500 zlata, +10 prestíž)",
				"effect": {"gold": -500, "prestige": 10}
			},
			"fortify": {
				"text": "Postaviť opevnenie (300 zlata, +5 prestíž)",
				"effect": {"gold": -300, "prestige": 5}
			}
		}
	}