# scripts/core/SaveManager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://save.dat"
const AUTOSAVE_PATH := "user://autosave.dat"
const _GameState := preload("res://scripts/core/GameState.gd")

var rng := RandomNumberGenerator.new()
var current_seed: int = 0


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()
	current_seed = seed_value
	rng.seed = current_seed


func get_rng() -> RandomNumberGenerator:
	return rng


func save_game(state, path: String = DEFAULT_PATH) -> bool:
	# Single source of truth: GameState.to_dict()
	var save_data: Dictionary = state.to_dict()
	save_data["version"] = SAVE_VERSION
	save_data["rng_seed"] = current_seed
	save_data["rng_state"] = rng.state

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Cannot write to %s" % path)
		return false

	file.store_string(JSON.stringify(save_data))
	file.close()
	return true


func load_game(path: String = DEFAULT_PATH):
	if not FileAccess.file_exists(path):
		push_error("SaveManager: Save file does not exist: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: Failed to parse save file")
		return null

	var version := int(data.get("version", 1))
	data = _migrate(data, version)

	var state = _GameState.from_dict(data)

	current_seed = int(data.get("rng_seed", 0))
	rng.seed = current_seed
	rng.state = int(data.get("rng_state", 0))

	return state


func _migrate(data: Dictionary, version: int) -> Dictionary:
	if version < 2:
		if not data.has("pending_event"):
			data["pending_event"] = null
	return data


## One rotating autosave slot (not one file per year).
func autosave(state) -> void:
	save_game(state, AUTOSAVE_PATH)


func autosave_if_year_end(state) -> void:
	if state.month == 12:
		autosave(state)
