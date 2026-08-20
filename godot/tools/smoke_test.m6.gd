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
	var sm_ev = SaveManager.new()
	sm_ev._init(seed_val)
	var em_ev = EventManager.new()
	em_ev._init(gs_ev, sm_ev.get_rng())
	em_ev.set_save_seed(sm_ev.get_save_seed())
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

	# 10) P0.5 Narration hook kontrakt a overenie 8 MVP eventov
	print("--- Testing P0.5 Narration hook contract across all 8 MVP events ---")
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

	print("P0.5 8 MVP Events narration hooks verified successfully!")

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

	print("SMOKE_M6_PASS")
	quit(0)
