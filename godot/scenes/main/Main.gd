# scenes/main/Main.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var status_bar: HBoxContainer = $UI/StatusBarRow/StatusBar
@onready var religion_axis: HBoxContainer = $UI/StatusBarRow/ReligionAxis
@onready var map_view: Control = $UI/Body/MainColumn/MapView
@onready var chronicle_label: RichTextLabel = $UI/Body/MainColumn/Chronicle
@onready var next_month_btn: Button = $UI/ButtonRow/NextMonthButton
@onready var skirmish_btn: Button = $UI/ButtonRow/SkirmishButton
@onready var devine_btn: Button = $UI/ButtonRow/DevineButton
@onready var save_btn: Button = $UI/ButtonRow/SaveButton
@onready var menu_btn: Button = $UI/ButtonRow/MenuButton
@onready var provinces_label: Label = $UI/Body/MainColumn/ProvincesLabel
@onready var selection_label: Label = $UI/Body/MainColumn/SelectionLabel
@onready var help_label: Label = $UI/HelpBar
@onready var event_panel: PanelContainer = $UI/Body/MainColumn/EventPanel
@onready var event_title: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventTitle
@onready var event_body: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventBody
@onready var choice_a_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceA
@onready var choice_b_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceB
@onready var title_label: Label = $UI/Title
@onready var background: ColorRect = $Background
@onready var bg_art: TextureRect = $BackgroundArt
@onready var army_ui: Control = $UI/Body/SidePanel/SideTabs/Armády
@onready var diplomacy_panel: Control = $"UI/Body/SidePanel/SideTabs/Diplomacia"
@onready var event_art: TextureRect = $UI/Body/MainColumn/EventPanel/EventVBox/EventArt
@onready var hero_art: TextureRect = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroArt
@onready var hero_caption: Label = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroCaption
@onready var ruler_art: TextureRect = $UI/Body/SidePanel/RulerRow/RulerArt
@onready var notification_feed: Node = $UI/Body/MainColumn/NotificationFeed
@onready var battle_view: Node = $UI/Body/MainColumn/BattleView

var selection_art_id: String = "mojmir_ii_master_portrait"


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
	if map_view and map_view.has_signal("province_selected"):
		map_view.province_selected.connect(_on_province_selected)
	if diplomacy_panel and diplomacy_panel.has_signal("action_done"):
		diplomacy_panel.action_done.connect(_on_diplomacy_action)
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	if help_label:
		help_label.text = "Ako hrať: ① Klikni župu na mape  ② Sleduj zdroje hore  ③ Ďalší mesiac = ťah  ④ Eventy majú 2 voľby  ⑤ Devín 907 / Skirmish = bitka"
	_refresh_ui()
	_append_chronicle("Kronika sa začína. Mojmír II. vládne Veľkej Morave.")
	_notify("Vitaj v Regnum Moravicum — rok 902.")


func _apply_regnum_theme() -> void:
	var built: Theme = _ThemeFactory.build()
	theme = built
	if background:
		background.color = _Colors.BG_DARKER
	if title_label:
		title_label.theme_type_variation = &"TitleLabel"
	if event_title:
		event_title.theme_type_variation = &"SubtitleLabel"
	if provinces_label:
		provinces_label.theme_type_variation = &"MutedLabel"
	if selection_label:
		selection_label.theme_type_variation = &"MutedLabel"
	if help_label:
		help_label.theme_type_variation = &"MutedLabel"
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
		bg_art.modulate = Color(1, 1, 1, 0.22)
		bg_art.visible = true
	else:
		bg_art.visible = false


func _setup_default_hero() -> void:
	selection_art_id = "mojmir_ii_master_portrait"
	_set_hero_art(selection_art_id, "Mojmír II. · knieža Veľkej Moravy")
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


func _on_next_month() -> void:
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		return
	var report: Dictionary = GameManager.process_next_month()
	_refresh_ui()
	if report.has("chronicle") and str(report["chronicle"]) != "":
		_append_chronicle("[%d/%02d] %s" % [
			report.get("year", 0),
			report.get("month", 0),
			report["chronicle"]
		])
	_check_ending()
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())


func _on_skirmish() -> void:
	var outcome: Dictionary = GameManager.run_skirmish("nitra", "field")
	_refresh_ui()
	if outcome.has("chronicle"):
		_append_chronicle(str(outcome["chronicle"]))
	_set_hero_art("nitra_master_hero", "Bitka / skirmish · Nitra")
	_show_battle("Bitka pri Nitre", outcome, "nitra_master_hero")
	_log_battle_phases(outcome)


func _on_devine() -> void:
	var outcome: Dictionary = GameManager.run_devine_battle()
	_refresh_ui()
	if outcome.has("chronicle"):
		_append_chronicle(str(outcome["chronicle"]))
	_set_hero_art("battle_danube_composition", "Kríza 907 · Bitka pri Devíne (Maďari)")
	_show_battle("Bitka pri Devíne (907)", outcome, "battle_danube_composition")
	_log_battle_phases(outcome)


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
			_append_chronicle("  · %s: A-%d D-%d (ratio %.2f)" % [
				phase,
				int(log.get("attacker_losses", 0)),
				int(log.get("defender_losses", 0)),
				float(log.get("ratio", 0.0))
			])
		elif phase == "decision":
			_append_chronicle("  · decision: %s" % str(log.get("winner", "?")))


func _on_province_selected(province_id: String) -> void:
	var p = GameManager.game_state.provinces.get(province_id, {})
	if typeof(p) != TYPE_DICTIONARY:
		selection_label.text = "Župa: %s" % province_id
		return
	selection_label.text = "Vybrané: %s · vlastník %s · lojalita %s · prosperita %s" % [
		str(p.get("name", province_id)),
		str(p.get("owner_faction", "?")),
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?"))
	]
	var art_id: String = ArtCatalog.province_art_id(province_id)
	if art_id == "":
		art_id = "mojmir_dynasty_emblem"
	selection_art_id = art_id
	var cap: String = "%s · %s" % [str(p.get("name", province_id)), str(p.get("owner_faction", "?"))]
	_set_hero_art(art_id, cap)
	_notify("Župa: %s" % str(p.get("name", province_id)))


func _show_event(ev: Variant) -> void:
	if ev == null or typeof(ev) != TYPE_DICTIONARY:
		return
	# Normalize legacy EventManager shape {text, choices: Dictionary}
	var norm: Dictionary = _normalize_event(ev)
	event_panel.visible = true
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	event_title.text = str(norm.get("title", "Udalosť"))
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


func _normalize_event(ev: Dictionary) -> Dictionary:
	# Target shape: {title, body, art_id, choices: Array[{id,label,effect?}]}
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
	if "mojmír" in low or "mojmir" in low or "svätopluk" in low:
		return "mojmir_ii_master_portrait"
	if "nitra" in low:
		return "nitra_master_hero"
	if "devín" in low or "devin" in low:
		return "devin_master_fortress"
	if "bratislava" in low:
		return "bratislava_master_river"
	if "rada" in low or "župan" in low:
		return "moravian_court_interior"
	if "bitka" in low or "battle" in low:
		return "battle_danube_composition"
	return "moravian_court_interior"


func _on_choice_a() -> void:
	_resolve(str(choice_a_btn.get_meta("choice_id", "")))


func _on_choice_b() -> void:
	_resolve(str(choice_b_btn.get_meta("choice_id", "")))


func _resolve(choice_id: String) -> void:
	var result: Dictionary = GameManager.resolve_event_choice(choice_id)
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	_refresh_ui()
	if result.get("ok", false) and result.has("chronicle"):
		_append_chronicle(str(result["chronicle"]))
	if selection_art_id != "":
		_set_hero_art(selection_art_id, "")


func _on_diplomacy_action(line: String = "") -> void:
	if line != "":
		_append_chronicle(line)
	_refresh_ui()


func _refresh_ui() -> void:
	if status_bar and status_bar.has_method("refresh"):
		status_bar.call("refresh")
	if religion_axis and religion_axis.has_method("refresh"):
		religion_axis.call("refresh")
	if map_view and map_view.has_method("refresh"):
		map_view.call("refresh")
	var s = GameManager.game_state
	var edge_hint := 0
	for pid in s.provinces:
		var p = s.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY:
			edge_hint += p.get("neighbors", []).size()
	var occ := 0
	for pid2 in s.provinces:
		var p2 = s.provinces[pid2]
		if typeof(p2) == TYPE_DICTIONARY and p2.has("occupier_faction"):
			occ += 1
	provinces_label.text = "Župy: %d · susedstvá: %d · okupované: %d" % [
		s.provinces.size(), edge_hint / 2, occ
	]
	if army_ui and army_ui.has_method("_update_army_list"):
		army_ui.call("_update_army_list")
	if diplomacy_panel and diplomacy_panel.has_method("refresh"):
		diplomacy_panel.call("refresh")


func _append_chronicle(text: String) -> void:
	chronicle_label.append_text(text + "\n")
	_notify(text)


func _notify(text: String) -> void:
	if notification_feed and notification_feed.has_method("push"):
		notification_feed.call("push", text)


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
