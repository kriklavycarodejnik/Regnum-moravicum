# scripts/core/SaveManager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://save.dat"
const AUTOSAVE_PATH := "user://autosave.dat"
const _GameState := preload("res://scripts/core/GameState.gd")

var rng := RandomNumberGenerator.new()
var current_seed: int = 0


func _init(seed_value: int = 42) -> void:
	rng.seed = seed_value
	current_seed = seed_value


func get_rng() -> RandomNumberGenerator:
	return rng


func save_game(state, path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	var dict: Dictionary = state.to_dict()
	dict["_save_version"] = SAVE_VERSION
	dict["_rng_seed"] = current_seed
	dict["_rng_state"] = rng.get_state()

	file.store_string(JSON.stringify(dict))
	file.close()
	return true


func load_game(path: String = DEFAULT_PATH):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var content: String = file.get_as_text()
	file.close()

	var dict: Dictionary = JSON.parse_string(content)
	if typeof(dict) != TYPE_DICTIONARY:
		return null

	if dict.get("_save_version", 0) != SAVE_VERSION:
		return null

	current_seed = int(dict.get("_rng_seed", 42))
	rng.seed = current_seed
	rng.set_state(dict.get("_rng_state", []))

	var state = _GameState.new()
	state.year = int(dict.get("year", 902))
	state.month = int(dict.get("month", 1))
	state.provinces = dict.get("provinces", {}).duplicate(true)
	state.nobles = dict.get("nobles", {}).duplicate(true)
	state.factions = dict.get("factions", {}).duplicate(true)
	state.resources = dict.get("resources", {
		"gold": 1000,
		"food": 5000,
		"wood": 2000,
		"stone": 1000,
		"iron": 500,
		"prestige": 50
	}).duplicate(true)
	state.chronicle = dict.get("chronicle", []).duplicate(true)
	state.pending_event = dict.get("pending_event", null)
	state.armies = dict.get("armies", {}).duplicate(true)
	state.army_templates = dict.get("army_templates", {}).duplicate(true)
	return state


func autosave_if_year_end(state) -> bool:
	if state.month == 12:
		return save_game(state, AUTOSAVE_PATH)
	return true