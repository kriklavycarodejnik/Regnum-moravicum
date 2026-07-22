# ui/StatusBar.gd
extends HBoxContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const ICON_DIR := "res://assets/icons/ui/"
const RESOURCE_ORDER := [
	{"key": "gold", "icon": "icon_gold", "label": "Zlato"},
	{"key": "food", "icon": "icon_food", "label": "Jedlo"},
	{"key": "wood", "icon": "icon_wood", "label": "Drevo"},
	{"key": "stone", "icon": "icon_stone", "label": "Kameň"},
	{"key": "iron", "icon": "icon_iron", "label": "Železo"},
	{"key": "prestige", "icon": "icon_prestige", "label": "Prestíž"},
]

var _year_label: Label
var _chip_labels: Dictionary = {}
var _built: bool = false


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	add_theme_constant_override("separation", 10)
	_build()
	call_deferred("refresh")


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_chip_labels.clear()
	_year_label = Label.new()
	_year_label.name = "YearLabel"
	_year_label.text = "Rok 902 · mesiac 1"
	_year_label.add_theme_font_size_override("font_size", 18)
	add_child(_year_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	for spec in RESOURCE_ORDER:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.custom_minimum_size = Vector2(0, 48)
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = ICON_DIR + str(spec["icon"]) + "_64.png"
		if ResourceLoader.exists(icon_path):
			tex_rect.texture = load(icon_path) as Texture2D
		chip.add_child(tex_rect)
		var lbl := Label.new()
		lbl.name = "Value_" + str(spec["key"])
		lbl.text = "%s: 0" % str(spec["label"])
		lbl.add_theme_font_size_override("font_size", 14)
		chip.add_child(lbl)
		_chip_labels[str(spec["key"])] = {"label": lbl, "title": str(spec["label"])}
		add_child(chip)
	_built = true


func refresh() -> void:
	if not _built:
		_build()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return
	var s = gm.game_state
	if _year_label:
		_year_label.text = "Rok %d · mesiac %d" % [s.year, s.month]
	var res: Dictionary = s.resources if s.resources != null else {}
	for key in _chip_labels:
		var info: Dictionary = _chip_labels[key]
		var val: int = int(res.get(key, 0))
		var lbl2: Label = info["label"]
		lbl2.text = "%s: %d" % [str(info["title"]), val]
