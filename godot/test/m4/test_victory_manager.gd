# test/m4/test_victory_manager.gd
class_name TestVictoryManager
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const VictoryManager := preload("res://scripts/managers/VictoryManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const MapManager := preload("res://scripts/managers/MapManager.gd")

var victory_manager
var game_state
var map_manager


func before_test():
	game_state = GameState.new()
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	victory_manager = VictoryManager.new(game_state)

	# Setup initial state
	game_state.resources["prestige"] = 0
	for province_id in game_state.provinces:
		var province: Dictionary = game_state.provinces[province_id]
		province["owner_faction"] = "moravia"
		province["religion"] = "pagan"


func test_check_victory_no_conditions():
	var report: Dictionary = victory_manager.check_victory()
	assert_that(report.get("victory", true)).is_false()
	assert_that(report.get("victory_type", "")).is_equal("")


func test_check_victory_prestige():
	game_state.resources["prestige"] = 100
	var report: Dictionary = victory_manager.check_victory()
	assert_that(report.get("victory", false)).is_true()
	assert_that(report.get("victory_type", "")).is_equal("prestige")


func test_check_victory_provinces():
	game_state.resources["prestige"] = 0
	var owned: int = 0
	for province_id in game_state.provinces:
		if owned < 10:
			game_state.provinces[province_id]["owner_faction"] = "moravia"
			owned += 1
		else:
			game_state.provinces[province_id]["owner_faction"] = "madari"

	var report: Dictionary = victory_manager.check_victory()
	assert_that(report.get("victory", false)).is_true()
	assert_that(report.get("victory_type", "")).is_equal("provinces")


func test_check_victory_religion():
	game_state.resources["prestige"] = 0
	for province_id in game_state.provinces:
		game_state.provinces[province_id]["religion"] = "christian"

	var report: Dictionary = victory_manager.check_victory()
	assert_that(report.get("victory", false)).is_true()
	assert_that(report.get("victory_type", "")).is_equal("religion")