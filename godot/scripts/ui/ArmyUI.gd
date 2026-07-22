extends Control

# Autoloads
const GameManager = preload("res://scripts/GameManager.gd")

# Managers
var army_manager: ArmyManager
var map_manager: MapManager

# UI Nodes
@onready var army_list: VBoxContainer = $ArmyList
@onready var army_info_label: Label = $ArmyInfoPanel/ArmyInfoLabel
@onready var move_button: Button = $ActionButtons/MoveButton
@onready var battle_button: Button = $ActionButtons/BattleButton
@onready var siege_button: Button = $ActionButtons/SiegeButton

# Selected army
var selected_army_id: String = ""

func _ready() -> void:
    # Get managers from GameManager
    army_manager = GameManager.army_manager
    map_manager = GameManager.map_manager
    
    # Connect buttons
    move_button.pressed.connect(_on_move_pressed)
    battle_button.pressed.connect(_on_battle_pressed)
    siege_button.pressed.connect(_on_siege_pressed)
    
    # Update UI
    _update_army_list()

func _update_army_list() -> void:
    # Clear existing list
    for child in army_list.get_children():
        child.queue_free()
    
    # Get armies from ArmyManager
    var armies = army_manager.list_armies()
    
    # Create a button for each army
    for army_id in armies:
        var army = armies[army_id]
        var button = Button.new()
        button.text = "Army %s (%d units)" % [army_id, army.size]
        button.pressed.connect(_callable_mp(this, "_on_army_selected").bind(army_id))
        army_list.add_child(button)

func _update_army_info(army_id: String) -> void:
    if army_id == "":
        army_info_label.text = "Army Info:\nSize: 0\nMorale: 0\nSupplies: 0"
        return
    
    var armies = army_manager.list_armies()
    if not armies.has(army_id):
        return
    
    var army = armies[army_id]
    army_info_label.text = "Army Info:\nSize: %d\nMorale: %d\nSupplies: %d" % [army.size, army.morale, army.supplies]

func _on_army_selected(army_id: String) -> void:
    selected_army_id = army_id
    _update_army_info(army_id)

func _on_move_pressed() -> void:
    if selected_army_id == "":
        return
    
    # TODO: Implement movement logic
    print("Move army: %s" % selected_army_id)

func _on_battle_pressed() -> void:
    if selected_army_id == "":
        return
    
    # TODO: Implement battle logic
    print("Battle with army: %s" % selected_army_id)

func _on_siege_pressed() -> void:
    if selected_army_id == "":
        return
    
    # TODO: Implement siege logic
    print("Siege with army: %s" % selected_army_id)