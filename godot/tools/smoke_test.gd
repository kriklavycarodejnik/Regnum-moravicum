# tools/smoke_test.gd
# Headless smoke: determinism, provinces+neighbors, events, save/load
# godot --headless --path . -s res://tools/smoke_test.gd
extends SceneTree

const _GameState := preload("res://scripts/core/GameState.gd")
const _SaveManager := preload("res://scripts/core/SaveManager.gd")
const _TickManager := preload("res://scripts/core/TickManager.gd")
const _EconomyManager := preload("res://scripts/managers/EconomyManager.gd")
const _NobilityManager := preload("res://scripts/managers/NobilityManager.gd")
const _NarrationManager := preload("res://scripts/managers/NarrationManager.gd")
const _EventManager := preload("res://scripts/managers/EventManager.gd")
const _MapManager := preload("res://scripts/managers/MapManager.gd")


func _make_world(seed_value: int):
	var state = _GameState.new()
	var save = _SaveManager.new(seed_value)
	var map = _MapManager.new(state)
	map.load_provinces_from_dir("res://data/provinces/")
	state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii", "name": "Mojmír II.", "birth_year": 870, "is_ruler": true
	}
	var eco = _EconomyManager.new(state)
	var nob = _NobilityManager.new(state, save.get_rng())
	var nar = _NarrationManager.new(state, save.get_rng())
	var ev = _EventManager.new(state, save.get_rng())
	var tick = _TickManager.new(state, eco, nob, nar, ev, save)
	return {"state": state, "save": save, "tick": tick, "events": ev, "map": map}


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test v2 ===")

	var w = _make_world(42)
	var state = w.state
	var save = w.save
	var tick = w.tick
	var events = w.events

	# Provinces + neighbors
	if state.provinces.size() != 11:
		print("FAIL: provinces ", state.provinces.size())
		ok = false
	else:
		print("provinces: 11")

	var edges := 0
	for pid in state.provinces:
		var p = state.provinces[pid]
		var ns: Array = p.get("neighbors", [])
		edges += ns.size()
		for n in ns:
			if not state.provinces.has(n):
				print("FAIL: neighbor missing ", n)
				ok = false
			elif not state.provinces[n].get("neighbors", []).has(pid):
				print("FAIL: asymmetric edge ", pid, "<->", n)
				ok = false
	print("neighbor edges (directed count): ", edges)

	# Determinism: two worlds same seed → same chronicles after N ticks
	var w1 = _make_world(77)
	var w2 = _make_world(77)
	var chronicles_a: Array = []
	var chronicles_b: Array = []
	for i in range(8):
		var r1: Dictionary = w1.tick.process_tick()
		var r2: Dictionary = w2.tick.process_tick()
		chronicles_a.append(r1.get("chronicle", ""))
		chronicles_b.append(r2.get("chronicle", ""))
	if chronicles_a != chronicles_b:
		print("FAIL: chronicle not deterministic under same seed")
		print(" A=", chronicles_a)
		print(" B=", chronicles_b)
		ok = false
	else:
		print("determinism OK (8 ticks, seed 77)")

	# Calendar + event raise
	for i in range(13):
		tick.process_tick()
	print("after 13 ticks: %d/%d gold=%s prestige=%s pending=%s" % [
		state.year, state.month,
		state.resources.get("gold"), state.resources.get("prestige"),
		state.pending_event != null
	])
	if state.year != 903 or state.month != 2:
		print("FAIL: calendar")
		ok = false
	if state.pending_event == null:
		print("FAIL: expected pending event by month 3+")
		ok = false
	else:
		print("event raised: ", state.pending_event.get("title"))
		var res: Dictionary = events.resolve_choice("gifts")
		if not res.get("ok", false):
			print("FAIL: resolve_choice")
			ok = false
		else:
			print("choice resolved OK")
		if state.pending_event != null:
			print("FAIL: pending not cleared")
			ok = false

	# Save uses to_dict path
	if not save.save_game(state, "user://smoke_save.dat"):
		print("FAIL: save")
		ok = false
	var loaded = save.load_game("user://smoke_save.dat")
	if loaded == null or loaded.year != state.year:
		print("FAIL: load")
		ok = false
	else:
		print("save/load OK (versioned to_dict)")

	# Autosave single slot
	state.month = 12
	save.autosave_if_year_end(state)
	if not FileAccess.file_exists("user://autosave.dat"):
		print("FAIL: autosave.dat missing")
		ok = false
	else:
		print("autosave single slot OK")

	if ok:
		print("SMOKE_PASS")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)
