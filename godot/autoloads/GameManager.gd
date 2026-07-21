# autoloads/GameManager.gd
extends Node

const _GameState := preload("res://scripts/core/GameState.gd")
const _SaveManager := preload("res://scripts/core/SaveManager.gd")
const _TickManager := preload("res://scripts/core/TickManager.gd")
const _EconomyManager := preload("res://scripts/managers/EconomyManager.gd")
const _NobilityManager := preload("res://scripts/managers/NobilityManager.gd")
const _NarrationManager := preload("res://scripts/managers/NarrationManager.gd")
const _EventManager := preload("res://scripts/managers/EventManager.gd")
const _DiplomacyManager := preload("res://scripts/managers/DiplomacyManager.gd")
const _WarManager := preload("res://scripts/managers/WarManager.gd")
const _BattleManager := preload("res://scripts/managers/BattleManager.gd")
const _MapManager := preload("res://scripts/managers/MapManager.gd")

var game_state
var save_manager
var tick_manager
var economy_manager
var nobility_manager
var narration_manager
var event_manager
var diplomacy_manager
var war_manager
var battle_manager
var map_manager


func _ready() -> void:
	_bootstrap()
	print("GameManager ready – M1+M2+M3 (battle+scenario) year %d provinces %d factions %d" % [
		game_state.year, game_state.provinces.size(), game_state.factions.size()
	])


func _bootstrap() -> void:
	game_state = _GameState.new()
	save_manager = _SaveManager.new(42)
	var rng = save_manager.get_rng()
	economy_manager = _EconomyManager.new(game_state)
	nobility_manager = _NobilityManager.new(game_state, rng)
	narration_manager = _NarrationManager.new(game_state, rng)
	event_manager = _EventManager.new(game_state, rng)
	diplomacy_manager = _DiplomacyManager.new(game_state, rng)
	war_manager = _WarManager.new(game_state, rng)
	battle_manager = war_manager.battle_manager
	map_manager = _MapManager.new(game_state)
	var loaded: int = map_manager.load_provinces_from_dir("res://data/provinces/")
	print("MapManager loaded provinces: ", loaded)
	tick_manager = _TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		event_manager,
		diplomacy_manager,
		war_manager,
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


func resolve_event_choice(choice_id: String) -> Dictionary:
	return event_manager.resolve_choice(choice_id)


func has_pending_event() -> bool:
	return game_state.pending_event != null


func get_pending_event() -> Variant:
	return game_state.pending_event


func run_skirmish(province_id: String = "nitra", terrain: String = "field") -> Dictionary:
	var outcome: Dictionary = war_manager.resolve_skirmish(province_id, terrain)
	var line := "Bitka pri %s (%s): víťaz %s — výsledok %s" % [
		province_id,
		terrain,
		str(outcome.get("winner", "?")),
		str(outcome.get("result", "?"))
	]
	game_state.chronicle.append({
		"year": game_state.year,
		"month": game_state.month,
		"text": line
	})
	outcome["chronicle"] = line
	return outcome


func run_devine_battle() -> Dictionary:
	var outcome: Dictionary = war_manager.resolve_devine_battle()
	var line := "Bitka pri Devíne 907: víťaz %s — %s" % [
		str(outcome.get("winner", "?")),
		str(outcome.get("result", "?"))
	]
	game_state.chronicle.append({
		"year": game_state.year,
		"month": game_state.month,
		"text": line
	})
	if outcome.has("rewards_applied"):
		var r = outcome["rewards_applied"]
		line += " | Odmena: +%d prestíž, +%d zlato, +%d lojalita" % [
			r.get("prestige", 0), r.get("gold", 0), r.get("loyalty_bonus", 0)
		]
	outcome["chronicle"] = line
	return outcome


func save() -> bool:
	return save_manager.save_game(game_state)


func load_save() -> bool:
	var loaded = save_manager.load_game()
	if loaded == null:
		return false
	game_state = loaded
	var rng = save_manager.get_rng()
	economy_manager = _EconomyManager.new(game_state)
	nobility_manager = _NobilityManager.new(game_state, rng)
	narration_manager = _NarrationManager.new(game_state, rng)
	event_manager = _EventManager.new(game_state, rng)
	diplomacy_manager = _DiplomacyManager.new(game_state, rng)
	war_manager = _WarManager.new(game_state, rng)
	battle_manager = war_manager.battle_manager
	map_manager = _MapManager.new(game_state)
	map_manager.provinces = game_state.provinces.duplicate(true)
	tick_manager = _TickManager.new(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		event_manager,
		diplomacy_manager,
		war_manager,
		save_manager
	)
	return true