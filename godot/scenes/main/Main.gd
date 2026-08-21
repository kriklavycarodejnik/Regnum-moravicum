# scenes/main/Main.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")
const _Translations = preload("res://scripts/ui/BattleViewTranslations.gd")

@onready var status_bar: HBoxContainer = $UI/StatusBarRow/StatusBar
@onready var religion_axis: HBoxContainer = $UI/StatusBarRow/ReligionAxis
@onready var map_view: Control = $UI/Body/MainColumn/MapView
@onready var chronicle_scroll: ScrollContainer = $UI/Body/MainColumn/ChroniclePanel/ChronicleScroll
@onready var chronicle_list: VBoxContainer = $UI/Body/MainColumn/ChroniclePanel/ChronicleScroll/ChronicleList
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
@onready var event_art_placeholder: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventArtPlaceholder
@onready var hero_art: TextureRect = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroArt
@onready var hero_caption: Label = $UI/Body/SidePanel/HeroPanel/HeroBox/HeroCaption
@onready var ruler_art: TextureRect = $UI/Body/SidePanel/RulerRow/RulerArt
@onready var notification_feed: Node = $UI/Body/MainColumn/NotificationFeed
@onready var battle_view: Node = $UI/Body/MainColumn/BattleView
@onready var turn_report: PanelContainer = $TurnReport
@onready var side_tabs: TabContainer = $UI/Body/SidePanel/SideTabs

var selection_art_id: String = "mojmir_ii_master_portrait"
var _months_played: int = 0
var _active_battle: Dictionary = {}
var _battle_round: int = 0
var _army_wizard_step: int = 0
var _army_wizard_overlay_active: bool = false
var _bg_cycle_assets: Array = ["nitra_master_hero", "devin_master_fortress", "bratislava_master_river", "moravian_court_interior", "regnum_visual_style_master"]


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
	if army_ui and army_ui.has_signal("army_selected"):
		army_ui.army_selected.connect(_on_army_wizard_army_selected)
	if army_ui and army_ui.has_signal("move_dialog_opened"):
		army_ui.move_dialog_opened.connect(_on_army_wizard_move_dialog_opened)
	if army_ui and army_ui.has_signal("army_moved"):
		army_ui.army_moved.connect(_on_army_wizard_army_moved)
	if notification_feed and notification_feed.has_signal("notification_clicked"):
		notification_feed.notification_clicked.connect(_on_action_notification_clicked)
	if battle_view and battle_view.has_signal("action_chosen"):
		battle_view.action_chosen.connect(_on_battle_action)
	if turn_report and turn_report.continue_pressed:
		turn_report.continue_pressed.connect(_on_turn_report_dismissed)
	event_panel.visible = false
	if event_art:
		event_art.visible = false
	_refresh_ui()
	_make_chronicle_entry("Mojmír II. zasadá na trón Veľkej Moravy. Kronika sa otvára.", "succession", 902, 1)
	_make_chronicle_entry("Tvoj cieľ: udržať dynastiu a aspoň jednu župu do roku 1000.", "generic")
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

	# Dim overlay — IGNORE so clicks pass through to underlying MapView / NextMonthButton
	var overlay := PanelContainer.new()
	overlay.name = "CoachOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _coach_style())

	# Dim background — fully passive, clicks pass through
	var dim := ColorRect.new()
	dim.name = "CoachDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	# Content vbox — IGNORE (text only, no click-catch)
	var vbox := VBoxContainer.new()
	vbox.name = "CoachContent"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Button row — added as DIRECT child of Main (not inside IGNORE overlay)
	# so buttons can catch clicks (STOP) while overlay stays IGNORE
	var btn_row := HBoxContainer.new()
	btn_row.name = "CoachButtons"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.anchors_preset = Control.PRESET_CENTER_TOP
	btn_row.offset_top = 180
	btn_row.set_h_size_flags(Control.SIZE_EXPAND_FILL)

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
			call_deferred("_show_coach_overlay")
		)
		btn_row.add_child(ack_btn)

	add_child(overlay)
	add_child(btn_row)


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
	var buttons := get_node_or_null("CoachButtons")
	if buttons != null:
		buttons.queue_free()


func _coach_on_province_selected(province_id: String) -> void:
	var gs = GameManager.game_state
	if gs.tutorial_done:
		return
	if gs.tutorial_step == 0 and province_id == "nitra":
		gs.tutorial_step = 1
		_coach_cleanup()
		call_deferred("_show_coach_overlay")


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


# ─── Army wizard — P1 kontrakt §3.2: signal-driven W1–W4 sekvencia ───

func _try_show_army_wizard() -> void:
	"""Zobraz army wizard overlay, ak je prístupný a nie je dokončený."""
	if _army_wizard_overlay_active:
		return
	if GameManager == null or GameManager.game_state == null:
		return
	var gs = GameManager.game_state
	if gs.army_wizard_done:
		return
	var year: int = int(gs.year)
	if year < 906:
		return
	_army_wizard_step = 0
	_army_wizard_overlay_active = false
	_army_wizard_cleanup()
	_show_army_wizard()


func _show_army_wizard() -> void:
	"""Zobraz wizard overlay – čaká na hernú akciu (výber armády, presun)."""
	var gs = GameManager.game_state
	if gs == null or gs.army_wizard_done:
		return
	_army_wizard_overlay_active = true

	var overlay := PanelContainer.new()
	overlay.name = "ArmyWizardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _coach_style())

	var dim := ColorRect.new()
	dim.name = "ArmyWizardDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.name = "ArmyWizardContent"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchors_preset = Control.PRESET_CENTER_TOP
	vbox.offset_top = 60
	vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)

	var title_lbl := Label.new()
	title_lbl.theme_type_variation = &"TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match _army_wizard_step:
		0:
			title_lbl.text = "Príprava na Devín — Krok 1/4"
		1:
			title_lbl.text = "Príprava na Devín — Krok 2/4"
		2:
			title_lbl.text = "Príprava na Devín — Krok 3/4"
		3:
			title_lbl.text = "Príprava na Devín — Krok 4/4"
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_lbl.add_theme_font_size_override("font_size", 16)
	match _army_wizard_step:
		0:
			body_lbl.text = "Pošli armádu k Devínu — Maďari sa zhromažďujú.\n\nOtvor panel Armády vpravo a klikni na armádu, ktorú chceš použiť."
		1:
			body_lbl.text = "Rok 906. Maďarské družiny sa zhromažďujú za Karpatskými priesmykmi.\n\nTeraz klikni na tlačidlo „Presunúť“ a v dialógu vyber cieľ."
		2:
			body_lbl.text = "Vyber veliteľa.\n\nRadomír z Gemera je skúsený vojak — potvrď výber tlačidlom nižšie."
		3:
			body_lbl.text = "Armáda smeruje k Devínu.\n\nKlikni na Devín v otvorenom dialógi presunu.\nBitka sa odohrá v roku 907."
	vbox.add_child(body_lbl)

	overlay.add_child(vbox)

	var btn_row := HBoxContainer.new()
	btn_row.name = "ArmyWizardButtons"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.anchors_preset = Control.PRESET_CENTER_TOP
	btn_row.offset_top = 180
	btn_row.set_h_size_flags(Control.SIZE_EXPAND_FILL)

	# Zavrieť – vždy dostupný (pozastaví wizard)
	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.text = "Zavrieť"
	close_btn.pressed.connect(func():
		_army_wizard_overlay_active = false
		_army_wizard_cleanup()
		_notify("Armádny wizard pozastavený. Otvor panel Armády, keď budeš pripravený.")
	)
	btn_row.add_child(close_btn)

	# Krok 2 (W3): tlačidlo „Potvrdiť veliteľa“ – vyžaduje platnú vybranú armádu s veliteľom
	if _army_wizard_step == 2:
		# Zistiť, či je vybraná armáda a má veliteľa
		var has_valid_commander: bool = false
		var cmd_name: String = ""
		var cmd_skill: int = 0
		if army_ui != null and army_ui.selected_army_id != "":
			var gm = GameManager
			if gm != null and gm.army_manager != null:
				var selected_army: Dictionary = gm.army_manager.get_army(army_ui.selected_army_id)
				if not selected_army.is_empty():
					var cmd: Dictionary = selected_army.get("commander", {})
					if typeof(cmd) == TYPE_DICTIONARY and not cmd.is_empty():
						var n: String = str(cmd.get("name", ""))
						if n != "":
							cmd_name = n
							cmd_skill = int(cmd.get("skill", 0))
							has_valid_commander = true
							# Aktualizovať body text s reálnym menom veliteľa
							body_lbl.text = "Vyber veliteľa.\n\n%s je skúsený vojak — potvrď výber tlačidlom nižšie." % [cmd_name]
		if has_valid_commander:
			var select_cmd_btn := Button.new()
			select_cmd_btn.custom_minimum_size = Vector2(0, 48)
			select_cmd_btn.text = "Potvrdiť veliteľa: %s (zručnosť %d)" % [cmd_name, cmd_skill]
			select_cmd_btn.pressed.connect(_on_army_wizard_commander_confirmed)
			btn_row.add_child(select_cmd_btn)
		else:
			# Bez platnej armády/veliteľa — tlačidlo nie je dostupné
			# (wizard čaká, kým hráč vyberie armádu s veliteľom cez ArmyUI)
			pass

	add_child(overlay)
	add_child(btn_row)


func _army_wizard_cleanup() -> void:
	var overlay := get_node_or_null("ArmyWizardOverlay")
	if overlay != null:
		overlay.queue_free()
	var buttons := get_node_or_null("ArmyWizardButtons")
	if buttons != null:
		buttons.queue_free()


func _on_army_wizard_army_selected(army_id: String) -> void:
	"""W1->W2: hráč vybral armádu → postup iba ak wizard čaká v kroku 0."""
	if not _army_wizard_overlay_active:
		return
	var gs = GameManager.game_state
	if gs == null or gs.army_wizard_done:
		return
	if _army_wizard_step != 0:
		return
	_army_wizard_step = 1
	_army_wizard_cleanup()
	call_deferred("_show_army_wizard")


func _on_army_wizard_move_dialog_opened() -> void:
	"""W2->W3: hráč otvoril dialóg presunu → postup iba ak wizard čaká v kroku 1."""
	if not _army_wizard_overlay_active:
		return
	var gs = GameManager.game_state
	if gs == null or gs.army_wizard_done:
		return
	if _army_wizard_step != 1:
		return
	_army_wizard_step = 2
	_army_wizard_cleanup()
	call_deferred("_show_army_wizard")


func _on_army_wizard_commander_confirmed() -> void:
	"""W3->W4: hráč potvrdil veliteľa pre vybranú armádu.
	Znovu overí, že vybraná armáda stále platí a má veliteľa."""
	if not _army_wizard_overlay_active:
		return
	var gs = GameManager.game_state
	if gs == null or gs.army_wizard_done:
		return
	if _army_wizard_step != 2:
		return
	# Overiť, že vybraná armáda stále existuje a má veliteľa
	var valid: bool = false
	if army_ui != null and army_ui.selected_army_id != "":
		var gm = GameManager
		if gm != null and gm.army_manager != null:
			var selected_army: Dictionary = gm.army_manager.get_army(army_ui.selected_army_id)
			if not selected_army.is_empty():
				var cmd: Dictionary = selected_army.get("commander", {})
				if typeof(cmd) == TYPE_DICTIONARY and not cmd.is_empty():
					var n: String = str(cmd.get("name", ""))
					if n != "":
						valid = true
	if not valid:
		return
	_army_wizard_step = 3
	_army_wizard_cleanup()
	call_deferred("_show_army_wizard")


func _on_army_wizard_army_moved(army_id: String, target_province: String) -> void:
	"""W3->W4->DONE: hráč úspešne presunul armádu k Devínu.
	Postupuje IBA ak cieľ = devin a army_id = aktuálne vybraná armáda.
	Iný cieľ alebo neúspešný presun nemenia krok."""
	if not _army_wizard_overlay_active:
		return
	var gs = GameManager.game_state
	if gs == null or gs.army_wizard_done:
		return
	if _army_wizard_step != 3:
		return
	if target_province != "devin":
		return
	# Overiť, že presunutá armáda je tá istá, ktorú hráč vybral v ArmyUI
	if army_ui == null or army_id != army_ui.selected_army_id:
		return
	gs.army_wizard_done = true
	_army_wizard_step = 0
	_army_wizard_overlay_active = false
	_army_wizard_cleanup()
	_notify("Wizard dokončený. Armáda smeruje k Devínu — bitka sa odohrá v roku 907.")


func _on_action_notification_clicked(action_id: String) -> void:
	"""Spracuje klik na akčnú notifikáciu (napr. armádny wizard)."""
	if action_id == "army_wizard":
		# Prepnúť na záložku Armády a spustiť wizard
		if side_tabs:
			# Hľadať index záložky Armády (Godot 4: get_tab_count() je metóda)
			for i in range(side_tabs.get_tab_count()):
				if side_tabs.get_tab_title(i) == "Armády":
					side_tabs.current_tab = i
					break
		# _try_show_army_wizard je idempotentná cez _army_wizard_overlay_active
		# a done guard — otvorí najviac jeden wizard aj pri synchronom tab_changed.
		_try_show_army_wizard()


func _on_side_tab_changed(tab_index: int) -> void:
	"""Keď hráč prepne na tab Armády, skús znova zobraziť wizard, ak nie je dokončený."""
	if side_tabs == null:
		return
	var tab_title: String = side_tabs.get_tab_title(tab_index)
	if tab_title == "Armády":
		var gs = GameManager.game_state if GameManager != null else null
		if gs != null and not gs.army_wizard_done and int(gs.year) >= 906:
			if not _army_wizard_overlay_active:
				_try_show_army_wizard()


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
	# Show BackgroundArt with modulation — the map's _draw() provides its own
	# backdrop overlay, but this art adds depth behind panels.
	bg_art.visible = true
	bg_art.modulate = Color(1, 1, 1, 0.18)
	# Start with default art
	_rotate_background()


func _update_background(art_id: String) -> void:
	if bg_art == null or art_id == "":
		return
	var tex: Texture2D = ArtCatalog.safe_texture(art_id)
	if tex != null:
		bg_art.texture = tex
		bg_art.visible = true


func _rotate_background() -> void:
	# Cycle through hero assets every 10 turns
	var idx: int = (_months_played / 10) % _bg_cycle_assets.size()
	_update_background(_bg_cycle_assets[idx])


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
	if side_tabs and side_tabs.has_signal("tab_changed"):
		side_tabs.tab_changed.connect(_on_side_tab_changed)
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
		hero_caption.text = caption


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
			var stored_prov_name: String = str(p.get("name", ""))
			worst_province = _Translations.translate_province(stored_prov_name if stored_prov_name != "" else pid)
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
			var stored_fac_name: String = str(f.get("name", ""))
			worst_faction = _Translations.translate_faction(stored_fac_name if stored_fac_name != "" else fid)
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
	if _months_played % 10 == 0:
		_rotate_background()
	_refresh_ui()
	# Δ resources
	var deltas: Array = []
	var res_after: Dictionary = GameManager.game_state.resources
	var res_names_sk: Dictionary = {
		"gold": "Zlato",
		"food": "Jedlo",
		"wood": "Drevo",
		"stone": "Kameň",
		"iron": "Železo",
		"prestige": "Prestíž"
	}
	for key in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		var d: int = int(res_after.get(key, 0)) - int(res_before.get(key, 0))
		if d != 0:
			var sign: String = "+" if d > 0 else ""
			var label_sk: String = str(res_names_sk.get(key, key))
			deltas.append("%s: %s%d" % [label_sk, sign, d])
	var delta_str: String = ""
	if not deltas.is_empty():
		delta_str = " Δ: %s" % ", ".join(deltas)
	# Chronicle entry with icon from report type
	var chronicle_type: String = str(report.get("chronicle_type", "monthly"))
	if report.has("chronicle") and str(report["chronicle"]) != "":
		_make_chronicle_entry(report["chronicle"], chronicle_type, report.get("year", 0), report.get("month", 0), delta_str)
	else:
		_make_chronicle_entry("Mesiac uplynul v tichu dvorov a polí.", "monthly", GameManager.game_state.year, GameManager.game_state.month, delta_str)
	_check_ending()
	# Post-tick notifications
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		_notify("Udalosť! Vyber jednu z dvoch volieb.")
	elif gs.year == 906 and gs.month == 1:
		_show_devin_modal("warning")
	elif gs.year >= 906 and gs.month >= 6 and not gs.army_wizard_done:
		# Použiť push_action — klikateľná notifikácia spustí armádny wizard
		if notification_feed and notification_feed.has_method("push_action"):
			notification_feed.call("push_action", "Pošli armádu k Devínu — Maďari sa zhromažďujú.", "army_wizard")
		else:
			_notify("Pošli armádu k Devínu — Maďari sa zhromažďujú.")
	elif gs.year == 907 and gs.month == 1:
		_show_devin_modal("prepare")
	# Show turn report card
	_show_turn_report_via_node(res_before, res_after, report.get("chronicle", ""))


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
		_notify(str(outcome["chronicle"]))
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
	var phase_label: String = ""
	for log in logs:
		if typeof(log) != TYPE_DICTIONARY:
			continue
		var phase: String = str(log.get("phase", "?"))
		# Preklady fáz pre hráča
		if phase == "attack":
			phase_label = "útok"
		elif phase == "counterattack":
			phase_label = "protiútok"
		elif phase == "decision":
			phase_label = "rozhodnutie"
		else:
			phase_label = "neznáma fáza"
		if phase in ["attack", "counterattack"]:
			_make_chronicle_entry(" · %s: Ú-%d O-%d" % [
				phase_label,
				int(log.get("attacker_losses", 0)),
				int(log.get("defender_losses", 0)),
			], "battle")
		elif phase == "decision":
			var winner_sk: String = str(log.get("winner", "?"))
			if winner_sk == "attacker":
				winner_sk = "útočník"
			elif winner_sk == "defender":
				winner_sk = "obranca"
			else:
				winner_sk = "neznámy výsledok"
			_make_chronicle_entry(" · výsledok: %s" % winner_sk, "battle")


func _on_province_selected(province_id: String) -> void:
	var p = GameManager.game_state.provinces.get(province_id, {})
	var stored_prov_name: String = str(p.get("name", "")) if typeof(p) == TYPE_DICTIONARY else ""
	var prov_name: String = _Translations.translate_province(stored_prov_name if stored_prov_name != "" else province_id)
	if typeof(p) != TYPE_DICTIONARY:
		selection_label.text = "Župa: %s" % prov_name
		return
	var owner_raw: String = str(p.get("owner_faction", "moravia"))
	var owner_name: String = _Translations.translate_faction(owner_raw)
	var name_sk: String = prov_name
	selection_label.text = "Župa %s · vlastník %s · lojalita %s · prosperita %s  →  ďalej: Ďalší mesiac alebo Diplomacia" % [
		name_sk,
		owner_name,
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?"))
	]
	var art_id: String = ArtCatalog.province_art_id(province_id)
	if art_id == "":
		art_id = "mojmir_dynasty_emblem"
	selection_art_id = art_id
	_set_hero_art(art_id, "%s · tvoja ríša" % name_sk)
	# Background art matches selected province
	_update_background(art_id)


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
		var tex: Texture2D = ArtCatalog.safe_texture(art_id)
		if tex != null and event_art:
			event_art.texture = tex
			event_art.visible = true
			if event_art_placeholder:
				event_art_placeholder.visible = false
		else:
			if event_art:
				event_art.visible = false
			if event_art_placeholder:
				event_art_placeholder.visible = true
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
				devine_btn.text = "★ Scénár: Devín 907 (odporúčané)"
			else:
				devine_btn.text = "Scénár: Devín 907"


# ─── Chronicle — štruktúrovaný zoznam ───

const CHRONICLE_ICONS := {
	"event": "icon_scroll_64",
	"war": "icon_sword_64",
	"battle": "icon_sword_64",
	"diplomacy": "icon_eagle_64",
	"economy": "icon_shield_64",
	"armies": "icon_shield_64",
	"succession": "icon_cross_latin_64",
	"religion": "icon_cross_latin_64",
	"victory": "icon_victory_64",
	"defeat": "icon_defeat_64",
	"monthly": "icon_scroll_64",
	"generic": "icon_scroll_64",
}

const MAX_CHRONICLE_ENTRIES := 50


func _make_chronicle_entry(text: String, entry_type: String, year: int = 0, month: int = 0, suffix: String = "") -> void:
	if chronicle_list == null:
		return
	# Derive current date when callers omit year/month
	if year == 0 and month == 0:
		var gs = GameManager.game_state if GameManager != null else null
		if gs != null:
			year = gs.year
			month = gs.month
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var icon_id: String = CHRONICLE_ICONS.get(entry_type, "icon_scroll_64")
	var icon_tex: Texture2D = ArtCatalog.safe_texture(icon_id)
	if icon_tex != null:
		icon.texture = icon_tex
		icon.modulate = Color(0.85, 0.75, 0.55, 0.9)
	row.add_child(icon)

	# Date label
	var date_str: String = ""
	if year > 0 and month > 0:
		date_str = "%d/%02d" % [year, month]
	elif year > 0:
		date_str = "Rok %d" % year
	if date_str != "":
		var date_label := Label.new()
		date_label.text = date_str
		date_label.add_theme_font_size_override("font_size", 10)
		date_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4, 0.8))
		date_label.custom_minimum_size = Vector2(50, 0)
		date_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(date_label)

	# Text label
	var text_label := Label.new()
	text_label.text = text + suffix
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("font_size", 12)
	row.add_child(text_label)

	chronicle_list.add_child(row)

	# Trim if over max
	while chronicle_list.get_child_count() > MAX_CHRONICLE_ENTRIES:
		var old := chronicle_list.get_child(0)
		chronicle_list.remove_child(old)
		old.queue_free()

	# Auto scroll to bottom
	await get_tree().process_frame
	if is_instance_valid(chronicle_scroll):
		chronicle_scroll.scroll_vertical = chronicle_scroll.get_v_scroll_bar().max_value


func _append_chronicle(text: String) -> void:
	# Backward-compat wrapper: creates a generic entry
	_make_chronicle_entry(text, "generic")


func _notify(text: String) -> void:
	if notification_feed and notification_feed.has_method("push"):
		# short line only
		var short: String = text
		if short.length() > 120:
			short = short.substr(0, 117) + "…"
		notification_feed.call("push", short)


# ─── TurnReport card ───

func _show_turn_report_via_node(res_before: Dictionary, res_after: Dictionary, chronicle_line: String) -> void:
	if turn_report == null:
		return
	var gs = GameManager.game_state
	var res_delta: Dictionary = {}
	for key in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		var d: int = int(res_after.get(key, 0)) - int(res_before.get(key, 0))
		if d != 0:
			res_delta[key] = d
	# Disable buttons — CTA musí byť jediný krok pokračovania
	if next_month_btn:
		next_month_btn.disabled = true
	if skirmish_btn:
		skirmish_btn.disabled = true
	if devine_btn:
		devine_btn.disabled = true
	turn_report.show_report({
		"year": gs.year,
		"month": gs.month,
		"resources_delta": res_delta,
		"narration": chronicle_line if chronicle_line != "" else "Mesiac uplynul v tichu dvorov a polí.",
	})


func _on_turn_report_dismissed() -> void:
	# Hide the TurnReport panel
	if turn_report:
		turn_report.hide()
	# If event panel is visible, buttons stay disabled until event resolved
	if event_panel != null and event_panel.visible:
		return
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
			body_lbl.text = "Kupci a vyzvedači hlásia zhromažďovanie maďarských jazdcov za hranicami.\nRok 907 prinesie rozhodujúcu bitku pri Devíne.\n\nPriprav sa: posilni armády, uzatvor spojenectvá (Diplomacia),\na opevni Nitru a Devín („Ďalší mesiac“ → opevňovacie eventy)."
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