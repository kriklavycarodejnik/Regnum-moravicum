# ui/ReligionAxis.gd
# M6 náboženská os Rím ↔ Konštantínopol (vizuál + dominant z ReligionManager).
extends HBoxContainer

const C = preload("res://assets/theme/colors.gd")

var _bar: ProgressBar
var _label: Label
var _icon_rome: TextureRect
var _icon_byz: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(180, 48)
	add_theme_constant_override("separation", 6)
	_build()
	call_deferred("refresh")


func _build() -> void:
	for c in get_children():
		c.queue_free()

	_icon_rome = _make_icon("icon_cross_latin_64")
	add_child(_icon_rome)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)

	_label = Label.new()
	_label.text = "Rím ↔ Konštantínopol"
	_label.add_theme_font_size_override("font_size", 11)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 50
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(120, 14)
	mid.add_child(_bar)
	add_child(mid)

	_icon_byz = _make_icon("icon_cross_patriarchal_64")
	add_child(_icon_byz)


func _make_icon(art_id: String) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(28, 28)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = ArtCatalog.texture(art_id)
	if tex != null:
		t.texture = tex
	return t


func refresh() -> void:
	if _bar == null:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return
	var score := _compute_axis(gm.game_state.provinces)
	_bar.value = score
	# 0 = silný Rím lean, 100 = Konštantínopol lean; stred 50
	if score < 40.0:
		_label.text = "Rím (%d)" % int(score)
		_label.add_theme_color_override("font_color", C.RELIGION_ROME)
	elif score > 60.0:
		_label.text = "Konštantínopol (%d)" % int(score)
		_label.add_theme_color_override("font_color", C.RELIGION_BYZ)
	else:
		_label.text = "Zmiešané (%d)" % int(score)
		_label.add_theme_color_override("font_color", C.PARCHMENT)


func _compute_axis(provinces: Dictionary) -> float:
	# Map province religion → 0..100 axis score (higher = more eastern/byzantine christian).
	if provinces.is_empty():
		return 50.0
	var total := 0.0
	var n := 0
	for pid in provinces:
		var p = provinces[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var rel = p.get("religion", 50)
		var v := 50.0
		if typeof(rel) == TYPE_INT or typeof(rel) == TYPE_FLOAT:
			v = clampf(float(rel), 0.0, 100.0)
		else:
			var s: String = str(rel).to_lower()
			match s:
				"pagan":
					v = 35.0
				"christian", "latin", "rome", "catholic":
					v = 25.0
				"orthodox", "byzantine", "greek":
					v = 80.0
				_:
					v = 50.0
		total += v
		n += 1
	if n == 0:
		return 50.0
	return total / float(n)
