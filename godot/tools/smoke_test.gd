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
const _MapManager := preload("res://scripts/managers/MapManager.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")


func _make_world(seed_value: int):
	var state = _GameState.new()
	var save = _SaveManager.new(seed_value)
	var rng = save.get_rng()
	var map = _MapManager.new(state)
	map.load_provinces_from_dir("res://data/provinces/")
	state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true
	}
	var eco = _EconomyManager.new(state)
	var nob = _NobilityManager.new(state, rng)
	var nar = _NarrationManager.new(state, rng)
	var ev = _EventManager.new(state, rng)
	var dip = _DiplomacyManager.new(state, rng)
	var war = _WarManager.new(state, rng)
	var tick = _TickManager.new(state, eco, nob, nar, ev, dip, war, save)
	return {"state": state, "save": save, "tick": tick, "events": ev, "war": war, "dip": dip}


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test v4 (battle) ===")

	var w = _make_world(42)
	var state = w.state
	var war = w.war
	var bm = war.battle_manager

	# --- Battle formulas ---
	var atk = bm.make_army("a", "madari", 1000, 80.0, {"infantry": 0.2, "cavalry": 0.6, "archers": 0.2}, 5)
	var def = bm.make_army("d", "moravia", 900, 70.0, {"infantry": 0.6, "cavalry": 0.15, "archers": 0.25}, 6)

	var es_field_atk := Formulas.calculate_effective_strength(atk, true, "field")
	var es_fort_def := Formulas.calculate_effective_strength(def, false, "fortress")
	print("ES field attacker (magyar cav): %.1f" % es_field_atk)
	print("ES fortress defender (moravia): %.1f" % es_fort_def)
	if es_field_atk <= 0.0 or es_fort_def <= 0.0:
		print("FAIL: ES non-positive"); ok = false

	# Counter matrix sanity
	if Formulas.get_action_modifier("melee", "ranged") != 1.15:
		print("FAIL: counter melee>ranged"); ok = false
	else:
		print("counter matrix OK")

	# Deterministic auto-resolve
	var b1 = _BattleManager.new(state, _SaveManager.new(99).get_rng())
	var b2 = _BattleManager.new(state, _SaveManager.new(99).get_rng())
	var army_a1 = b1.make_army("a", "madari", 1000, 75.0, {"infantry": 0.25, "cavalry": 0.55, "archers": 0.20}, 5)
	var army_d1 = b1.make_army("d", "moravia", 900, 70.0, {"infantry": 0.55, "cavalry": 0.20, "archers": 0.25}, 6)
	var army_a2 = b2.make_army("a", "madari", 1000, 75.0, {"infantry": 0.25, "cavalry": 0.55, "archers": 0.20}, 5)
	var army_d2 = b2.make_army("d", "moravia", 900, 70.0, {"infantry": 0.55, "cavalry": 0.20, "archers": 0.25}, 6)
	var r1: Dictionary = b1.auto_resolve(army_a1, army_d1, "field")
	var r2: Dictionary = b2.auto_resolve(army_a2, army_d2, "field")
	if r1.get("winner") != r2.get("winner") or r1.get("result") != r2.get("result"):
		print("FAIL: battle not deterministic under same seed")
		print(" r1=", r1.get("winner"), r1.get("result"), " r2=", r2.get("winner"), r2.get("result"))
		ok = false
	else:
		print("battle determinism OK winner=%s result=%s phases=%d" % [
			r1.get("winner"), r1.get("result"), r1.get("phase_logs", []).size()
		])

	if r1.get("phase_logs", []).is_empty():
		print("FAIL: no phase logs"); ok = false

	# Fortress favors defender somewhat vs field for same armies — soft check
	var bf = _BattleManager.new(state, _SaveManager.new(7).get_rng())
	var rf: Dictionary = bf.auto_resolve(
		bf.make_army("a", "madari", 800, 70.0, {"infantry": 0.3, "cavalry": 0.5, "archers": 0.2}, 4),
		bf.make_army("d", "moravia", 800, 70.0, {"infantry": 0.6, "cavalry": 0.2, "archers": 0.2}, 6),
		"fortress"
	)
	print("fortress battle winner=%s (soft info)" % rf.get("winner"))

	# River morale on magyar attacker
	var mor: Dictionary = Formulas.apply_terrain_morale(atk, def, "river")
	if float(mor["attacker_morale"]) >= 80.0:
		print("FAIL: hungarian river morale penalty missing"); ok = false
	else:
		print("hungarian river morale OK: %.1f" % mor["attacker_morale"])

	# Skirmish + occupation path
	var sk: Dictionary = war.resolve_skirmish("nitra", "field")
	print("skirmish nitra: winner=%s result=%s occ=%s" % [
		sk.get("winner"), sk.get("result"), sk.get("occupation_applied")
	])
	if not sk.has("phase_logs"):
		print("FAIL: skirmish missing logs"); ok = false

	# Prior suite quick
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
		print("tick determinism OK")

	if ok:
		print("SMOKE_PASS")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)
