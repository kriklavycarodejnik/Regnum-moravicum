# scripts/core/GameState.gd
extends RefCounted

const DEFAULT_RESOURCES: Dictionary = {
	"gold": 1000,
	"food": 500,
	"wood": 300,
	"stone": 200,
	"iron": 100,
	"prestige": 50,
}

var year: int = 902
var month: int = 1
var provinces: Dictionary = {}
var nobles: Dictionary = {}
var factions: Dictionary = {}
var resources: Dictionary = {
	"gold": 1000,
	"food": 500,
	"wood": 300,
	"stone": 200,
	"iron": 100,
	"prestige": 50,
}
var armies: Dictionary = {}
var army_templates: Dictionary = {}
var chronicle: Array = []
var pending_event = null
var game_over: bool = false
var ending: Dictionary = {}
var devine_resolved: bool = false
var triggered_events: Array = []
var event_cooldowns: Dictionary = {}
var tutorial_step: int = 0
var tutorial_done: bool = false


func to_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"provinces": provinces.duplicate(true),
		"nobles": nobles.duplicate(true),
		"factions": factions.duplicate(true),
		"resources": resources.duplicate(true),
		"armies": armies.duplicate(true),
		"army_templates": army_templates.duplicate(true),
		"chronicle": chronicle.duplicate(true),
		"pending_event": pending_event,
		"game_over": game_over,
		"ending": ending.duplicate(true),
		"devine_resolved": devine_resolved,
		"triggered_events": triggered_events.duplicate(true),
		"event_cooldowns": event_cooldowns.duplicate(true),
		"tutorial_step": tutorial_step,
		"tutorial_done": tutorial_done,
	}


func from_dict(data: Dictionary) -> void:
	year = int(data.get("year", 902))
	month = int(data.get("month", 1))
	provinces = data.get("provinces", {}) as Dictionary
	if provinces == null:
		provinces = {}
	else:
		provinces = provinces.duplicate(true)
	nobles = data.get("nobles", {}) as Dictionary
	if nobles == null:
		nobles = {}
	else:
		nobles = nobles.duplicate(true)
	factions = data.get("factions", {}) as Dictionary
	if factions == null:
		factions = {}
	else:
		factions = factions.duplicate(true)
	var loaded_res = data.get("resources", {})
	resources = _merge_resources(loaded_res)
	armies = data.get("armies", {}) as Dictionary
	if armies == null:
		armies = {}
	else:
		armies = armies.duplicate(true)
	army_templates = data.get("army_templates", {}) as Dictionary
	if army_templates == null:
		army_templates = {}
	else:
		army_templates = army_templates.duplicate(true)
	var chron = data.get("chronicle", [])
	chronicle = chron if typeof(chron) == TYPE_ARRAY else []
	pending_event = data.get("pending_event", null)
	game_over = bool(data.get("game_over", false))
	var endv = data.get("ending", {})
	ending = endv.duplicate(true) if typeof(endv) == TYPE_DICTIONARY else {}
	devine_resolved = bool(data.get("devine_resolved", false))
	var trev = data.get("triggered_events", [])
	triggered_events = trev.duplicate(true) if typeof(trev) == TYPE_ARRAY else []
	var eco = data.get("event_cooldowns", {})
	event_cooldowns = eco.duplicate(true) if typeof(eco) == TYPE_DICTIONARY else {}
	tutorial_step = int(data.get("tutorial_step", 0))
	tutorial_done = bool(data.get("tutorial_done", false))


func _merge_resources(loaded) -> Dictionary:
	var out: Dictionary = {
		"gold": 1000,
		"food": 500,
		"wood": 300,
		"stone": 200,
		"iron": 100,
		"prestige": 50,
	}
	if typeof(loaded) != TYPE_DICTIONARY:
		return out
	var ld: Dictionary = loaded
	for k in ld.keys():
		out[str(k)] = ld[k]
	return out


func ensure_resources() -> void:
	resources = _merge_resources(resources)
