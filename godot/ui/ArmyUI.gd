# ui/ArmyUI.gd
extends VBoxContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")

@onready var army_list: VBoxContainer = $ArmyList
@onready var army_info: Label = $ArmyInfo
@onready var move_button: Button = $Actions/MoveButton
@onready var battle_button: Button = $Actions/BattleButton
@onready var siege_button: Button = $Actions/SiegeButton

var army_manager
var map_manager
var selected_army_id: String = ""


func _ready() -> void:
	_apply_regnum_theme()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		army_manager = gm.army_manager
		map_manager = gm.map_manager
	if move_button:
		move_button.pressed.connect(_on_move_button_pressed)
	if battle_button:
		battle_button.pressed.connect(_on_battle_button_pressed)
	if siege_button:
		siege_button.pressed.connect(_on_siege_button_pressed)
	_update_army_list()


func _apply_regnum_theme() -> void:
	if theme == null:
		theme = _ThemeFactory.build()


func _clear_list() -> void:
	if army_list == null:
		return
	for c in army_list.get_children():
		c.queue_free()


func _update_army_list() -> void:
	if army_list == null:
		return
	_clear_list()
	if army_manager == null:
		if army_info:
			army_info.text = "ArmyManager nie je pripravený."
		return
	var armies = army_manager.list_armies()
	var list: Array = []
	if typeof(armies) == TYPE_ARRAY:
		list = armies
	elif typeof(armies) == TYPE_DICTIONARY:
		for k in armies:
			var a = armies[k]
			if typeof(a) == TYPE_DICTIONARY:
				if not a.has("id"):
					a = a.duplicate()
					a["id"] = k
				list.append(a)
	for army in list:
		if typeof(army) != TYPE_DICTIONARY:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.text = "%s (%s)" % [str(army.get("id", "?")), str(army.get("province_id", "?"))]
		var aid: String = str(army.get("id", ""))
		button.pressed.connect(_on_army_selected.bind(aid))
		army_list.add_child(button)
	if list.is_empty() and army_info:
		army_info.text = "Žiadne armády."


func _on_army_selected(army_id: String) -> void:
	selected_army_id = army_id
	if army_manager == null or army_info == null:
		return
	var army = army_manager.get_army(army_id)
	if typeof(army) != TYPE_DICTIONARY:
		army_info.text = "Armáda nenájdená."
		return
	army_info.text = "Armáda: %s\nProvincia: %s\nVeľkosť: %s\nMorálka: %s\nZásoby: %s\nStatus: %s" % [
		str(army.get("id", "?")),
		str(army.get("province_id", "?")),
		str(army.get("size", army.get("strength", "?"))),
		str(army.get("morale", "?")),
		str(army.get("supply", "?")),
		str(army.get("status", "?")),
	]


func _on_move_button_pressed() -> void:
	if selected_army_id == "" or army_manager == null or map_manager == null:
		return
	var army = army_manager.get_army(selected_army_id)
	if typeof(army) != TYPE_DICTIONARY:
		return
	var current_province: String = str(army.get("province_id", ""))
	var province = map_manager.get_province(current_province)
	var neighbors: Array = []
	if typeof(province) == TYPE_DICTIONARY:
		neighbors = province.get("neighbors", [])
	var dialog := AcceptDialog.new()
	dialog.title = "Cieľová provincia"
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	for province_id in neighbors:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.text = str(province_id)
		button.pressed.connect(_on_target_province_selected.bind(selected_army_id, str(province_id)))
		vbox.add_child(button)
	add_child(dialog)
	dialog.popup_centered()


func _on_target_province_selected(army_id: String, target_province_id: String) -> void:
	if army_manager == null:
		return
	var result = army_manager.move_army(army_id, target_province_id)
	if typeof(result) == TYPE_DICTIONARY and result.get("ok", false):
		_update_army_list()
		_on_army_selected(army_id)


func _on_battle_button_pressed() -> void:
	if selected_army_id == "" or army_manager == null or army_info == null:
		return
	army_info.text = "Bitka: použi Skirmish/Devín tlačidlá alebo Campaign AI."


func _on_siege_button_pressed() -> void:
	if selected_army_id == "" or army_info == null:
		return
	army_info.text = "Obliehanie — CampaignManager (M6+)."
