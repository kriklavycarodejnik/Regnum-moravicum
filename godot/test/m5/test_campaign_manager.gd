# test/m5/test_campaign_manager.gd
class_name TestCampaignManager
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const CampaignManager := preload("res://scripts/managers/CampaignManager.gd")
const ArmyManager := preload("res://scripts/managers/ArmyManager.gd")
const WarManager := preload("res://scripts/managers/WarManager.gd")
const MapManager := preload("res://scripts/managers/MapManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var game_state: GameState
var save_manager: SaveManager
var army_manager: ArmyManager
var war_manager: WarManager
var campaign_manager: CampaignManager
var map_manager: MapManager
var rng: RandomNumberGenerator


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	rng = save_manager.get_rng()
	army_manager = ArmyManager.new(game_state, rng)
	war_manager = WarManager.new(game_state, rng)
	campaign_manager = CampaignManager.new(game_state, war_manager, null, rng)
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")

	# Setup initial armies for testing
	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("hungary_horde_1", "madari_horde", "uzhorod", "hungary")


func test_campaign_determinism():
	var report_1: Dictionary = campaign_manager.process_campaign()
	# Reset and recreate with same seed
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	rng = save_manager.get_rng()
	army_manager = ArmyManager.new(game_state, rng)
	war_manager = WarManager.new(game_state, rng)
	campaign_manager = CampaignManager.new(game_state, war_manager, null, rng)
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("hungary_horde_1", "madari_horde", "uzhorod", "hungary")
	var report_2: Dictionary = campaign_manager.process_campaign()

	assert_that(report_1).is_equal(report_2)


func test_hungarian_expansion():
	var report: Dictionary = campaign_manager.process_campaign()
	var hungary_events: Array = []
	for event in report.get("events", []):
		if event.get("faction_id", "") == "hungary":
			hungary_events.append(event)

	assert_that(hungary_events.size()).is_greater(0)
	for event in hungary_events:
		var event_type: String = event.get("type", "")
		assert_that(event_type in ["ai_movement", "ai_siege_start"]).is_true()


func test_supply_attrition():
	army_manager.create_army("isolated_army", "moravia_levy", "transylvania", "moravia")
	var report: Dictionary = campaign_manager.process_campaign()
	var attrition_events: Array = []
	for event in report.get("events", []):
		if event.get("type", "") == "attrition":
			attrition_events.append(event)

	assert_that(attrition_events.size()).is_greater(0)
	for event in attrition_events:
		assert_that(event.get("reason", "")).is_equal("out_of_supply")