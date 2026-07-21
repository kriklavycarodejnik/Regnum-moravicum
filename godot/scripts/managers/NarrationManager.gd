# scripts/managers/NarrationManager.gd
class_name NarrationManager
extends RefCounted

const _GameState := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator
var recent_templates: Array = []


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func generate_chronicle(report: Dictionary) -> String:
	var lines: Array = []
	var template: String = ""

	match report.get("type", ""):
		"economy":
			template = _generate_economy_text(report)
		"nobility":
			template = _generate_nobility_text(report)
		"diplomacy":
			template = _generate_diplomacy_text(report)
		"war":
			template = _generate_war_text(report)
		"event":
			template = _generate_event_text(report)
		"succession":
			template = _generate_succession_text(report)
		"religion":
			template = _generate_religion_text(report)
		"victory":
			template = _generate_victory_text(report)
		"armies":
			template = _generate_armies_text(report)
		_:
			return ""

	# Anti-repetition
	if recent_templates.has(template):
		return ""
	recent_templates.append(template)
	if recent_templates.size() > 12:
		recent_templates.pop_front()

	return template


func _generate_economy_text(report: Dictionary) -> String:
	var province_id: String = report.prosperity_growth.keys()[0]
	var prosperity: float = report.prosperity_growth[province_id]
	return "Provincia %s: prosperita %.1f%% (upkeep: %d zlata)" % [province_id, prosperity, report.upkeep.get("nobles", 0)]


func _generate_nobility_text(report: Dictionary) -> String:
	if report.deaths.size() > 0:
		var death = report.deaths[0]
		return "Zomrel šľachtic %s (vek %d)" % [death.name, death.age]
	if report.births.size() > 0:
		var birth = report.births[0]
		return "Narodil sa nový šľachtic: %s" % birth.name
	return ""


func _generate_diplomacy_text(report: Dictionary) -> String:
	return "Diplomatické vzťahy sa menia..."


func _generate_war_text(report: Dictionary) -> String:
	if report.get("occupation_applied", false):
		return "Nepriateľ obsadil provinciu!"
	return "Vojna pokračuje..."


func _generate_event_text(report: Dictionary) -> String:
	return "Dôležitá udalosť: %s" % report.get("text", "?")


func _generate_succession_text(report: Dictionary) -> String:
	if report.get("new_ruler", null) != null:
		var ruler = report.new_ruler
		return "Nový vládca: %s" % ruler.name
	return ""


func _generate_religion_text(report: Dictionary) -> String:
	return "Náboženská situácia: %s" % report.get("dominant_religion", "?")


func _generate_victory_text(report: Dictionary) -> String:
	if report.get("victory", false):
		return "Víťazstvo! %s" % report.get("victory_type", "?")
	return ""


func _generate_armies_text(report: Dictionary) -> String:
	if report.events.size() > 0:
		var event = report.events[0]
		if event.type == "army_desertion":
			return "Armáda %s stráca %d vojakov kvôli nedostatku zásob!" % [event.army_id, event.size_loss]
	return "Armády sú pripravené."