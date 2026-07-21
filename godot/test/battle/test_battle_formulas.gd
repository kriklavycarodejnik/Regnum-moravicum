# test/battle/test_battle_formulas.gd
class_name TestBattleFormulas
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const Formulas := preload("res://scripts/battle/BattleFormulas.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")


func test_calculate_effective_strength():
	var army: Dictionary = {
		"size": 1000,
		"morale": 75.0,
		"composition": {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2},
		"commander": {"skill": 5},
		"faction_id": "moravia"
	}

	# Field
	var es_field: float = Formulas.calculate_effective_strength(army, true, "field")
	assert_that(es_field).is_greater_than(0.0)

	# Fortress
	var es_fortress: float = Formulas.calculate_effective_strength(army, false, "fortress")
	assert_that(es_fortress).is_greater_than(es_field)

	# Hungarian cavalry on field
	army["faction_id"] = "madari"
	var es_hungarian: float = Formulas.calculate_effective_strength(army, true, "field")
	assert_that(es_hungarian).is_greater_than(es_field)


func test_action_counter_matrix():
	# melee > ranged > flank > melee
	assert_that(Formulas.get_action_modifier("melee", "ranged")).is_equal(1.15)
	assert_that(Formulas.get_action_modifier("ranged", "flank")).is_equal(1.15)
	assert_that(Formulas.get_action_modifier("flank", "melee")).is_equal(1.15)
	assert_that(Formulas.get_action_modifier("melee", "melee")).is_equal(1.00)


func test_river_morale_penalty():
	var attacker: Dictionary = {
		"size": 1000,
		"morale": 80.0,
		"composition": {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2},
		"commander": {"skill": 5},
		"faction_id": "madari"
	}
	var defender: Dictionary = {
		"size": 1000,
		"morale": 80.0,
		"composition": {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2},
		"commander": {"skill": 5},
		"faction_id": "moravia"
	}
	var morale_before: float = float(attacker["morale"])
	var morale_after: Dictionary = Formulas.apply_terrain_morale(attacker, defender, "river")
	assert_that(morale_after["attacker_morale"]).is_less_than(morale_before)


func test_composition_factor():
	var comp: Dictionary = {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2}
	var factor_field: float = Formulas.composition_factor(comp, "field", "moravia")
	var factor_fortress: float = Formulas.composition_factor(comp, "fortress", "moravia")
	assert_that(factor_fortress).is_greater_than(factor_field)


func test_terrain_bonus():
	var bonus_attacker: float = C.TERRAIN_MODIFIERS["fortress"]["attackBonus"]
	var bonus_defender: float = C.TERRAIN_MODIFIERS["fortress"]["defenseBonus"]
	assert_that(bonus_defender).is_greater_than(bonus_attacker)