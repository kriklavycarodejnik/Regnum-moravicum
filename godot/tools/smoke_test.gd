# tools/smoke_test.gd
extends SceneTree

const _GameState := preload("res://scripts/core/GameState.gd")
const _SaveManager := preload("res://scripts/core/SaveManager.gd")
const _TickManager := preload("res://scripts/core/TickManager.gd")
const _EconomyManager := preload("res://scripts/managers/EconomyManager.gd")
const _NobilityManager := preload("res://scripts/managers/NobilityManager.gd")
const _NarrationManager := preload("res://scripts/managers/NarrationManager.gd")
const _EventManager := preload("res://scripts/managers/EventManager.gd")
const _DiplomacyManager := preload("res://scripts/managers/DiplomacyManager.gd")
const _WarManager := preload("res://scripts/managers/WarManager.gd")
const _BattleManager := preload("res://scripts/managers/BattleManager.gd")
const _HungarianWarScenario := preload("res://scripts/scenarios/HungarianWarScenario.gd")
const _SuccessionManager := preload("res://scripts/managers/SuccessionManager.gd")
const _ReligionManager := preload("res://scripts/managers/ReligionManager.gd")
const _VictoryManager := preload("res://scripts/managers/VictoryManager.gd")
const _MapManager := preload("res://scripts/managers/MapManager.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")


func _make_world(seed_value: int):
	var state = _GameState.new()
	var save = _SaveManager.new(seed_value)
	var rng = save.get_rng()
	var map = _MapManager.new(state)
	map.load_provinces_from_dir("res://data/provinces/")
	state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true, "dynasty_id": "mojmir", "prestige": 50
	}
	state.nobles["svatopluk_ii"] = {
		"id": "svatopluk_ii", "name": "Svätopluk II.", "birth_year": 880, "is_ruler": false, "dynasty_id": "mojmir", "prestige": 30
	}
	var eco = _EconomyManager.new(state)
	var nob = _NobilityManager.new(state, rng)
	var nar = _NarrationManager.new(state, rng)
	var ev = _EventManager.new(state, rng)
	var dip = _DiplomacyManager.new(state, rng)
	var war = _WarManager.new(state, rng)
	var suc = _SuccessionManager.new(state, rng)
	var rel = _ReligionManager.new(state, rng)
	var vic = _VictoryManager.new(state)
	var tick = _TickManager.new(state, eco, nob, nar, ev, dip, war, suc, rel, vic, save)
	return {"state": state, "save": save, "tick": tick, "war": war, "dip": dip, "suc": suc, "rel": rel, "vic": vic}


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test v7 (M4) ===")

	var w = _make_world(42)
	var state = w.state
	var war = w.war
	var scenario = war.hungarian_war_scenario
	var succession = w.suc
	var religion = w.rel
	var victory = w.vic

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
		if int(state.resources.get("prestige", 0)) < 5:
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
	print("Succession: ruler=%s, heir=%s, type=%s" % [
		ruler_before.get("name", "?"), heir.get("name", "?"), succession.current_type
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

	# --- ES sanity + river morale penalty ---
	var armies: Dictionary = scenario.create_initial_armies()
	var hungarian: Dictionary = armies["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies["moravian_main"].duplicate(true)
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
	if state.provinces.size() != 11 or state.factions.size() != 6:
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