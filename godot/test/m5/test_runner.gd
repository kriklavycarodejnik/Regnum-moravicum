# test/m5/test_runner.gd
@tool
extends EditorScript

func _run():
	var test_suite = preload("res://addons/gdUnit4/src/GdUnitTestSuite.gd").new()
	test_suite.add_test("res://test/m5/test_campaign_manager.gd")
	test_suite.add_test("res://test/integration/test_devine_907.gd")
	test_suite.add_test("res://test/integration/test_save_load_m5.gd")
	test_suite.run()
	print("M5 test run completed")