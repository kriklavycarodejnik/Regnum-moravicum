# scripts/core/GameState.gd
class_name GameState
extends RefCounted

var year: int = 902
var month: int = 1

var provinces: Dictionary = {}
var nobles: Dictionary = {}
var factions: Dictionary = {}
var resources: Dictionary = {
	"gold": 100,
	"food": 100,
	"wood": 50,
	"stone": 40,
	"iron": 30,
	"prestige": 20
}
var chronicle: Array = []


func duplicate_state():
	var new_state = get_script().new()
	new_state.year = year
	new_state.month = month
	new_state.provinces = provinces.duplicate(true)
	new_state.nobles = nobles.duplicate(true)
	new_state.factions = factions.duplicate(true)
	new_state.resources = resources.duplicate(true)
	new_state.chronicle = chronicle.duplicate(true)
	return new_state


func to_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"provinces": provinces,
		"nobles": nobles,
		"factions": factions,
		"resources": resources,
		"chronicle": chronicle
	}


static func from_dict(data: Dictionary):
	# Avoid class_name return type (needs editor global class cache)
	var script = load("res://scripts/core/GameState.gd")
	var s = script.new()
	s.year = int(data.get("year", 902))
	s.month = int(data.get("month", 1))
	s.provinces = data.get("provinces", {})
	s.nobles = data.get("nobles", {})
	s.factions = data.get("factions", {})
	s.resources = data.get("resources", s.resources)
	s.chronicle = data.get("chronicle", [])
	return s
