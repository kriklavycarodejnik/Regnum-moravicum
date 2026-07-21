# test/m4/test_runner.gd
@tool
extends EditorScript

func _run():
	var test_suite = preload("res://addons/gdUnit4/src/GdUnitTestSuite.gd").new()
	test_suite.add_test("res://test/m4/test_succession_manager.gd")
	test_suite.add_test("res://test/m4/test_religion_manager.gd")
	test_suite.add_test("res://test/m4/test_victory_manager.gd")
	test_suite.run()
	print("M4 test run completed")