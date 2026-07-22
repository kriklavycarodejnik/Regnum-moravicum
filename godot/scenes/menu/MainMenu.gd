# scenes/menu/MainMenu.gd
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var new_btn: Button = $Center/Panel/VBox/NewButton
@onready var load_btn: Button = $Center/Panel/VBox/LoadButton
@onready var quit_btn: Button = $Center/Panel/VBox/QuitButton
@onready var status_label: Label = $Center/Panel/VBox/StatusLabel
@onready var emblem: TextureRect = $Center/Panel/VBox/Emblem
@onready var bg_art: TextureRect = $BackgroundArt


func _ready() -> void:
	theme = _ThemeFactory.build()
	$Background.color = _Colors.BG_DARKER

	# Emblem
	var emblem_tex := ArtCatalog.texture("mojmir_dynasty_emblem")
	if emblem_tex != null:
		emblem.texture = emblem_tex

	# Background art (dimmed court interior)
	if bg_art:
		var bg_tex := ArtCatalog.texture("moravian_court_interior")
		if bg_tex != null:
			bg_art.texture = bg_tex
			bg_art.modulate = Color(1, 1, 1, 0.35)
		else:
			bg_art.visible = false

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
			status_label.text = "Načítanie zlyhalo."
	else:
		status_label.text = "Load API nie je pripravené."


func _on_quit() -> void:
	get_tree().quit()
