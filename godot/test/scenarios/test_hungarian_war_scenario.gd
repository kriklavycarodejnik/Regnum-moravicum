# test/scenarios/test_hungarian_war_scenario.gd
class_name TestHungarianWarScenario
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const HungarianWarScenario := preload("res://scripts/scenarios/HungarianWarScenario.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")
const WarManager := preload("res://scripts/managers/WarManager.gd")
const BattleManager := preload("res://scripts/managers/BattleManager.gd")
const MapManager := preload("res://scripts/managers/MapManager.gd")

var scenario
var game_state
var save_manager
var war_manager
var battle_manager
var map_manager


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	var rng = save_manager.get_rng()
	war_manager = WarManager.new(game_state, rng)
	battle_manager = war_manager.battle_manager
	map_manager = MapManager.new(game_state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	scenario = HungarianWarScenario.new(game_state, war_manager, battle_manager, rng)


func test_devine_battle_determinism():
	var s1 = HungarianWarScenario.new(game_state.duplicate(true), war_manager, battle_manager, SaveManager.new(77).get_rng())
	var s2 = HungarianWarScenario.new(game_state.duplicate(true), war_manager, battle_manager, SaveManager.new(77).get_rng())

	var r1: Dictionary = s1.resolve_devine_battle()
	var r2: Dictionary = s2.resolve_devine_battle()

	assert_that(r1["winner"]).is_equal(r2["winner"])
	assert_that(r1["result"]).is_equal(r2["result"])
	assert_that(r1["phase_logs"].size()).is_equal(r2["phase_logs"].size())


func test_devine_battle_rewards():
	# Force Moravian victory
	var armies: Dictionary = scenario.create_initial_armies()
	armies["hungarian_main"]["morale"] = 10.0  # Force rout
	var outcome: Dictionary = scenario.resolve_devine_battle()

	assert_that(outcome["winner"]).is_equal("defender")
	assert_that(outcome.has("rewards_applied")).is_true()
	var rewards: Dictionary = outcome["rewards_applied"]
	assert_that(rewards["prestige"]).is_equal(5)
	assert_that(rewards["gold"]).is_equal(1000)
	assert_that(rewards["loyalty_bonus"]).is_equal(10)


func test_devine_battle_river_morale():
	var armies: Dictionary = scenario.create_initial_armies()
	var hungarian_morale_before: float = float(armies["hungarian_main"]["morale"])
	var outcome: Dictionary = scenario.resolve_devine_battle()
	var hungarian_morale_after: float = float(outcome["armies"]["hungarian_main"]["morale"])

	assert_that(hungarian_morale_after).is_less_than(hungarian_morale_before)
	assert_that(hungarian_morale_after).is_less_or_equal(70.0)


func test_devine_battle_occupation():
	# Force Hungarian victory
	var armies: Dictionary = scenario.create_initial_armies()
	armies["moravian_main"]["morale"] = 10.0  # Force rout
	var outcome: Dictionary = scenario.resolve_devine_battle()

	assert_that(outcome["winner"]).is_equal("attacker")
	assert_that(outcome["occupation_applied"]).is_true()
	assert_that(game_state.provinces["bratislava"]["occupier_faction"]).is_equal("madari")