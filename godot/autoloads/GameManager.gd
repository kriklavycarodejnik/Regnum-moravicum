# autoloads/GameManager.gd
extends Node

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
var campaign_manager

func _ready() -> void:
	_bootstrap()
	print("GameManager ready — M1–M5 (year %d, provinces %d, factions %d, armies %d)" % [
		game_state.year, game_state.provinces.size(), game_state.factions.size(), game_state.armies.size()
	])

func _bootstrap() -> void:
	var GameState = preload("res://scripts/core/GameState.gd")
	var SaveManager = preload("res://scripts/core/SaveManager.gd")
	var TickManager = preload("res://scripts/core/TickManager.gd")
	var EconomyManager = preload("res://scripts/managers/EconomyManager.gd")
	var NobilityManager = preload("res://scripts/managers/NobilityManager.gd")
	var NarrationManager = preload("res://scripts/managers/NarrationManager.gd")
	var EventManager = preload("res://scripts/managers/EventManager.gd")
	var DiplomacyManager = preload("res://scripts/managers/DiplomacyManager.gd")
	var WarManager = preload("res://scripts/managers/WarManager.gd")
	var SuccessionManager = preload("res://scripts/managers/SuccessionManager.gd")
	var ReligionManager = preload("res://scripts/managers/ReligionManager.gd")
	var VictoryManager = preload("res://scripts/managers/VictoryManager.gd")
	var ArmyManager = preload("res://scripts/managers/ArmyManager.gd")
	var MapManager = preload("res://scripts/managers/MapManager.gd")
	var CampaignManager = preload("res://scripts/managers/CampaignManager.gd")

	game_state = GameState.new()
	if game_state.has_method("ensure_resources"):
		game_state.ensure_resources()
	save_manager = SaveManager.new()
	save_manager._init(42)
	var rng = save_manager.get_rng()
	economy_manager = EconomyManager.new()
	economy_manager._init(game_state)
	nobility_manager = NobilityManager.new()
	nobility_manager._init(game_state, rng)
	narration_manager = NarrationManager.new()
	narration_manager._init(game_state, rng)
	event_manager = EventManager.new()
	event_manager._init(game_state, rng)
	diplomacy_manager = DiplomacyManager.new()
	diplomacy_manager._init(game_state, rng)
	war_manager = WarManager.new()
	war_manager._init(game_state, rng)
	battle_manager = war_manager.battle_manager
	succession_manager = SuccessionManager.new()
	succession_manager._init(game_state, rng)
	religion_manager = ReligionManager.new()
	religion_manager._init(game_state, rng)
	victory_manager = VictoryManager.new()
	victory_manager._init(game_state)
	army_manager = ArmyManager.new()
	army_manager._init(game_state, rng)
	map_manager = MapManager.new()
	map_manager._init(game_state)
	var loaded: int = map_manager.load_provinces_from_dir("res://data/provinces/")
	print("MapManager loaded provinces: ", loaded)
	campaign_manager = CampaignManager.new()
	campaign_manager._init(game_state, war_manager, diplomacy_manager, rng, army_manager)
	tick_manager = TickManager.new()
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
		campaign_manager,
		save_manager
	)

	# Inicializovať nobles
	if game_state.nobles.is_empty():
		game_state.nobles = {
			"mojmir_ii": {"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true, "dynasty_id": "mojmir", "prestige": 50},
			"svatopluk_ii": {"id": "svatopluk_ii", "name": "Svätopluk II.", "birth_year": 880, "is_ruler": false, "dynasty_id": "mojmir", "prestige": 30}
		}

	# M5: Initial armies
	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("moravia_feudal_1", "moravia_feudal", "bratislava")
	army_manager.create_army("madari_horde_1", "madari_horde", "uzhorod", "madari")

func process_next_month() -> Dictionary:
	return tick_manager.process_tick()

func has_pending_event() -> bool:
	return game_state.pending_event != null

func get_pending_event() -> Variant:
	var pending = game_state.pending_event
	if pending == null:
		return null
	# pending is expected to have: text (String), choices (Dict)
	var title = "Udalosť"
	var body = pending.get("text", "")
	var art_id = ""  # let Main.gd use fallback or empty
	var choices_dict = pending.get("choices", {})
	var choices_array = []
	if typeof(choices_dict) == TYPE_DICTIONARY:
		for choice_id in choices_dict.keys():
			var choice = choices_dict[choice_id]
			if typeof(choice) == TYPE_DICTIONARY:
				choices_array.append({
					"id": choice_id,
					"label": choice.get("text", ""),
					"effect": choice.get("effect", {})
				})
	return {
		"title": title,
		"body": body,
		"art_id": art_id,
		"choices": choices_array
	}

func run_skirmish(province_id: String, terrain: String = "field") -> Dictionary:
	return war_manager.resolve_skirmish(province_id, terrain)

func run_devine_battle() -> Dictionary:
	return war_manager.resolve_devine_battle()

func resolve_event_choice(choice_id: String) -> Dictionary:
	return event_manager.resolve_choice(choice_id)

func save() -> bool:
	return save_manager.save_game(game_state)

func load_save() -> bool:
	var loaded = save_manager.load_game()
	if loaded == null:
		return false
	game_state = loaded
	if game_state.has_method("ensure_resources"):
		game_state.ensure_resources()
	var rng = save_manager.get_rng()
	var EconomyManager = preload("res://scripts/managers/EconomyManager.gd")
	var NobilityManager = preload("res://scripts/managers/NobilityManager.gd")
	var NarrationManager = preload("res://scripts/managers/NarrationManager.gd")
	var EventManager = preload("res://scripts/managers/EventManager.gd")
	var DiplomacyManager = preload("res://scripts/managers/DiplomacyManager.gd")
	var WarManager = preload("res://scripts/managers/WarManager.gd")
	var SuccessionManager = preload("res://scripts/managers/SuccessionManager.gd")
	var ReligionManager = preload("res://scripts/managers/ReligionManager.gd")
	var VictoryManager = preload("res://scripts/managers/VictoryManager.gd")
	var ArmyManager = preload("res://scripts/managers/ArmyManager.gd")
	var MapManager = preload("res://scripts/managers/MapManager.gd")
	var CampaignManager = preload("res://scripts/managers/CampaignManager.gd")
	var TickManager = preload("res://scripts/core/TickManager.gd")
	economy_manager = EconomyManager.new()
	economy_manager._init(game_state)
	nobility_manager = NobilityManager.new()
	nobility_manager._init(game_state, rng)
	narration_manager = NarrationManager.new()
	narration_manager._init(game_state, rng)
	event_manager = EventManager.new()
	event_manager._init(game_state, rng)
	diplomacy_manager = DiplomacyManager.new()
	diplomacy_manager._init(game_state, rng)
	war_manager = WarManager.new()
	war_manager._init(game_state, rng)
	battle_manager = war_manager.battle_manager
	succession_manager = SuccessionManager.new()
	succession_manager._init(game_state, rng)
	religion_manager = ReligionManager.new()
	religion_manager._init(game_state, rng)
	victory_manager = VictoryManager.new()
	victory_manager._init(game_state)
	army_manager = ArmyManager.new()
	army_manager._init(game_state, rng)
	map_manager = MapManager.new()
	map_manager._init(game_state)
	map_manager.provinces = game_state.provinces.duplicate(true)
	campaign_manager = CampaignManager.new()
	campaign_manager._init(game_state, war_manager, diplomacy_manager, rng, army_manager)
	tick_manager = TickManager.new()
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
		campaign_manager,
		save_manager
	)
	return true
EOF