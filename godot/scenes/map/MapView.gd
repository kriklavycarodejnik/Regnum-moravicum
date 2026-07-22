# scenes/map/MapView.gd
# M6 mapa žúp — Control-based (nie tilemap). Klik = výber + tooltip.
extends Control

signal province_selected(province_id: String)

const C = preload("res://assets/theme/colors.gd")
const LAYOUT_PATH := "res://data/map_layout.json"

var _layout: Dictionary = {}
var _selected_id: String = ""
var _hover_id: String = ""
var _tooltip: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(400, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_layout()
	_tooltip = Label.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_font_size_override("font_size", 13)
	_tooltip.add_theme_color_override("font_color", C.PARCHMENT)
	add_child(_tooltip)
	queue_redraw()


func _load_layout() -> void:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_layout = data


func refresh() -> void:
	queue_redraw()


func get_selected_id() -> String:
	return _selected_id


func _provinces() -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return {}
	return gm.game_state.provinces


func _faction_color(faction: String) -> Color:
	match faction:
		"moravia":
			return C.MORAVIA_CRIMSON
		"hungary", "magyar", "magyars":
			return C.MAGYAR_STEPPE
		"franks", "frankia":
			return C.ROYAL_BLUE
		"bavaria":
			return Color("6B5A3A")
		"poland":
			return Color("8B3A4A")
		"bohemia":
			return Color("3A5A6B")
		_:
			return C.STONE_WALL


func _loyalty_ring(loyalty: float) -> Color:
	if loyalty >= 70.0:
		return C.SUCCESS
	if loyalty >= 40.0:
		return C.WARNING
	return C.MORAVIA_CRIMSON


func _draw() -> void:
	var rect := get_rect()
	var w := size.x
	var h := size.y
	# background terrain wash
	draw_rect(Rect2(Vector2.ZERO, size), C.FOREST_CANOPY.darkened(0.35), true)
	# soft meadow blob
	draw_circle(Vector2(w * 0.45, h * 0.55), min(w, h) * 0.35, C.MEADOW.darkened(0.25))
	# danube-ish band
	var river := PackedVector2Array([
		Vector2(0.0, h * 0.72),
		Vector2(w * 0.35, h * 0.68),
		Vector2(w * 0.55, h * 0.75),
		Vector2(w, h * 0.70),
		Vector2(w, h * 0.78),
		Vector2(w * 0.55, h * 0.82),
		Vector2(w * 0.35, h * 0.76),
		Vector2(0.0, h * 0.80),
	])
	draw_colored_polygon(river, C.DANUBE.darkened(0.15))

	var provs := _provinces()
	var layout_p: Dictionary = _layout.get("provinces", {})
	for pid in layout_p:
		var node: Dictionary = layout_p[pid]
		var cx: float = float(node.get("x", 0.5)) * w
		var cy: float = float(node.get("y", 0.5)) * h
		var r: float = float(node.get("r", 30))
		var pdata: Dictionary = provs.get(pid, {}) if typeof(provs.get(pid, {})) == TYPE_DICTIONARY else {}
		var owner: String = str(pdata.get("owner_faction", "moravia"))
		var loyalty: float = float(pdata.get("loyalty", 50))
		var fill := _faction_color(owner)
		fill.a = 0.85
		draw_circle(Vector2(cx, cy), r, fill)
		draw_arc(Vector2(cx, cy), r + 3.0, 0.0, TAU, 32, _loyalty_ring(loyalty), 3.0, true)
		if pid == _selected_id:
			draw_arc(Vector2(cx, cy), r + 8.0, 0.0, TAU, 40, C.BYZANTINE_GOLD, 2.5, true)
		if pid == _hover_id and pid != _selected_id:
			draw_arc(Vector2(cx, cy), r + 6.0, 0.0, TAU, 36, C.PARCHMENT, 1.5, true)
		# label
		var name_sk: String = str(pdata.get("name", pid))
		var font := ThemeDB.fallback_font
		var fs := 12
		var text_size := font.get_string_size(name_sk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(cx - text_size.x * 0.5, cy + 4), name_sk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C.PARCHMENT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := _hit_test(event.position)
		if id != _hover_id:
			_hover_id = id
			_update_tooltip(event.position)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id2 := _hit_test(event.position)
		if id2 != "":
			_selected_id = id2
			province_selected.emit(id2)
			_update_tooltip(event.position)
			queue_redraw()


func _hit_test(pos: Vector2) -> String:
	var w := size.x
	var h := size.y
	var layout_p: Dictionary = _layout.get("provinces", {})
	var best := ""
	var best_d := INF
	for pid in layout_p:
		var node: Dictionary = layout_p[pid]
		var cx: float = float(node.get("x", 0.5)) * w
		var cy: float = float(node.get("y", 0.5)) * h
		var r: float = float(node.get("r", 30))
		var d := pos.distance_to(Vector2(cx, cy))
		if d <= r + 4.0 and d < best_d:
			best_d = d
			best = pid
	return best


func _update_tooltip(mouse_pos: Vector2) -> void:
	if _tooltip == null:
		return
	var id := _hover_id if _hover_id != "" else _selected_id
	if id == "":
		_tooltip.visible = false
		return
	var provs := _provinces()
	var p: Dictionary = provs.get(id, {}) if typeof(provs.get(id, {})) == TYPE_DICTIONARY else {}
	var rel = p.get("religion", "?")
	_tooltip.text = "%s\nVlastník: %s\nLojalita: %s · Prosperita: %s\nNáboženstvo: %s" % [
		str(p.get("name", id)),
		str(p.get("owner_faction", "?")),
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?")),
		str(rel),
	]
	_tooltip.visible = true
	_tooltip.position = mouse_pos + Vector2(14, 14)
	# keep on screen
	var br := _tooltip.get_minimum_size()
	if _tooltip.position.x + br.x > size.x:
		_tooltip.position.x = size.x - br.x - 4
	if _tooltip.position.y + br.y > size.y:
		_tooltip.position.y = size.y - br.y - 4
