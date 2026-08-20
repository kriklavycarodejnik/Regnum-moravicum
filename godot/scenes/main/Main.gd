# scenes/main/Main.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var status_bar: HBoxContainer = $UI/StatusBarRow/StatusBar
@onready var religion_axis: HBoxContainer = $UI/StatusBarRow/ReligionAxis
@onready var map_view: Control = $UI/Body/MainColumn/MapView
@onready var chronicle_label: RichTextLabel = $UI/Body/MainColumn/Chronicle
@onready var next_month_btn: Button = $UI/PrimaryRow/NextMonthButton
@onready var skirmish_btn: Button = $UI/ToolsRow/SkirmishButton
@onready var devine_btn: Button = $UI/ToolsRow/DevineButton
@onready var save_btn: Button = $UI/PrimaryRow/SaveButton
@onready var menu_btn: Button = $UI/PrimaryRow/MenuButton
@onready var selection_label: Label = $UI/Body/MainColumn/SelectionLabel
@onready var story_line: Label = $UI/Header/HelpStrip/StoryLine
@onready var help_strip: PanelContainer = $UI/Header/HelpStrip
@onready var event_panel: PanelContainer = $UI/Body/MainColumn/EventPanel
@onready var event_title: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventTitle
@onready var event_body: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventBody
@onready var choice_a_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceA
@onready var choice_b_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceB
@onready var choice_c_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceC
@onready var title_label: Label = $UI/Header/Title
@onready var background: ColorRect = $Background
@onready var bg_art: TextureRect = $BackgroundArt
@onready var army_ui: Control = $UI/Body/SidePanel/SideTabs/Armády
@onready var diplomacy_panel: Control = $"UI/Body/SidePanel/SideTabs/Diplomacia"
@onready var objectives_panel: Node = $UI/ObjectivesPanel
@onready var threat_clock: Node = $UI/ThreatClockRow/ThreatClock
@onready var event_art: TextureRect = $UI/Body/MainColumn/EventPanel/EventVBox/EventArt
@onready var hero_art: TextureRect = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroArt
@onready var hero_caption: Label = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroCaption
@onready var ruler_art: TextureRect = $UI/Body/SidePanel/RulerRow/RulerArt
@onready var notification_feed: Node = $UI/Body/MainColumn/NotificationFeed
@onready var battle_view: Node = $UI/Body/MainColumn/BattleView
@onready var turn_report: PanelContainer = $TurnReport

var selection_art_id: String = "mojmir_ii_master_portrait"
var _months_played: int = 0
var _active_battle: Dictionary = {}
var _battle_round: int = 0


func _ready() -> void:
	_apply_regnum_theme()
	_setup_background_art()
	_setup_default_hero()
	_setup_ui_panels()
	next_month_btn.pressed.connect(_on_next_month)
	skirmish_btn.pressed.connect(_on_skirmish)
	devine_btn.pressed.connect(_on_devine)
	save_btn.pressed.connect(_on_save)
	menu_btn.pressed.connect(_on_menu)
	choice_a_btn.pressed.connect(_on_choice_a)
	choice_b_btn.pressed.connect(_on_choice_b)
	choice_c_btn.pressed.connect(_on_choice_c)
	if map_view and map_view.has_signal("province_selected"):
		map_view.province_selected.connect(_on_province_selected)
	if diplomacy_panel and diplomacy_panel.has_signal("action_done"):
		diplomacy_panel.action_done.connect(_on_diplomacy_action)
	if battle_view and battle_view.has_signal("action_chosen"):
		battle_view.action_chosen.connect(_on_battle_action)
	if turn_report and turn_report.continue_pressed:
		turn_report.continue_pressed.connect(_on_turn_report_dismissed)
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	_refresh_ui()
	_append_chronicle("Rok 902. Mojmír II. zasadá na trón Veľkej Moravy. Kronika sa otvára.")
	_append_chronicle("Tvoj cieľ: udržať dynastiu a aspoň jednu župu do roku 1000.")
	if not GameManager.game_state.tutorial_done:
		# Connect coach advancement before normal handlers
		if map_view and map_view.has_signal("province_selected") and not map_view.province_selected.is_connected(_coach_on_province_selected):
			map_view.province_selected.connect(_coach_on_province_selected)
		_show_coach_overlay()


# ─── Coach / Tutorial ───

func _show_coach_overlay() -> void:
	var gs = GameManager.game_state
	if gs.tutorial_done:
		return
	var step: int = gs.tutorial_step  # 0, 1, or 2

	var overlay := PanelContainer.new()
	overlay.name = "CoachOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_theme_stylebox_override("panel", _coach_style())

	# Dim background — fully passive, clicks pass through
	var dim := ColorRect.new()
	dim.name = "CoachDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	# Content vbox — also passive (text only, no click-catch)
	var vbox := VBoxContainer.new()
	vbox.name = "CoachContent"
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchors_preset = Control.PRESET_CENTER_TOP
	vbox.offset_top = 60
	vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)

	# Title: "Krok N/3"
	var title_lbl := Label.new()
	title_lbl.text = "Krok %d/3" % [step + 1]
	title_lbl.theme_type_variation = &"TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	# Body text — one sentence from spec §2.2
	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_lbl.add_theme_font_size_override("font_size", 16)
	match step:
		0:
			body_lbl.text = "Klikni na Nitru — srdce tvojej ríše a sídlo rodu Mojmírovcov."
		1:
			body_lbl.text = "Toto je tvoje poslanie: udržať Nitru a dynastiu Mojmírovcov do roku 1000. Pozri si ho hore nad mapou."
		2:
			body_lbl.text = "Stlač „Ďalší mesiac“ dole — každý mesiac posunie tvoju vládu bližšie k roku 907, keď prídu Maďari."
	vbox.add_child(body_lbl)

	# Arrow indicator pointing to target
	var arrow_text := Label.new()
	arrow_text.name = "CoachArrowChar"
	arrow_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_text.add_theme_font_size_override("font_size", 32)
	arrow_text.add_theme_color_override("font_color", _Colors.BYZANTINE_GOLD)
	arrow_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var target_node: Control = null
	var target_is_above: bool = false  # true if arrow should be below target, pointing up
	match step:
		0:
			target_node = map_view
			target_is_above = false
		1:
			target_node = objectives_panel if is_instance_valid(objectives_panel) else null
			target_is_above = true
		2:
			target_node = next_month_btn
			target_is_above = false
	if target_node != null and is_instance_valid(target_node):
		arrow_text.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_call_deferred_arrow_pos(arrow_text, target_node, overlay, target_is_above)
	overlay.add_child(arrow_text)

	overlay.add_child(vbox)

	# Button row — these DO catch clicks (STOP)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Skip button (always visible)
	var skip_btn := Button.new()
	skip_btn.text = "Preskočiť tutoriál"
	skip_btn.custom_minimum_size = Vector2(0, 48)
	skip_btn.pressed.connect(func():
		gs.tutorial_step = 3
		gs.tutorial_done = true
		_coach_cleanup()
		_notify("Tutoriál preskočený. Hlavný ťah = „Ďalší mesiac“.")
	)
	btn_row.add_child(skip_btn)

	# Step 1: "Rozumiem" acknowledge button (per spec §2.2 — only exception for overlay click-through)
	if step == 1:
		var ack_btn := Button.new()
		ack_btn.text = "Rozumiem"
		ack_btn.custom_minimum_size = Vector2(0, 48)
		ack_btn.pressed.connect(func():
			gs.tutorial_step = 2
			_coach_cleanup()
			_show_coach_overlay()
		)
		btn_row.add_child(ack_btn)

	vbox.add_child(btn_row)

	add_child(overlay)


func _call_deferred_arrow_pos(arrow: Label, target: Control, overlay_parent: Control, is_above: bool) -> void:
	# Wait one frame so layout is computed
	await get_tree().process_frame
	if not is_instance_valid(arrow) or not is_instance_valid(target):
		return
	var target_gr := target.get_global_rect()
	var overlay_gr := overlay_parent.get_global_rect()
	var ox: float = target_gr.position.x - overlay_gr.position.x + target_gr.size.x / 2 - 16
	var oy: float
	if is_above:
		# Arrow below target, pointing UP
		oy = target_gr.position.y - overlay_gr.position.y + target_gr.size.y + 4
		arrow.text = "▲"
	else:
		# Arrow above target, pointing DOWN
		oy = target_gr.position.y - overlay_gr.position.y - 36
		arrow.text = "▼"
	arrow.position = Vector2(ox, oy)


func _coach_cleanup() -> void:
	var overlay := get_node_or_null("CoachOverlay")
	if overlay != null:
		overlay.queue_free()


func _coach_on_province_selected(province_id: String) -> void:
	var gs = GameManager.game_state
	if gs.tutorial_done:
		return
	if gs.tutorial_step == 0 and province_id == "nitra":
		gs.tutorial_step = 1
		_coach_cleanup()
		_show_coach_overlay()


func _coach_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	s.border_color = Color(_Colors.BYZANTINE_GOLD.r, _Colors.BYZANTINE_GOLD.g, _Colors.BYZANTINE_GOLD.b, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.content_margin_left = 40
	s.content_margin_top = 30
	s.content_margin_right = 40
	s.content_margin_bottom = 30
	return s


func _apply_regnum_theme() -> void:
	var built: Theme = _ThemeFactory.build()
	theme = built
	if background:
		background.color = _Colors.BG_DARKER
	if title_label:
		title_label.theme_type_variation = &"TitleLabel"
	if event_title:
		event_title.theme_type_variation = &"SubtitleLabel"
	if selection_label:
		selection_label.theme_type_variation = &"MutedLabel"
	if story_line:
		story_line.theme_type_variation = &"SubtitleLabel"
	if hero_caption:
		hero_caption.theme_type_variation = &"MutedLabel"
	# Help strip panel style
	if help_strip:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.15, 0.10, 0.06, 0.85)
		s.border_color = _Colors.BYZANTINE_GOLD
		s.border_width_left = 2
		s.border_width_top = 0
		s.border_width_right = 0
		s.border_width_bottom = 0
		s.set_corner_radius_all(4)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		help_strip.add_theme_stylebox_override("panel", s)


func _setup_background_art() -> void:
	if bg_art == null:
		return
	var tex: Texture2D = ArtCatalog.texture("regnum_visual_style_master")
	if tex == null:
		tex = ArtCatalog.texture("moravian_court_interior")
	if tex != null:
		bg_art.texture = tex
		bg_art.modulate = Color(1, 1, 1, 0.18)
		bg_art.visible = true
	else:
		bg_art.visible = false


func _setup_default_hero() -> void:
	selection_art_id = "mojmir_ii_master_portrait"
	_set_hero_art(selection_art_id, "Mojmír II. — ty vládneš")
	if ruler_art:
		var rt: Texture2D = ArtCatalog.texture("mojmir_ii_master_portrait")
		if rt != null:
			ruler_art.texture = rt
			ruler_art.visible = true


func _setup_ui_panels() -> void:
	# ThreatClock and ObjectivesPanel are instance nodes in Main.tscn
	# (direct children of UI, between StatusBarRow and Body)
	pass


func _set_hero_art(art_id: String, caption: String = "") -> void:
	if hero_art == null:
		return
	var tex: Texture2D = ArtCatalog.texture(art_id)
	if tex != null:
		hero_art.texture = tex
		hero_art.visible = true
	else:
		hero_art.visible = false
	if hero_caption:
		hero_caption.text = caption if caption != "" else art_id


# ─── Help strip / CTA ───

func _compute_cta_text() -> String:
	# Determines what the player should do NOW based on game state.
	if GameManager == null or GameManager.game_state == null:
		return ""

	var gs = GameManager.game_state

	# 1. Tutorial active (not yet done)
	if not gs.tutorial_done:
		return "Krok %d/3 — postupuj podľa tutoriálu" % [mini(gs.tutorial_step + 1, 3)]

	# 2. Pending event — player must resolve it first
	if GameManager.has_pending_event():
		return "◈  Vyber voľbu v paneli udalostí"

	# 3. Battle active — battle_view actions visible (not post-outcome)
	if battle_view and battle_view.has_method(&"is_in_active_combat") and battle_view.call(&"is_in_active_combat"):
		return "⚔  Vyber akciu v bitke"

	# 4. Devín scenario recommended (year 906–908, not resolved yet)
	if gs.devine_resolved == false:
		var y: int = int(gs.year)
		if y >= 906 and y <= 908:
			return "★  Odporúčame: spusti Scénár „Devín 907“ v nástrojoch"

	# 5. Normal play — primary CTA is Next Month
	var year: int = int(gs.year)
	var month: int = int(gs.month)
	var owned: int = 0
	for pid in gs.provinces:
		var p = gs.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == "moravia":
			owned += 1
	return "▶  Ďalší mesiac  ·  župy %d  ·  %d/%02d" % [owned, year, month]


func _update_story_line() -> void:
	if story_line == null or GameManager == null or GameManager.game_state == null:
		return
	var gs = GameManager.game_state
	var cta: String = _compute_cta_text()
	# Threat strip: worst loyalty, hostile faction, food runway
	var threats: Array = []
	var worst_loyalty := 100.0
	var worst_province := ""
	for pid in gs.provinces:
		var p = gs.provinces[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var loy: float = float(p.get("loyalty", 50))
		if loy < worst_loyalty:
			worst_loyalty = loy
			worst_province = str(p.get("name", pid))
	if worst_loyalty < 40 and worst_province != "":
		threats.append("lojalita %s: %.0f" % [worst_province, worst_loyalty])
	var worst_mood := 100.0
	var worst_faction := ""
	for fid in gs.factions:
		var f = gs.factions[fid]
		if typeof(f) != TYPE_DICTIONARY:
			continue
		if fid == "moravia":
			continue
		var mood: float = float(f.get("mood", 50))
		if mood < worst_mood:
			worst_mood = mood
			worst_faction = str(f.get("name", fid))
	if worst_mood < 35 and worst_faction != "":
		threats.append("%s: %.0f" % [worst_faction, worst_mood])
	var food: int = int(gs.resources.get("food", 0))
	if food < 50:
		threats.append("jedlo: %d" % food)
	var threat_text: String = ""
	if not threats.is_empty():
		threat_text = "  ⚠ " + " · ".join(threats)
	story_line.text = cta + threat_text


func _on_next_month() -> void:
	var gs = GameManager.game_state
	# Coach completion: step 2 + pressed = finish tutorial, then normal month
	if not gs.tutorial_done and gs.tutorial_step == 2:
		gs.tutorial_done = true
		gs.tutorial_step = 3
		_coach_cleanup()
		_notify("Tutoriál dokončený. Veľa šťastia, Mojmír II.!")

	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		_notify("Najprv vyrieš udalosť — vyber voľbu A alebo B.")
		return
	var res_before: Dictionary = GameManager.game_state.resources.duplicate(true)
	var report: Dictionary = GameManager.process_next_month()
	_months_played += 1
	_refresh_ui()
	# Δ resources
	var deltas: Array = []
	var res_after: Dictionary = GameManager.game_state.resources
	for key in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		var d: int = int(res_after.get(key, 0)) - int(res_before.get(key, 0))
		if d != 0:
			var sign: String = "+" if d > 0 else ""
			deltas.append("%s%s%d" % [key, sign, d])
	var delta_str: String = ""
	if not deltas.is_empty():
		delta_str = " Δ: %s" % ", ".join(deltas)
	if report.has("chronicle") and str(report["chronicle"]) != "":
		_append_chronicle("[%d/%02d] %s%s" % [
			report.get("year", 0),
			report.get("month", 0),
			report["chronicle"],
			delta_str
		])
	else:
		_append_chronicle("[%d/%02d] Mesiac uplynul v tichu dvorov a polí.%s" % [
			GameManager.game_state.year, GameManager.game_state.month, delta_str
		])
	_check_ending()
	# Post-tick notifications
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		_notify("Udalosť! Vyber jednu z dvoch volieb.")
	elif gs.year == 906 and gs.month == 1:
		_show_devin_modal("warning")
	elif gs.year == 906 and gs.month >= 6:
		_notify("Rok 906: pošli armádu k Devínu (Armády → Presun → devin).")
	elif gs.year == 907 and gs.month == 1:
		_show_devin_modal("prepare")
	# Show turn report card
	_show_turn_report_via_node(deltas, report.get("chronicle", ""))


func _on_skirmish() -> void:
	var attacker := {"faction_id": "moravia", "size": 1000, "morale": 80.0,
		"composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1}, "commander": {"skill": 5}}
	var defender := {"faction_id": "hungary", "size": 800, "morale": 70.0,
		"composition": {"infantry": 0.5, "cavalry": 0.4, "archers": 0.1}, "commander": {"skill": 4}}
	_active_battle = GameManager.war_manager.battle_manager.begin_phased_battle(attacker, defender, "field")
	_battle_round = 0
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	battle_view.call("show_actions", true)
	_set_hero_art("nitra_master_hero", "Cvičná bitka · Nitra")
	battle_view.visible = true


func _on_battle_action(action: String) -> void:
	var bm = GameManager.war_manager.battle_manager
	if _battle_round < 2:
		var phase := "attack" if _battle_round == 0 else "counterattack"
		var enemy_action: String = bm.pick_ai_action(_active_battle["defender"])
		_active_battle = bm.resolve_phase_round(_active_battle, phase, action, enemy_action)
		_battle_round += 1
		if _active_battle.get("routed", "") != "" or _battle_round >= 2:
			_finish_battle(action)
		else:
			battle_view.call("show_actions", true)
	else:
		_finish_battle(action)


func _finish_battle(last_action: String) -> void:
	var bm = GameManager.war_manager.battle_manager
	var enemy_action: String = bm.pick_ai_action(_active_battle["defender"])
	_active_battle = bm.resolve_decision(_active_battle, last_action, enemy_action)
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	battle_view.call("show_actions", false)
	_show_battle("Cvičná bitka pri Nitre", _active_battle, "nitra_master_hero")
	_log_battle_phases(_active_battle)
	_notify("Cvičná bitka hotová — späť k mesačným ťahom.")
	_refresh_ui()


func _on_devine() -> void:
	if GameManager.game_state.devine_resolved:
		_notify("Scenár Devín 907 už bol odohraný.")
		return
	var outcome: Dictionary = GameManager.run_devine_battle()
	if not outcome.get("ok", true):
		_notify(str(outcome.get("chronicle", "Devín 907 už odohraný.")))
		return
	_refresh_ui()
	if outcome.has("chronicle"):
		_append_chronicle(str(outcome["chronicle"]))
	_set_hero_art("battle_danube_composition", "Kríza 907 · Devín (Maďari útočia)")
	_show_battle("Bitka pri Devíne (907)", outcome, "battle_danube_composition")
	_log_battle_phases(outcome)
	_show_devin_modal("epilogue")
	_notify("Scénár 907 odohraný. Pokračuj „Ďalší mesiac“.")


func _on_save() -> void:
	GameManager.save()
	_notify("Hra uložená.")


func _on_menu() -> void:
	GameManager.save()
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")


func _show_battle(title: String, outcome: Dictionary, art_id: String = "") -> void:
	var path: String = ""
	if art_id != "":
		path = ArtCatalog.path(art_id)
	if battle_view and battle_view.has_method("show_outcome"):
		battle_view.call("show_outcome", title, outcome, path)


func _log_battle_phases(outcome: Dictionary) -> void:
	var logs: Array = outcome.get("phase_logs", [])
	for log in logs:
		if typeof(log) != TYPE_DICTIONARY:
			continue
		var phase: String = str(log.get("phase", "?"))
		if phase in ["attack", "counterattack"]:
			_append_chronicle("  · %s: A-%d D-%d" % [
				phase,
				int(log.get("attacker_losses", 0)),
				int(log.get("defender_losses", 0)),
			])
		elif phase == "decision":
			_append_chronicle("  · výsledok: %s" % str(log.get("winner", "?")))


func _on_province_selected(province_id: String) -> void:
	var p = GameManager.game_state.provinces.get(province_id, {})
	if typeof(p) != TYPE_DICTIONARY:
		selection_label.text = "Župa: %s" % province_id
		return
	selection_label.text = "Župa %s · vlastník %s · lojalita %s · prosperita %s  →  ďalej: Ďalší mesiac alebo Diplomacia" % [
		str(p.get("name", province_id)),
		str(p.get("owner_faction", "?")),
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?"))
	]
	var art_id: String = ArtCatalog.province_art_id(province_id)
	if art_id == "":
		art_id = "mojmir_dynasty_emblem"
	selection_art_id = art_id
	_set_hero_art(art_id, "%s · tvoja ríša" % str(p.get("name", province_id)))


func _show_event(ev: Variant) -> void:
	if ev == null or typeof(ev) != TYPE_DICTIONARY:
		return
	var norm: Dictionary = _normalize_event(ev)
	event_panel.visible = true
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	event_title.text = str(norm.get("title", "Udalosť na dvore"))
	event_body.text = str(norm.get("body", ""))
	var art_id: String = str(norm.get("art_id", ""))
	if art_id == "":
		art_id = _get_event_fallback_art(norm)
	if art_id != "":
		var tex: Texture2D = ArtCatalog.texture(art_id)
		if tex != null and event_art:
			event_art.texture = tex
			event_art.visible = true
		_set_hero_art(art_id, str(norm.get("title", "Udalosť")))
	elif event_art:
		event_art.visible = false
	var choices: Array = norm.get("choices", [])
	if choices.size() >= 1 and typeof(choices[0]) == TYPE_DICTIONARY:
		choice_a_btn.text = str(choices[0].get("label", "A"))
		choice_a_btn.set_meta("choice_id", str(choices[0].get("id", "")))
		choice_a_btn.visible = true
	else:
		choice_a_btn.visible = false
	if choices.size() >= 2 and typeof(choices[1]) == TYPE_DICTIONARY:
		choice_b_btn.text = str(choices[1].get("label", "B"))
		choice_b_btn.set_meta("choice_id", str(choices[1].get("id", "")))
		choice_b_btn.visible = true
	else:
		choice_b_btn.visible = false
	if choices.size() >= 3 and typeof(choices[2]) == TYPE_DICTIONARY:
		choice_c_btn.text = str(choices[2].get("label", "C"))
		choice_c_btn.set_meta("choice_id", str(choices[2].get("id", "")))
		choice_c_btn.visible = true
	else:
		choice_c_btn.visible = false


func _normalize_event(ev: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"title": str(ev.get("title", "")),
		"body": str(ev.get("body", "")),
		"art_id": str(ev.get("art_id", "")),
		"choices": [],
	}
	if out["body"] == "" and ev.has("text"):
		out["body"] = str(ev.get("text", ""))
	if out["title"] == "":
		out["title"] = "Rada / Udalosť"
	var ch = ev.get("choices", [])
	var arr: Array = []
	if typeof(ch) == TYPE_ARRAY:
		arr = ch
	elif typeof(ch) == TYPE_DICTIONARY:
		var d: Dictionary = ch
		for k in d.keys():
			var item = d[k]
			if typeof(item) != TYPE_DICTIONARY:
				continue
			arr.append({
				"id": str(k),
				"label": str(item.get("text", item.get("label", k))),
				"effect": item.get("effect", {}),
			})
	out["choices"] = arr
	return out


func _get_event_fallback_art(ev: Dictionary) -> String:
	var text: String = str(ev.get("body", "")) + " " + str(ev.get("title", ""))
	var low: String = text.to_lower()
	if "rada" in low or "župan" in low:
		return "moravian_court_interior"
	if "nitra" in low:
		return "nitra_master_hero"
	if "devín" in low or "devin" in low:
		return "devin_master_fortress"
	if "bitka" in low:
		return "battle_danube_composition"
	return "moravian_court_interior"


func _on_choice_a() -> void:
	_resolve(str(choice_a_btn.get_meta("choice_id", "")))


func _on_choice_b() -> void:
	_resolve(str(choice_b_btn.get_meta("choice_id", "")))


func _on_choice_c() -> void:
	_resolve(str(choice_c_btn.get_meta("choice_id", "")))


func _resolve(choice_id: String) -> void:
	var result: Dictionary = GameManager.resolve_event_choice(choice_id)
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	_refresh_ui()
	if result.get("ok", false):
		if result.has("chronicle"):
			_append_chronicle(str(result["chronicle"]))
		_notify("Voľba prijatá. Môžeš ísť „Ďalší mesiac“.")
	if selection_art_id != "":
		_set_hero_art(selection_art_id, "")


func _on_diplomacy_action(line: String = "") -> void:
	if line != "":
		_append_chronicle(line)
	_refresh_ui()
	_notify("Diplomacia vykonaná.")


func _refresh_ui() -> void:
	if status_bar and status_bar.has_method("refresh"):
		status_bar.call("refresh")
	if religion_axis and religion_axis.has_method("refresh"):
		religion_axis.call("refresh")
	if map_view and map_view.has_method("refresh"):
		map_view.call("refresh")
	if objectives_panel and objectives_panel.has_method("refresh"):
		objectives_panel.call("refresh")
	if threat_clock and threat_clock.has_method("refresh"):
		threat_clock.call("refresh")
	if army_ui and army_ui.has_method("_update_army_list"):
		army_ui.call("_update_army_list")
	if diplomacy_panel and diplomacy_panel.has_method("refresh"):
		diplomacy_panel.call("refresh")
	_update_story_line()
	# Year-gate Devín button + hint
	if devine_btn and GameManager and GameManager.game_state:
		var y: int = int(GameManager.game_state.year)
		if y < 906:
			devine_btn.disabled = true
			devine_btn.text = "Scénár: Devín 907 (od roku 906)"
		else:
			devine_btn.disabled = false
			if y >= 906 and y <= 908:
				devine_btn.text = "★ Scénar: Devín 907 (odporúčané)"
			else:
				devine_btn.text = "Scénár: Devín 907"


func _append_chronicle(text: String) -> void:
	if chronicle_label:
		chronicle_label.append_text(text + "\n")
	_notify(text)


func _notify(text: String) -> void:
	if notification_feed and notification_feed.has_method("push"):
		# short line only
		var short: String = text
		if short.length() > 120:
			short = short.substr(0, 117) + "…"
		notification_feed.call("push", short)


# ─── TurnReport card ───

func _show_turn_report_via_node(deltas: Array, chronicle_line: String) -> void:
	if turn_report == null:
		return
	var gs = GameManager.game_state
	var res_delta: Dictionary = {}
	for key in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		for d in deltas:
			if key in str(d):
				var val: int = int(d.replace(key, "").replace("+", "").replace("-", ""))
				if "-" in str(d):
					val = -val
				res_delta[key] = val
	turn_report.show_report({
		"year": gs.year,
		"month": gs.month,
		"resources_delta": res_delta,
		"narration": chronicle_line if chronicle_line != "" else "Mesiac uplynul v tichu dvorov a polí.",
	})


func _on_turn_report_dismissed() -> void:
	if next_month_btn:
		next_month_btn.disabled = false
	if skirmish_btn:
		skirmish_btn.disabled = false
	if devine_btn:
		devine_btn.disabled = false


# ─── Devín chapter modal ───

func _show_devin_modal(stage: String) -> void:
	var modal := PanelContainer.new()
	modal.name = "DevinModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_theme_stylebox_override("panel", _modal_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl := Label.new()
	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match stage:
		"warning":
			title_lbl.text = "Rok 906 — Blíži sa invázia"
			body_lbl.text = "Kupci a vyzvedaci hlásia zhromažďovanie maďarských jazdcov za hranicami.\nRok 907 prinesie rozhodujúcu bitku pri Devíne.\n\nPriprav sa: posilni armády, uzatvor spojenectvá (Diplomacia),\na opevni Nitru a Devín („Ďalší mesiac“ → opevňovacie eventy)."
		"prepare":
			title_lbl.text = "Rok 907 — Devín volá"
			body_lbl.text = "Maďarské vojská sa valia na Devín!\nToto je rozhodujúci moment tvojej vlády.\n\nScenár Devín 907 je pripravený — klikni na tlačidlo\n„★ Scenár: Devín 907“ v nástrojoch dole."
		"epilogue":
			title_lbl.text = "Po Devíne — kríza prežitá"
			body_lbl.text = "Bitka pri Devíne sa skončila. Maďari zvíťazili —\nako predpovedali kroniky, ako varovali kupci.\n\nMorava však stojí. Dynastia žije.\nTvoj cieľ: vydržať do roku 1000.\n\nPokračuj „Ďalší mesiac“."
	title_lbl.theme_type_variation = &"TitleLabel"
	vbox.add_child(title_lbl)
	vbox.add_child(body_lbl)
	var close_btn := Button.new()
	close_btn.text = "Rozumiem"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.pressed.connect(func(): modal.queue_free())
	vbox.add_child(close_btn)
	modal.add_child(vbox)
	add_child(modal)


func _modal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.05, 0.03, 0.96)
	s.border_color = Color(_Colors.MORAVIA_CRIMSON.r, _Colors.MORAVIA_CRIMSON.g, _Colors.MORAVIA_CRIMSON.b, 0.6)
	s.set_border_width_all(3)
	s.set_corner_radius_all(18)
	s.content_margin_left = 50
	s.content_margin_top = 40
	s.content_margin_right = 50
	s.content_margin_bottom = 40
	return s


func _check_ending() -> void:
	if GameManager == null or GameManager.victory_manager == null:
		return
	var result: Dictionary = GameManager.victory_manager.check_victory()
	if bool(result.get("victory", false)) or bool(result.get("defeat", false)):
		var msg: String = str(result.get("message", "Koniec hry."))
		_append_chronicle(msg)
		if GameManager.has_method("save"):
			GameManager.save()
		get_tree().change_scene_to_file("res://scenes/end/EndScreen.tscn")