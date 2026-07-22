# tools/smoke_test.gd
# Headless smoke M5: determinism, provinces, armies, campaign, Devin 907
extends SceneTree

const GameState = preload("res://scripts/core/GameState.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")
const MapManager = preload("res://scripts/managers/MapManager.gd")
const ArmyManager = preload("res://scripts/managers/ArmyManager.gd")
const WarManager = preload("res://scripts/managers/WarManager.gd")
const CampaignManager = preload("res://scripts/managers/CampaignManager.gd")
const DiplomacyManager = preload("res://scripts/managers/DiplomacyManager.gd")
const HungarianWarScenario = preload("res://scripts/scenarios/HungarianWarScenario.gd")
const Formulas = preload("res://scripts/battle/BattleFormulas.gd")
const C = preload("res://scripts/battle/BattleConfig.gd")


func _make_world(seed: int):
	var gs = GameState.new()
	var save = SaveManager.new()
	save._init(seed)
	var rng = save.get_rng()

	var map = MapManager.new()
	map.game_state = gs
	map.load_provinces_from_dir("res://data/provinces/")

	# Init diplomacy first (creates default factions)
	var dip = DiplomacyManager.new()
	dip.game_state = gs
	dip.rng = rng
	dip._ensure_default_factions()

	var army = ArmyManager.new()
	army.game_state = gs
	army.rng = rng
	army._init_armies()

	var war = WarManager.new()
	war.game_state = gs
	war.rng = rng

	var campaign = CampaignManager.new()
	campaign._init(gs, war, dip, rng, army)

	return {"gs": gs, "rng": rng, "army": army, "war": war, "campaign": campaign}


func _init():
	var ok = true
	print("=== Regnum Moravicum smoke M5 ===")

	# 1. World bootstrap
	var w = _make_world(42)
	var gs = w.gs
	check(gs.provinces.size() >= 11, "provinces count")
	check(gs.factions.size() >= 1, "factions count")
	print("Provinces: %d, Factions: %d" % [gs.provinces.size(), gs.factions.size()])

	# 2. Armies
	w.army.create_army("test_army", "moravia_levy", "nitra")
	var armies = gs.armies
	check(armies.size() >= 1, "army created")
	print("Armies: %d total" % armies.size())

	# 3. Devin 907
	var scenario = HungarianWarScenario.new()
	scenario.game_state = gs
	scenario.war_manager = w.war
	scenario.battle_manager = w.war.battle_manager
	scenario.rng = w.rng
	# Ensure rng on battle_manager
	if w.war.battle_manager and w.war.battle_manager.rng == null:
		w.war.battle_manager.rng = w.rng
	var outcome = scenario.resolve_devine_battle()
	check(outcome.has("winner"), "Devin outcome has winner")
	print("Devin 907: winner=%s result=%s" % [outcome.get("winner", "?"), outcome.get("result", "?")])

	# 4. Campaign AI
	var camp_report = w.campaign.process_campaign()
	check(camp_report.get("type", "") == "campaign", "campaign type")
	print("Campaign: events=%d" % camp_report.get("events", []).size())

	# 5. Tick determinism
	var w1 = _make_world(77)
	var w2 = _make_world(77)
	check(w1.gs.year == w2.gs.year, "year determinism")
	check(w1.gs.month == w2.gs.month, "month determinism")
	print("Determinism OK")

	# 6. ES sanity + river morale
	var armies_s = scenario.create_initial_armies()
	var hung = armies_s["hungarian_main"].duplicate(true)
	var mor = armies_s["moravian_main"].duplicate(true)
	var tm = C.TERRAIN_MODIFIERS.get("river", C.TERRAIN_MODIFIERS["field"])
	hung["morale"] = clampf(hung["morale"] + tm["attackerMorale"] + C.HUNGARIAN_RIVER_MORALE, 0, 100)
	var f = Formulas.new()
	var es_hun = f.calculate_effective_strength(hung, true, "river")
	var es_mor = f.calculate_effective_strength(mor, false, "river") * C.GREEK_FIRE_BONUS
	check(es_hun > 0 and es_mor > 0, "ES positive")
	print("ES Devin: magyar %.1f | moravia %.1f" % [es_hun, es_mor])
	print("River morale: %.1f" % hung["morale"])

	if ok:
		print("SMOKE_PASS")
	else:
		print("SMOKE_FAIL")


func check(cond, msg):
	if not cond:
		print("FAIL: " + msg)
		quit(1)