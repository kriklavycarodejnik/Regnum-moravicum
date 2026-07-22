# scenes/map/MapView.gd
# Mapa žúp s ilustračným pozadím + art markermi pre kľúčové lokality.
extends Control

signal province_selected(province_id: String)

const C = preload("res://assets/theme/colors.gd")
const LAYOUT_PATH := "res://data/map_layout.json"

var _layout: Dictionary = {}
var _selected_id: String = ""
var _hover_id: String = ""
var _tooltip: Label
var _bg_tex: Texture2D
var _marker_tex: Dictionary = {}  # pid -> Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(480, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_layout()
	_load_art()
	_tooltip = Label.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_font_size_override("font_size", 13)
	_tooltip.add_theme_color_override("font_color", C.PARCHMENT)
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
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


func _load_art() -> void:
	var cat = get_node_or_null("/root/ArtCatalog")
	if cat == null:
		return
	# Prefer landscape plate as map backdrop (court / style master).
	_bg_tex = cat.texture("moravian_court_interior")
	if _bg_tex == null:
		_bg_tex = cat.texture("regnum_visual_style_master")
	for pid in ["nitra", "devin", "bratislava", "morava"]:
		var aid: String = cat.province_art_id(pid) if cat.has_method("province_art_id") else ""
		if aid == "":
			continue
		var t: Texture2D = cat.texture(aid)
		if t != null:
			_marker_tex[pid] = t


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
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	# --- Illustrated parchment map frame ---
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, C.OAK_DARK, true)
	var inner := Rect2(4, 4, w - 8, h - 8)
	draw_rect(inner, C.OAK_MID, false, 2.0)

	# Art backdrop (dimmed chronicle plate)
	if _bg_tex != null:
		var tex_size := _bg_tex.get_size()
		var scale: float = maxf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
		var dw := tex_size.x * scale
		var dh := tex_size.y * scale
		var dx := inner.position.x + (inner.size.x - dw) * 0.5
		var dy := inner.position.y + (inner.size.y - dh) * 0.5
		draw_texture_rect(_bg_tex, Rect2(dx, dy, dw, dh), false, Color(1, 1, 1, 0.42))
		# dark vignette so markers pop
		draw_rect(inner, Color(0.04, 0.03, 0.02, 0.38), true)
	else:
		draw_rect(inner, C.FOREST_CANOPY.darkened(0.35), true)
		draw_circle(Vector2(w * 0.45, h * 0.55), minf(w, h) * 0.35, C.MEADOW.darkened(0.25))

	# Danube band (always, slight transparency over art)
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
	var river_col := C.DANUBE
	river_col.a = 0.55
	draw_colored_polygon(river, river_col)

	var provs := _provinces()
	var layout_p: Dictionary = _layout.get("provinces", {})
	var font := ThemeDB.fallback_font
	if font == null:
		return

	# Neighbor lines (soft)
	for pid in layout_p:
		var node: Dictionary = layout_p[pid]
		var cx0: float = float(node.get("x", 0.5)) * w
		var cy0: float = float(node.get("y", 0.5)) * h
		var pdata0: Dictionary = {}
		var raw0 = provs.get(pid, {})
		if typeof(raw0) == TYPE_DICTIONARY:
			pdata0 = raw0
		var nbs = pdata0.get("neighbors", [])
		if typeof(nbs) != TYPE_ARRAY:
			continue
		for nb in nbs:
			var nid: String = str(nb)
			if not layout_p.has(nid):
				continue
			if str(pid) > nid:
				continue  # draw once
			var nnode: Dictionary = layout_p[nid]
			var cx1: float = float(nnode.get("x", 0.5)) * w
			var cy1: float = float(nnode.get("y", 0.5)) * h
			draw_line(Vector2(cx0, cy0), Vector2(cx1, cy1), Color(C.BYZANTINE_GOLD.r, C.BYZANTINE_GOLD.g, C.BYZANTINE_GOLD.b, 0.22), 1.5, true)

	for pid in layout_p:
		var node2: Dictionary = layout_p[pid]
		var cx: float = float(node2.get("x", 0.5)) * w
		var cy: float = float(node2.get("y", 0.5)) * h
		var r: float = float(node2.get("r", 30))
		var pdata: Dictionary = {}
		var raw = provs.get(pid, {})
		if typeof(raw) == TYPE_DICTIONARY:
			pdata = raw
		var owner: String = str(pdata.get("owner_faction", "moravia"))
		var loyalty: float = float(pdata.get("loyalty", 50))
		var center := Vector2(cx, cy)

		# Soft shadow
		draw_circle(center + Vector2(2, 3), r + 2.0, Color(0, 0, 0, 0.35))

		var has_art: bool = _marker_tex.has(pid)
		if has_art:
			var tex: Texture2D = _marker_tex[pid]
			# circular-ish art disc via clipped texture rect + ring
			var d := r * 2.0
			var dest := Rect2(cx - r, cy - r, d, d)
			# dark plate under art
			draw_circle(center, r + 1.0, C.OAK_DARK)
			draw_texture_rect(tex, dest, false, Color(1, 1, 1, 0.92))
			# faction tint rim
			var rim := _faction_color(owner)
			rim.a = 0.9
			draw_arc(center, r + 2.0, 0.0, TAU, 48, rim, 4.0, true)
		else:
			var fill := _faction_color(owner)
			fill = fill.lightened(0.08)
			fill.a = 0.92
			draw_circle(center, r, fill)
			# inner parchment highlight
			var hi := C.PARCHMENT
			hi.a = 0.12
			draw_circle(center + Vector2(-r * 0.25, -r * 0.25), r * 0.45, hi)

		draw_arc(center, r + 5.0, 0.0, TAU, 40, _loyalty_ring(loyalty), 2.5, true)

		if pid == _selected_id:
			draw_arc(center, r + 10.0, 0.0, TAU, 48, C.BYZANTINE_GOLD, 3.0, true)
		elif pid == _hover_id:
			draw_arc(center, r + 8.0, 0.0, TAU, 40, C.PARCHMENT, 2.0, true)

		# Label with shadow
		var name_sk: String = str(pdata.get("name", pid))
		var fs := 13 if r >= 32.0 else 11
		var text_size := font.get_string_size(name_sk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tp := Vector2(cx - text_size.x * 0.5, cy + r + 16)
		draw_string(font, tp + Vector2(1, 1), name_sk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
		draw_string(font, tp, name_sk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C.PARCHMENT)

	# Hint strip
	var hint := "Klikni na župu · zlatý kruh = výber · farba okraja = lojalita"
	var hfs := 11
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs)
	draw_rect(Rect2(8, h - 26, hs.x + 16, 20), Color(0.08, 0.06, 0.04, 0.72), true)
	draw_string(font, Vector2(16, h - 12), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, C.TEXT_MUTED)


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
		if d <= r + 6.0 and d < best_d:
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
	var p: Dictionary = {}
	var raw = provs.get(id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		p = raw
	_tooltip.text = "%s\nVlastník: %s\nLojalita: %s · Prosperita: %s\nNáboženstvo: %s" % [
		str(p.get("name", id)),
		str(p.get("owner_faction", "?")),
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?")),
		str(p.get("religion", "?")),
	]
	_tooltip.visible = true
	_tooltip.position = mouse_pos + Vector2(14, 14)
	var br := _tooltip.get_minimum_size()
	if _tooltip.position.x + br.x > size.x:
		_tooltip.position.x = size.x - br.x - 4
	if _tooltip.position.y + br.y > size.y:
		_tooltip.position.y = size.y - br.y - 4
