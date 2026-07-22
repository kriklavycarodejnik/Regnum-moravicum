# scripts/core/GameState.gd
class_name GameState
extends RefCounted

var year: int = 902
var month: int = 1

var provinces: Dictionary = {}
var nobles: Dictionary = {}
var factions: Dictionary = {}
var resources: Dictionary = {"gold": 1000, "prestige": 50}
var armies: Dictionary = {}
var army_templates: Dictionary = {}
var chronicle: Array = []
var pending_event = null


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
		"pending_event": pending_event
	}


func from_dict(data: Dictionary) -> void:
	year = data.get("year", 902)
	month = data.get("month", 1)
	provinces = data.get("provinces", {}).duplicate(true)
	nobles = data.get("nobles", {}).duplicate(true)
	factions = data.get("factions", {}).duplicate(true)
	resources = data.get("resources", {"gold": 1000, "prestige": 50}).duplicate(true)
	armies = data.get("armies", {}).duplicate(true)
	army_templates = data.get("army_templates", {}).duplicate(true)
	chronicle = data.get("chronicle", []).duplicate(true)
	pending_event = data.get("pending_event", null)