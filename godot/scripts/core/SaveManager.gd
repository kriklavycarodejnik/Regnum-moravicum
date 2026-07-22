# scripts/core/SaveManager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://save.dat"
const AUTOSAVE_PATH := "user://autosave.dat"
const GAME_STATE := preload("res://scripts/core/GameState.gd")

var rng: RandomNumberGenerator


func _init(seed_value: int = 42) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


func get_rng() -> RandomNumberGenerator:
	return rng


func save_game(state: RefCounted, path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: " + path)
		return false

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"seed": rng.seed,
		"state": state.to_dict(),
		"rng_state": rng.state
	}
	file.store_string(JSON.stringify(save_data))
	file.close()
	return true


func load_game(path: String = DEFAULT_PATH) -> RefCounted:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: " + path)
		return null

	var content: String = file.get_as_text()
	file.close()
	var json: Dictionary = JSON.parse_string(content)
	if typeof(json) != TYPE_DICTIONARY:
		push_error("Invalid save file format")
		return null

	if int(json.get("version", 0)) != SAVE_VERSION:
	    push_error("Save file version mismatch")
	    return null

	rng.seed = int(json.get("seed") or 42)
	rng.state = json.get("rng_state") or 0
	var state_dict: Dictionary = json.get("state") or {}
	var state = GAME_STATE.new()
	state.from_dict(state_dict)
	return state


func autosave_if_year_end(state: RefCounted) -> bool:
	var current_month: int = state.get("month") or 1
	if current_month != 12:
		return false
	return save_game(state, AUTOSAVE_PATH)