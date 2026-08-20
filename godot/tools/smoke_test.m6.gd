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
const ObjectivesPanel = preload("res://ui/ObjectivesPanel.gd")


var _m6_failed: bool = false

func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("SMOKE_M6_FAIL: " + label)
		print("SMOKE_M6_FAIL: ", label)
		_m6_failed = true


# Helper: run a multi-month event sequence on a fresh GameState + EventManager.
# Starts at 903/1 and advances `num_months` months sequentially.
# Returns array of event ID strings, one per month.
# If battle_draws > 0, consumes that many battle RNG values before each event tick
# to verify that battle draws do not perturb the event RNG stream.
func _run_event_sequence(seed_val: int, num_months: int, battle_draws: int) -> Array:
	var gs_ev = GameState.new()
	gs_ev.ensure_resources()
	gs_ev.year = 903
	gs_ev.month = 1
	gs_ev.event_rng_seed = seed_val
	var sm_ev = SaveManager.new()
	sm_ev._init(seed_val)
	var em_ev = EventManager.new()
	em_ev._init(gs_ev)

	em_ev._load_catalog()
	var ids: Array = []
	for _m in range(num_months):
		for _b in range(battle_draws):
			sm_ev.get_rng().randi_range(1, 100)
		gs_ev.month += 1
		if gs_ev.month > 12:
			gs_ev.month = 1
			gs_ev.year += 1
		gs_ev.pending_event = null
		var rep: Dictionary = em_ev.process_events()
		ids.append(str(rep.get("id", "")))
	return ids


# Helper: vytvorí GameState pre testovanie compute_beats s požadovanými hodnotami.
# dip_overrides: Dictionary {faction_id: mood_override} – prepíše mood frakcií.
static func _make_test_gs(year: int, month: int, gold: int, food: int,
		prestige: int, devine_resolved: bool, dip_overrides: Dictionary) -> GameState:
	var gs_test := GameState.new()
	gs_test.ensure_resources()
	gs_test.year = year
	gs_test.month = month
	gs_test.resources["gold"] = gold
	gs_test.resources["food"] = food
	gs_test.resources["prestige"] = prestige
	gs_test.devine_resolved = devine_resolved
	# Provinces: minimal set + uzhorod with loyalty
	if typeof(gs_test.provinces) != TYPE_DICTIONARY:
		gs_test.provinces = {}
	if not gs_test.provinces.has("nitra"):
		gs_test.provinces["nitra"] = {"id": "nitra", "owner_faction": "moravia", "loyalty": 80.0, "prosperity": 60.0}
	if not gs_test.provinces.has("bratislava"):
		gs_test.provinces["bratislava"] = {"id": "bratislava", "owner_faction": "moravia", "loyalty": 60.0, "prosperity": 50.0}
	if not gs_test.provinces.has("devin"):
		gs_test.provinces["devin"] = {"id": "devin", "owner_faction": "moravia", "loyalty": 50.0, "prosperity": 30.0}
	if not gs_test.provinces.has("uzhorod"):
		gs_test.provinces["uzhorod"] = {"id": "uzhorod", "owner_faction": "moravia", "loyalty": 60.0, "prosperity": 40.0}
	# Factions: ensure default set via DiplomacyManager
	var sm_dip := SaveManager.new()
	sm_dip._init(42)
	var dip_mgr := DiplomacyManager.new()
	dip_mgr._init(gs_test, sm_dip.get_rng())
	# Apply overrides
	for fid in dip_overrides:
		var mood_val: float = float(dip_overrides[fid])
		if gs_test.factions.has(fid):
			gs_test.factions[fid]["mood"] = mood_val
	# Also set uzhorod loyalty if overridden
	if dip_overrides.has("uzhorod_loyalty"):
		var uzh_prov = gs_test.provinces.get("uzhorod", {})
		if typeof(uzh_prov) == TYPE_DICTIONARY:
			uzh_prov["loyalty"] = float(dip_overrides["uzhorod_loyalty"])
	return gs_test


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
	# 7a) Determinizmus: dva čerstvé runy s rovnakým save_seed → rovnaká postupnosť event ID
	var seq_a: Array = _run_event_sequence(42, 24, 0)
	var seq_b: Array = _run_event_sequence(42, 24, 0)
	check(seq_a == seq_b, "event RNG determinism: same save_seed → same event ID sequence")
	print("Event RNG determinism: seq_a=", seq_a)
	print("Event RNG determinism: seq_b=", seq_b)

	# 7b) Izolácia: rôzny save_seed → rôzna postupnosť (aspoň jedna pozícia sa líši)
	var seq_c: Array = _run_event_sequence(999, 24, 0)
	check(seq_a != seq_c, "event RNG isolation: different save_seed → different event ID sequence")
	print("Event RNG isolation: seq_c=", seq_c)

	# 7c) Aspoň jeden reálny event (nie iba prázdne fallback reporty)
	var has_real_event: bool = false
	for _id in seq_a:
		if str(_id) != "":
			has_real_event = true
			break
	check(has_real_event, "event RNG: at least one real event selected in 24 months")
	print("Event RNG: real events present in sequence (count of non-empty IDs)")

	# 8) Battle RNG izolácia: rovnaký save_seed, ale s battle RNG drawmi pred eventami
	#    → identická postupnosť event ID (battle draws neovplyvní event stream)
	var seq_d: Array = _run_event_sequence(42, 24, 0)
	var seq_e: Array = _run_event_sequence(42, 24, 5)
	check(seq_d == seq_e, "event RNG battle isolation: battle draws do not perturb event ID sequence")
	print("Event RNG battle isolation: seq_d=", seq_d)
	print("Event RNG battle isolation: seq_e=", seq_e)

	# 9) Seed-level assertions (zachované z predchádzajúcej verzie)
	var ev_seed_a: int = 0
	var ev_seed_b: int = 0
	var gs_ss = GameState.new()
	gs_ss.ensure_resources()
	gs_ss.year = 903
	gs_ss.month = 2
	var sm_ss = SaveManager.new()
	sm_ss._init(42)
	var em_ss = EventManager.new()
	em_ss._init(gs_ss)


	ev_seed_a = em_ss.event_rng.seed
	var gs_ss2 = GameState.new()
	gs_ss2.ensure_resources()
	gs_ss2.year = 903
	gs_ss2.month = 2
	var sm_ss2 = SaveManager.new()
	sm_ss2._init(42)
	var em_ss2 = EventManager.new()
	em_ss2._init(gs_ss2)


	ev_seed_b = em_ss2.event_rng.seed
	check(ev_seed_a == ev_seed_b, "event RNG seed determinism: same save_seed → same event seed")
	print("Event RNG seed: a=%d b=%d" % [ev_seed_a, ev_seed_b])

	# 10) P0.5 Narration hook kontrakt a overenie MVP eventov (vrátane 902 openingov)
	print("--- Testing P0.5 Narration hook contract across all MVP events (including 902 openings) ---")
	var p05_gs = GameState.new()
	p05_gs.ensure_resources()
	p05_gs.year = 905
	p05_gs.month = 6
	# Initialize 12 provinces
	var all_12_provinces: Array = [
		"bratislava", "devin", "gemer", "hont", "morava", "nitra",
		"novohrad", "spis", "tekov", "trencin", "uzhorod", "zemplin"
	]
	p05_gs.provinces = {}
	for pid in all_12_provinces:
		p05_gs.provinces[pid] = {"name": pid, "loyalty": 50.0, "religion": 50}

	var p05_dip = DiplomacyManager.new()
	p05_dip._init(p05_gs)

	var p05_em = EventManager.new()
	p05_em._init(p05_gs)
	p05_em._load_catalog()

	# Helper to find catalog event by id
	var find_catalog_event = func(target_id: String) -> Dictionary:
		for ev in p05_em._catalog:
			if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == target_id:
				return ev.duplicate(true)
		return {}

	# 0. hist_mojmir_coronation_902
	var ev0_1 = find_catalog_event.call("hist_mojmir_coronation_902")
	check(not ev0_1.is_empty(), "found hist_mojmir_coronation_902")
	p05_gs.pending_event = ev0_1.duplicate(true)
	var res0_grand = p05_em.resolve_choice("grand")
	check(res0_grand.get("ok", false) and res0_grand.get("event_id") == "hist_mojmir_coronation_902", "event 0.1 grand ok")
	check(res0_grand.get("choice_result") == "grand", "event 0.1 grand choice_result")
	check(res0_grand.get("context", {}).get("faction_ids") == ["moravia"], "event 0.1 grand faction_ids")
	check(res0_grand.get("context", {}).get("province_ids") == [], "event 0.1 grand province_ids")

	p05_gs.pending_event = ev0_1.duplicate(true)
	var res0_modest = p05_em.resolve_choice("modest")
	check(res0_modest.get("choice_result") == "modest" and res0_modest.get("context", {}).get("province_ids") == ["nitra"], "event 0.1 modest")

	# 0.2 hist_magyar_reports_902
	var ev0_2 = find_catalog_event.call("hist_magyar_reports_902")
	check(not ev0_2.is_empty(), "found hist_magyar_reports_902")
	p05_gs.pending_event = ev0_2.duplicate(true)
	var res0_scouts = p05_em.resolve_choice("scouts")
	check(res0_scouts.get("ok", false) and res0_scouts.get("event_id") == "hist_magyar_reports_902", "event 0.2 scouts ok")
	check(res0_scouts.get("choice_result") == "scouts", "event 0.2 scouts choice_result")
	check(res0_scouts.get("context", {}).get("faction_ids") == ["hungary"], "event 0.2 scouts faction_ids")
	check(res0_scouts.get("context", {}).get("province_ids") == ["zemplin"], "event 0.2 scouts province_ids")

	p05_gs.pending_event = ev0_2.duplicate(true)
	var res0_ignore = p05_em.resolve_choice("ignore")
	check(res0_ignore.get("choice_result") == "ignore" and res0_ignore.get("context", {}).get("faction_ids") == ["hungary"], "event 0.2 ignore")

	# 1. hist_papal_legation_903
	var ev1 = find_catalog_event.call("hist_papal_legation_903")
	check(not ev1.is_empty(), "found hist_papal_legation_903")
	p05_gs.pending_event = ev1.duplicate(true)
	var res1_rome = p05_em.resolve_choice("rome")
	check(res1_rome.get("ok", false) and res1_rome.get("event_id") == "hist_papal_legation_903", "event 1 rome ok")
	check(res1_rome.get("choice_result") == "rome", "event 1 rome choice_result")
	check(res1_rome.get("context", {}).get("faction_ids") == ["franks"], "event 1 rome faction_ids")
	check(res1_rome.get("context", {}).get("province_ids") == [], "event 1 rome province_ids")

	p05_gs.pending_event = ev1.duplicate(true)
	var res1_dec = p05_em.resolve_choice("decline")
	check(res1_dec.get("choice_result") == "decline" and res1_dec.get("context", {}).get("faction_ids") == ["franks"], "event 1 decline")

	# 2.1 byz_bride_proposal_906
	var ev2_1 = find_catalog_event.call("byz_bride_proposal_906")
	check(not ev2_1.is_empty(), "found byz_bride_proposal_906")
	p05_gs.pending_event = ev2_1.duplicate(true)
	var res2_acc = p05_em.resolve_choice("accept")
	check(res2_acc.get("event_id") == "byz_bride_proposal_906" and res2_acc.get("choice_result") == "accept", "event 2.1 accept")
	check(res2_acc.get("context", {}).get("faction_ids") == ["byzantium"], "event 2.1 accept faction_ids")
	check(res2_acc.get("context", {}).get("next_event") == "byz_bride_wedding_907", "event 2.1 accept next_event")

	p05_gs.pending_event = ev2_1.duplicate(true)
	var res2_dec = p05_em.resolve_choice("decline")
	check(res2_dec.get("choice_result") == "decline" and res2_dec.get("context", {}).get("next_event") == "byz_bride_insult_907", "event 2.1 decline")

	# 2.2 byz_bride_wedding_907
	var ev2_2 = find_catalog_event.call("byz_bride_wedding_907")
	check(not ev2_2.is_empty(), "found byz_bride_wedding_907")
	p05_gs.pending_event = ev2_2.duplicate(true)
	var res2_grand = p05_em.resolve_choice("grand")
	check(res2_grand.get("event_id") == "byz_bride_wedding_907" and res2_grand.get("choice_result") == "grand", "event 2.2 grand")
	var facs_grand: Array = res2_grand.get("context", {}).get("faction_ids", [])
	check(facs_grand.has("byzantium") and facs_grand.has("moravia"), "event 2.2 grand factions")

	p05_gs.pending_event = ev2_2.duplicate(true)
	var res2_modest = p05_em.resolve_choice("modest")
	check(res2_modest.get("choice_result") == "modest" and res2_modest.get("context", {}).get("faction_ids") == ["byzantium"], "event 2.2 modest")

	# 2.3 byz_bride_insult_907
	var ev2_3 = find_catalog_event.call("byz_bride_insult_907")
	check(not ev2_3.is_empty(), "found byz_bride_insult_907")
	p05_gs.pending_event = ev2_3.duplicate(true)
	var res2_apol = p05_em.resolve_choice("apologize")
	check(res2_apol.get("event_id") == "byz_bride_insult_907" and res2_apol.get("context", {}).get("faction_ids") == ["byzantium"], "event 2.3 apologize")

	p05_gs.pending_event = ev2_3.duplicate(true)
	var res2_stand = p05_em.resolve_choice("stand")
	check(res2_stand.get("choice_result") == "stand" and res2_stand.get("context", {}).get("faction_ids") == ["byzantium"], "event 2.3 stand")

	# 3.1 hist_bogata_conspiracy_915
	var ev3_1 = find_catalog_event.call("hist_bogata_conspiracy_915")
	check(not ev3_1.is_empty(), "found hist_bogata_conspiracy_915")
	p05_gs.pending_event = ev3_1.duplicate(true)
	var res3_arr = p05_em.resolve_choice("arrest")
	check(res3_arr.get("event_id") == "hist_bogata_conspiracy_915" and res3_arr.get("choice_result") == "arrest", "event 3.1 arrest")
	check(res3_arr.get("context", {}).get("province_ids") == ["uzhorod"], "event 3.1 arrest province_ids")
	check(res3_arr.get("context", {}).get("next_event") == "bogata_trial_916", "event 3.1 arrest next_event")

	p05_gs.pending_event = ev3_1.duplicate(true)
	var res3_wat = p05_em.resolve_choice("watch")
	check(res3_wat.get("choice_result") == "watch" and res3_wat.get("context", {}).get("next_event") == "bogata_uprising_917", "event 3.1 watch")

	# 3.2 bogata_trial_916
	var ev3_2 = find_catalog_event.call("bogata_trial_916")
	check(not ev3_2.is_empty(), "found bogata_trial_916")
	for tr_c in ["exile", "death", "pardon"]:
		p05_gs.pending_event = ev3_2.duplicate(true)
		var res3_tr = p05_em.resolve_choice(tr_c)
		check(res3_tr.get("event_id") == "bogata_trial_916" and res3_tr.get("choice_result") == tr_c, "event 3.2 " + tr_c)
		check(res3_tr.get("context", {}).get("province_ids") == ["uzhorod"], "event 3.2 " + tr_c + " province_ids")

	# 3.3 bogata_uprising_917
	var ev3_3 = find_catalog_event.call("bogata_uprising_917")
	check(not ev3_3.is_empty(), "found bogata_uprising_917")
	for up_c in ["crush", "negotiate"]:
		p05_gs.pending_event = ev3_3.duplicate(true)
		var res3_up = p05_em.resolve_choice(up_c)
		check(res3_up.get("event_id") == "bogata_uprising_917" and res3_up.get("choice_result") == up_c, "event 3.3 " + up_c)
		check(res3_up.get("context", {}).get("province_ids") == ["uzhorod"], "event 3.3 " + up_c + " province_ids")

	# 4. rand_bad_harvest
	var ev4 = find_catalog_event.call("rand_bad_harvest")
	check(not ev4.is_empty(), "found rand_bad_harvest")
	for h_c in ["open", "ignore"]:
		p05_gs.pending_event = ev4.duplicate(true)
		var res4 = p05_em.resolve_choice(h_c)
		check(res4.get("event_id") == "rand_bad_harvest" and res4.get("choice_result") == h_c, "event 4 " + h_c)
		check(res4.get("context", {}).get("province_ids") == ["zemplin"], "event 4 " + h_c + " province_ids")

	# 5. rand_border_raid
	var ev5 = find_catalog_event.call("rand_border_raid")
	check(not ev5.is_empty(), "found rand_border_raid")
	p05_gs.pending_event = ev5.duplicate(true)
	var res5_chase = p05_em.resolve_choice("chase")
	check(res5_chase.get("event_id") == "rand_border_raid" and res5_chase.get("choice_result") == "chase", "event 5 chase")
	check(res5_chase.get("context", {}).get("province_ids") == ["gemer"], "event 5 chase province_ids")
	check(res5_chase.get("context", {}).get("faction_ids") == ["hungary"], "event 5 chase faction_ids")

	p05_gs.pending_event = ev5.duplicate(true)
	var res5_fort = p05_em.resolve_choice("fortify")
	check(res5_fort.get("choice_result") == "fortify" and res5_fort.get("context", {}).get("province_ids") == ["gemer"], "event 5 fortify")
	check(res5_fort.get("context", {}).get("faction_ids") == [], "event 5 fortify faction_ids empty")

	# 6. council
	var ev6 = p05_em._build_council_event()
	check(not ev6.is_empty(), "council event built")
	p05_gs.pending_event = ev6.duplicate(true)
	var res6_gifts = p05_em.resolve_choice("gifts")
	check(res6_gifts.get("event_id") == "council" and res6_gifts.get("choice_result") == "gifts", "council gifts")
	check(res6_gifts.get("context", {}).get("province_ids").size() == 12, "council gifts 12 provinces")

	p05_gs.pending_event = ev6.duplicate(true)
	var res6_fort = p05_em.resolve_choice("fortify")
	check(res6_fort.get("choice_result") == "fortify", "council fortify")
	var fort_provs: Array = res6_fort.get("context", {}).get("province_ids", [])
	check(fort_provs.size() == 4 and fort_provs.has("gemer") and fort_provs.has("novohrad") and fort_provs.has("uzhorod") and fort_provs.has("zemplin"), "council fortify 4 border provinces")

	p05_gs.pending_event = ev6.duplicate(true)
	var res6_tax = p05_em.resolve_choice("taxes")
	check(res6_tax.get("choice_result") == "taxes" and res6_tax.get("context", {}).get("province_ids").size() == 12, "council taxes 12 provinces")

	# 7. rand_noble_feud
	var ev7 = find_catalog_event.call("rand_noble_feud")
	check(not ev7.is_empty(), "found rand_noble_feud")
	for f_c in ["nitra_side", "trencin_side", "no_ruling"]:
		p05_gs.pending_event = ev7.duplicate(true)
		var res7 = p05_em.resolve_choice(f_c)
		check(res7.get("event_id") == "rand_noble_feud" and res7.get("choice_result") == f_c, "event 7 " + f_c)
		var pids7: Array = res7.get("context", {}).get("province_ids", [])
		check(pids7.has("nitra") and pids7.has("trencin"), "event 7 province_ids nitra and trencin")

	# 8. rand_missionary_dispute
	var ev8 = find_catalog_event.call("rand_missionary_dispute")
	check(not ev8.is_empty(), "found rand_missionary_dispute")
	p05_gs.pending_event = ev8.duplicate(true)
	var res8_latin = p05_em.resolve_choice("latin")
	check(res8_latin.get("event_id") == "rand_missionary_dispute" and res8_latin.get("choice_result") == "latin", "event 8 latin")
	check(res8_latin.get("context", {}).get("province_ids") == ["morava"], "event 8 latin province_ids")
	check(res8_latin.get("context", {}).get("faction_ids") == ["franks"], "event 8 latin faction_ids")

	p05_gs.pending_event = ev8.duplicate(true)
	var res8_byz = p05_em.resolve_choice("byzantine")
	check(res8_byz.get("choice_result") == "byzantine", "event 8 byzantine")
	var facs8_byz: Array = res8_byz.get("context", {}).get("faction_ids", [])
	check(facs8_byz.has("franks") and facs8_byz.has("byzantium"), "event 8 byzantine factions")

	p05_gs.pending_event = ev8.duplicate(true)
	var res8_ban = p05_em.resolve_choice("ban")
	check(res8_ban.get("choice_result") == "ban" and res8_ban.get("context", {}).get("province_ids") == ["morava"], "event 8 ban")
	check(res8_ban.get("context", {}).get("faction_ids") == [], "event 8 ban faction_ids empty")

	print("P0.5 MVP Events narration hooks verified successfully!")

	# 11) Structural sentence count assertion (3-6 Slovak sentences per event body + council)
	print("--- Testing sentence count assertion (3-6 sentences) on all catalog events and council ---")
	var count_sentences = func(text: String) -> int:
		var cleaned = text.strip_edges()
		if cleaned == "":
			return 0
		var count: int = 0
		var in_sentence: bool = false
		for i in range(cleaned.length()):
			var c = cleaned[i]
			if c in [".", "!", "?"]:
				# Avoid counting abbreviations or duplicate punctuation if preceded by char
				if in_sentence:
					count += 1
					in_sentence = false
			elif c != " " and c != "	" and c != "\n":
				in_sentence = true
		if in_sentence:
			count += 1
		return count

	for cat in p05_em._catalog:
		if typeof(cat) != TYPE_DICTIONARY:
			continue
		var eid: String = str(cat.get("id", ""))
		var body_str: String = str(cat.get("body", ""))
		var sc: int = count_sentences.call(body_str)
		check(sc >= 3 and sc <= 6, "event %s body sentence count (%d) in range 3..6" % [eid, sc])

	var council_ev: Dictionary = p05_em._build_council_event()
	var council_body: String = str(council_ev.get("body", council_ev.get("text", "")))
	var council_sc: int = count_sentences.call(council_body)
	check(council_sc >= 3 and council_sc <= 6, "council fallback body sentence count (%d) in range 3..6" % council_sc)
	print("Sentence count assertions OK: all catalog events and council have 3-6 sentences.")

	# 12) P0.7a No-immediate-repeat poistka
	#     Acceptancia: v 20 po sebe idúcich ťahoch sa žiadny event
	#     neopakuje dva ťahy za sebou (rovnaké id na pozíciách i a i+1).
	#     Re-runuje sekvenciu cez existujúci helper _run_event_sequence.
	var seq_rep: Array = _run_event_sequence(42, 20, 0)
	var repeat_found: bool = false
	var repeat_at: int = -1
	for i in range(seq_rep.size() - 1):
		var a: String = str(seq_rep[i])
		var b: String = str(seq_rep[i + 1])
		# Prázdne id (fallback „žiadny event") sa nepovažuje za opakovanie —
		# poistka platí len pre reálne eventy s neprázdnym id.
		if a != "" and a == b:
			repeat_found = true
			repeat_at = i
			break
	check(not repeat_found, "P0.7a no-immediate-repeat: žiadny event sa neopakuje dva ťahy za sebou (seq=%s)" % str(seq_rep))
	print("P0.7a no-immediate-repeat: seq_rep=", seq_rep)
	if repeat_found:
		print("  FAIL detail: opakovanie na pozícii %d ('%s')" % [repeat_at, str(seq_rep[repeat_at])])

	# 13) P0.7a last_event_id perzistencia v save/loade (to_dict/from_dict round-trip)
	#     Nové pole na GameState musí prežiť serializáciu + deserializáciu.
	var gs_rt = GameState.new()
	gs_rt.ensure_resources()
	gs_rt.last_event_id = "rand_bad_harvest"
	var d: Dictionary = gs_rt.to_dict()
	check(str(d.get("last_event_id", "")) == "rand_bad_harvest", "P0.7a to_dict: last_event_id serializovaný")
	var gs_loaded = GameState.new()
	gs_loaded.from_dict(d)
	check(gs_loaded.last_event_id == "rand_bad_harvest", "P0.7a from_dict: last_event_id načítaný späť")
	# Starý save bez last_event_id → default "" (spätná kompatibilita)
	var gs_old = GameState.new()
	gs_old.from_dict({"year": 903, "month": 1})
	check(gs_old.last_event_id == "", "P0.7a from_dict: starý save bez last_event_id → prázdny default")
	print("P0.7a last_event_id round-trip OK (to_dict + from_dict + old-save default)")

	# 7) TurnReport exists and has report API
	check(FileAccess.file_exists("res://ui/TurnReport.tscn"), "TurnReport scene exists")
	check(FileAccess.file_exists("res://ui/TurnReport.gd"), "TurnReport script file exists")
	print("TurnReport OK")

	# 14) P0 Design Gate 4a — NarrationManager dispatch z TickManager reportu
	#     TickManager odovzdá celý tick report (s kľúčmi year, month, economy,
	#     nobility, war, event, ...) NarrationManager.generate_chronicle().
	#     Starý kód robil match report.get("type", "") → vždy "" → fallback.
	#     Nový kód iteruje sub-reporty v prioritnom poradí a vráti prvý
	#     non-prázdny text. Tu overujeme, že:
	#     (a) full tick report s ekonomikou → non-prázdny text (nie fallback)
	#     (b) event sub-report → event text (nie fallback)
	#     (c) war sub-report → war text (nie fallback)
	#     (d) prázdny report (žiadne sub-reporty) → "" (nie náhodný text)
	print("--- Testing P0 Design Gate 4a: NarrationManager dispatch ---")
	var NarrationMgr = preload("res://scripts/managers/NarrationManager.gd")
	var nm_test = NarrationMgr.new()
	nm_test._init(p05_gs)
	var _FALLBACK = "Mesiac uplynul v tichu dvorov a polí."

	# (a) Full tick report s ekonomikou → non-prázdny text (nie fallback)
	var eco_sub: Dictionary = {
		"type": "economy",
		"prosperity_growth": {"nitra": 65.5},
		"upkeep": {"nobles": 100, "army_food": 20},
		"production": {"gold": 10, "food": 50, "wood": 5},
		"balance": {},
	}
	var full_tick_report: Dictionary = {
		"year": 903,
		"month": 1,
		"economy": eco_sub,
	}
	var eco_narration: String = nm_test.generate_chronicle(full_tick_report)
	check(eco_narration != "", "4a(a) economy narration non-empty (got: '%s')" % eco_narration)
	check(eco_narration != _FALLBACK, "4a(a) economy narration is not the fallback string")
	print("4a(a) economy narration: ", eco_narration)

	# (b) Event sub-report → event text (nie fallback)
	var event_sub: Dictionary = {
		"type": "event",
		"id": "rand_bad_harvest",
		"title": "Neúroda",
		"text": "Neúroda postihla Zemplín!",
		"body": "Neúroda postihla Zemplín!",
		"art_id": "",
		"choices": [],
	}
	var event_tick_report: Dictionary = {
		"year": 903,
		"month": 2,
		"event": event_sub,
		"economy": eco_sub,  # event má vyššiu prioritu ako economy
	}
	var event_narration: String = nm_test.generate_chronicle(event_tick_report)
	check(event_narration != "", "4a(b) event narration non-empty")
	check(event_narration != _FALLBACK, "4a(b) event narration is not the fallback string")
	# Event narration must contain the event text (dispatch worked, not economy fallback)
	check(event_narration.find("Neúroda") != -1, "4a(b) event narration contains event text 'Neúroda'")
	print("4a(b) event narration: ", event_narration)

	# (c) War sub-report → war text (nie fallback)
	var war_sub: Dictionary = {
		"type": "war",
		"battles": [{"winner": "attacker", "result": "decisive_victory"}],
		"occupations": [],
	}
	var war_tick_report: Dictionary = {
		"year": 907,
		"month": 7,
		"war": war_sub,
		"economy": eco_sub,  # war má vyššiu prioritu ako economy
	}
	var war_narration: String = nm_test.generate_chronicle(war_tick_report)
	check(war_narration != "", "4a(c) war narration non-empty")
	check(war_narration != _FALLBACK, "4a(c) war narration is not the fallback string")
	# War narration must mention something battle-related (dispatch worked)
	check(war_narration.find("Devín") != -1 or war_narration.find("obran") != -1 or war_narration.find("nepriateľ") != -1, "4a(c) war narration mentions Devín/obrana/nepriateľ")
	print("4a(c) war narration: ", war_narration)

	# (d) Prázdny report (žiadne sub-reporty) → "" (nie náhodný text)
	var empty_report: Dictionary = {"year": 903, "month": 3}
	var empty_narration: String = nm_test.generate_chronicle(empty_report)
	check(empty_narration == "", "4a(d) empty report returns empty string")
	print("4a(d) empty narration: '", empty_narration, "'")

	# (e) Prázdny event sub-report (id="", text="") → skip, fallback na economy
	#     Používame fresh NarrationManager (anti-repetition by potlačil rovnaký text ako v (a))
	var nm_test2 = NarrationMgr.new()
	nm_test2._init(p05_gs)
	var empty_event_sub: Dictionary = {
		"type": "event", "id": "", "title": "", "text": "", "body": "", "art_id": "", "choices": []
	}
	var mixed_report: Dictionary = {
		"year": 903, "month": 4,
		"event": empty_event_sub,
		"economy": eco_sub,
	}
	var mixed_narration: String = nm_test2.generate_chronicle(mixed_report)
	check(mixed_narration != "", "4a(e) mixed report (empty event + economy) returns economy text")
	check(mixed_narration != _FALLBACK, "4a(e) mixed report narration is not the fallback string")
	print("4a(e) mixed narration: ", mixed_narration)

	# (f) Spätná kompatibilita: sub-report volaný samostatne (má "type")
	var nm_test3 = NarrationMgr.new()
	nm_test3._init(p05_gs)
	var standalone_sub: Dictionary = {
		"type": "economy",
		"prosperity_growth": {"morava": 70.0},
		"upkeep": {"nobles": 50},
	}
	var standalone_narration: String = nm_test3.generate_chronicle(standalone_sub)
	check(standalone_narration != "", "4a(f) standalone sub-report (direct type) returns text")
	check(standalone_narration != _FALLBACK, "4a(f) standalone narration is not the fallback string")

	print("P0 Design Gate 4a NarrationManager dispatch verified!")

	# 15) P0.5 Rok 902 opening eventy timing & no-repeat runtime test
	print("--- Testing P0.5 Rok 902 opening events timing & no-repeat runtime ---")
	var gs_902 = GameState.new()
	gs_902.ensure_resources()
	gs_902.year = 902
	gs_902.month = 1
	var em_902 = EventManager.new()
	em_902._init(gs_902)
	em_902._load_catalog()

	# Tick 902/02: first processed tick at 902/02 must return hist_mojmir_coronation_902
	gs_902.month = 2
	var rep_02: Dictionary = em_902.process_events()
	check(str(rep_02.get("id", "")) == "hist_mojmir_coronation_902", "902/02 returns hist_mojmir_coronation_902 (got: '%s')" % str(rep_02.get("id", "")))
	var res_02: Dictionary = em_902.resolve_choice("grand")
	check(res_02.get("ok", false) and res_02.get("event_id") == "hist_mojmir_coronation_902", "902/02 resolve_choice grand ok")
	check(gs_902.pending_event == null, "902/02 pending_event cleared after resolve")

	# Advance to 902/06: processed tick must return hist_magyar_reports_902
	gs_902.month = 6
	var rep_06: Dictionary = em_902.process_events()
	check(str(rep_06.get("id", "")) == "hist_magyar_reports_902", "902/06 returns hist_magyar_reports_902 (got: '%s')" % str(rep_06.get("id", "")))
	var res_06: Dictionary = em_902.resolve_choice("scouts")
	check(res_06.get("ok", false) and res_06.get("event_id") == "hist_magyar_reports_902", "902/06 resolve_choice scouts ok")
	check(gs_902.pending_event == null, "902/06 pending_event cleared after resolve")

	# Advance and process another 902 tick (e.g. 902/07): neither opening ID may be returned again
	gs_902.month = 7
	var rep_07: Dictionary = em_902.process_events()
	var rep_07_id: String = str(rep_07.get("id", ""))
	check(rep_07_id != "hist_mojmir_coronation_902" and rep_07_id != "hist_magyar_reports_902", "902/07 neither opening ID repeated (got: '%s')" % rep_07_id)

	# Both IDs must be present exactly once in triggered_events
	var tr_count_coronation: int = 0
	var tr_count_magyar: int = 0
	for te in gs_902.triggered_events:
		if str(te) == "hist_mojmir_coronation_902":
			tr_count_coronation += 1
		elif str(te) == "hist_magyar_reports_902":
			tr_count_magyar += 1
	check(tr_count_coronation == 1, "hist_mojmir_coronation_902 present exactly once in triggered_events (count=%d)" % tr_count_coronation)
	check(tr_count_magyar == 1, "hist_magyar_reports_902 present exactly once in triggered_events (count=%d)" % tr_count_magyar)
	print("P0.5 Rok 902 opening events timing and no-repeat assertions OK!")

	# 16) P1 — plný port 14 historických eventov: regression checks
	#     P1 kontrakt §10: 14 IDs, conditions, weights, chains, Bogata zupaLoyalty,
	#     chainOnly scan exclusion, army_wizard_done serialization.
	print("--- Testing P1: 14 event catalog regression ---")

	# 16a) Presne 14 event IDs (13 v JSON katalógu + council fallback)
	var p1_expected_ids: Array = [
		"hist_mojmir_coronation_902", "hist_magyar_reports_902",
		"hist_papal_legation_903", "byz_bride_proposal_906",
		"byz_bride_wedding_907", "byz_bride_insult_907",
		"hist_bogata_conspiracy_915", "bogata_trial_916", "bogata_uprising_917",
		"rand_bad_harvest", "rand_border_raid", "rand_noble_feud",
		"rand_missionary_dispute",
	]
	var p1_catalog_ids: Array = []
	for cat_p1 in p05_em._catalog:
		if typeof(cat_p1) == TYPE_DICTIONARY:
			p1_catalog_ids.append(str(cat_p1.get("id", "")))
	for eid_p1 in p1_expected_ids:
		check(p1_catalog_ids.has(eid_p1), "P1 event %s present in catalog" % eid_p1)
	check(p1_catalog_ids.size() == 13, "P1 catalog has exactly 13 JSON events (got %d)" % p1_catalog_ids.size())
	# council is the 14th, built at runtime
	var council_p1: Dictionary = p05_em._build_council_event()
	check(str(council_p1.get("id", "")) == "council", "P1 council fallback is the 14th event")
	print("P1: all 14 event IDs present (13 catalog + council)")

	# 16b) Bogata reťaz používa zupaLoyalty: {"uzhorod": ...}, NIE moodChanges
	var bogata_ev: Dictionary = find_catalog_event.call("hist_bogata_conspiracy_915")
	check(not bogata_ev.is_empty(), "P1 found bogata_conspiracy for zupaLoyalty check")
	for bog_choice in bogata_ev.get("choices", []):
		if typeof(bog_choice) == TYPE_DICTIONARY:
			var bc_id: String = str(bog_choice.get("id", ""))
			if bc_id == "arrest" or bc_id == "watch":
				check(bog_choice.has("zupaLoyalty"), "P1 bogata %s has zupaLoyalty" % bc_id)
				var bog_zl: Dictionary = bog_choice.get("zupaLoyalty", {})
				check(bog_zl.has("uzhorod"), "P1 bogata %s zupaLoyalty targets uzhorod" % bc_id)
				check(not bog_choice.has("moodChanges"), "P1 bogata %s does NOT use moodChanges (per P1 kontrakt)" % bc_id)
	# bogata_trial_916 and bogata_uprising_917 also use zupaLoyalty, not moodChanges
	for bog_chain_id in ["bogata_trial_916", "bogata_uprising_917"]:
		var bog_chain_ev: Dictionary = find_catalog_event.call(bog_chain_id)
		check(not bog_chain_ev.is_empty(), "P1 found %s" % bog_chain_id)
		for bog_chain_choice in bog_chain_ev.get("choices", []):
			if typeof(bog_chain_choice) == TYPE_DICTIONARY:
				if bog_chain_choice.has("zupaLoyalty"):
					var bcz: Dictionary = bog_chain_choice.get("zupaLoyalty", {})
					check(bcz.has("uzhorod"), "P1 %s zupaLoyalty targets uzhorod" % bog_chain_id)
				check(not bog_chain_choice.has("moodChanges"), "P1 %s does NOT use moodChanges" % bog_chain_id)
	print("P1: Bogata chain uses zupaLoyalty, not moodChanges")

	# 16c) chainOnly eventy sa nespustia cez historical/random scan
	#     Set year to 915 to trigger bogata; chainOnly bogata_trial_916 must NOT be returned
	var gs_chain = GameState.new()
	gs_chain.ensure_resources()
	gs_chain.year = 915
	gs_chain.month = 1
	gs_chain.event_rng_seed = 42
	var em_chain = EventManager.new()
	em_chain._init(gs_chain)
	em_chain._load_catalog()
	gs_chain.pending_event = null
	var rep_chain: Dictionary = em_chain.process_events()
	var rep_chain_id: String = str(rep_chain.get("id", ""))
	check(rep_chain_id == "hist_bogata_conspiracy_915", "P1 915 triggers hist_bogata_conspiracy_915 (got '%s')" % rep_chain_id)
	# Now verify chainOnly events are never returned directly by historical scan
	# by checking that none of the 4 chainOnly IDs appear as a year-triggered event
	var chain_only_ids: Array = []
	for cat_co in em_chain._catalog:
		if typeof(cat_co) == TYPE_DICTIONARY and bool(cat_co.get("chainOnly", false)):
			chain_only_ids.append(str(cat_co.get("id", "")))
	check(chain_only_ids.size() == 4, "P1 exactly 4 chainOnly events (got %d)" % chain_only_ids.size())
	check(chain_only_ids.has("byz_bride_wedding_907"), "P1 chainOnly: byz_bride_wedding_907")
	check(chain_only_ids.has("byz_bride_insult_907"), "P1 chainOnly: byz_bride_insult_907")
	check(chain_only_ids.has("bogata_trial_916"), "P1 chainOnly: bogata_trial_916")
	check(chain_only_ids.has("bogata_uprising_917"), "P1 chainOnly: bogata_uprising_917")
	print("P1: chainOnly events correctly identified (4 total)")

	# 16d) Reťazenia next_event — všetky ciele existujú v katalógu
	#     byz_bride_proposal_906 → accept → byz_bride_wedding_907 (chainOnly)
	#     byz_bride_proposal_906 → decline → byz_bride_insult_907 (chainOnly)
	#     hist_bogata_conspiracy_915 → arrest → bogata_trial_916 (chainOnly)
	#     hist_bogata_conspiracy_915 → watch → bogata_uprising_917 (chainOnly)
	var chain_pairs: Array = [
		["byz_bride_proposal_906", "accept", "byz_bride_wedding_907"],
		["byz_bride_proposal_906", "decline", "byz_bride_insult_907"],
		["hist_bogata_conspiracy_915", "arrest", "bogata_trial_916"],
		["hist_bogata_conspiracy_915", "watch", "bogata_uprising_917"],
	]
	for cp in chain_pairs:
		var parent_id: String = cp[0]
		var choice_id: String = cp[1]
		var expected_target: String = cp[2]
		var parent_ev: Dictionary = find_catalog_event.call(parent_id)
		check(not parent_ev.is_empty(), "P1 chain parent %s found" % parent_id)
		var found_target: bool = false
		for pch in parent_ev.get("choices", []):
			if typeof(pch) == TYPE_DICTIONARY and str(pch.get("id", "")) == choice_id:
				var ne: String = str(pch.get("next_event", ""))
				check(ne == expected_target, "P1 chain %s→%s next_event='%s' (expected '%s')" % [parent_id, choice_id, ne, expected_target])
				found_target = true
				# Target must exist in catalog and be chainOnly
				var target_ev: Dictionary = find_catalog_event.call(expected_target)
				check(not target_ev.is_empty(), "P1 chain target %s exists in catalog" % expected_target)
				check(bool(target_ev.get("chainOnly", false)), "P1 chain target %s is chainOnly" % expected_target)
		check(found_target, "P1 chain parent %s has choice %s" % [parent_id, choice_id])
	print("P1: all 4 chain links verified (next_event targets exist + chainOnly)")

	# 16e) once: true eventy sa neopakujú (triggered_events kontrola)
	#     Hist_papal_legation_903: once=true, year=903 → triggers once, then never again
	var gs_once = GameState.new()
	gs_once.ensure_resources()
	gs_once.year = 903
	gs_once.month = 1
	gs_once.event_rng_seed = 42
	var em_once = EventManager.new()
	em_once._init(gs_once)
	em_once._load_catalog()
	gs_once.pending_event = null
	var rep_once_1: Dictionary = em_once.process_events()
	check(str(rep_once_1.get("id", "")) == "hist_papal_legation_903", "P1 903 triggers hist_papal_legation_903 (got '%s')" % str(rep_once_1.get("id", "")))
	em_once.resolve_choice("rome")
	# Advance month — same year, event should NOT trigger again
	gs_once.pending_event = null
	gs_once.month = 2
	var rep_once_2: Dictionary = em_once.process_events()
	check(str(rep_once_2.get("id", "")) != "hist_papal_legation_903", "P1 once event does not trigger again (got '%s')" % str(rep_once_2.get("id", "")))
	check(gs_once.triggered_events.has("hist_papal_legation_903"), "P1 once event recorded in triggered_events")
	print("P1: once:true events do not repeat")

	# 16f) Váhy a cooldowny pre random eventy
	var weight_checks: Array = [
		["rand_bad_harvest", 15, 24],
		["rand_border_raid", 12, 15],
		["rand_noble_feud", 10, 20],
		["rand_missionary_dispute", 10, 20],
	]
	for wc in weight_checks:
		var wc_id: String = wc[0]
		var wc_weight: int = wc[1]
		var wc_cd: int = wc[2]
		var wc_ev: Dictionary = find_catalog_event.call(wc_id)
		check(not wc_ev.is_empty(), "P1 weight check: %s found" % wc_id)
		check(int(wc_ev.get("weight", 0)) == wc_weight, "P1 weight %s = %d (got %d)" % [wc_id, wc_weight, int(wc_ev.get("weight", 0))])
		check(int(wc_ev.get("cooldownTicks", 0)) == wc_cd, "P1 cooldown %s = %d (got %d)" % [wc_id, wc_cd, int(wc_ev.get("cooldownTicks", 0))])
	print("P1: weights and cooldowns verified for all 4 random events")

	# 16g) army_wizard_done serialization round-trip (to_dict / from_dict)
	var gs_aw = GameState.new()
	gs_aw.ensure_resources()
	gs_aw.army_wizard_done = true
	var aw_d: Dictionary = gs_aw.to_dict()
	check(bool(aw_d.get("army_wizard_done", false)) == true, "P1 to_dict: army_wizard_done=true serialized")
	var gs_aw_loaded = GameState.new()
	gs_aw_loaded.from_dict(aw_d)
	check(gs_aw_loaded.army_wizard_done == true, "P1 from_dict: army_wizard_done=true loaded back")
	# Old save without army_wizard_done → default false (backwards compat)
	var gs_aw_old = GameState.new()
	gs_aw_old.from_dict({"year": 903, "month": 1})
	check(gs_aw_old.army_wizard_done == false, "P1 from_dict: old save without army_wizard_done → false default")
	print("P1: army_wizard_done round-trip + old-save default OK")

	# 16h) Deterministický event seed: rovnaký seed → rovnaký výsledok
	#      (already covered by test 7a/7b, but add explicit P1 assertion with 14-event catalog)
	var p1_det_a: Array = _run_event_sequence(42, 36, 0)
	var p1_det_b: Array = _run_event_sequence(42, 36, 0)
	check(p1_det_a == p1_det_b, "P1 determinism: same seed → same 36-month event sequence")
	# Battle draws do not perturb event RNG
	var p1_det_c: Array = _run_event_sequence(42, 36, 3)
	check(p1_det_a == p1_det_c, "P1 event RNG isolation: battle draws do not perturb event sequence")
	print("P1: deterministic seed + battle RNG isolation verified (36 months)")

	print("P1: 14 event catalog regression ALL CHECKS PASSED!")

	# ─── 17) P1.2 — Fázové beaty v ObjectivesPanel (§2.3) ───
	print("--- Testing P1.2: ObjectivesPanel phased beats ---")
	var dip_hungary_50: Array = [{"id": "hungary", "name": "Maďari", "mood": 50.0}]
	var dip_worst_40: Array = [{"id": "franks", "name": "Frankovia", "mood": 40.0}]
	var dip_worst_25: Array = [{"id": "franks", "name": "Frankovia", "mood": 25.0}]
	var dip_all_good: Array = [
		{"id": "hungary", "name": "Maďari", "mood": 60.0},
		{"id": "franks", "name": "Frankovia", "mood": 60.0},
		{"id": "byzantium", "name": "Byzancia", "mood": 65.0},
	]
	var dip_hungary_low: Array = [
		{"id": "hungary", "name": "Maďari", "mood": 25.0},
		{"id": "franks", "name": "Frankovia", "mood": 60.0},
	]
	var dip_byz_low: Array = [
		{"id": "hungary", "name": "Maďari", "mood": 55.0},
		{"id": "byzantium", "name": "Byzancia", "mood": 35.0},
	]

	# 17a) Phase I A1: 902/2, gold=1000 → tutorial next_step
	var gs_a1 = _make_test_gs(902, 2, 1000, 500, 50, false, {})
	var b_a1 = ObjectivesPanel.compute_beats(gs_a1, dip_all_good)
	check(b_a1.get("phase_name", "").begins_with("Fáza I"), "P1.2: A1 phase_name")
	check(str(b_a1.get("next_step", "")).find("Prečítaj") >= 0, "P1.2: A1 next_step has tutorial")
	print("P1.2: beat A1 OK (902/2 tutorial)")

	# 17b) Phase I A2: 903/6, gold=500 → economy next_step
	var gs_a2 = _make_test_gs(903, 6, 500, 500, 50, false, {})
	var b_a2 = ObjectivesPanel.compute_beats(gs_a2, dip_all_good)
	check(str(b_a2.get("next_step", "")).find("Ďalší mesiac") >= 0, "P1.2: A2 next_step mentions next month")
	print("P1.2: beat A2 OK (903/6 gold=500 -> economy)")

	# 17c) Phase I A3: 905/6, gold=1000, hungary mood=25 → hungary warning
	var gs_a3 = _make_test_gs(905, 6, 1000, 500, 50, false, {})
	var b_a3 = ObjectivesPanel.compute_beats(gs_a3, dip_hungary_low)
	var goals_a3: PackedStringArray = b_a3.get("goals", PackedStringArray())
	var has_hungary_warn_a3 := false
	for g_a3 in goals_a3:
		if str(g_a3).find("Maďari") >= 0:
			has_hungary_warn_a3 = true
	check(has_hungary_warn_a3, "P1.2: A3 hungary warning present when mood < 30")
	print("P1.2: beat A3 OK (905/6 hungary mood 25 -> warning)")

	# 17d) Phase I A3: 905/6, gold=1000, hungary mood=35 → NO hungary warning
	var b_a3b = ObjectivesPanel.compute_beats(gs_a3, dip_all_good)
	var goals_a3b: PackedStringArray = b_a3b.get("goals", PackedStringArray())
	var has_hungary_warn_a3b := false
	for g_a3b in goals_a3b:
		if str(g_a3b).find("Maďari") >= 0:
			has_hungary_warn_a3b = true
	check(not has_hungary_warn_a3b, "P1.2: A3 no hungary warning when mood 60")
	print("P1.2: beat A3b OK (905/6 hungary mood 60 -> no warning)")

	# 17e) Phase I A4: 906/6, gold=1000, byzantium mood=35 → byzantium warning
	var gs_a4 = _make_test_gs(906, 6, 1000, 500, 50, false, {})
	var b_a4 = ObjectivesPanel.compute_beats(gs_a4, dip_byz_low)
	check(str(b_a4.get("next_step", "")).find("Blíži sa 907") >= 0, "P1.2: A4 next_step mentions Devín")
	var goals_a4: PackedStringArray = b_a4.get("goals", PackedStringArray())
	var has_byz_warn := false
	for g_a4 in goals_a4:
		if str(g_a4).find("Byzancia") >= 0:
			has_byz_warn = true
	check(has_byz_warn, "P1.2: A4 byzantium warning present when mood < 40")
	print("P1.2: beat A4 OK (906/6 byzantium mood 35 -> warning)")

	# 17f) Phase II B1: 907/6, devine_resolved=false → Devín button next_step
	var gs_b1 = _make_test_gs(907, 6, 1000, 500, 50, false, {})
	var b_b1 = ObjectivesPanel.compute_beats(gs_b1, dip_hungary_50)
	check(b_b1.get("phase_name", "").find("Kríza") >= 0, "P1.2: B1 phase has Kríza")
	check(str(b_b1.get("next_step", "")).find("Devín 907") >= 0, "P1.2: B1 next_step mentions Devín button")
	print("P1.2: beat B1 OK (907/6 unresolved -> Devín button)")

	# 17g) Phase II B2: 907/8, devine_resolved=true → Devín padol
	var gs_b2 = _make_test_gs(907, 8, 1000, 500, 50, true, {"hungary": 80.0})
	var b_b2 = ObjectivesPanel.compute_beats(gs_b2, dip_hungary_50)
	check(str(b_b2.get("next_step", "")).find("Devín padol") >= 0, "P1.2: B2 next_step says Devín padol")
	var goals_b2: PackedStringArray = b_b2.get("goals", PackedStringArray())
	var has_hungary_b2 := false
	for g_b2 in goals_b2:
		if str(g_b2).find("Maďari") >= 0:
			has_hungary_b2 = true
	check(has_hungary_b2, "P1.2: B2 shows hungary mood after Devín")
	print("P1.2: beat B2 OK (907/8 resolved -> Devín padol)")

	# 17h) Phase III C1: 910/1 → obnova
	var gs_c1 = _make_test_gs(910, 1, 1000, 500, 50, false, {})
	var b_c1 = ObjectivesPanel.compute_beats(gs_c1, dip_all_good)
	check(b_c1.get("phase_name", "").find("Prežitie") >= 0, "P1.2: C1 phase has Prežitie")
	check(str(b_c1.get("next_step", "")).find("Obnov ríšu") >= 0, "P1.2: C1 next_step mentions obnova")
	print("P1.2: beat C1 OK (910/1 -> obnova)")

	# 17i) Phase III C2: 916/1, uzhorod.loyalty=35 → conspiracy warning
	var gs_c2 = _make_test_gs(916, 1, 1000, 500, 50, true, {"uzhorod_loyalty": 35.0})
	var b_c2 = ObjectivesPanel.compute_beats(gs_c2, dip_all_good)
	check(str(b_c2.get("next_step", "")).find("Sprisahanie") >= 0, "P1.2: C2 next_step mentions sprisahanie")
	var goals_c2: PackedStringArray = b_c2.get("goals", PackedStringArray())
	var has_uzh_warn := false
	for g_c2 in goals_c2:
		if str(g_c2).find("Užhorod") >= 0:
			has_uzh_warn = true
	check(has_uzh_warn, "P1.2: C2 uzhorod warning present when loyalty < 40")
	print("P1.2: beat C2 OK (916/1 uzhorod loyalty 35 -> conspiracy)")

	# 17j) Phase III C2: 916/1, uzhorod.loyalty=60 → NO conspiracy warning
	var gs_c2b = _make_test_gs(916, 1, 1000, 500, 50, true, {"uzhorod_loyalty": 60.0})
	var b_c2b = ObjectivesPanel.compute_beats(gs_c2b, dip_all_good)
	var goals_c2b: PackedStringArray = b_c2b.get("goals", PackedStringArray())
	var has_uzh_warn_b := false
	for g_c2b in goals_c2b:
		if str(g_c2b).find("Užhorod") >= 0:
			has_uzh_warn_b = true
	check(not has_uzh_warn_b, "P1.2: C2 no uzhorod warning when loyalty >= 40")
	print("P1.2: beat C2b OK (916/1 loyalty 60 -> no warning)")

	# 17k) Phase III C3: 930/1 → diplomacia a armády
	var gs_c3 = _make_test_gs(930, 1, 1000, 500, 50, true, {})
	var b_c3 = ObjectivesPanel.compute_beats(gs_c3, dip_all_good)
	check(str(b_c3.get("next_step", "")).find("Diplomacia a armády") >= 0, "P1.2: C3 next_step mentions diplomacia")
	print("P1.2: beat C3 OK (930/1 -> diplomacia)")

	# 17l) Phase IV D1: 970/1 → roky do 1000 + owned + prestige
	var gs_d1 = _make_test_gs(970, 1, 1000, 500, 80, true, {})
	var b_d1 = ObjectivesPanel.compute_beats(gs_d1, dip_all_good)
	check(b_d1.get("phase_name", "").find("Cesta k 1000") >= 0, "P1.2: D1 phase name")
	check(str(b_d1.get("next_step", "")).find("30 r.") >= 0, "P1.2: D1 next_step has years left (1000-970=30)")
	check(str(b_d1.get("next_step", "")).find("prestíž: 80") >= 0, "P1.2: D1 next_step has prestige")
	print("P1.2: beat D1 OK (970/1 -> years left + prestige)")

	# 17m) Diplomacy side-goal: worst faction mood=40 (<50) → goal added
	var gs_dip1 = _make_test_gs(910, 1, 1000, 500, 50, false, {})
	var b_dip1 = ObjectivesPanel.compute_beats(gs_dip1, dip_worst_40)
	var goals_dip1: PackedStringArray = b_dip1.get("goals", PackedStringArray())
	var has_dip_goal := false
	for g_dip1 in goals_dip1:
		if str(g_dip1).find("má náladu len") >= 0:
			has_dip_goal = true
	check(has_dip_goal, "P1.2: diplomacy goal added when worst faction mood=40")
	print("P1.2: diplomacy goal OK (franks mood 40 -> goal)")

	# 17n) Diplomacy side-goal: worst mood=25 (<30) → urgent next_step override
	var b_dip2 = ObjectivesPanel.compute_beats(gs_dip1, dip_worst_25)
	var next_dip2: String = str(b_dip2.get("next_step", ""))
	check(next_dip2.find("URGENTNÉ") >= 0, "P1.2: diplomacy next_step override when mood=25")
	print("P1.2: diplomacy urgent OK (franks mood 25 -> URGENTNÉ)")

	# 17o) Diplomacy side-goal: hungary excluded (mood 20 should not trigger for hungary)
	var dip_hungary_mad: Array = [{"id": "hungary", "name": "Maďari", "mood": 20.0}]
	var b_dip3 = ObjectivesPanel.compute_beats(gs_dip1, dip_hungary_mad)
	var goals_dip3: PackedStringArray = b_dip3.get("goals", PackedStringArray())
	var has_hungary_dip := false
	for g_dip3 in goals_dip3:
		# "má náladu len" je unikátna fráza z _compute_diplomacy_goal — NIE z base cieľov
		if str(g_dip3).find("má náladu len") >= 0:
			has_hungary_dip = true
	check(not has_hungary_dip, "P1.2: hungary excluded from diplomacy side-goal")
	print("P1.2: diplomacy exclusion OK (hungary mood 20 ignored)")

	# 17p) Save-load round-trip: compute_beats same output after serialization
	var gs_save = _make_test_gs(905, 6, 1000, 500, 50, false, {})
	gs_save.ensure_resources()
	var save_dict: Dictionary = gs_save.to_dict()
	var gs_save_loaded = GameState.new()
	gs_save_loaded.from_dict(save_dict)
	var b_save_orig = ObjectivesPanel.compute_beats(gs_save, dip_all_good)
	var b_save_load = ObjectivesPanel.compute_beats(gs_save_loaded, dip_all_good)
	check(str(b_save_orig.get("next_step", "")) == str(b_save_load.get("next_step", "")), "P1.2: save-load next_step identical")
	check(str(b_save_orig.get("phase_name", "")) == str(b_save_load.get("phase_name", "")), "P1.2: save-load phase_name identical")
	print("P1.2: save-load round-trip OK (same output after to_dict/from_dict)")

	print("P1.2: ObjectivesPanel phased beats ALL CHECKS PASSED!")

	if _m6_failed:
		print("SMOKE_M6_FAIL: one or more checks failed (see above)")
		quit(1)

	print("SMOKE_M6_PASS")
	quit(0)
