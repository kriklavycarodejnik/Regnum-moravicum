# test/scenarios/test_hungarian_war_scenario.gd
class_name TestHungarianWarScenario
extends "res://addons/gdUnit4/src/GdUnitTest.gd"

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

	assert_eq(r1.get("winner"), r2.get("winner"))
	assert_eq(r1.get("result"), r2.get("result"))
	assert_eq(r1.get("phase_logs").size(), r2.get("phase_logs").size())


func test_devine_battle_rewards():
	# Force Moravian victory
	var armies: Dictionary = scenario.create_initial_armies()
	armies["hungarian_main"]["morale"] = 10.0  # Force rout
	var outcome: Dictionary = scenario.resolve_devine_battle()

	assert_eq(outcome.get("winner"), "defender")
	assert_true(outcome.has("rewards_applied"))
	var rewards: Dictionary = outcome.get("rewards_applied")
	assert_eq(rewards.get("prestige", 0), 5)
	assert_eq(rewards.get("gold", 0), 1000)
	assert_eq(rewards.get("loyalty_bonus", 0), 10)


func test_devine_battle_river_morale():
	var armies: Dictionary = scenario.create_initial_armies()
	var hungarian_morale_before: float = float(armies["hungarian_main"].get("morale", 0))
	var outcome: Dictionary = scenario.resolve_devine_battle()
	var hungarian_morale_after: float = float(outcome.get("armies", {})["hungarian_main"].get("morale", 0))

	assert_true(hungarian_morale_after < hungarian_morale_before, "River morale penalty should apply")
	assert_true(hungarian_morale_after <= 70.0, "Morale should be <= 70 after river penalty")


func test_devine_battle_occupation():
	# Force Hungarian victory
	var armies: Dictionary = scenario.create_initial_armies()
	armies["moravian_main"]["morale"] = 10.0  # Force rout
	var outcome: Dictionary = scenario.resolve_devine_battle()

	assert_eq(outcome.get("winner"), "attacker")
	assert_true(outcome.get("occupation_applied", false))
	assert_eq(game_state.provinces["devin"].get("occupier_faction", ""), "madari")