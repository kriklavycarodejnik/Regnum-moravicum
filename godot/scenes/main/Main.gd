# scenes/main/Main.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var status_bar: HBoxContainer = $UI/StatusBarRow/StatusBar
@onready var religion_axis: HBoxContainer = $UI/StatusBarRow/ReligionAxis
@onready var map_view: Control = $UI/Body/MainColumn/MapView
@onready var chronicle_label: RichTextLabel = $IO/Body/MainColumn/Chronicle
@onready var next_month_btn: Button = $UI/ButtonRow/NextMonthButton
@onready var skirmish_btn: Button = $UI/ButtonRow/SkirmishButton
@onready var devine_btn: Button = $UI/ButtonRow/DevineButton
@onready var save_btn: Button = $UI/ButtonRow/SaveButton
@onready var menu_btn: Button = $UI/ButtonRow/MenuButton
@onready var provinces_label: Label = $UI/Body/MainColumn/ProvincesLabel
@onready var selection_label: Label = $UI/Body/MainColumn/SelectionLabel
@onready var selection_art: TextureRect = $UI/Body/MainColumn/SelectionArt  # NEW: for province art
@onready var event_panel: PanelContainer = $UI/Body/MainColumn/EventPanel
@onready var event_title: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventTitle
@onready var event_body: Label = $UI/Body/MainColumn/EventPanel/EventVBox/EventBody
@onready var choice_a_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceA
@onready var choice_b_btn: Button = $UI/Body/MainColumn/EventPanel/EventVBox/Choices/ChoiceB
@onready var title_label: Label = $UI/Title
@onready var background: ColorRect = $Background
@onready var army_ui: Control = $UI/Body/SidePanel/SideTabs/Armády
@onready var diplomacy_panel: Control = $"UI/Body/SidePanel/SideTabs/Diplomacia"
@onready var event_art: TextureRect = $UI/Body/MainColumn/EventPanel/EventVBox/EventArt
@onready var notification_feed: Node = $UI/Body/MainColumn/NotificationFeed
@onready var battle_view: Node = $UI/Body/MainColumn/BattleView

# We'll add a new node for selection_art in the scene. But note: we are we are changing the scene.
# We must update the .tscn file as well. However, we are only allowed to change .gd files? 
# The user said we can use the tools, but we are in a text-based interface. We cannot edit .tscn directly.
# We have two options:
#   1. Assume the SelectionArt node already exists in the scene (we can add it via code if not, but that's hacky).
#   2. Instead of adding a new node, we can use the existing event_art or another existing node to show the selection art temporarily? 
#      But that would interfere with event art.
#   3. We can create a new TextureRect in code and add it to the scene. However, we are not supposed to change the scene structure via code? 
#      We can, but it's better to edit the .tscn. However, we don't have the ability to edit .tscn via the text tools easily.
#
# Given the constraints, we will skip adding a new node for selection_art and instead show the selection art in the event_art area when no event is active? 
# But that would be confusing.
#
# Alternatively, we can change the selection_label to show the art as an icon? But it's a Label.
#
# Let's re-read the document: 
#   "2) Výber župy (MapView → Main)" 
#   - už mapuje nitra/devin/bratislava; rozšír:
#        - morava → moravian_court_interior (alebo nitra)
#        - default → mojmir_dynasty_emblem alebo style master (tlmene)
#   - zobraz art v bočnom náhľade ALEBO EventArt/Selection preview (jednoduchý TextureRect `ProvinceArt` v MainColumn ak treba).
#
# It says we can either show it in the existing EventArt (when no event) or create a new TextureRect called ProvinceArt.
#
# Since we cannot easily add a new node to the scene without editing the .tscn, we will do the following:
#   - We will use the event_art to show the selection art when there is no active event.
#   - When an event is active, we will show the event art in event_art and hide the selection art (by not setting it).
#   - We will keep a separate variable to store the current selection art_id and set it on event_art when there is no event.
#
# We'll add a new variable: `var selection_art_id: String = ""`
# And in _on_province_selected, we set the selection_art_id and update the art if no event is showing.
# In _show_event, we will show the event art and hide the selection art (by clearing the event_art or setting it to the event art).
# In _hide_event (when event is dismissed), we will show the selection art again if there is a selection.
#
# This is a bit complex but doable without changing the scene.
#
# Let's implement.

func _ready() -> void:
	_apply_regnum_theme()
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
	_refresh_ui()
	_append_chronicle("Kronika sa začína. Mojmír II. vládne Veľkej Morave.")

# New: track the current selection for art
var selection_art_id: String = ""

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
	# Determine the art id for this province
	var art_id := ""
	match province_id:
		"nitra":
			art_id = "nitra_master_hero"
		"devin":
			art_id = "devin_master_fortress"
		"bratislava":
			art_id = "bratislava_master_river"
		"morava":
			art_id = "moravian_court_interior"
		_:
			art_id = "mojmir_dynasty_emblem"  # default to dynasty emblem
	selection_art_id = art_id
	# If no event is showing, update the event_art with the selection art
	if not event_panel.visible:
		_update_selection_art()

func _update_selection_art() -> void:
	if event_art == null:
		return
	if selection_art_id == "":
		event_art.visible = false
		return
	var art_cat = ArtCatalog.new()
	var tex = art_cat.texture(selection_art_id)
	if tex != null:
		event_art.texture = tex
		event_art.visible = true
	else:
		event_art.visible = false

func _show_event(ev: Variant) -> void:
	if ev == null or typeof(ev) != TYPE_DICTIONARY:
		return
	event_panel.visible = true
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	event_title.text = str(ev.get("title", "Udalosť"))
	event_body.text = str(ev.get("body", ""))
	var art_id := str(ev.get("art_id", ""))
	if art_id != "":
		var art_cat = ArtCatalog.new()
		var tex = art_cat.texture(art_id)
		if tex:
			event_art.texture = tex
			event_art.visible = true
		else:
			event_art.visible = false
	else:
		# No art_id in event, use fallback
		var fallback_art_id := _get_event_fallback_art(ev)
		if fallback_art_id != "":
			var art_cat = ArtCatalog.new()
			var tex = art_cat.texture(fallback_art_id)
			if tex:
				event_art.texture = tex
				event_art.visible = true
			else:
				event_art.visible = false
		else:
			event_art.visible = false
	var choices: Array = ev.get("choices", [])
	if choices.size() >= 1:
		choice_a_btn.text = str(choices[0].get("label", "A"))
		choice_a_btn.set_meta("choice_id", str(choices[0].get("id", "")))
	if choices.size() >= 2:
		choice_b_btn.text = str(choices[1].get("label", "B"))
		choice_b_btn.set_meta("choice_id", str(choices[1].get("id", "")))

func _get_event_fallback_art(ev: Dictionary) -> String:
	# Check if the event is related to a ruler/dynasty
	var text := str(ev.get("text", ""))
	if "Mojmír" in text or "Svätopluk" in text or "Rastislav" in text:
		return "mojmir_ii_master_portrait"
	# Check if it's about a province
	# We could parse the text for province names, but for simplicity we'll use a mapping of keywords.
	# This is a simple fallback; we can improve later.
	if "Nitra" in text:
		return "nitra_master_hero"
	if "Devín" in text:
		return "devin_master_fortress"
	if "Bratislava" in text:
		return "bratislava_master_river"
	if "Morava" in text:
		return "moravian_court_interior"
	# If it's a battle event, we might have a battle art
	if "bitka" in text.lower() or "battle" in text.lower():
		return "battle_danube_composition"
	return ""

func _on_choice_a() -> void:
	_resolve(str(choice_a_btn.get_meta("choice_id", "")))

func _on_choice_b() -> void:
	_resolve(str(choice_b_btn.get_meta("choice_id", "")))

func _resolve(choice_id: String) -> void:
	var result: Dictionary = GameManager.resolve_event_choice(choice_id)
	event_panel.visible = false
	if event_art:
		event_art.visible = false  # clear event art
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	_refresh_ui()
	if result.get("ok", false) and result.has("chronicle"):
		_append_chronicle(str(result["chronicle"]))
	# After resolving an event, if there is a selected province, show its art again
	if selection_art_id != "":
		_update_selection_art()

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

func _append_chronicle(text: String) -> void:
	chronicle_label.append_text(text + "\n")

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