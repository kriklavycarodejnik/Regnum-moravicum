# scripts/ui/ArtCatalog.gd
# Autoload — centrálny lookup art_id → cesta / texture.
extends Node

var _art_map: Dictionary = {}
var _tex_cache: Dictionary = {}


func _ready() -> void:
	_load_art_map()


func _load_art_map() -> void:
	var map_path: String = "res://data/art_map.json"
	if not FileAccess.file_exists(map_path):
		push_warning("ArtCatalog: chýba %s" % map_path)
		_art_map = {}
		return
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY:
		_art_map = data
	else:
		_art_map = {}


func path(art_id: String) -> String:
	if art_id == "":
		return ""
	return str(_art_map.get(art_id, ""))


func has(art_id: String) -> bool:
	return art_id != "" and _art_map.has(art_id)


func texture(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	if _tex_cache.has(art_id):
		return _tex_cache[art_id] as Texture2D
	var p: String = path(art_id)
	if p == "" or not ResourceLoader.exists(p):
		return null
	var res = load(p)
	if res is Texture2D:
		_tex_cache[art_id] = res
		return res as Texture2D
	return null


func province_art_id(province_id: String) -> String:
	match province_id:
		"nitra":
			return "nitra_master_hero"
		"devin":
			return "devin_master_fortress"
		"bratislava":
			return "bratislava_master_river"
		"morava":
			return "moravian_court_interior"
		_:
			return ""
