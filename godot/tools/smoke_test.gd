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
const _MapManager := preload("res://scripts/managers/MapManager.gd")


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
	return {
		"state": state, "save": save, "tick": tick, "events": ev,
		"dip": dip, "war": war, "map": map
	}


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test v3 (M3skel) ===")

	var w = _make_world(42)
	var state = w.state
	var save = w.save
	var tick = w.tick
	var events = w.events
	var war = w.war
	var dip = w.dip

	if state.provinces.size() != 11:
		print("FAIL: provinces"); ok = false
	else:
		print("provinces: 11")

	if state.factions.size() != 6:
		print("FAIL: factions ", state.factions.size()); ok = false
	else:
		print("factions: 6")

	# Adjacency
	if not war.are_adjacent("nitra", "morava"):
		print("FAIL: nitra-morava adjacency"); ok = false
	else:
		print("adjacency nitra↔morava OK")
	if war.are_adjacent("uzhorod", "nitra"):
		print("FAIL: uzhorod should not border nitra"); ok = false

	# Frontiers: all moravia-owned → 0 external unless we mark enemy
	war.set_occupier("uzhorod", "madari")
	var fronts: Array = war.list_frontiers("moravia")
	print("frontiers after magyar occupy uzhorod: ", fronts.size())
	if fronts.is_empty():
		print("FAIL: expected frontier with zemplin"); ok = false
	else:
		print("war frontiers OK")

	# Determinism
	var w1 = _make_world(77)
	var w2 = _make_world(77)
	var a: Array = []
	var b: Array = []
	for i in range(8):
		a.append(w1.tick.process_tick().get("chronicle", ""))
		b.append(w2.tick.process_tick().get("chronicle", ""))
	if a != b:
		print("FAIL: determinism"); ok = false
	else:
		print("determinism OK")

	# Diplomacy drift runs
	var mood0: float = dip.get_mood("madari")
	for i in range(5):
		tick.process_tick()
	var mood1: float = dip.get_mood("madari")
	print("madari mood drift: %.2f -> %.2f" % [mood0, mood1])
	# aggressive should tend downward; allow noise
	if mood1 > mood0 + 2.0:
		print("WARN: unexpected mood rise for aggressive")

	# Events + resolve
	while state.pending_event == null and state.year < 904:
		tick.process_tick()
	if state.pending_event == null:
		print("FAIL: no event"); ok = false
	else:
		print("event: ", state.pending_event.get("title"))
		if not events.resolve_choice("fortify").get("ok", false):
			print("FAIL: resolve"); ok = false
		else:
			print("event resolve OK")

	# Save/load
	if not save.save_game(state, "user://smoke_save.dat"):
		print("FAIL: save"); ok = false
	var loaded = save.load_game("user://smoke_save.dat")
	if loaded == null or loaded.factions.size() != 6:
		print("FAIL: load factions"); ok = false
	else:
		print("save/load OK")

	if ok:
		print("SMOKE_PASS")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)
