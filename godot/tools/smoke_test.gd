# tools/smoke_test.gd
extends SceneTree

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const SAVE_MANAGER := preload("res://scripts/core/SaveManager.gd")
const TICK_MANAGER := preload("res://scripts/core/TickManager.gd")
const ECONOMY_MANAGER := preload("res://scripts/managers/EconomyManager.gd")
const NOBILITY_MANAGER := preload("res://scripts/managers/NobilityManager.gd")
const NARRATION_MANAGER := preload("res://scripts/managers/NarrationManager.gd")
const EVENT_MANAGER := preload("res://scripts/managers/EventManager.gd")
const DIPLOMACY_MANAGER := preload("res://scripts/managers/DiplomacyManager.gd")
const WAR_MANAGER := preload("res://scripts/managers/WarManager.gd")
const BATTLE_MANAGER := preload("res://scripts/managers/BattleManager.gd")
const HUNGARIAN_WAR_SCENARIO := preload("res://scripts/scenarios/HungarianWarScenario.gd")
const SUCCESSION_MANAGER := preload("res://scripts/managers/SuccessionManager.gd")
const RELIGION_MANAGER := preload("res://scripts/managers/ReligionManager.gd")
const VICTORY_MANAGER := preload("res://scripts/managers/VictoryManager.gd")
const ARMY_MANAGER := preload("res://scripts/managers/ArmyManager.gd")
const MAP_MANAGER := preload("res://scripts/managers/MapManager.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")


func _make_world(seed_value: int):
	var state = GAME_STATE.new()
	var save = SAVE_MANAGER.new()
	save._init(seed_value)
	var rng = save.get_rng()
	var map = MAP_MANAGER.new()
	map._init(state)
	var loaded: int = map.load_provinces_from_dir("res://data/provinces/")
	
	var nobles: Dictionary = {}
	if typeof(state.get("nobles")) == TYPE_DICTIONARY:
		nobles = state.get("nobles")
	nobles["mojmir_ii"] = {
		"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true, "dynasty_id": "mojmir", "prestige": 50
	}
	nobles["svatopluk_ii"] = {
		"id": "svatopluk_ii", "name": "Svätopluk II.", "birth_year": 880, "is_ruler": false, "dynasty_id": "mojmir", "prestige": 30
	}
	state.set("nobles", nobles)
	
	var eco = ECONOMY_MANAGER.new()
	eco._init(state)
	var nob = NOBILITY_MANAGER.new()
	nob._init(state, rng)
	var nar = NARRATION_MANAGER.new()
	nar._init(state, rng)
	var ev = EVENT_MANAGER.new()
	ev._init(state, rng)
	var dip = DIPLOMACY_MANAGER.new()
	dip._init(state, rng)
	var war = WAR_MANAGER.new()
	war._init(state, rng)
	var suc = SUCCESSION_MANAGER.new()
	suc._init(state, rng)
	var rel = RELIGION_MANAGER.new()
	rel._init(state, rng)
	var vic = VICTORY_MANAGER.new()
	vic._init(state)
	var arm = ARMY_MANAGER.new()
	arm._init(state, rng)
	var tick = TICK_MANAGER.new()
	tick._init(state, eco, nob, nar, ev, dip, war, suc, rel, vic, arm, save)
	return {"state": state, "save": save, "tick": tick, "war": war, "dip": dip, "suc": suc, "rel": rel, "vic": vic, "arm": arm}


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test v8 (M5) ===")

	var w = _make_world(42)
	var state = w.state
	var war = w.war
	var scenario = war.hungarian_war_scenario
	var succession = w.suc
	var religion = w.rel
	var victory = w.vic
	var army = w.arm

	# --- Devín 907 scenario ---
	var devin_outcome: Dictionary = scenario.resolve_devine_battle()
	print("Devín 907 battle: winner=%s result=%s" % [
		devin_outcome.get("winner", "?"), devin_outcome.get("result", "?")
	])
	if devin_outcome.get("winner", "") != "defender":
		print("WARN: Devín 907 should favor defender (river morale, fortress composition)")
	else:
		print("Devín 907 defender win OK")

	# Rewards
	if devin_outcome.has("rewards_applied"):
		var r = devin_outcome["rewards_applied"]
		print("Rewards: +%d prestige, +%d gold, +%d loyalty" % [
			r.get("prestige", 0), r.get("gold", 0), r.get("loyalty_bonus", 0)
		])
		var resources: Dictionary = {}
		if typeof(state.get("resources")) == TYPE_DICTIONARY:
			resources = state.get("resources")
		var prestige: int = resources.get("prestige", 0)
		if prestige < 5:
			print("FAIL: prestige reward missing"); ok = false
	else:
		print("FAIL: no rewards applied"); ok = false

	# Occupation
	if devin_outcome.get("occupation_applied", false):
		print("FAIL: occupation should be cleared on defender win"); ok = false
	else:
		print("Occupation cleared OK")

	# --- Succession ---
	var ruler_before: Dictionary = succession._get_current_ruler()
	var heir: Dictionary = succession.get_heir()
	print("Succession: ruler=%s, heir=%s, type=seniority" % [
		ruler_before.get("name", "?"), heir.get("name", "?")
	])
	if ruler_before.is_empty() or heir.is_empty():
		print("FAIL: succession data missing"); ok = false
	else:
		print("Succession data OK")

	# --- Religion ---
	var religion_report: Dictionary = religion.process_religion()
	print("Religion: dominant=%s, changes=%d" % [
		religion_report.get("dominant_religion", "?"), religion_report.get("changes", []).size()
	])
	if religion_report.get("dominant_religion", "") == "":
		print("FAIL: dominant religion missing"); ok = false
	else:
		print("Religion dominant OK")

	# --- Victory ---
	var victory_report: Dictionary = victory.check_victory()
	print("Victory: %s, type=%s" % [
		"YES" if victory_report.get("victory", false) else "NO",
		victory_report.get("victory_type", "none")
	])
	if victory_report.get("victory", false):
		print("WARN: victory too early (should not trigger in 902)")

	# --- Armies (M5) ---
	var armies: Array = army.list_armies()
	print("Armies: %d total" % armies.size())
	if armies.size() < 3:
		print("FAIL: initial armies missing"); ok = false
	else:
		print("Initial armies OK")

	# Army movement
	var move_result: Dictionary = army.move_army("moravia_levy_1", "morava")
	if not move_result.get("ok", false):
		print("FAIL: army movement failed"); ok = false
	else:
		print("Army movement OK")

	# Army upkeep
	var upkeep_report: Dictionary = army.process_armies()
	print("Army upkeep: %d events" % upkeep_report.get("events", []).size())

	# --- ES sanity + river morale penalty ---
	var armies_scenario: Dictionary = scenario.create_initial_armies()
	var hungarian: Dictionary = armies_scenario["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies_scenario["moravian_main"].duplicate(true)
	# Apply river penalty manually
	var tm: Dictionary = C.TERRAIN_MODIFIERS.get("river", C.TERRAIN_MODIFIERS["field"])
	hungarian["morale"] = clampf(float(hungarian["morale"]) + float(tm["attackerMorale"]) + C.HUNGARIAN_RIVER_MORALE, 0.0, 100.0)
	moravian["morale"] = clampf(float(moravian["morale"]) + float(tm["defenderMorale"]), 0.0, 100.0)
	# Apply Greek fire bonus
	moravian["morale"] = clampf(float(moravian["morale"]) * 1.15, 0.0, 100.0)
	var es_hungarian: float = Formulas.calculate_effective_strength(hungarian, true, "river")
	var es_moravian: float = Formulas.calculate_effective_strength(moravian, false, "river")
	print("ES Devín: magyar %.1f | moravia %.1f" % [es_hungarian, es_moravian])
	if es_hungarian <= 0.0 or es_moravian <= 0.0:
		print("FAIL: ES non-positive"); ok = false
	if float(hungarian["morale"]) >= 80.0:
		print("FAIL: hungarian river morale penalty missing"); ok = false
	else:
		print("Hungarian river morale OK: %.1f" % hungarian["morale"])

	# --- Prior suite quick ---
	var provinces: Dictionary = {}
	if typeof(state.get("provinces")) == TYPE_DICTIONARY:
		provinces = state.get("provinces")
	var factions: Dictionary = {}
	if typeof(state.get("factions")) == TYPE_DICTIONARY:
		factions = state.get("factions")
	if provinces.size() != 11 or factions.size() != 6:
		print("FAIL: world bootstrap"); ok = false
	if not war.are_adjacent("nitra", "morava"):
		print("FAIL: adjacency"); ok = false

	var w1 = _make_world(77)
	var w2 = _make_world(77)
	var ca: Array = []
	var cb: Array = []
	for i in range(6):
		ca.append(w1.tick.process_tick().get("chronicle", ""))
		cb.append(w2.tick.process_tick().get("chronicle", ""))
	if ca != cb:
		print("FAIL: tick determinism"); ok = false
	else:
		print("Tick determinism OK")

	if ok:
		print("SMOKE_PASS")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)