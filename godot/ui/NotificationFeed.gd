# ui/NotificationFeed.gd
# Krátke herné notifikácie (posledných N riadkov).
extends PanelContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")
const MAX_LINES := 8

var _list: VBoxContainer
var _lines: Array = []


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	var panel_style := C.create_panel_style()
	add_theme_stylebox_override("panel", panel_style)
	custom_minimum_size = Vector2(0, 72)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	# Header with bell icon
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var bell := TextureRect.new()
	bell.custom_minimum_size = Vector2(18, 18)
	bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bell.texture = ArtCatalog.texture("icon_bell_64")
	if bell.texture == null:
		bell.texture = ArtCatalog.texture("icon_scroll_64")
	header.add_child(bell)
	var title := Label.new()
	title.text = "Notifikácie"
	title.theme_type_variation = &"MutedLabel"
	title.add_theme_font_size_override("font_size", 11)
	header.add_child(title)
	add_child(header)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	margin.add_child(_list)
	_rebuild()


func push(text: String) -> void:
	var line: String = text.strip_edges()
	if line == "":
		return
	_lines.push_front(line)
	while _lines.size() > MAX_LINES:
		_lines.pop_back()
	_rebuild()


func clear_feed() -> void:
	_lines.clear()
	_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	if _lines.is_empty():
		var empty := Label.new()
		empty.text = "Žiadne nové správy."
		empty.theme_type_variation = &"MutedLabel"
		empty.add_theme_font_size_override("font_size", 12)
		_list.add_child(empty)
		return
	for i in range(_lines.size()):
		var lbl := Label.new()
		lbl.text = "• " + str(_lines[i])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		_list.add_child(lbl)
