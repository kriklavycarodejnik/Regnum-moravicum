# autoloads/GameManager.gd
# Tenký Node wrapper — logika je v RefCounted manažéroch
extends Node

var game_state: GameState
var save_manager: SaveManager
var tick_manager: TickManager
var economy_manager: EconomyManager
var nobility_manager: NobilityManager
var narration_manager: NarrationManager
var map_manager: MapManager


func _ready() -> void:
	_bootstrap()
	print("GameManager ready – M1+M2 core loaded (year %d)" % game_state.year)


func _bootstrap() -> void:
	game_state = GameState.new()
	save_manager = SaveManager.new(42)  # fixed seed for early testing; change later
	economy_manager = EconomyManager.new(game_state)
	nobility_manager = NobilityManager.new(game_state, save_manager.get_rng())
	narration_manager = NarrationManager.new(game_state)
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	tick_manager = TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		save_manager
	)

	# Počiatočný vládca (Mojmír II.)
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
	var loaded := save_manager.load_game()
	if loaded == null:
		return false
	game_state = loaded
	# Rebind managers to loaded state
	economy_manager = EconomyManager.new(game_state)
	nobility_manager = NobilityManager.new(game_state, save_manager.get_rng())
	narration_manager = NarrationManager.new(game_state)
	map_manager = MapManager.new(game_state)
	map_manager.provinces = game_state.provinces.duplicate(true)
	tick_manager = TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		save_manager
	)
	return true
