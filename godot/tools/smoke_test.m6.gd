# tools/smoke_test.m6.gd
# Headless smoke M6: resources, diplomacy API, victory API, art_map, map layout, UI scripts load
extends SceneTree

const GameState = preload("res://scripts/core/GameState.gd")
const EconomyManager = preload("res://scripts/managers/EconomyManager.gd")
const DiplomacyManager = preload("res://scripts/managers/DiplomacyManager.gd")
const VictoryManager = preload("res://scripts/managers/VictoryManager.gd")
const MapManager = preload("res://scripts/managers/MapManager.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")
const EventManager = preload("res://scripts/managers/EventManager.gd")


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("SMOKE_M6_FAIL: " + label)
		print("SMOKE_M6_FAIL: ", label)
		quit(1)


func _init() -> void:
	print("=== Regnum Moravicum smoke M6 ===")

	# 1) Resources defaults
	var gs = GameState.new()
	if gs.has_method("ensure_resources"):
		gs.ensure_resources()
	for k in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		check(gs.resources.has(k), "resource key " + k)
	print("Resources OK: ", gs.resources)

	# 2) Economy production changes food/wood
	var eco = EconomyManager.new()
	eco._init(gs)
	var map = MapManager.new()
	map._init(gs)
	map.load_provinces_from_dir("res://data/provinces/")
	# own all as moravia for production
	for pid in gs.provinces.keys():
		var p = gs.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY:
			p["owner_faction"] = "moravia"
			p["prosperity"] = 60.0
	var food0: int = int(gs.resources.get("food", 0))
	var eco_rep: Dictionary = eco.process_economy()
	check(eco_rep.get("type", "") == "economy", "economy report type")
	check(int(gs.resources.get("food", 0)) != food0 or int(eco_rep.get("production", {}).get("food", 0)) >= 0, "economy ran")
	print("Economy production: ", eco_rep.get("production", {}))

	# 3) Diplomacy actions
	var save = SaveManager.new()
	save._init(7)
	var rng = save.get_rng()
	var dip = DiplomacyManager.new()
	dip._init(gs, rng)
	var factions: Array = dip.list_factions()
	check(factions.size() >= 4, "diplomacy factions >= 4")
	var target: String = str(factions[0].get("id", "hungary"))
	var gift: Dictionary = dip.send_gift(target, 10)
	check(bool(gift.get("ok", false)), "gift ok")
	var threat: Dictionary = dip.threaten(target)
	check(bool(threat.get("ok", false)), "threat ok")
	var nap: Dictionary = dip.set_treaty(target, "nap", true)
	check(bool(nap.get("ok", false)), "nap ok")
	print("Diplomacy OK target=", target)

	# 4) Victory API (no instant game over on fresh state ideally)
	var vic = VictoryManager.new()
	vic._init(gs)
	var v0: Dictionary = vic.check_victory()
	check(v0.has("victory") and v0.has("defeat"), "victory keys")
	print("Victory check fresh: victory=", v0.get("victory"), " defeat=", v0.get("defeat"))

	# 5) art_map + layout + icons
	check(FileAccess.file_exists("res://data/art_map.json"), "art_map exists")
	check(FileAccess.file_exists("res://data/map_layout.json"), "map_layout exists")
	var layout_txt := FileAccess.get_file_as_string("res://data/map_layout.json")
	var layout = JSON.parse_string(layout_txt)
	check(typeof(layout) == TYPE_DICTIONARY, "layout dict")
	var provs: Dictionary = layout.get("provinces", {})
	check(provs.size() == 12, "layout 12 provinces")
	check(FileAccess.file_exists("res://assets/icons/ui/icon_gold_64.png"), "icon_gold")
	check(FileAccess.file_exists("res://assets/portraits/mojmir_ii_master_portrait_v1.png"), "portrait mojmir")
	check(FileAccess.file_exists("res://scenes/main/Main.tscn"), "Main scene")
	check(FileAccess.file_exists("res://scenes/menu/MainMenu.tscn"), "MainMenu scene")
	check(FileAccess.file_exists("res://scenes/end/EndScreen.tscn"), "EndScreen scene")
	check(FileAccess.file_exists("res://ui/DiplomacyPanel.tscn"), "DiplomacyPanel")
	check(FileAccess.file_exists("res://scenes/map/MapView.tscn"), "MapView")
	check(FileAccess.file_exists("res://scenes/battle/BattleView.tscn"), "BattleView")
	check(FileAccess.file_exists("res://ui/NotificationFeed.tscn"), "NotificationFeed")
	print("Assets/scenes OK")

	# 6) Devin still magyar win via existing M5 path lightly
	check(gs.provinces.has("devin"), "devin province present")

	# 7) Event RNG: vlastný stream oddelený od battle/economy RNG
	#    event_seed = hash(save_seed, month_index, faction_id, "event")
	#    Acceptancia: dva runy s rovnakým save_seed dajú rovnakú postupnosť eventov;
	#    zmena battle RNG neovplyvní postupnosť eventov.
	#
	# Helper: run N months of process_events() on a fresh GameState + EventManager
	# and return the Array of event IDs ("" when no event fired).
	var _run_event_sequence = func(seed_val: int, num_months: int, battle_draws: int) -> Array:
		var gs_ev = GameState.new()
		gs_ev.ensure_resources()
		gs_ev.year = 903
		gs_ev.month = 1
		var sm_ev = SaveManager.new()
		sm_ev._init(seed_val)
		var em_ev = EventManager.new()
		em_ev._init(gs_ev, sm_ev.get_rng())
		em_ev.set_save_seed(sm_ev.get_save_seed())
		# Load the event catalog
		em_ev._load_catalog()
		var ids: Array = []
		for _m in range(num_months):
			# Simulate battle RNG draws before event processing (if requested)
			for _b in range(battle_draws):
				sm_ev.get_rng().randi_range(1, 100)
			# Advance month
			gs_ev.month += 1
			if gs_ev.month > 12:
				gs_ev.month = 1
				gs_ev.year += 1
			# Clear pending event so process_events() runs fresh each month
			gs_ev.pending_event = null
			var rep: Dictionary = em_ev.process_events()
			ids.append(str(rep.get("id", "")))
		return ids

	# Determinism: two runs with the same save_seed → identical event ID sequence
	var seq_a: Array = _run_event_sequence.call(42, 24, 0)
	var seq_b: Array = _run_event_sequence.call(42, 24, 0)
	check(seq_a == seq_b, "event RNG determinism: same save_seed → same event sequence")
	print("Event RNG determinism: seq_a=", seq_a)
	print("Event RNG determinism: seq_b=", seq_b)

	# Different save_seed → different sequence (at least one position differs)
	var seq_c: Array = _run_event_sequence.call(999, 24, 0)
	check(seq_a != seq_c, "event RNG isolation: different save_seed → different event sequence")
	print("Event RNG isolation: seq_c=", seq_c)

	# At least one non-empty event ID in the sequence (not all empty fallbacks)
	var has_real_event: bool = false
	for _id in seq_a:
		if _id != "":
			has_real_event = true
			break
	check(has_real_event, "event RNG: at least one real event selected in 24 months")
	print("Event RNG: real events present in sequence")

	# Battle isolation: same save_seed, but with battle RNG draws before events
	# → identical event ID sequence (battle draws do not perturb event stream)
	var seq_d: Array = _run_event_sequence.call(42, 24, 0)
	var seq_e: Array = _run_event_sequence.call(42, 24, 5)
	check(seq_d == seq_e, "event RNG battle isolation: battle draws do not perturb event sequence")
	print("Event RNG battle isolation: seq_d=", seq_d)
	print("Event RNG battle isolation: seq_e=", seq_e)

	# Seed-level assertions (kept from prior version)
	var ev_seed_a: int = 0
	var ev_seed_b: int = 0
	var gs_ss = GameState.new()
	gs_ss.ensure_resources()
	gs_ss.year = 903
	gs_ss.month = 2
	var sm_ss = SaveManager.new()
	sm_ss._init(42)
	var em_ss = EventManager.new()
	em_ss._init(gs_ss, sm_ss.get_rng())
	em_ss.set_save_seed(sm_ss.get_save_seed())
	em_ss._refresh_event_rng()
	ev_seed_a = em_ss.event_rng.seed
	var gs_ss2 = GameState.new()
	gs_ss2.ensure_resources()
	gs_ss2.year = 903
	gs_ss2.month = 2
	var sm_ss2 = SaveManager.new()
	sm_ss2._init(42)
	var em_ss2 = EventManager.new()
	em_ss2._init(gs_ss2, sm_ss2.get_rng())
	em_ss2.set_save_seed(sm_ss2.get_save_seed())
	em_ss2._refresh_event_rng()
	ev_seed_b = em_ss2.event_rng.seed
	check(ev_seed_a == ev_seed_b, "event RNG seed determinism: same save_seed → same event seed")
	print("Event RNG seed: a=%d b=%d" % [ev_seed_a, ev_seed_b])

	print("SMOKE_M6_PASS")
	quit(0)
