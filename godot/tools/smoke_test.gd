# tools/smoke_test.gd
# Headless smoke: 13 ticks + save/load roundtrip
# Run: godot --headless --path . -s res://tools/smoke_test.gd
extends SceneTree

const _GameState := preload("res://scripts/core/GameState.gd")
const _SaveManager := preload("res://scripts/core/SaveManager.gd")
const _TickManager := preload("res://scripts/core/TickManager.gd")
const _EconomyManager := preload("res://scripts/managers/EconomyManager.gd")
const _NobilityManager := preload("res://scripts/managers/NobilityManager.gd")
const _NarrationManager := preload("res://scripts/managers/NarrationManager.gd")
const _MapManager := preload("res://scripts/managers/MapManager.gd")


func _init() -> void:
	var ok := true
	print("=== Regnum Moravicum smoke test ===")

	var state = _GameState.new()
	var save = _SaveManager.new(42)
	var map = _MapManager.new(state)
	var n_prov := map.load_provinces_from_dir("res://data/provinces/")
	print("provinces loaded: ", n_prov)
	if n_prov != 11:
		print("FAIL: expected 11 provinces")
		ok = false

	state.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true
	}

	var eco = _EconomyManager.new(state)
	var nob = _NobilityManager.new(state, save.get_rng())
	var nar = _NarrationManager.new(state)
	var tick = _TickManager.new(state, eco, nob, nar, save)

	var last_report := {}
	for i in range(13):
		last_report = tick.process_tick()

	print("after 13 ticks: year=%d month=%d gold=%s prestige=%s" % [
		state.year, state.month, state.resources.get("gold"), state.resources.get("prestige")
	])
	if state.year != 903 or state.month != 2:
		print("FAIL: calendar expected 903/2")
		ok = false
	if int(state.resources.get("gold", -1)) != 100 - 5 * 13:
		print("FAIL: gold upkeep")
		ok = false
	if int(state.resources.get("prestige", -1)) != 20 + 13:
		print("FAIL: prestige growth")
		ok = false
	if state.chronicle.is_empty():
		print("FAIL: chronicle empty")
		ok = false
	else:
		print("chronicle entries: ", state.chronicle.size())
		print("last chronicle: ", last_report.get("chronicle", ""))

	var path := "user://smoke_save.dat"
	if not save.save_game(state, path):
		print("FAIL: save_game")
		ok = false
	var loaded = save.load_game(path)
	if loaded == null:
		print("FAIL: load_game null")
		ok = false
	elif loaded.year != state.year or loaded.month != state.month:
		print("FAIL: load mismatch year/month")
		ok = false
	else:
		print("save/load OK")

	# Determinism: same seed -> same first RNG float sequence start
	var s1 = _SaveManager.new(99)
	var s2 = _SaveManager.new(99)
	var a := s1.get_rng().randf()
	var b := s2.get_rng().randf()
	if a != b:
		print("FAIL: seeded RNG not deterministic")
		ok = false
	else:
		print("seeded RNG OK: ", a)

	if ok:
		print("SMOKE_PASS")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)
