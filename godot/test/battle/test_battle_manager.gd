# test/battle/test_battle_manager.gd
class_name TestBattleManager
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const BattleManager := preload("res://scripts/managers/BattleManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var battle_manager
var game_state
var save_manager


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	battle_manager = BattleManager.new(game_state, save_manager.get_rng())


func test_make_army():
	var army: Dictionary = battle_manager.make_army(
		"test_army", "moravia", 1000, 75.0,
		{"infantry": 0.5, "cavalry": 0.3, "archers": 0.2},
		5, "Test Commander"
	)
	assert_that(army["id"]).is_equal("test_army")
	assert_that(army["size"]).is_equal(1000)
	assert_that(army["morale"]).is_equal(75.0)
	assert_that(army["commander"].name).is_equal("Test Commander")


func test_auto_resolve_determinism():
	var army_a1 = battle_manager.make_army("a1", "madari", 1000, 75.0, {"infantry": 0.25, "cavalry": 0.55, "archers": 0.20}, 5)
	var army_d1 = battle_manager.make_army("d1", "moravia", 900, 70.0, {"infantry": 0.55, "cavalry": 0.20, "archers": 0.25}, 6)
	var army_a2 = battle_manager.make_army("a2", "madari", 1000, 75.0, {"infantry": 0.25, "cavalry": 0.55, "archers": 0.20}, 5)
	var army_d2 = battle_manager.make_army("d2", "moravia", 900, 70.0, {"infantry": 0.55, "cavalry": 0.20, "archers": 0.25}, 6)

	var b1 = BattleManager.new(game_state, SaveManager.new(99).get_rng())
	var b2 = BattleManager.new(game_state, SaveManager.new(99).get_rng())

	var r1: Dictionary = b1.auto_resolve(army_a1, army_d1, "field")
	var r2: Dictionary = b2.auto_resolve(army_a2, army_d2, "field")

	assert_that(r1["winner"]).is_equal(r2["winner"])
	assert_that(r1["result"]).is_equal(r2["result"])
	assert_that(r1["phase_logs"].size()).is_equal(r2["phase_logs"].size())


func test_rout_condition():
	var army = battle_manager.make_army("test", "moravia", 1000, 15.0, {"infantry": 1.0}, 5)
	var outcome: Dictionary = battle_manager.auto_resolve(
		army,
		battle_manager.make_army("enemy", "madari", 500, 80.0, {"cavalry": 1.0}, 6),
		"field"
	)
	assert_that(outcome["result"]).is_equal("victory_rout")


func test_retreat_condition():
	var army = battle_manager.make_army("test", "moravia", 1000, 30.0, {"infantry": 1.0}, 5)
	army["morale"] = 25.0  # Force retreat
	var outcome: Dictionary = battle_manager.auto_resolve(
		army,
		battle_manager.make_army("enemy", "madari", 500, 80.0, {"cavalry": 1.0}, 6),
		"field"
	)
	assert_that(outcome["result"]).is_equal("retreat")