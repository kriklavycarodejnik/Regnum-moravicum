# scripts/managers/MapManager.gd
class_name MapManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var provinces: Dictionary = {}


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state


func load_provinces_from_dir(dir_path: String) -> int:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return 0

	var count: int = 0
	if dir.file_exists("provinces.json"):
		var file = FileAccess.open(dir_path + "/provinces.json", FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			var json: Dictionary = JSON.parse_string(content)
			if typeof(json) == TYPE_DICTIONARY:
				provinces = json.duplicate(true)
				count = json.size()
				game_state.provinces = provinces.duplicate(true)

	else:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.begins_with("."):
				var file = FileAccess.open(dir_path + "/" + file_name, FileAccess.READ)
				if file != null:
					var content: String = file.get_as_text()
					var json: Dictionary = JSON.parse_string(content)
					if typeof(json) == TYPE_DICTIONARY:
						var province_id: String = file_name.get_basename()
						provinces[province_id] = json.duplicate(true)
						count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	# Inicializovať neighbors a religion pre každú provinciu
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		if not province.has("neighbors"):
			province["neighbors"] = []
		if not province.has("religion"):
			province["religion"] = "pagan"
	game_state.provinces = provinces.duplicate(true)
	return count


func get_province(province_id: String) -> Dictionary:
	return provinces.get(province_id, {})


func get_provinces() -> Dictionary:
	return provinces.duplicate(true)