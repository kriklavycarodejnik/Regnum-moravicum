# ui/ArmyUI.gd
extends Control

@onready var army_list = $ArmyList
@onready var army_info = $ArmyInfo
@onready var move_button = $MoveButton
@onready var battle_button = $BattleButton
@onready var siege_button = $SiegeButton

var army_manager: ArmyManager
var map_manager: MapManager
var selected_army_id: String = ""


func _ready() -> void:
	army_manager = get_node("/root/GameManager").army_manager
	map_manager = get_node("/root/GameManager").map_manager
	_update_army_list()
	
	# Pripojiť signály
	move_button.pressed.connect(_on_move_button_pressed)
	battle_button.pressed.connect(_on_battle_button_pressed)
	siege_button.pressed.connect(_on_siege_button_pressed)


func _update_army_list() -> void:
	army_list.clear()
	var armies = army_manager.list_armies()
	for army in armies:
		var button = Button.new()
		button.text = "%s (%s)" % [army.get("id", "?"), army.get("province_id", "?")]
		button.pressed.connect(_on_army_selected.bind(army.get("id")))
		army_list.add_child(button)


func _on_army_selected(army_id: String) -> void:
	selected_army_id = army_id
	var army = army_manager.get_army(army_id)
	army_info.text = """
		Armáda: %s
		Provincia: %s
		Veľkosť: %d
		Morálka: %.1f
		Zásoby: %.1f
		Status: %s
	""" % [
		army.get("id", "?"),
		army.get("province_id", "?"),
		army.get("size", 0),
		army.get("morale", 0.0),
		army.get("supply", 0.0),
		army.get("status", "?")
	]


func _on_move_button_pressed() -> void:
	if selected_army_id == "":
		return
	
	var army = army_manager.get_army(selected_army_id)
	var current_province = army.get("province_id", "")
	var neighbors = map_manager.get_province(current_province).get("neighbors", [])
	
	# Zobraziť dialóg pre výber cieľovej provincie
	var dialog = AcceptDialog.new()
	dialog.title = "Vyber cieľovú provinciu"
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	for province_id in neighbors:
		var button = Button.new()
		button.text = province_id
		button.pressed.connect(_on_target_province_selected.bind(selected_army_id, province_id))
		vbox.add_child(button)
	
	add_child(dialog)
	dialog.popup_centered()


func _on_target_province_selected(army_id: String, target_province_id: String) -> void:
	var result = army_manager.move_army(army_id, target_province_id)
	if result.get("ok", false):
		print("Armáda %s presunutá do %s" % [army_id, target_province_id])
		_update_army_list()
	else:
		print("Chyba: %s" % result.get("error", "neznáma chyba"))


func _on_battle_button_pressed() -> void:
	if selected_army_id == "":
		return
	
	var army = army_manager.get_army(selected_army_id)
	var province_id = army.get("province_id", "")
	var enemies = army_manager.list_armies("", province_id)
	
	# Odstrániť vlastnú armádu zo zoznamu
	enemies.erase(selected_army_id)
	
	if enemies.is_empty():
		print("Žiadne nepriateľské armády v provincii!")
		return
	
	# Zobraziť dialóg pre výber nepriateľskej armády
	var dialog = AcceptDialog.new()
	dialog.title = "Vyber nepriateľskú armádu"
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	for enemy in enemies:
		var button = Button.new()
		button.text = "%s (%s)" % [enemy.get("id", "?"), enemy.get("faction_id", "?")]
		button.pressed.connect(_on_enemy_army_selected.bind(selected_army_id, enemy.get("id")))
		vbox.add_child(button)
	
	add_child(dialog)
	dialog.popup_centered()


func _on_enemy_army_selected(army_id: String, enemy_army_id: String) -> void:
	var result = army_manager.start_battle(army_id, enemy_army_id)
	if result.get("ok", false):
		print("Bitka medzi %s a %s začatá!" % [army_id, enemy_army_id])
	else:
		print("Chyba: %s" % result.get("error", "neznáma chyba"))


func _on_siege_button_pressed() -> void:
	if selected_army_id == "":
		return
	
	var army = army_manager.get_army(selected_army_id)
	var province_id = army.get("province_id", "")
	var province = map_manager.get_province(province_id)
	
	if province.get("owner_faction", "") == army.get("faction_id", ""):
		print("Nemôžeš obliehať vlastnú provinciu!")
		return
	
	print("Obliehanie provincie %s začaté!" % province_id)
	# TODO: Implementovať logiku obliehania v CampaignManager.gd