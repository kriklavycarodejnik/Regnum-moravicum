# test/m4/test_religion_manager.gd
class_name TestReligionManager
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const ReligionManager := preload("res://scripts/managers/ReligionManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")
const MapManager := preload("res://scripts/managers/MapManager.gd")

var religion_manager
var game_state
var save_manager
var map_manager


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	religion_manager = ReligionManager.new(game_state, save_manager.get_rng())


func test_set_religion():
	assert_that(religion_manager.set_religion("nitra", "christian")).is_true()
	assert_that(religion_manager.set_religion("invalid", "christian")).is_false()
	assert_that(religion_manager.set_religion("nitra", "invalid")).is_false()


func test_get_religion():
	religion_manager.set_religion("nitra", "christian")
	assert_that(religion_manager.get_religion("nitra")).is_equal("christian")
	assert_that(religion_manager.get_religion("invalid")).is_equal("pagan")


func test_convert_province():
	# Force success (seed 42 gives predictable RNG)
	var result: Dictionary = religion_manager.convert_province("nitra", "christian")
	assert_that(result.get("ok", false)).is_true()
	assert_that(result.get("province", "")).is_equal("nitra")
	assert_that(result.get("religion", "")).is_equal("christian")

	# Force failure (invalid)
	var fail_result: Dictionary = religion_manager.convert_province("invalid", "christian")
	assert_that(fail_result.get("ok", true)).is_false()


func test_process_religion():
	# Force some conversions
	religion_manager.set_religion("nitra", "christian")
	religion_manager.set_religion("morava", "orthodox")

	var report: Dictionary = religion_manager.process_religion()
	assert_that(report.get("type", "")).is_equal("religion")
	assert_that(report.get("dominant_religion", "")).is_in(["pagan", "christian", "orthodox"])
	assert_that(report.get("changes", []).size()).is_greater_or_equal(0)