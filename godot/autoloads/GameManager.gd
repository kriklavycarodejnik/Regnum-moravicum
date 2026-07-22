# autoloads/GameManager.gd
extends Node

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const SAVE_MANAGER := preload("res://scripts/core/SaveManager.gd")
const TICK_MANAGER := preload("res://scripts/core/TickManager.gd")
const ECONOMY_MANAGER := preload("res://scripts/managers/EconomyManager.gd")
const NOBILITY_MANAGER := preload("res://scripts/managers/NobilityManager.gd")
const NARRATION_MANAGER := preload("res://scripts/managers/NarrationManager.gd")
const EVENT_MANAGER := preload("res://scripts/managers/EventManager.gd")
const DIPLOMACY_MANAGER := preload("res://scripts/managers/DiplomacyManager.gd")
const WAR_MANAGER := preload("res://scripts/managers/WarManager.gd")
const BATTLE_MANAGER := preload("res://scripts/managers/BattleManager.gd")
const SUCCESSION_MANAGER := preload("res://scripts/managers/SuccessionManager.gd")
const RELIGION_MANAGER := preload("res://scripts/managers/ReligionManager.gd")
const VICTORY_MANAGER := preload("res://scripts/managers/VictoryManager.gd")
const ARMY_MANAGER := preload("res://scripts/managers/ArmyManager.gd")
const MAP_MANAGER := preload("res://scripts/managers/MapManager.gd")
const CAMPAIGN_MANAGER := preload("res://scripts/managers/CampaignManager.gd")

var game_state: GameState
var save_manager: SaveManager
var tick_manager: TickManager
var economy_manager: EconomyManager
var nobility_manager: NobilityManager
var narration_manager: NarrationManager
var event_manager: EventManager
var diplomacy_manager: DiplomacyManager
var war_manager: WarManager
var battle_manager: BattleManager
var succession_manager: SuccessionManager
var religion_manager: ReligionManager
var victory_manager: VictoryManager
var army_manager: ArmyManager
var map_manager: MapManager
var campaign_manager: CampaignManager


func _ready() -> void:
	_bootstrap()
	print("GameManager ready — M1+M2+M3+M4+M5 (year %d, provinces %d, factions %d, armies %d)" % [
		game_state.year, game_state.provinces.size(), game_state.factions.size(), game_state.armies.size()
	])


func _bootstrap() -> void:
	game_state = GAME_STATE.new()
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
	campaign_manager = CAMPAIGN_MANAGER.new()
	campaign_manager._init(game_state, war_manager, diplomacy_manager, rng)
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

	# Inicializovať nobles
	if game_state.nobles.is_empty():
		game_state.nobles = {
			"mojmir_ii": {
				"id": "mojmir_ii",
				"name": "Mojmír II.",
				"birth_year": 870,
				"is_ruler": true,
				"dynasty_id": "mojmir",
				"prestige": 50
			},
			"svatopluk_ii": {
				"id": "svatopluk_ii",
				"name": "Svätopluk II.",
				"birth_year": 880,
				"is_ruler": false,
				"dynasty_id": "mojmir",
				"prestige": 30
			}
		}

	# M5: Initial armies
	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("moravia_feudal_1", "moravia_feudal", "bratislava")
	army_manager.create_army("madari_horde_1", "madari_horde", "uzhorod", "madari")


func process_next_month() -> Dictionary:
	return tick_manager.process_tick()


func resolve_event_choice(choice_id: String) -> Dictionary:
	return event_manager.resolve_choice(choice_id)


func has_pending_event() -> bool:
	return game_state.chronicle.size() > 0


func get_pending_event() -> Variant:
	if game_state.chronicle.size() > 0:
		return game_state.chronicle[-1]
	return null


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
	map_manager.provinces = game_state.provinces.duplicate(true)
	campaign_manager = CAMPAIGN_MANAGER.new()
	campaign_manager._init(game_state, war_manager, diplomacy_manager, rng)
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