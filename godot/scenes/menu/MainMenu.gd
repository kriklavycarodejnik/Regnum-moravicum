# scenes/menu/MainMenu.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var new_btn: Button = $Center/Panel/VBox/NewButton
@onready var load_btn: Button = $Center/Panel/VBox/LoadButton
@onready var quit_btn: Button = $Center/Panel/VBox/QuitButton
@onready var status_label: Label = $Center/Panel/VBox/StatusLabel
@onready var emblem: TextureRect = $Center/Panel/VBox/Emblem


func _ready() -> void:
	theme = _ThemeFactory.build()
	$Background.color = _Colors.BG_DARKER
	var emblem_path := "res://assets/icons/factions/mojmir_dynasty_emblem_v1.png"
	if ResourceLoader.exists(emblem_path):
		emblem.texture = load(emblem_path) as Texture2D
	new_btn.pressed.connect(_on_new)
	load_btn.pressed.connect(_on_load)
	quit_btn.pressed.connect(_on_quit)
	status_label.text = "Veľká Morava · 902–1000"


func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_load() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("load_save"):
		var ok: bool = gm.load_save()
		if ok:
			get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
		else:
			status_label.text = "Načítanie zlyhalo — žiadny save alebo chyba."
	else:
		status_label.text = "Load API nie je pripravené."


func _on_quit() -> void:
	get_tree().quit()
