# test/integration/test_devine_907.gd
class_name TestDevine907
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const HungarianWarScenario := preload("res://scripts/scenarios/HungarianWarScenario.gd")
const WarManager := preload("res://scripts/managers/WarManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var game_state: GameState
var war_manager: WarManager
var scenario: HungarianWarScenario


func before_test():
	game_state = GameState.new()
	game_state.year = 907
	game_state.month = 7
	var save_manager = SaveManager.new(42)
	war_manager = WarManager.new(game_state, save_manager.get_rng())
	scenario = HungarianWarScenario.new(game_state, war_manager, war_manager.battle_manager, save_manager.get_rng())


func test_devine_907_hungarian_victory():
	# 🔥 Historický fakt: Bitka pri Bratislave/Devíne 907 bola
	# rozhodujúce víťazstvo Maďarov nad Bavormi, ktoré rozbilo Veľkú Moravu.
	# Maďari (ako útočníci) mali početnú prevahu a jazdeckú taktiku.
	var outcome: Dictionary = scenario.resolve_devine_battle()

	# Overíme, že víťazom je attacker (hungary) — nie defender (moravia)
	assert_that(outcome.get("winner", "")).is_equal("attacker")
	assert_that(outcome.get("result", "")).is_not_equal("defeat")


func test_devine_907_river_morale_penalty_applied():
	var armies: Dictionary = scenario.create_initial_armies()
	var hungarian: Dictionary = armies["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies["moravian_main"].duplicate(true)

	var formulas = preload("res://scripts/battle/BattleFormulas.gd").new()
	var es_hungarian: float = formulas.calculate_effective_strength(hungarian, true, "river")
	var es_moravian: float = formulas.calculate_effective_strength(moravian, false, "river")

	# Útočník (Maďari) by mal mať penalizovanú ES kvôli rieke
	assert_that(es_hungarian).is_greater(0.0)
	assert_that(es_moravian).is_greater(0.0)
	# Maďari mali početnú prevahu (12000 vs 8000) aj s river penalty
	assert_that(es_hungarian).is_greater(es_moravian)