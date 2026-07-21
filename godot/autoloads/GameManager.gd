# autoloads/GameManager.gd
extends Node

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const SAVE_MANAGER := preload("res://scripts/core/SaveManager.gd")
const TICK_MANAGER := preload("res://scripts/core/TickManager.gd")

# Dynamické načítanie manažérov
var ECONOMY_MANAGER := load("res://scripts/managers/EconomyManager.gd")
var NOBILITY_MANAGER := load("res://scripts/managers/NobilityManager.gd")
var NARRATION_MANAGER := load("res://scripts/managers/NarrationManager.gd")
var EVENT_MANAGER := load("res://scripts/managers/EventManager.gd")
var DIPLOMACY_MANAGER := load("res://scripts/managers/DiplomacyManager.gd")
var WAR_MANAGER := load("res://scripts/managers/WarManager.gd")
var BATTLE_MANAGER := load("res://scripts/managers/BattleManager.gd")
var SUCCESSION_MANAGER := load("res://scripts/managers/SuccessionManager.gd")
var RELIGION_MANAGER := load("res://scripts/managers/ReligionManager.gd")
var VICTORY_MANAGER := load("res://scripts/managers/VictoryManager.gd")
var ARMY_MANAGER := load("res://scripts/managers/ArmyManager.gd")
var MAP_MANAGER := load("res://scripts/managers/MapManager.gd")
var HUNGARIAN_WAR_SCENARIO := load("res://scripts/scenarios/HungarianWarScenario.gd")

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
var succession_manager
var religion_manager
var victory_manager
var army_manager
var map_manager


func _ready() -> void:
	_bootstrap()
	var provinces: Dictionary = game_state.get("provinces") or {}
	var factions: Dictionary = game_state.get("factions") or {}
	print("GameManager ready – M1+M2+M3+M4+M5 (year %d, provinces %d, factions %d)" % [
		(game_state.get("year") or 902), provinces.size(), factions.size()
	])


func _bootstrap() -> void:
	game_state = GAME_STATE.new()

	# Inicializácia prázdnych Dictionary pre game_state
	if typeof(game_state.get("nobles")) != TYPE_DICTIONARY:
		game_state.set("nobles", {})
	if typeof(game_state.get("armies")) != TYPE_DICTIONARY:
		game_state.set("armies", {})
	if typeof(game_state.get("provinces")) != TYPE_DICTIONARY:
		game_state.set("provinces", {})
	if typeof(game_state.get("factions")) != TYPE_DICTIONARY:
		game_state.set("factions", {})
	if typeof(game_state.get("resources")) != TYPE_DICTIONARY:
		game_state.set("resources", {"gold": 1000, "prestige": 50})
	if typeof(game_state.get("chronicle")) != TYPE_ARRAY:
		game_state.set("chronicle", [])

	save_manager = SAVE_MANAGER.new()
	save_manager._init(42)
	var rng = save_manager.get_rng()
	economy_manager = ECONOMY_MANAGER.new()
	economy_manager._init(game_state)
	nobility_manager = NOBILITY_MANAGER.new()
	nobility_manager._init(game_state, rng)
	narration_manager = NARRATION_MANAGER.new()
	narration_manager._init(game_state, rng)
	event_manager = EVENT_MANAGER.new()
	event_manager._init(game_state, rng)
	diplomacy_manager = DIPLOMACY_MANAGER.new()
	diplomacy_manager._init(game_state, rng)
	war_manager = WAR_MANAGER.new()
	war_manager._init(game_state, rng)
	battle_manager = war_manager.battle_manager
	succession_manager = SUCCESSION_MANAGER.new()
	succession_manager._init(game_state, rng)
	religion_manager = RELIGION_MANAGER.new()
	religion_manager._init(game_state, rng)
	victory_manager = VICTORY_MANAGER.new()
	victory_manager._init(game_state)
	army_manager = ARMY_MANAGER.new()
	army_manager._init(game_state, rng)
	map_manager = MAP_MANAGER.new()
	map_manager._init(game_state)
	var loaded: int = map_manager.load_provinces_from_dir("res://data/provinces/")
	print("MapManager loaded provinces: ", loaded)
	tick_manager = TICK_MANAGER.new()
	tick_manager._init(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		event_manager,
		diplomacy_manager,
		war_manager,
		succession_manager,
		religion_manager,
		victory_manager,
		army_manager,
		save_manager
	)

	var nobles: Dictionary = game_state.get("nobles") or {}
	if nobles.is_empty():
		nobles["mojmir_ii"] = {
			"id": "mojmir_ii",
			"name": "Mojmír II.",
			"birth_year": 870,
			"is_ruler": true,
			"dynasty_id": "mojmir",
			"prestige": 50
		}
		nobles["svatopluk_ii"] = {
			"id": "svatopluk_ii",
			"name": "Svätopluk II.",
			"birth_year": 880,
			"is_ruler": false,
			"dynasty_id": "mojmir",
			"prestige": 30
		}
		game_state.set("nobles", nobles)

	# M5: Initial armies
	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("moravia_feudal_1", "moravia_feudal", "bratislava")
	army_manager.create_army("madari_horde_1", "madari_horde", "uzhorod", "madari")


func process_next_month() -> Dictionary:
	return tick_manager.process_tick()


func resolve_event_choice(choice_id: String) -> Dictionary:
	return event_manager.resolve_choice(choice_id)


func has_pending_event() -> bool:
	return game_state.get("pending_event") != null


func get_pending_event() -> Variant:
	return game_state.get("pending_event")


func run_skirmish(province_id: String = "nitra", terrain: String = "field") -> Dictionary:
	var outcome: Dictionary = war_manager.resolve_skirmish(province_id, terrain)
	var line := "Bitka pri %s (%s): víťaz %s — výsledok %s" % [
		province_id,
		terrain,
		str(outcome.get("winner", "?")),
		str(outcome.get("result", "?"))
	]
	var chronicle: Array = game_state.get("chronicle") or []
	chronicle.append({
		"year": game_state.get("year") or 902,
		"month": game_state.get("month") or 1,
		"text": line
	})
	game_state.set("chronicle", chronicle)
	outcome["chronicle"] = line
	return outcome


func run_devine_battle() -> Dictionary:
	var outcome: Dictionary = war_manager.resolve_devine_battle()
	var line := "Bitka pri Devíne 907: víťaz %s — %s" % [
		str(outcome.get("winner", "?")),
		str(outcome.get("result", "?"))
	]
	var chronicle: Array = game_state.get("chronicle") or []
	chronicle.append({
		"year": game_state.get("year") or 902,
		"month": game_state.get("month") or 1,
		"text": line
	})
	game_state.set("chronicle", chronicle)
	if outcome.has("rewards_applied"):
		var r = outcome["rewards_applied"]
		line += " | Odmena: +%d prestíž, +%d zlato, +%d lojalita" % [
			r.get("prestige", 0), r.get("gold", 0), r.get("loyalty_bonus", 0)
		]
	outcome["chronicle"] = line
	return outcome


func create_army(army_id: String, template_id: String, province_id: String, faction_id: String = "moravia") -> Dictionary:
	return army_manager.create_army(army_id, template_id, province_id, faction_id)


func move_army(army_id: String, target_province_id: String) -> Dictionary:
	return army_manager.move_army(army_id, target_province_id)


func start_battle(army_id: String, enemy_army_id: String, terrain: String = "field") -> Dictionary:
	return army_manager.start_battle(army_id, enemy_army_id, terrain)


func get_army(army_id: String) -> Dictionary:
	return army_manager.get_army(army_id)


func list_armies(faction_id: String = "", province_id: String = "") -> Array:
	return army_manager.list_armies(faction_id, province_id)


func save() -> bool:
	return save_manager.save_game(game_state)


func load_save() -> bool:
	var loaded = save_manager.load_game()
	if loaded == null:
		return false
	game_state = loaded
	var rng = save_manager.get_rng()
	economy_manager = ECONOMY_MANAGER.new()
	economy_manager._init(game_state)
	nobility_manager = NOBILITY_MANAGER.new()
	nobility_manager._init(game_state, rng)
	narration_manager = NARRATION_MANAGER.new()
	narration_manager._init(game_state, rng)
	event_manager = EVENT_MANAGER.new()
	event_manager._init(game_state, rng)
	diplomacy_manager = DIPLOMACY_MANAGER.new()
	diplomacy_manager._init(game_state, rng)
	war_manager = WAR_MANAGER.new()
	war_manager._init(game_state, rng)
	battle_manager = war_manager.battle_manager
	succession_manager = SUCCESSION_MANAGER.new()
	succession_manager._init(game_state, rng)
	religion_manager = RELIGION_MANAGER.new()
	religion_manager._init(game_state, rng)
	victory_manager = VICTORY_MANAGER.new()
	victory_manager._init(game_state)
	army_manager = ARMY_MANAGER.new()
	army_manager._init(game_state, rng)
	map_manager = MAP_MANAGER.new()
	map_manager._init(game_state)
	var provinces: Dictionary = game_state.get("provinces") or {}
	map_manager.provinces = provinces.duplicate(true)
	tick_manager = TICK_MANAGER.new()
	tick_manager._init(
		game_state,
		economy_manager,
		nobility_manager,
		narration_manager,
		event_manager,
		diplomacy_manager,
		war_manager,
		succession_manager,
		religion_manager,
		victory_manager,
		army_manager,
		save_manager
	)
	return true