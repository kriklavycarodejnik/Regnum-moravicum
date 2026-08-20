# ui/StatusBar.gd
extends HBoxContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const THREAT_FOOD_THRESHOLD := 100  # P1 kontrakt §4.2

const RESOURCE_ORDER := [
	{"key": "gold", "icon": "icon_gold_64", "label": "Zlato"},
	{"key": "food", "icon": "icon_food_64", "label": "Jedlo"},
	{"key": "wood", "icon": "icon_wood_64", "label": "Drevo"},
	{"key": "stone", "icon": "icon_stone_64", "label": "Kameň"},
	{"key": "iron", "icon": "icon_iron_64", "label": "Železo"},
	{"key": "prestige", "icon": "icon_prestige_64", "label": "Prestíž"},
]

var _year_label: Label
var _chip_labels: Dictionary = {}
var _built: bool = false
var _food_chip: PanelContainer  # referencia na food chip pre threat marker
var _food_warning: Label  # ⚠ indikátor na food chipe


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	add_theme_constant_override("separation", 8)
	_build()
	call_deferred("refresh")


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_chip_labels.clear()
	_food_chip = null
	_food_warning = null
	_year_label = Label.new()
	_year_label.name = "YearLabel"
	_year_label.text = "Rok 902 · mesiac 1"
	_year_label.add_theme_font_size_override("font_size", 18)
	add_child(_year_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	for spec in RESOURCE_ORDER:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0, 48)
		chip.add_theme_stylebox_override("panel", _ThemeFactory.resource_chip_style())
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(28, 28)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex: Texture2D = ArtCatalog.texture(str(spec["icon"]))
		if tex != null:
			tex_rect.texture = tex
		hbox.add_child(tex_rect)
		var lbl := Label.new()
		lbl.name = "Value_" + str(spec["key"])
		lbl.text = "0"
		lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(lbl)
		chip.add_child(hbox)
		_chip_labels[str(spec["key"])] = {"label": lbl, "title": str(spec["label"])}
		add_child(chip)
		# Uložiť referenciu na food chip pre threat marker
		if spec["key"] == "food":
			_food_chip = chip
			var warn_lbl := Label.new()
			warn_lbl.name = "FoodWarning"
			warn_lbl.text = " ⚠"
			warn_lbl.add_theme_font_size_override("font_size", 16)
			warn_lbl.add_theme_color_override("font_color", Color("C9902F"))
			warn_lbl.visible = false
			_food_warning = warn_lbl
			hbox.add_child(warn_lbl)
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
		lbl2.text = "%d" % val

	# Threat marker pre nízke jedlo (P1 kontrakt §4.2)
	# Zobrazí ⚠ na food chip a zmení farbu pozadia ak food < THREAT_FOOD_THRESHOLD
	var food_val: int = int(res.get("food", 0))
	if _food_warning != null:
		_food_warning.visible = food_val < THREAT_FOOD_THRESHOLD
		if food_val < THREAT_FOOD_THRESHOLD:
			_food_warning.tooltip_text = "Zásoby jedla: %d — hladomor" % food_val
		else:
			_food_warning.tooltip_text = ""