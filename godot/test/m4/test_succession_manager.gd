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

	# Setup nobles — all male (canon: male-only inheritance within dynasty).
	# Mojmír II. is the ruling knieža; Predslav (born 860) is the oldest living male
	# dynastic relative; Svätopluk II. (born 880) is the next-generation candidate.
	game_state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true,
		"dynasty_id": "mojmir",
		"prestige": 50,
		"gender": "male"
	}
	game_state.nobles["svatopluk_ii"] = {
		"id": "svatopluk_ii",
		"name": "Svätopluk II.",
		"birth_year": 880,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 30,
		"gender": "male"
	}
	game_state.nobles["predslav"] = {
		"id": "predslav",
		"name": "Predslav",
		"birth_year": 860,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 40,
		"gender": "male"
	}


func test_set_succession_type():
	# ANALYZA_KANONU.md Chyba c.2: only seniority and primogeniture are canon.
	# Election must be rejected.
	assert_that(succession_manager.set_succession_type("seniority")).is_true()
	assert_that(succession_manager.set_succession_type("primogeniture")).is_true()
	assert_that(succession_manager.set_succession_type("election")).is_false()
	assert_that(succession_manager.set_succession_type("invalid")).is_false()


func test_get_heir_seniority():
	succession_manager.set_succession_type("seniority")
	var heir: Dictionary = succession_manager.get_heir()
	# Seniority: oldest living male dynastic relative → Predslav (born 860)
	assert_that(heir.get("id", "")).is_equal("predslav")


func test_get_heir_primogeniture():
	succession_manager.set_succession_type("primogeniture")
	var heir: Dictionary = succession_manager.get_heir()
	# Primogeniture: next-generation candidate (born after ruler) → Svätopluk II. (born 880)
	assert_that(heir.get("id", "")).is_equal("svatopluk_ii")


func test_get_heir_no_candidates_returns_empty():
	# No dynastic males available → empty heir (crisis, not election)
	game_state.nobles = {
		"mojmir_ii": {
			"id": "mojmir_ii",
			"name": "Mojmír II.",
			"birth_year": 870,
			"is_ruler": true,
			"dynasty_id": "mojmir",
			"prestige": 50,
			"gender": "male"
		}
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.is_empty()).is_true()


func test_process_succession_seniority_transfer():
	succession_manager.set_succession_type("seniority")
	# Simulate ruler death: clear is_ruler before tick processes succession
	game_state.nobles["mojmir_ii"]["is_ruler"] = false
	var old_ruler_name: String = "Mojmír II."
	var report: Dictionary = succession_manager.process_succession()
	var new_ruler: Dictionary = succession_manager._get_current_ruler()

	assert_that(report.get("type", "")).is_equal("succession")
	assert_that(report.get("old_ruler", "")).is_equal(old_ruler_name)
	assert_that(report.get("new_ruler", "")).is_equal("Predslav")
	assert_that(new_ruler.get("is_ruler", false)).is_true()
	# Old ruler remains non-ruler
	assert_that(game_state.nobles["mojmir_ii"].get("is_ruler", true)).is_false()


func test_process_succession_crisis_on_empty_line():
	# Dynasty line extinct → dynastic crisis, not election
	game_state.nobles = {
		"mojmir_ii": {
			"id": "mojmir_ii",
			"name": "Mojmír II.",
			"birth_year": 870,
			"is_ruler": true,
			"dynasty_id": "mojmir",
			"prestige": 50,
			"gender": "male"
		}
	}
	# Ruler dies with no dynastic heir
	game_state.nobles["mojmir_ii"]["is_ruler"] = false
	var report: Dictionary = succession_manager.process_succession()
	assert_that(report.get("event", "")).is_equal("dynastic_crisis")
	assert_that(report.get("new_ruler", null)).is_nil()
	assert_that(report.get("heir", null)).is_nil()
	# Verify no one was elected to the throne
	var ruler_after: Dictionary = succession_manager._get_current_ruler()
	assert_that(ruler_after.is_empty()).is_true()


func test_process_succession_alive_ruler_no_change():
	succession_manager.set_succession_type("seniority")
	# Ruler alive → process_succession reports heir but does not transfer rule
	var report: Dictionary = succession_manager.process_succession()
	var ruler: Dictionary = succession_manager._get_current_ruler()

	assert_that(report.get("type", "")).is_equal("succession")
	assert_that(report.get("old_ruler", "")).is_equal("Mojmír II.")
	assert_that(report.get("heir", null).get("id", "")).is_equal("predslav")
	assert_that(ruler.get("is_ruler", false)).is_true()
	assert_that(report.get("new_ruler", null)).is_nil()
