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
		_notify("Rok 906 — Maďari sa blížia. O rok Devín. Priprav sa: armády, diplomacia, opevnenia.")
	elif gs.year == 907 and gs.month == 1:
		_notify("Rok 907 — Devín! Scenár čaká (tlačidlo „Scénár: Devín 907“).")


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
	if GameManager == null or GameManager.victory_manager == null:
		return
	var result: Dictionary = GameManager.victory_manager.check_victory()
	if bool(result.get("victory", false)) or bool(result.get("defeat", false)):
		var msg: String = str(result.get("message", "Koniec hry."))
		_append_chronicle(msg)
		if GameManager.has_method("save"):
			GameManager.save()
		get_tree().change_scene_to_file("res://scenes/end/EndScreen.tscn")
