# scripts/ui/ArtCatalog.gd
# Singleton for centralized art asset lookup.
# Loads art_map.json once and provides path/texture lookup with fallbacks.

extends Node

# Cache for the art map dictionary.
var _art_map: Dictionary = {}

func _ready() -> void:
	_load_art_map()

func _load_art_map() -> void:
	var map_path := "res://data/art_map.json"
	var file = FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		push_warning("ArtCatalog: Could not open art map at %s" % map_path)
		return
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if typeof(data) == TYPE_DICTIONARY:
		_art_map = data.duplicate()
	else:
		push_warning("ArtCatalog: art_map.json is not a dictionary")
		_art_map = {}

# Returns the filesystem path for a given art_id, or empty string if not found.
func path(art_id: String) -> String:
	return _art_map.get(art_id, "")

# Returns a Texture2D for the art_id, or null if not found or fails to load.
func texture(art_id: String) -> Texture2D:
	var p = _art_map.get(art_id, "")
	if p == "":
		return null
	var res = ResourceLoader.load(p)
	if res and res is Texture2D:
		return res as Texture2D
	push_warning("ArtCatalog: Failed to load texture for %s (%s)" % [art_id, p])
	return null

# Convenience: checks if an art_id exists in the map.
func has(art_id: String) -> bool:
	return _art_map.has(art_id)