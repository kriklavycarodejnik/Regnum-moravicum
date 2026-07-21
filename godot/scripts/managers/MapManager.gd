# scripts/managers/MapManager.gd
class_name MapManager
extends RefCounted

var game_state: GameState
var provinces: Dictionary = {}


func _init(state: GameState = null) -> void:
	game_state = state


func load_provinces_from_dir(data_path: String = "res://data/provinces/") -> int:
	provinces.clear()
	var dir := DirAccess.open(data_path)
	if dir == null:
		push_error("MapManager: Cannot open %s" % data_path)
		return 0

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var count := 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := data_path.path_join(file_name)
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var data = JSON.parse_string(file.get_as_text())
				file.close()
				if typeof(data) == TYPE_DICTIONARY and data.has("id"):
					provinces[str(data["id"])] = data
					count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	if game_state != null:
		game_state.provinces = provinces.duplicate(true)

	return count


func get_province(id: String) -> Dictionary:
	return provinces.get(id, {})


func get_all_province_ids() -> Array:
	return provinces.keys()
