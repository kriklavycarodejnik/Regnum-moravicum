# scripts/core/SaveManager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://save.dat"
const AUTOSAVE_PATH := "user://autosave.dat"
const GAME_STATE := preload("res://scripts/core/GameState.gd")

var rng: RandomNumberGenerator
var save_seed: int = 42
var event_rng: RandomNumberGenerator


func _init(seed_value: int = 42) -> void:
	save_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	event_rng = RandomNumberGenerator.new()
	event_rng.seed = seed_value


func get_rng() -> RandomNumberGenerator:
	return rng


func get_save_seed() -> int:
	return save_seed

func get_event_rng() -> RandomNumberGenerator:
	return event_rng


func save_game(state: RefCounted, path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: " + path)
		return false

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"seed": rng.seed,
		"state": state.to_dict(),
		"rng_state": rng.state,
		"event_rng_seed": event_rng.seed,
		"event_rng_state": event_rng.state,
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

	save_seed = int(json.get("seed", 42))
	rng.seed = save_seed
	rng.state = int(json.get("rng_state", 0))
	event_rng.seed = int(json.get("event_rng_seed", 42))
	event_rng.state = int(json.get("event_rng_state", 0))
	var state_dict: Dictionary = json.get("state", {})
	if state_dict == null:
		state_dict = {}
	var state = GAME_STATE.new()
	state.from_dict(state_dict)
	return state


func autosave_if_year_end(state: RefCounted) -> bool:
	var current_month: int = state.month
	if current_month != 12:
		return false
	return save_game(state, AUTOSAVE_PATH)