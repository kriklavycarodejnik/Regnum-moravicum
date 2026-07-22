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
@onready var story_line: Label = $UI/Header/StoryLine
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
@onready var objectives_panel: Node = $UI/Body/SidePanel/ObjectivesPanel
@onready var event_art: TextureRect = $UI/Body/MainColumn/EventPanel/EventVBox/EventArt
@onready var hero_art: TextureRect = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroArt
@onready var hero_caption: Label = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroCaption
@onready var ruler_art: TextureRect = $UI/Body/SidePanel/RulerRow/RulerArt
@onready var notification_feed: Node = $UI/Body/MainColumn/NotificationFeed
@onready var battle_view: Node = $UI/Body/MainColumn/BattleView

var selection_art_id: String = "mojmir_ii_master_portrait"
var _months_played: int = 0


func _ready() -> void:
	_apply_regnum_theme()
	_setup_background_art()
	_setup_default_hero()
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
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	_refresh_ui()
	_append_chronicle("Rok 902. Mojmír II. zasadá na trón Veľkej Moravy. Kronika sa otvára.")
	_append_chronicle("Tvoj cieľ: udržať dynastiu a aspoň jednu župu do roku 1000.")
	_notify("Hlavný ťah = tlačidlo „Ďalší mesiac“.")
	if not GameManager.game_state.tutorial_done:
		_show_coach_overlay()


func _show_coach_overlay() -> void:
	var gs = GameManager.game_state
	if gs.tutorial_done:
		return
	var step: int = gs.tutorial_step
	var overlay := PanelContainer.new()
	overlay.name = "CoachOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", _coach_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl := Label.new()
	title_lbl.text = "Krok %d/3" % [step + 1]
	title_lbl.theme_type_variation = &"TitleLabel"
	vbox.add_child(title_lbl)
	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match step:
		0:
			body_lbl.text = "Vitaj v Regnum Moravicum!\nKlikni na župu Nitra na mape (v strede mapy, zelený kruh)."
		1:
			body_lbl.text = "Výborne! Teraz klikni na „Ďalší mesiac“ — postúpiš o jeden mesiac vpred."
		2:
			body_lbl.text = "Skvelé! Preskúmaj Diplomaciu v bočnom paneli vpravo.\nMôžeš rokovať so susednými ríšami."
	vbox.add_child(body_lbl)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	var skip_btn := Button.new()
	skip_btn.text = "Preskočiť tutoriál"
	skip_btn.custom_minimum_size = Vector2(0, 48)
	skip_btn.pressed.connect(func():
		gs.tutorial_step = 3
		gs.tutorial_done = true
		overlay.queue_free()
		_notify("Tutoriál preskočený. Hlavný ťah = „Ďalší mesiac“.")
	)
	btn_row.add_child(skip_btn)
	if step < 2:
		var next_btn := Button.new()
		next_btn.text = "Ďalej"
		next_btn.custom_minimum_size = Vector2(0, 48)
		next_btn.pressed.connect(func():
			gs.tutorial_step += 1
			overlay.queue_free()
			_show_coach_overlay()
		)
		btn_row.add_child(next_btn)
	else:
		var done_btn := Button.new()
		done_btn.text = "Rozumiem, začať hrať"
		done_btn.custom_minimum_size = Vector2(0, 48)
		done_btn.pressed.connect(func():
			gs.tutorial_done = true
			overlay.queue_free()
			_notify("Tutoriál dokončený. Veľa šťastia, Mojmír II.!")
		)
		btn_row.add_child(done_btn)
	vbox.add_child(btn_row)
	overlay.add_child(vbox)
	add_child(overlay)


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
		story_line.theme_type_variation = &"MutedLabel"
	if hero_caption:
		hero_caption.theme_type_variation = &"MutedLabel"


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


func _update_story_line() -> void:
	if story_line == null or GameManager == null or GameManager.game_state == null:
		return
	var y: int = int(GameManager.game_state.year)
	var m: int = int(GameManager.game_state.month)
	var gs = GameManager.game_state
	if gs.devine_resolved and y < 907:
		story_line.text = "Devín už rozhodol osud ríše  ·  cieľ: prežiť do 1000  ·  ťah = Ďalší mesiac"
	elif y < 907:
		var months_left: int = (907 - y) * 12 + (7 - m)
		if months_left <= 0:
			months_left = 1
		story_line.text = "Do maďarskej invázie: ~%d mes.  ·  cieľ: prežiť do 1000  ·  ťah = Ďalší mesiac" % months_left
	else:
		var years_left: int = maxi(0, 1000 - y)
		story_line.text = "Po Devíne  ·  zostáva ~%d r. do 1000  ·  ťah = Ďalší mesiac" % years_left


func _on_next_month() -> void:
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
	var gs = GameManager.game_state
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		_notify("Udalosť! Vyber jednu z dvoch volieb.")
	elif gs.year == 906 and gs.month == 1:
		_show_devin_modal("warning")
	elif gs.year == 907 and gs.month == 1:
		_show_devin_modal("prepare")
	# Show turn report card
	_show_turn_report(deltas, report.get("chronicle", ""))


func _on_skirmish() -> void:
	var outcome: Dictionary = GameManager.run_skirmish("nitra", "field")
	_refresh_ui()
	if outcome.has("chronicle"):
		_append_chronicle(str(outcome["chronicle"]))
	_set_hero_art("nitra_master_hero", "Cvičná bitka · Nitra")
	_show_battle("Cvičná bitka pri Nitre", outcome, "nitra_master_hero")
	_log_battle_phases(outcome)
	_notify("Cvičná bitka hotová — späť k mesačným ťahom.")


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
				devine_btn.text = "★ Scénár: Devín 907 (odporúčané)"
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


func _check_ending() -> void:


# ─── TurnReport card ───

func _show_turn_report(deltas: Array, chronicle_line: String) -> void:
	var card := PanelContainer.new()
	card.name = "TurnReportCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.custom_minimum_size = Vector2(480, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl := Label.new()
	title_lbl.text = "Ťah %d/%02d" % [GameManager.game_state.year, GameManager.game_state.month]
	title_lbl.theme_type_variation = &"SubtitleLabel"
	vbox.add_child(title_lbl)
	if chronicle_line != "":
		var chr := Label.new()
		chr.text = str(chronicle_line)
		chr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(chr)
	if not deltas.is_empty():
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 10)
		for delta in deltas:
			var lbl := Label.new()
			lbl.text = str(delta)
			lbl.add_theme_font_size_override("font_size", 13)
			if "+" in str(delta):
				lbl.add_theme_color_override("font_color", _Colors.SUCCESS)
			else:
				lbl.add_theme_color_override("font_color", _Colors.WARNING)
			hbox.add_child(lbl)
		vbox.add_child(hbox)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "žiadne zmeny zdrojov"
		empty_lbl.add_theme_color_override("font_color", _Colors.TEXT_MUTED)
		vbox.add_child(empty_lbl)
	card.add_child(vbox)
	add_child(card)
	# Auto-remove after 4 seconds
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.timeout.connect(func(): card.queue_free())
	add_child(timer)
	timer.start()
	# Click to dismiss
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			card.queue_free()
	)


func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.07, 0.04, 0.92)
	s.border_color = Color(_Colors.BYZANTINE_GOLD.r, _Colors.BYZANTINE_GOLD.g, _Colors.BYZANTINE_GOLD.b, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 20
	s.content_margin_top = 12
	s.content_margin_right = 20
	s.content_margin_bottom = 12
	return s


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
			body_lbl.text = "Kupci a vyzvedači hlásia zhromažďovanie maďarských jazdcov za hranicami.\nRok 907 prinesie rozhodujúcu bitku pri Devíne.\n\nPriprav sa: posilni armády, uzatvor spojenectvá (Diplomacia),\na opevni Nitru a Devín („Ďalší mesiac“ → opevňovacie eventy)."
				"prepare":
					title_lbl.text = "Rok 907 — Devín volá"
					body_lbl.text = "Maďarské vojská sa valia na Devín!\nToto je rozhodujúci moment tvojej vlády.\n\nScenár Devín 907 je pripravený — klikni na tlačidlo\n„★ Scénár: Devín 907“ v nástrojoch dole."
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
