# test/test_base.gd
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const SAVE_MANAGER := preload("res://scripts/core/SaveManager.gd")
const ARMY_MANAGER := preload("res://scripts/managers/ArmyManager.gd")
const WAR_MANAGER := preload("res://scripts/managers/WarManager.gd")
const CAMPAIGN_MANAGER := preload("res://scripts/managers/CampaignManager.gd")


func _make_world(seed_value: int):
	var state = GAME_STATE.new()
	var save = SAVE_MANAGER.new()
	save._init(seed_value)
	var rng = save.get_rng()
	
	# Load provinces
	var map_manager = load("res://scripts/managers/MapManager.gd").new()
	map_manager._init(state)
	map_manager.load_provinces_from_dir("res://data/provinces/")
	
	# Initialize managers
	var army = ARMY_MANAGER.new()
	army._init(state, rng)
	var war = WAR_MANAGER.new()
	war._init(state, rng)
	var campaign = CAMPAIGN_MANAGER.new()
	campaign._init(state, war, null, rng)
	
	return {
		"state": state,
		"army": army,
		"war": war,
		"campaign": campaign
	}


func assert_eq(a, b, message: String = "") -> void:
	if a != b:
		push_error("ASSERT_EQ FAILED: %s\nExpected: %s\nGot: %s" % [message, str(a), str(b)])
		get_tree().quit(1)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		push_error("ASSERT_TRUE FAILED: %s" % message)
		get_tree().quit(1)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		push_error("ASSERT_FALSE FAILED: %s" % message)
		get_tree().quit(1)