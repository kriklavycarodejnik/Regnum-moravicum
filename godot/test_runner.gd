# test_runner.gd
@tool
extends EditorScript

func _run():
	var test_suite = preload("res://addons/gdUnit4/src/GdUnitTestSuite.gd").new()
	test_suite.add_test("res://test/battle/test_battle_formulas.gd")
	test_suite.add_test("res://test/battle/test_battle_manager.gd")
	test_suite.add_test("res://test/scenarios/test_hungarian_war_scenario.gd")
	test_suite.run()
	print("Test run completed")