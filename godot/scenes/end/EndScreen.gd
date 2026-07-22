# scenes/end/EndScreen.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var body_label: Label = $Center/Panel/VBox/Body
@onready var art: TextureRect = $Center/Panel/VBox/Art
@onready var menu_btn: Button = $Center/Panel/VBox/MenuButton
@onready var restart_btn: Button = $Center/Panel/VBox/RestartButton


func _ready() -> void:
	theme = _ThemeFactory.build()
	$Background.color = _Colors.BG_DARKER
	menu_btn.pressed.connect(_on_menu)
	restart_btn.pressed.connect(_on_restart)
	_populate()


func _populate() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var ending: Dictionary = {}
	if gm and gm.game_state:
		ending = gm.game_state.ending if typeof(gm.game_state.ending) == TYPE_DICTIONARY else {}
	var won: bool = bool(ending.get("won", false))
	title_label.text = "Víťazstvo" if won else "Porážka"
	title_label.theme_type_variation = &"TitleLabel"
	body_label.text = str(ending.get("message", "Koniec hry."))
	var art_id := "moravian_court_interior" if won else "battle_danube_composition"
	var path := _art(art_id)
	if path != "" and ResourceLoader.exists(path):
		art.texture = load(path) as Texture2D


func _art(art_id: String) -> String:
	var map_path := "res://data/art_map.json"
	if not FileAccess.file_exists(map_path):
		return ""
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	return str(data.get(art_id, ""))


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")


func _on_restart() -> void:
	# re-bootstrap cez reload autoload scény: najjednoduchšie znova načítať main po reset tree
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_bootstrap"):
		gm._bootstrap()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
