# test/m4/test_succession_seniority.gd
# Rozšírenie testov — seniorátna vetva (seniority branch):
# najstarší mužský príbuzný, nie syn; deterministický test s fixným seedom.
class_name TestSuccessionSeniority
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const SuccessionManager := preload("res://scripts/managers/SuccessionManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var succession_manager
var game_state

# Setup: Mojmír II. (870) je vládca; má syna Rastislava (885) a strýka Predslava (860).
# Seniorita musí vybrať Predslava (najstaršieho mužského), NIE syna Rastislava.
func before_test():
	game_state = GameState.new()
	var save_manager = SaveManager.new(42)
	succession_manager = SuccessionManager.new(game_state, save_manager.get_rng())
	succession_manager.set_succession_type("seniority")

	game_state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true,
		"dynasty_id": "mojmir",
		"prestige": 50,
		"gender": "male"
	}
	# Syn — mladší ako strýk, seniorita musí uprednostniť strýka
	game_state.nobles["rastislav"] = {
		"id": "rastislav",
		"name": "Rastislav",
		"birth_year": 885,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 20,
		"gender": "male"
	}
	# Strýko — najstarší žijúci mužský príbuzný
	game_state.nobles["predslav"] = {
		"id": "predslav",
		"name": "Predslav",
		"birth_year": 860,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 40,
		"gender": "male"
	}


func test_seniority_uncle_over_son():
	# Seniorita vyberie najstaršieho mužského príbuzného → Predslav (860), nie syn Rastislav (885).
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("predslav")
	assert_that(heir.get("name", "")).is_equal("Predslav")
	assert_that(heir.get("birth_year", 0)).is_equal(860)


func test_seniority_female_excluded():
	# Pridáme staršiu ženu (855) — musí byť vylúčená, Predslav (860) ostáva dedičom.
	game_state.nobles["zora"] = {
		"id": "zora",
		"name": "Zora",
		"birth_year": 855,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 35,
		"gender": "female"
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("predslav", "Žena s vyšším vekom nesmie byť vybraná pred mužským príbuzným")


func test_seniority_other_dynasty_excluded():
	# Pridáme mimodynastického šľachtica (850) — vylúčený.
	game_state.nobles["arnold"] = {
		"id": "arnold",
		"name": "Arnold",
		"birth_year": 850,
		"is_ruler": false,
		"dynasty_id": "arnoldovci",
		"prestige": 60,
		"gender": "male"
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("predslav", "Šľachtic z inej dynastie nesmie byť vybraný")


func test_seniority_determinism_same_seed():
	# Rovnaký seed + rovnakí nobless = rovnaký dedič.
	var heir_1: Dictionary = succession_manager.get_heir()

	var game_state_2 = GameState.new()
	var save_manager_2 = SaveManager.new(42)
	var sm2 = SuccessionManager.new(game_state_2, save_manager_2.get_rng())
	sm2.set_succession_type("seniority")
	game_state_2.nobles = game_state.nobles.duplicate(true)

	var heir_2: Dictionary = sm2.get_heir()

	assert_that(heir_1).is_equal(heir_2, "Rovnaký seed + rovnaký setup = rovnaký dedič")


func test_seniority_multiple_candidates_oldest_wins():
	# 5 kandidátov — overíme, že najstarší (Svorad, 845) je vybraný.
	game_state.nobles["svorad"] = {
		"id": "svorad", "name": "Svorad", "birth_year": 845,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 55, "gender": "male"
	}
	game_state.nobles["horislav"] = {
		"id": "horislav", "name": "Horislav", "birth_year": 855,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 45, "gender": "male"
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("svorad", "Najstarší mužský príbuzný z 5 kandidátov")
	assert_that(heir.get("birth_year", 0)).is_equal(845)


func test_seniority_gender_absent_defaults_male():
	# Šľachtic bez gender poľa — implicitne male.
	game_state.nobles["starcek"] = {
		"id": "starcek", "name": "Starček", "birth_year": 840,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 30
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.get("id", "")).is_equal("starcek", "Šľachtic bez gender poľa musí byť predvolene male")


func test_seniority_only_males_in_other_dynasty():
	# Všetci mužskí kandidáti sú z inej dynastie → prázdny dedič.
	for nid in ["predslav", "rastislav"]:
		game_state.nobles[nid]["dynasty_id"] = "iná_dynastia"
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.is_empty()).is_true()


func test_seniority_all_females_excluded():
	# Iba ženy v dynastii → prázdny dedič.
	game_state.nobles.erase("predslav")
	game_state.nobles.erase("rastislav")
	game_state.nobles["bohdana"] = {
		"id": "bohdana", "name": "Bohdana", "birth_year": 850,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 40, "gender": "female"
	}
	game_state.nobles["kvetka"] = {
		"id": "kvetka", "name": "Kvetka", "birth_year": 865,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 30, "gender": "female"
	}
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.is_empty()).is_true("Všetky ženy — dedič musí byť prázdny")


func test_seniority_process_no_ruler_crisis():
	# Vládca zomrie → get_heir() vráti prázdny (lebo nevie určiť dynastiu bez vládcu)
	# → process_succession vráti dynastic_crisis.
	game_state.nobles["mojmir_ii"]["is_ruler"] = false
	var report: Dictionary = succession_manager.process_succession()
	assert_that(report.get("event", "")).is_equal("dynastic_crisis")
	assert_that(report.get("type", "")).is_equal("succession")


func test_seniority_process_ruler_alive():
	# Vládca žije → správa s dedičom, bez transferu.
	var report: Dictionary = succession_manager.process_succession()
	var ruler: Dictionary = succession_manager._get_current_ruler()
	assert_that(report.get("type", "")).is_equal("succession")
	assert_that(ruler.get("is_ruler", false)).is_true()
	assert_that(report.get("new_ruler", null)).is_null()
	assert_that(report.get("heir", {}).get("id", "")).is_equal("predslav")


func test_seniority_get_heir_no_ruler():
	# get_heir() vráti prázdny dict ak neexistuje vládca.
	game_state.nobles["mojmir_ii"]["is_ruler"] = false
	var heir: Dictionary = succession_manager.get_heir()
	assert_that(heir.is_empty()).is_true()