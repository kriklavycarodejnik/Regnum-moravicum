# scripts/core/GameState.gd
class_name GameState
extends RefCounted

var year: int = 902
var month: int = 1

var provinces: Dictionary = {}
var nobles: Dictionary = {}
var factions: Dictionary = {}
var resources: Dictionary = {
	"gold": 1000,
	"food": 100,
	"wood": 50,
	"stone": 50,
	"iron": 30,
	"prestige": 10
}
var chronicle: Array = []
## Pending player decision (null = none). Blocks free progression flavor until resolved.
var pending_event: Variant = null


func duplicate_state():
	var new_state = get_script().new()
	new_state.year = year
	new_state.month = month
	new_state.provinces = provinces.duplicate(true)
	new_state.nobles = nobles.duplicate(true)
	new_state.factions = factions.duplicate(true)
	new_state.resources = resources.duplicate(true)
	new_state.chronicle = chronicle.duplicate(true)
	new_state.pending_event = pending_event.duplicate(true) if typeof(pending_event) == TYPE_DICTIONARY else pending_event
	return new_state


func to_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"provinces": provinces,
		"nobles": nobles,
		"factions": factions,
		"resources": resources,
		"chronicle": chronicle,
		"pending_event": pending_event
	}


static func from_dict(data: Dictionary):
	var script = load("res://scripts/core/GameState.gd")
	var s = script.new()
	s.year = int(data.get("year", 902))
	s.month = int(data.get("month", 1))
	s.provinces = data.get("provinces", {})
	s.nobles = data.get("nobles", {})
	s.factions = data.get("factions", {})
	s.resources = data.get("resources", s.resources)
	s.chronicle = data.get("chronicle", [])
	s.pending_event = data.get("pending_event", null)
	return s
