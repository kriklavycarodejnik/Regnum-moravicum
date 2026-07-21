# test/m4/test_succession_manager.gd
class_name TestSuccessionManager
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const SuccessionManager := preload("res://scripts/managers/SuccessionManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var succession_manager
var game_state
var save_manager


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	succession_manager = SuccessionManager.new(game_state, save_manager.get_rng())

	# Setup nobles
	game_state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true,
		"dynasty_id": "mojmir",
		"prestige": 50
	}
	game_state.nobles["svatopluk_ii"] = {
		"id": "svatopluk_ii",
		"name": "Svätopluk II.",
		"birth_year": 880,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 30
	}
	game_state.nobles["predslav"] = {
		"id": "predslav",
		"name": "Predslav",
		"birth_year": 860,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 40
	}


func test_set_succession_type():
	assert_that(succession_manager.set_succession_type("seniority")).is_true()
	assert_that(succession_manager.set_succession_type("primogeniture")).is_true()
	assert_that(succession_manager.set_succession_type("election")).is_true()
	assert_that(succession_manager.set_succession_type("invalid")).is_false()


func test_get_heir_seniority():
	succession_manager.set_succession_type("seniority")
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("predslav")  # Oldest living male


func test_get_heir_primogeniture():
	succession_manager.set_succession_type("primogeniture")
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("svatopluk_ii")  # Firstborn son


func test_get_heir_election():
	succession_manager.set_succession_type("election")
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_in(["svatopluk_ii", "predslav"])  # Weighted random


func test_process_succession():
	succession_manager.set_succession_type("seniority")
	var old_ruler: Dictionary = succession_manager._get_current_ruler()
	var report: Dictionary = succession_manager.process_succession()
	var new_ruler: Dictionary = succession_manager._get_current_ruler()

	assert_that(report.get("type", "")).is_equal("succession")
	assert_that(report.get("old_ruler", "")).is_equal(old_ruler.get("name", ""))
	assert_that(report.get("new_ruler", "")).is_equal(new_ruler.get("name", ""))
	assert_that(new_ruler.get("is_ruler", false)).is_true()
	assert_that(old_ruler.get("is_ruler", true)).is_false()


func test_no_heir():
	game_state.nobles = {}
	game_state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true,
		"dynasty_id": "mojmir",
		"prestige": 50
	}
	var report: Dictionary = succession_manager.process_succession()
	assert_that(report.get("event", "")).is_equal("no_heir")