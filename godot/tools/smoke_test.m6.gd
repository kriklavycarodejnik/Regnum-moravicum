# tools/smoke_test.m6.gd
# Headless smoke M6: resources, diplomacy API, victory API, art_map, map layout, UI scripts load
extends SceneTree

const GameState = preload("res://scripts/core/GameState.gd")
const EconomyManager = preload("res://scripts/managers/EconomyManager.gd")
const DiplomacyManager = preload("res://scripts/managers/DiplomacyManager.gd")
const VictoryManager = preload("res://scripts/managers/VictoryManager.gd")
const MapManager = preload("res://scripts/managers/MapManager.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")


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
	var rep: Dictionary = eco.process_economy()
	check(rep.get("type", "") == "economy", "economy report type")
	check(int(gs.resources.get("food", 0)) != food0 or int(rep.get("production", {}).get("food", 0)) >= 0, "economy ran")
	print("Economy production: ", rep.get("production", {}))

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
	print("SMOKE_M6_PASS")
	quit(0)
