# ui/NotificationFeed.gd
# Krátke herné notifikácie (posledných N riadkov).
# Podporuje aj klikateľné notifikácie (push_action) pre armádny wizard.
extends PanelContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")
const MAX_LINES := 8

# Emitovaná keď hráč klikne na akčnú notifikáciu (push_action).
signal notification_clicked(action_id: String)

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
	_lines.push_front({"text": line, "action_id": ""})
	while _lines.size() > MAX_LINES:
		_lines.pop_back()
	_rebuild()


func push_action(text: String, action_id: String) -> void:
	"""Pridá klikateľnú notifikáciu. Kliknutie emituje notification_clicked(action_id)."""
	var line: String = text.strip_edges()
	if line == "" or action_id == "":
		return
	_lines.push_front({"text": line, "action_id": action_id})
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
		var entry: Dictionary = _lines[i] if typeof(_lines[i]) == TYPE_DICTIONARY else {"text": str(_lines[i]), "action_id": ""}
		var action_id: String = str(entry.get("action_id", ""))
		var line_text: String = str(entry.get("text", ""))
		if action_id != "":
			# Klikateľná notifikácia — Button namiesto Label
			var btn := Button.new()
			btn.flat = true
			btn.text = "→ " + line_text
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 12)
			btn.custom_minimum_size = Vector2(0, 32)
			btn.pressed.connect(_on_action_notification_pressed.bind(action_id))
			_list.add_child(btn)
		else:
			var lbl := Label.new()
			lbl.text = "• " + line_text
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 12)
			_list.add_child(lbl)


func _on_action_notification_pressed(action_id: String) -> void:
	notification_clicked.emit(action_id)
