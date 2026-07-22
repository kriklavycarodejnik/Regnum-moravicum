# test/integration/test_runner.gd

extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"


func _generate_test_suites() -> void:
	# M4 testy
	add_test_suite("res://test/m4/test_succession_manager.gd")
	add_test_suite("res://test/m4/test_religion_manager.gd")
	add_test_suite("res://test/m4/test_victory_manager.gd")
	
	# M5 testy
	add_test_suite("res://test/m5/test_army_manager.gd")
	add_test_suite("res://test/m5/test_campaign_manager.gd")
	
	# Integračné testy
	add_test_suite("res://test/integration/test_campaign_determinism.gd")
	add_test_suite("res://test/integration/test_historical_accuracy.gd")
	add_test_suite("res://test/integration/test_performance.gd")