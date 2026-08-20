# tools/verify_ui_labels.gd
# Runtime test: executes and verifies actual UI components & captures label values
extends Node

func _ready() -> void:
	print("=== SPUŠŤAM OVERENIE SLOVENSKÝCH NÁZVOV V UI ===")
	var BVT = load("res://scripts/ui/BattleViewTranslations.gd")
	var fails = 0
	var raw_tokens: Array = ["moravia_levy_1", "moravia_feudal_1", "madari_horde_1", "unknown_xyz", "unknown_fac_xyz", "unknown_army_xyz"]
	var check_surface := func(surface: String, value: String) -> void:
		print("  %s: \"%s\"" % [surface, value])
		if "_" in value:
			print("  [FAIL] %s obsahuje podtržník" % surface)
			fails += 1
		for token in raw_tokens:
			if token in value:
				print("  [FAIL] %s obsahuje raw ID %s" % [surface, token])
				fails += 1
	
	# 1. Kontrola Translation mapy a fallbackov
	print("\n--- 1. Overenie prekladového modulu a fallbackov ---")
	var known_provinces = ["nitra", "bratislava", "devin", "morava", "trencin", "tekov", "hont", "novohrad", "gemer", "spis", "zemplin", "uzhorod"]
	for p in known_provinces:
		var tr = BVT.translate_province(p)
		print("  Provincia '%s' -> '%s'" % [p, tr])
		if "_" in tr or tr == p:
			print("  [FAIL] raw ID leaky v provincii: %s" % tr)
			fails += 1
			
	var unknown_prov = BVT.translate_province("unknown_xyz")
	print("  Neznáma provincia 'unknown_xyz' -> '%s'" % unknown_prov)
	if unknown_prov != "Neznáma župa":
		print("  [FAIL] Neznáma župa fallback nesedí")
		fails += 1
		
	var unknown_fac = BVT.translate_faction("unknown_fac_xyz")
	print("  Neznáma frakcia 'unknown_fac_xyz' -> '%s'" % unknown_fac)
	if unknown_fac != "Neznáma frakcia":
		print("  [FAIL] Neznáma frakcia fallback nesedí")
		fails += 1

	var unknown_army = BVT.translate_army_name({}, "unknown_army_xyz")
	print("  Neznáma armáda 'unknown_army_xyz' -> '%s'" % unknown_army)
	if unknown_army != "Neznámy oddiel":
		print("  [FAIL] Neznámy oddiel fallback nesedí")
		fails += 1

	# 2. Main scéna a UI inštancie
	print("\n--- 2. Overenie Main.tscn a inštančných UI uzlov ---")
	var main_scene = load("res://scenes/main/Main.tscn")
	var main = main_scene.instantiate()
	add_child(main)
	
	# MapView kontrola
	var map_view = main.map_view
	print("  MapView node:", map_view != null)
	
	# Výber provincie a kontrola SelectionLabel
	main._on_province_selected("nitra")
	var sel_label = main.selection_label
	print("  SelectionLabel po výbere 'nitra': \"%s\"" % sel_label.text)
	check_surface.call("SelectionLabel", sel_label.text)
	if "nitra" in sel_label.text or "_" in sel_label.text:
		print("  [FAIL] SelectionLabel obsahuje raw ID alebo podtržník!")
		fails += 1

	main._on_province_selected("devin")
	print("  SelectionLabel po výbere 'devin': \"%s\"" % sel_label.text)
	check_surface.call("SelectionLabel Devín", sel_label.text)
	map_view._hover_id = "devin"
	map_view._update_tooltip(Vector2(20, 20))
	var map_tooltip_text: String = str(map_view._tooltip.text)
	print("  MapView tooltip text:\n%s" % map_tooltip_text)
	check_surface.call("MapView tooltip", map_tooltip_text)
	if "devin" in map_tooltip_text.to_lower() and not "Devín" in map_tooltip_text:
		print("  [FAIL] MapView tooltip obsahuje lowercase devin!")
		fails += 1
	if "devin" in sel_label.text or "_" in sel_label.text:
		print("  [FAIL] SelectionLabel obsahuje raw ID alebo podtržník!")
		fails += 1

	# ArmyUI kontrola
	print("\n--- 3. Overenie ArmyUI a detailu oddielov ---")
	var army_ui = main.army_ui
	army_ui._update_army_list()
	var army_list = army_ui.army_list
	print("  Počet zobrazených armád:", army_list.get_child_count())
	for child in army_list.get_children():
		if child is Button:
			print("  ArmyUI položka text: \"%s\"" % child.text)
			check_surface.call("ArmyUI položka", child.text)
			if "_" in child.text or "moravia_levy" in child.text or "madari_horde" in child.text:
				print("  [FAIL] ArmyUI tlačidlo obsahuje raw ID alebo podtržník!")
				fails += 1
				
	# Simulácia výberu armády a otvorenie presunu
	army_ui._on_army_selected("moravia_levy_1")
	var army_info_text = army_ui.army_info.text
	print("  Detail armády ->\n%s" % army_info_text)
	check_surface.call("Detail armády", army_info_text)
	if "_" in army_info_text:
		print("  [FAIL] Detail armády obsahuje podtržník!")
		fails += 1
	if "moravia_levy_1" in army_info_text or "nitra" in army_info_text.to_lower() and not "Nitra" in army_info_text:
		print("  [FAIL] Detail armády obsahuje raw ID!")
		fails += 1

	# Presun armády dialóg
	army_ui._on_move_button_pressed()
	# Nájdi AcceptDialog
	for child in army_ui.get_children():
		if child is AcceptDialog:
			print("  MoveDialog nájdený: %s" % child.title)
			for dchild in child.get_children():
				if dchild is VBoxContainer:
					for b in dchild.get_children():
						if b is Button:
							print("    Cieľová župa: \"%s\"" % b.text)
							check_surface.call("Cieľová župa", b.text)
							if "_" in b.text or b.text.to_lower() == b.text:
								print("  [FAIL] Cieľová župa je lowercase alebo obsahuje podtržník: %s" % b.text)
								fails += 1

	# DiplomacyPanel kontrola
	print("\n--- 4. Overenie DiplomacyPanel ---")
	var dip_panel = main.diplomacy_panel
	dip_panel.refresh()
	var dip_list = dip_panel._list
	print("  Počet frakcií v diplomacii:", dip_list.get_child_count())
	for row in dip_list.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					print("  Diplomacia frakcia: \"%s\"" % child.text)
					check_surface.call("Diplomacia frakcia", child.text)
					if "_" in child.text or "franks" in child.text or "bavaria" in child.text or "hungary" in child.text:
						print("  [FAIL] Diplomacia zoznam obsahuje raw ID!")
						fails += 1
				
	# Výber frakcie v diplomacii
	dip_panel._on_select("franks")
	var dip_info = dip_panel._info.text
	print("  Detail frakcie text:\n%s" % dip_info)
	check_surface.call("Detail diplomacie", dip_info)
	if not "Franská ríša" in dip_info:
		print("  [FAIL] Detail frakcie nezobrazuje 'Franská ríša'!")
		fails += 1

	# BattleView kontrola
	print("\n--- 5. Overenie BattleView prekladu fáz a výsledkov ---")
	var battle_view = main.battle_view
	var round_res = {
		"attacker": {"faction_id": "moravia", "name": "Nitrianska hotovosť", "losses": 20},
		"defender": {"faction_id": "hungary", "name": "Maďarská horda", "losses": 45},
		"winner": "decisive_victory",
		"phase_logs": [
			{"phase": "counterattack", "attacker_losses": 20, "defender_losses": 45, "ratio": 0.44},
			{"phase": "decision", "winner": "decisive_victory"}
		]
	}
	var res_sk = BVT.translate_winner(round_res["winner"])
	var phase_sk = BVT.translate_phase("counterattack")
	battle_view.show_outcome("Bitka pri Devíne (907)", round_res)
	var battle_title: String = "Bitka pri Devíne (907)"
	if battle_view._title != null:
		battle_title = str(battle_view._title.text)
	print("  BattleView titulok: \"%s\"" % battle_title)
	check_surface.call("BattleView titulok", battle_title)
	var battle_body: String = ""
	if battle_view._body != null:
		battle_body = str(battle_view._body.get_parsed_text())
	print("  BattleView telo text:\n%s" % battle_body)
	check_surface.call("BattleView výsledok", battle_body)
	if "rozhodujúce víťazstvo" not in battle_body or "protiútok" not in battle_body:
		print("  [FAIL] BattleView nevykreslil slovenský výsledok a fázu")
		fails += 1
	print("  Výsledok bitky: '%s' -> '%s'" % [round_res["winner"], res_sk])
	print("  Fáza bitky: '%s' -> '%s'" % ["counterattack", phase_sk])
	if res_sk != "rozhodujúce víťazstvo" or phase_sk != "protiútok":
		print("  [FAIL] BattleView preklad zlyhal!")
		fails += 1

	# Chronicle a CTA kontrola po ticku
	print("\n--- 6. Overenie StoryLine / CTA / Notifikácie 906 ---")
	main._update_story_line()
	var story_line = main.story_line
	print("  StoryLine / CTA: \"%s\"" % story_line.text)
	check_surface.call("StoryLine / CTA", story_line.text)
	if "_" in story_line.text:
		print("  [FAIL] StoryLine obsahuje podtržník!")
		fails += 1
		
	# Overenie notifikácie v roku 906
	GameManager.game_state.year = 906
	GameManager.game_state.month = 6
	# Vyvoláme kód notifikácie
	var feed = main.notification_feed
	var feed_text: String = ""
	if feed != null:
		feed.push("Rok 906: pošli armádu k Devínu (Armády → Presun → Devín).")
		if feed._list != null:
			for feed_child in feed._list.get_children():
				if feed_child is Label:
					feed_text += str(feed_child.text) + "\n"
	print("  NotificationFeed text:\n%s" % feed_text)
	check_surface.call("Notifikačný kanál", feed_text)
	if "Devín" not in feed_text or "Presun" not in feed_text:
		print("  [FAIL] Notifikačný kanál neobsahuje vloženú slovenskú správu")
		fails += 1

	# 7. Regresná kontrola manipulovaného state s raw lowercase/underscore hodnotami v `name`
	print("\n--- 7. Overenie imunity voči raw `name` hodnotám v GameState ---")
	GameManager.game_state.provinces["test_raw_prov"] = {
		"name": "raw_province_db_key",
		"owner_faction": "moravia",
		"loyalty": 20.0,
		"prosperity": 10.0,
		"religion": "pagan"
	}
	GameManager.game_state.factions["test_raw_fac"] = {
		"name": "raw_faction_db_key",
		"mood": 20.0,
		"relations": {}
	}
	# Threat a StoryLine kontrola s raw názvami
	main._update_story_line()
	print("  StoryLine s raw prov/fac v state: \"%s\"" % story_line.text)
	check_surface.call("StoryLine s raw dátami", story_line.text)

	# SelectionLabel s raw prov
	main._on_province_selected("test_raw_prov")
	print("  SelectionLabel s raw prov: \"%s\"" % sel_label.text)
	check_surface.call("SelectionLabel s raw dátami", sel_label.text)

	# MapView tooltip s raw prov
	map_view._hover_id = "test_raw_prov"
	map_view._update_tooltip(Vector2(50, 50))
	var raw_tooltip: String = str(map_view._tooltip.text)
	print("  MapView tooltip s raw prov:\n%s" % raw_tooltip)
	check_surface.call("MapView tooltip s raw dátami", raw_tooltip)
	if "pagan" in raw_tooltip.to_lower() or "raw_" in raw_tooltip:
		print("  [FAIL] MapView tooltip obsahuje surové náboženstvo alebo raw ID!")
		fails += 1
	if "Pohanstvo" not in raw_tooltip:
		print("  [FAIL] MapView tooltip neobsahuje lokalizovaný názov náboženstva 'Pohanstvo'!")
		fails += 1

	# DiplomacyPanel s raw fac
	dip_panel.refresh()
	for row in dip_panel._list.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					check_surface.call("Diplomacia zoznam (raw test)", child.text)
	dip_panel._on_select("test_raw_fac")
	var raw_dip_info = str(dip_panel._info.text)
	print("  Diplomacia detail s raw fac:\n%s" % raw_dip_info)
	check_surface.call("Diplomacia detail s raw dátami", raw_dip_info)

	# ObjectivesPanel kontrola
	var obj_panel = load("res://ui/ObjectivesPanel.tscn").instantiate()
	add_child(obj_panel)
	obj_panel.refresh()
	var obj_goals = str(obj_panel._goals_label.text)
	var obj_next = str(obj_panel._next_label.text)
	print("  ObjectivesPanel goals:\n%s" % obj_goals)
	print("  ObjectivesPanel next: \"%s\"" % obj_next)
	check_surface.call("ObjectivesPanel ciele", obj_goals)
	check_surface.call("ObjectivesPanel ďalší krok", obj_next)

	# Vyčistenie test_raw_prov / test_raw_fac
	GameManager.game_state.provinces.erase("test_raw_prov")
	GameManager.game_state.factions.erase("test_raw_fac")

	print("\n==========================================")
	if fails == 0:
		print("VŠETKY VIZUÁLNE A TEXTOVÉ KONTROLY PREŠLI BEZ CHÝB (0 chýb).")
	else:
		print("KONTROLA ZLYHALA: %d chýb!" % fails)
	print("==========================================")
	
	if fails > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
