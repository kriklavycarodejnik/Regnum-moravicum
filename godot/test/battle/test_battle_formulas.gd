# test/battle/test_battle_formulas.gd
class_name TestBattleFormulas
extends "res://addons/gdUnit4/src/GdUnitTest.gd"

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
	assert_eq_type(es_field, TYPE_FLOAT)
	assert_true(es_field > 0.0)

	# Fortress
	var es_fortress: float = Formulas.calculate_effective_strength(army, false, "fortress")
	assert_true(es_fortress > es_field, "Fortress should favor defender")

	# Hungarian cavalry on field
	army["faction_id"] = "madari"
	var es_hungarian: float = Formulas.calculate_effective_strength(army, true, "field")
	assert_true(es_hungarian > es_field, "Hungarian cavalry should have bonus on field")


func test_action_counter_matrix():
	# melee > ranged > flank > melee
	assert_eq(Formulas.get_action_modifier("melee", "ranged"), 1.15)
	assert_eq(Formulas.get_action_modifier("ranged", "flank"), 1.15)
	assert_eq(Formulas.get_action_modifier("flank", "melee"), 1.15)
	assert_eq(Formulas.get_action_modifier("melee", "melee"), 1.00)


func test_river_morale_penalty():
	var army: Dictionary = {
		"size": 1000,
		"morale": 80.0,
		"composition": {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2},
		"commander": {"skill": 5},
		"faction_id": "madari"
	}
	var tm: Dictionary = C.TERRAIN_MODIFIERS["river"]
	var expected_morale: float = 80.0 + float(tm["attackerMorale"]) + C.HUNGARIAN_RIVER_MORALE
	army = Formulas.apply_terrain_morale(army, "river", true)
	assert_eq(army["morale"], expected_morale)


func test_composition_factor():
	var comp: Dictionary = {"infantry": 0.5, "cavalry": 0.3, "archers": 0.2}
	var factor_field: float = Formulas.composition_factor(comp, "field", "moravia")
	var factor_fortress: float = Formulas.composition_factor(comp, "fortress", "moravia")
	assert_true(factor_fortress > factor_field, "Fortress should favor infantry")


func test_terrain_bonus():
	var bonus_attacker: float = Formulas.get_terrain_bonus("fortress", true)
	var bonus_defender: float = Formulas.get_terrain_bonus("fortress", false)
	assert_true(bonus_defender > bonus_attacker, "Fortress should favor defender")