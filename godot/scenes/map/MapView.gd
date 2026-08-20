# scenes/map/MapView.gd
# Mapa žúp s ilustračným pozadím + art markermi pre kľúčové lokality.
extends Control

signal province_selected(province_id: String)

const C = preload("res://assets/theme/colors.gd")
const LAYOUT_PATH := "res://data/map_layout.json"

# Prahy pre threat markery (P1 kontrakt §4.2)
const THREAT_LOYALTY_THRESHOLD := 30.0
const THREAT_MOOD_THRESHOLD := 25.0
const THREAT_FOOD_THRESHOLD := 100

var _layout: Dictionary = {}
var _selected_id: String = ""
var _hover_id: String = ""
var _tooltip_container: PanelContainer
var _tooltip_label: Label
var _mood_hover_faction: String = ""  # faction s náladovým markerom pod kurzorom
var _bg_tex: Texture2D
var _marker_tex: Dictionary = {}  # pid -> Texture2D
var _settlement_small: Texture2D
var _settlement_medium: Texture2D
var _settlement_large: Texture2D
var _fort_tex: Texture2D
var _army_dot: Texture2D

# Frakcie, ktoré majú mood marker na okraji mapy
# Formát: kľúč = faction_id, hodnota = {x, y} (relatívne 0..1 na view_size)
const _FACTION_MARKER_POSITIONS: Dictionary = {
	"franks": {"x": 0.02, "y": 0.45},
	"bavaria": {"x": 0.04, "y": 0.80},
	"poland": {"x": 0.30, "y": 0.04},
	"bohemia": {"x": 0.12, "y": 0.04},
	"byzantium": {"x": 0.88, "y": 0.82},
}
# Frakcie bez mood markeru (moravia a hungary)
const _THREAT_IGNORE_FACTIONS: Dictionary = {
	"moravia": true,
	"hungary": true,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(480, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_layout()
	_load_art()
	# Tooltip as a styled panel with opaque background, not bare text.
	_tooltip_container = PanelContainer.new()
	_tooltip_container.visible = false
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.add_theme_stylebox_override("panel", _tooltip_style())
	_tooltip_container.custom_minimum_size = Vector2(120, 0)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", C.PARCHMENT)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_container.add_child(_tooltip_label)
	add_child(_tooltip_container)
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
	_bg_tex = cat.texture("moravian_court_interior")
	if _bg_tex == null:
		_bg_tex = cat.texture("regnum_visual_style_master")
	# Load settlement markers
	_settlement_small = cat.texture("marker_settlement_small")
	_settlement_medium = cat.texture("marker_settlement_medium")
	_settlement_large = cat.texture("marker_settlement_large")
	_fort_tex = cat.texture("marker_fort")
	_army_dot = cat.texture("marker_army_dot")
	for pid in ["nitra", "devin", "bratislava", "morava"]:
		var aid: String = cat.province_art_id(pid) if cat.has_method("province_art_id") else ""
		if aid == "":
			continue
		var t: Texture2D = cat.texture(aid)
		if t != null:
			_marker_tex[pid] = t


func refresh() -> void:
	# Ak marker nálady, na ktorom visel kurzor, po zmene stavu prestal byť
	# aktívny (mood >= prah), vyčisti hover a schovaj tooltip.
	if _mood_hover_faction != "" and not _mood_faction_active(_mood_hover_faction):
		_mood_hover_faction = ""
		_show_mood_tooltip("", Vector2.ZERO)
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


# Tooltip style — opaque panel so text never bleeds into map.
static func _tooltip_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.10, 0.06, 0.96)
	s.border_color = Color(C.BYZANTINE_GOLD.r, C.BYZANTINE_GOLD.g, C.BYZANTINE_GOLD.b, 0.50)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


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
			var d := r * 2.0
			var dest := Rect2(cx - r, cy - r, d, d)
			draw_colored_polygon(_province_polygon(pid, cx, cy, r), C.OAK_DARK)
			draw_texture_rect(tex, dest, false, Color(1, 1, 1, 0.92))
			var rim := _faction_color(owner)
			rim.a = 0.9
			draw_arc(center, r + 2.0, 0.0, TAU, 48, rim, 4.0, true)
		else:
			# Use settlement marker based on prosperity
			var marker_tex: Texture2D = _settlement_medium
			var prosperity: float = float(pdata.get("prosperity", 50))
			if prosperity >= 70:
				marker_tex = _settlement_large if _settlement_large != null else _settlement_medium
			elif prosperity < 30:
				marker_tex = _settlement_small if _settlement_small != null else _settlement_medium
			var fill := _faction_color(owner)
			fill = fill.lightened(0.08)
			fill.a = 0.92
			draw_colored_polygon(_province_polygon(pid, cx, cy, r), fill)
			var hi := C.PARCHMENT
			hi.a = 0.12
			draw_circle(center + Vector2(-r * 0.25, -r * 0.25), r * 0.45, hi)
			# Draw settlement icon
			if marker_tex != null:
				var ms: float = r * 0.8
				draw_texture_rect(marker_tex, Rect2(cx - ms, cy - ms, ms * 2, ms * 2), false)

		# Fort indicator for occupied provinces
		if pdata.has("occupier_faction") and _fort_tex != null:
			var fs: float = r * 0.6
			draw_texture_rect(_fort_tex, Rect2(cx + r * 0.3, cy - r * 0.7, fs, fs), false)

		# Army dot if armies present in province
		if _army_dot != null:
			var armies: Dictionary = GameManager.game_state.armies if GameManager else {}
			for aid in armies:
				var a = armies[aid]
				if typeof(a) == TYPE_DICTIONARY and str(a.get("province_id", "")) == pid:
					var ads: float = r * 0.5
					draw_texture_rect(_army_dot, Rect2(cx - r * 0.4, cy + r * 0.1, ads, ads), false)
					break

		draw_arc(center, r + 5.0, 0.0, TAU, 40, _loyalty_ring(loyalty), 2.5, true)

		# Threat marker pre nízku lojalitu (P1 kontrakt §4.2)
		# Farba: moravia-crimson #8B1E2D pre low loyalty (nie warning)
		if loyalty < THREAT_LOYALTY_THRESHOLD:
			draw_arc(center, r + 9.0, 0.0, TAU, 60, C.MORAVIA_CRIMSON, 3.0, true)

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

	# --- Threat markery nálady frakcií (P1 kontrakt §4.2) ---
	_draw_faction_mood_markers(w, h, font)

	# Hint strip
	var hint := "Klikni na župu · zlatý kruh = výber · farba okraja = lojalita"
	var hfs := 11
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs)
	draw_rect(Rect2(8, h - 26, hs.x + 16, 20), Color(0.08, 0.06, 0.04, 0.72), true)
	draw_string(font, Vector2(16, h - 12), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, C.TEXT_MUTED)


func _draw_faction_mood_markers(w: float, h: float, font: Font) -> void:
	# Získať faction dáta
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return
	var factions: Dictionary = gm.game_state.factions
	if typeof(factions) != TYPE_DICTIONARY:
		return

	var marker_r: float = 6.0
	for fid in _FACTION_MARKER_POSITIONS:
		# Preskočiť moravia a hungary — nemajú mood marker
		if _THREAT_IGNORE_FACTIONS.has(fid):
			continue
		var pos: Dictionary = _FACTION_MARKER_POSITIONS[fid]
		var center := Vector2(pos["x"] * w, pos["y"] * h)

		# Získať mood hodnotu
		var f_data = factions.get(fid, {})
		if typeof(f_data) != TYPE_DICTIONARY:
			continue
		var mood: float = float(f_data.get("mood", 50.0))

		# Kresliť len ak mood < prah
		if mood >= THREAT_MOOD_THRESHOLD:
			continue

		# Warning ikona na okraji mapy (warning #C9902F)
		draw_circle(center, marker_r, C.WARNING)
		draw_circle(center, marker_r - 1.5, C.OAK_DARK)
		# Warning triangle-like mark
		draw_circle(center, marker_r * 0.5, C.WARNING)

		# Hover zvýraznenie — signalizuje, že marker má tooltip
		if fid == _mood_hover_faction:
			draw_arc(center, marker_r + 3.0, 0.0, TAU, 32, C.PARCHMENT, 1.5, true)

		# Label: názov frakcie
		var fname: String = str(f_data.get("name", fid))
		var mood_fs := 9
		var text_size := font.get_string_size(fname, HORIZONTAL_ALIGNMENT_LEFT, -1, mood_fs)
		var tp := Vector2(center.x - text_size.x * 0.5, center.y - marker_r - 4)
		draw_string(font, tp + Vector2(1, 1), fname, HORIZONTAL_ALIGNMENT_LEFT, -1, mood_fs, Color(0, 0, 0, 0.75))
		draw_string(font, tp, fname, HORIZONTAL_ALIGNMENT_LEFT, -1, mood_fs, C.WARNING)


# Vráti faction id náladového markeru pod kurzorom, alebo "" ak žiadny.
func _mood_marker_hit(pos: Vector2, w: float, h: float) -> String:
	var hit_r: float = 10.0
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return ""
	var factions: Dictionary = gm.game_state.factions
	if typeof(factions) != TYPE_DICTIONARY:
		return ""
	for fid in _FACTION_MARKER_POSITIONS:
		if _THREAT_IGNORE_FACTIONS.has(fid):
			continue
		var np: Dictionary = _FACTION_MARKER_POSITIONS[fid]
		var center := Vector2(np["x"] * w, np["y"] * h)
		var f_data = factions.get(fid, {})
		if typeof(f_data) != TYPE_DICTIONARY:
			continue
		var mood: float = float(f_data.get("mood", 50.0))
		if mood >= THREAT_MOOD_THRESHOLD:
			continue
		if pos.distance_to(center) <= hit_r:
			return fid
	return ""


# Vráti true ak daná frakcia má aktuálne aktívny mood marker (mood < prah).
func _mood_faction_active(faction: String) -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return false
	var factions: Dictionary = gm.game_state.factions
	if typeof(factions) != TYPE_DICTIONARY:
		return false
	var f_data = factions.get(faction, {})
	if typeof(f_data) != TYPE_DICTIONARY:
		return false
	var mood: float = float(f_data.get("mood", 50.0))
	if _THREAT_IGNORE_FACTIONS.has(faction):
		return false
	return mood < THREAT_MOOD_THRESHOLD


# Zobrazí tooltip pre mood marker nálady frakcie (P1 kontrakt §4.2).
func _show_mood_tooltip(faction: String, mouse_pos: Vector2) -> void:
	if _tooltip_container == null or _tooltip_label == null:
		return
	if faction == "":
		_tooltip_container.visible = false
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		_tooltip_container.visible = false
		return
	var factions: Dictionary = gm.game_state.factions
	var f_data = factions.get(faction, {}) if typeof(factions) == TYPE_DICTIONARY else {}
	if typeof(f_data) != TYPE_DICTIONARY:
		_tooltip_container.visible = false
		return
	var name_sk: String = str(f_data.get("name", faction))
	var mood: float = float(f_data.get("mood", 50.0))
	# P1 kontrakt §4.2 tooltip pre náladu frakcie
	_tooltip_label.text = "%s: nálada %.0f — hrozba konfliktu" % [name_sk, mood]
	_tooltip_container.visible = true
	_tooltip_container.position = mouse_pos + Vector2(14, 14)
	var br := _tooltip_container.get_minimum_size()
	if _tooltip_container.position.x + br.x > size.x:
		_tooltip_container.position.x = size.x - br.x - 4
	if _tooltip_container.position.y + br.y > size.y:
		_tooltip_container.position.y = size.y - br.y - 4


func _province_polygon(pid: String, cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 10
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pid)
	for i in range(n):
		var angle: float = (float(i) / float(n)) * TAU
		var jitter: float = 1.0 + rng.randf_range(-0.18, 0.18)
		var rr: float = r * 1.35 * jitter
		pts.append(Vector2(cx + cos(angle) * rr, cy + sin(angle) * rr))
	return pts


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		var w := size.x
		var h := size.y
		# Mood marker hover má prednosť pred výberom župy
		var mf := _mood_marker_hit(pos, w, h)
		if mf != _mood_hover_faction:
			_mood_hover_faction = mf
			queue_redraw()
		if mf != "":
			# Žiadna zmena hover župy — kurzor je na threat markeri nálady
			if _hover_id != "":
				_hover_id = ""
			_show_mood_tooltip(mf, pos)
			return
		var id := _hit_test(pos)
		if id != _hover_id:
			_hover_id = id
			_update_tooltip(pos)
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
	if _tooltip_container == null or _tooltip_label == null:
		return
	var id := _hover_id if _hover_id != "" else _selected_id
	if id == "":
		_tooltip_container.visible = false
		return
	var provs := _provinces()
	var p: Dictionary = {}
	var raw = provs.get(id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		p = raw
\tvar tooltip_text: String = "%s\nVlastník: %s\nLojalita: %s · Prosperita: %s\nNáboženstvo: %s" % [
		str(p.get("name", id)),
		str(p.get("owner_faction", "?")),
		str(p.get("loyalty", "?")),
		str(p.get("prosperity", "?")),
		str(p.get("religion", "?")),
	]
	# Pridať threat marker tooltip pre kriticky nízku lojalitu
	var loyalty: float = float(p.get("loyalty", 50))
	if loyalty < THREAT_LOYALTY_THRESHOLD:
		tooltip_text += "\n\n⚠ Lojalita %s: %.0f — hrozba vzbury" % [str(p.get("name", id)), loyalty]
	_tooltip_label.text = tooltip_text
	_tooltip_container.visible = true
	_tooltip_container.position = mouse_pos + Vector2(14, 14)
	var br := _tooltip_container.get_minimum_size()
	if _tooltip_container.position.x + br.x > size.x:
		_tooltip_container.position.x = size.x - br.x - 4
	if _tooltip_container.position.y + br.y > size.y:
		_tooltip_container.position.y = size.y - br.y - 4
