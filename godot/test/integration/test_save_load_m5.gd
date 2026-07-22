# test/integration/test_save_load_m5.gd
class_name TestSaveLoadM5
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")
const ArmyManager := preload("res://scripts/managers/ArmyManager.gd")

var game_state: GameState
var save_manager: SaveManager
var army_manager: ArmyManager


func before_test():
	game_state = GameState.new()
	save_manager = SaveManager.new(42)
	army_manager = ArmyManager.new(game_state, save_manager.get_rng())

	# Setup M5 state: armies, nobles, provinces
	game_state.provinces = {
		"nitra": {"id": "nitra", "name": "Nitra", "prosperity": 65, "loyalty": 85,
			"religion": 45, "owner_faction": "moravia", "neighbors": ["morava", "bratislava"]},
		"morava": {"id": "morava", "name": "Morava", "prosperity": 70, "loyalty": 90,
			"religion": 50, "owner_faction": "moravia", "neighbors": ["nitra", "bratislava"]}
	}
	game_state.nobles = {
		"mojmir_ii": {"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true, "dynasty_id": "mojmir", "prestige": 50}
	}
	game_state.resources = {"gold": 500, "prestige": 30}

	army_manager.create_army("moravia_levy_1", "moravia_levy", "nitra")
	army_manager.create_army("madari_horde_1", "madari_horde", "uzhorod", "madari")


func test_save_load_roundtrip_m5():
	# Save to temp file
	var tmp_path: String = "user://test_save_m5.dat"
	var saved: bool = save_manager.save_game(game_state, tmp_path)
	assert_that(saved).is_true()

	# Load back
	var loaded: GameState = save_manager.load_game(tmp_path)
	assert_that(loaded).is_not_null()

	# Compare M5-critical fields
	assert_that(loaded.armies.size()).is_equal(game_state.armies.size())
	assert_that(loaded.army_templates.size()).is_equal(game_state.army_templates.size())
	assert_that(loaded.provinces.size()).is_equal(game_state.provinces.size())
	assert_that(loaded.nobles.size()).is_equal(game_state.nobles.size())
	assert_that(loaded.resources.get("gold", 0)).is_equal(game_state.resources.get("gold", 0))

	# Verify army data integrity
	for army_id in loaded.armies:
		assert_that(game_state.armies.has(army_id)).is_true()
		var orig_army: Dictionary = game_state.armies[army_id]
		var loaded_army: Dictionary = loaded.armies[army_id]
		assert_that(loaded_army.get("size", 0)).is_equal(orig_army.get("size", 0))
		assert_that(loaded_army.get("faction_id", "")).is_equal(orig_army.get("faction_id", ""))
		assert_that(loaded_army.get("province_id", "")).is_equal(orig_army.get("province_id", ""))

	# Cleanup
	DirAccess.remove_absolute(tmp_path)