# scripts/managers/ArmyManager.gd
class_name ArmyManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator

# Army types
const ARMY_TYPES := {
	"levy": {"name": "Ľudové milície", "cost": 50, "upkeep": 2, "strength": 0.7},
	"feudal": {"name": "Feudálna armáda", "cost": 100, "upkeep": 5, "strength": 1.0},
	"elite": {"name": "Elitná garda", "cost": 200, "upkeep": 10, "strength": 1.5},
	"mercenary": {"name": "Žoldnieri", "cost": 150, "upkeep": 8, "strength": 1.2}
}

# Army status
const ARMY_STATUS := {
	"idle": "Nečinná",
	"marching": "Na pochode",
	"besieging": "Obliehanie",
	"battling": "V bitke",
	"disbanded": "Rozpustená"
}


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref
	if game_state != null:
		_init_armies()


func _init_armies() -> void:
	var armies: Dictionary = game_state.armies
	var army_templates: Dictionary = game_state.army_templates
	
	# Inicializovať army_templates, ak nie sú definované
	if army_templates.is_empty():
		army_templates = {
			"moravia_levy": {
				"type": "levy",
				"composition": {"infantry": 0.8, "cavalry": 0.1, "archers": 0.1},
				"default_size": 500,
				"max_size": 2000
			},
			"moravia_feudal": {
				"type": "feudal",
				"composition": {"infantry": 0.6, "cavalry": 0.2, "archers": 0.2},
				"default_size": 300,
				"max_size": 1000
			},
			"madari_horde": {
				"type": "elite",
				"composition": {"infantry": 0.3, "cavalry": 0.6, "archers": 0.1},
				"default_size": 800,
				"max_size": 3000
			}
		}
		game_state.army_templates = army_templates
	
	# Inicializovať armies, ak nie sú definované
	if armies.is_empty():
		armies = {}
		game_state.armies = armies


func create_army(
	army_id: String,
	template_id: String,
	province_id: String,
	faction_id: String = "moravia",
	size: int = -1,
	commander_skill: int = 5
) -> Dictionary:
	var army_templates: Dictionary = game_state.army_templates
	if not army_templates.has(template_id):
		return {"ok": false, "error": "invalid_template"}

	var template: Dictionary = army_templates[template_id]
	var army_type: String = str(template.get("type", "levy"))
	var default_size: int = int(template.get("default_size", 500))
	var final_size: int = size if size > 0 else default_size
	final_size = clampi(final_size, 1, int(template.get("max_size", 2000)))

	var army: Dictionary = {
		"id": army_id,
		"template_id": template_id,
		"faction_id": faction_id,
		"province_id": province_id,
		"size": final_size,
		"morale": 70.0,
		"status": "idle",
		"composition": template.get("composition", {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1}),
		"commander": {
			"id": army_id + "_cmd",
			"name": "Veliteľ armády",
			"skill": commander_skill
		},
		"movement_points": 3,
		"supply": 100.0
	}

	var armies: Dictionary = game_state.armies
	armies[army_id] = army
	game_state.armies = armies
	return {"ok": true, "army": army}


func disband_army(army_id: String) -> Dictionary:
	var armies: Dictionary = game_state.armies
	if not armies.has(army_id):
		return {"ok": false, "error": "army_not_found"}

	var army: Dictionary = armies[army_id]
	army["status"] = "disbanded"
	armies.erase(army_id)
	game_state.armies = armies
	return {"ok": true}


func move_army(army_id: String, target_province_id: String) -> Dictionary:
	var armies: Dictionary = game_state.armies
	var provinces: Dictionary = game_state.provinces
	if not armies.has(army_id):
		return {"ok": false, "error": "army_not_found"}
	if not provinces.has(target_province_id):
		return {"ok": false, "error": "province_not_found"}

	var army: Dictionary = armies[army_id]
	if army.get("status", "") != "idle":
		return {"ok": false, "error": "army_not_idle"}

	# Check adjacency
	var current_province_id: String = str(army.get("province_id", ""))
	var current_province: Dictionary = provinces.get(current_province_id, {})
	if typeof(current_province) != TYPE_DICTIONARY or not current_province.get("neighbors", []).has(target_province_id):
		return {"ok": false, "error": "not_adjacent"}

	# Consume movement points
	army["movement_points"] = int(army.get("movement_points", 3)) - 1
	army["province_id"] = target_province_id
	army["status"] = "marching"

	armies[army_id] = army
	game_state.armies = armies
	return {"ok": true, "army": army}


func start_battle(army_id: String, enemy_army_id: String, terrain: String = "field") -> Dictionary:
	var armies: Dictionary = game_state.armies
	if not armies.has(army_id) or not armies.has(enemy_army_id):
		return {"ok": false, "error": "army_not_found"}

	var army: Dictionary = armies[army_id]
	var enemy: Dictionary = armies[enemy_army_id]
	if army.get("faction_id", "") == enemy.get("faction_id", ""):
		return {"ok": false, "error": "same_faction"}

	army["status"] = "battling"
	enemy["status"] = "battling"

	armies[army_id] = army
	armies[enemy_army_id] = enemy
	game_state.armies = armies

	return {
		"ok": true,
		"army": army,
		"enemy": enemy,
		"terrain": terrain
	}


func process_armies() -> Dictionary:
	var report := {"type": "armies", "events": []}
	var armies: Dictionary = game_state.armies
	var resources: Dictionary = game_state.resources
	var army_templates: Dictionary = game_state.army_templates

	# Upkeep
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		if typeof(army) != TYPE_DICTIONARY:
			continue

		var template_id: String = str(army.get("template_id", ""))
		var template: Dictionary = army_templates.get(template_id, {})
		var army_type: String = str(template.get("type", "levy"))
		var upkeep: int = int(ARMY_TYPES.get(army_type, {}).get("upkeep", 2)) * int(army.get("size", 0)) / 100
		resources["gold"] = int(resources.get("gold", 0)) - upkeep

		# Morale recovery
		army["morale"] = clampf(float(army.get("morale", 50.0)) + 2.0, 0.0, 100.0)

		# Movement recovery
		if army.get("status", "") == "marching":
			army["status"] = "idle"
		army["movement_points"] = 3

		# Supply decay
		army["supply"] = clampf(float(army.get("supply", 100.0)) - 5.0, 0.0, 100.0)
		if army["supply"] <= 20.0:
			army["morale"] = clampf(float(army.get("morale", 50.0)) - 3.0, 0.0, 100.0)
			if army["morale"] <= 30.0:
				report.events.append({
					"type": "army_desertion",
					"army_id": army_id,
					"size_loss": int(army.get("size", 0)) * 0.1
				})
				army["size"] = int(army.get("size", 0)) - int(army.get("size", 0)) * 0.1

		armies[army_id] = army

	game_state.armies = armies
	game_state.resources = resources
	return report


func get_army(army_id: String) -> Dictionary:
	var armies: Dictionary = game_state.armies
	return armies.get(army_id, {})


func list_armies(faction_id: String = "", province_id: String = "") -> Array:
	var armies: Dictionary = game_state.armies
	var result: Array = []
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		if typeof(army) != TYPE_DICTIONARY:
			continue
		if faction_id != "" and str(army.get("faction_id", "")) != faction_id:
			continue
		if province_id != "" and str(army.get("province_id", "")) != province_id:
			continue
		result.append(army)
	return result