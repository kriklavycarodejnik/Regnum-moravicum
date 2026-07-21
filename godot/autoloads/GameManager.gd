# autoloads/GameManager.gd
# Tenký Node wrapper — logika je v RefCounted manažéroch
extends Node

const _GameState := preload("res://scripts/core/GameState.gd")
const _SaveManager := preload("res://scripts/core/SaveManager.gd")
const _TickManager := preload("res://scripts/core/TickManager.gd")
const _EconomyManager := preload("res://scripts/managers/EconomyManager.gd")
const _NobilityManager := preload("res://scripts/managers/NobilityManager.gd")
const _NarrationManager := preload("res://scripts/managers/NarrationManager.gd")
const _MapManager := preload("res://scripts/managers/MapManager.gd")

var game_state
var save_manager
var tick_manager
var economy_manager
var nobility_manager
var narration_manager
var map_manager


func _ready() -> void:
	_bootstrap()
	print("GameManager ready – M1+M2 core loaded (year %d, provinces %d)" % [
		game_state.year, game_state.provinces.size()
	])


func _bootstrap() -> void:
	game_state = _GameState.new()
	save_manager = _SaveManager.new(42)
	economy_manager = _EconomyManager.new(game_state)
	nobility_manager = _NobilityManager.new(game_state, save_manager.get_rng())
	narration_manager = _NarrationManager.new(game_state)
	map_manager = _MapManager.new(game_state)
	var loaded: int = map_manager.load_provinces_from_dir("res://data/provinces/")
	print("MapManager loaded provinces: ", loaded)
	tick_manager = _TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		save_manager
	)

	if game_state.nobles.is_empty():
		game_state.nobles["mojmir_ii"] = {
			"id": "mojmir_ii",
			"name": "Mojmír II.",
			"birth_year": 870,
			"is_ruler": true,
			"dynasty_id": "mojmir"
		}


func process_next_month() -> Dictionary:
	return tick_manager.process_tick()


func save() -> bool:
	return save_manager.save_game(game_state)


func load_save() -> bool:
	var loaded = save_manager.load_game()
	if loaded == null:
		return false
	game_state = loaded
	economy_manager = _EconomyManager.new(game_state)
	nobility_manager = _NobilityManager.new(game_state, save_manager.get_rng())
	narration_manager = _NarrationManager.new(game_state)
	map_manager = _MapManager.new(game_state)
	map_manager.provinces = game_state.provinces.duplicate(true)
	tick_manager = _TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		save_manager
	)
	return true
