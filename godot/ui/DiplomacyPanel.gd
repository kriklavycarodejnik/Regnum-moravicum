# ui/DiplomacyPanel.gd
extends VBoxContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")

signal action_done

var _list: VBoxContainer
var _info: Label
var _selected: String = ""
var _emblem: TextureRect
var gift_btn: Button
var threat_btn: Button
var nap_btn: Button
var trade_btn: Button
var pact_btn: Button

const FACTION_ART := {
	"moravia": "emblem_moravia",
	"hungary": "emblem_hungary",
	"franks": "emblem_franks",
	"frankia": "emblem_franks",
	"bavaria": "emblem_bavaria",
	"poland": "emblem_poland",
	"bohemia": "emblem_bohemia",
	"byzantium": "emblem_byzantium",
}


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	add_theme_constant_override("separation", 8)
	_build()
	call_deferred("refresh")


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var header := Label.new()
	header.text = "Diplomacia"
	header.theme_type_variation = &"SubtitleLabel"
	add_child(header)

	_emblem = TextureRect.new()
	_emblem.custom_minimum_size = Vector2(0, 120)
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_emblem.visible = false
	add_child(_emblem)

	_list = VBoxContainer.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text = "Vyber frakciu."
	add_child(_info)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	gift_btn = _mk_btn("Dar (−50 zlata)", _on_gift)
	threat_btn = _mk_btn("Hrozba", _on_threat)
	nap_btn = _mk_btn("Neútočná zmluva", _on_nap)
	trade_btn = _mk_btn("Obchod", _on_trade)
	pact_btn = _mk_btn("Vojenský pakt", _on_pact)
	for b in [gift_btn, threat_btn, nap_btn, trade_btn, pact_btn]:
		actions.add_child(b)
	add_child(actions)


func _mk_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 48)
	b.text = text
	b.pressed.connect(cb)
	return b


func refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.diplomacy_manager == null:
		_info.text = "Diplomacia nie je pripravená."
		return
	var factions: Array = gm.diplomacy_manager.list_factions()
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var fid: String = str(f.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(32, 32)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var art_id: String = str(FACTION_ART.get(fid, ""))
		if art_id != "":
			var thumb_tex: Texture2D = ArtCatalog.texture(art_id)
			if thumb_tex != null:
				thumb.texture = thumb_tex
		row.add_child(thumb)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		var mood: float = float(f.get("mood", 50))
		var stance: String = "nepriateľ" if mood < 35.0 else ("spojenec" if mood > 65.0 else "neutrál")
		b.text = "%s · %.0f (%s)" % [str(f.get("name", f.get("id", "?"))), mood, stance]
		b.pressed.connect(_on_select.bind(fid))
		row.add_child(b)
		_list.add_child(row)
	if _selected != "":
		_on_select(_selected)


func _on_select(faction_id: String) -> void:
	_selected = faction_id
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var f = gm.game_state.factions.get(faction_id, {})
	if typeof(f) != TYPE_DICTIONARY:
		_info.text = "Neznáma frakcia."
		if _emblem:
			_emblem.visible = false
		return
	var art_id: String = str(FACTION_ART.get(faction_id, ""))
	if art_id != "" and _emblem != null:
		var tex: Texture2D = ArtCatalog.texture(art_id)
		if tex != null:
			_emblem.texture = tex
			_emblem.visible = true
		else:
			_emblem.visible = false
	else:
		if _emblem:
			_emblem.visible = false
	var rel_raw = f.get("relations", {})
	var rel: Dictionary = rel_raw if typeof(rel_raw) == TYPE_DICTIONARY else {}
	_info.text = "%s\nNálada: %.0f\nNAP: %s · Obchod: %s · Pakt: %s" % [
		str(f.get("name", faction_id)),
		float(f.get("mood", 50)),
		"áno" if bool(rel.get("nap", false)) else "nie",
		"áno" if bool(rel.get("trade", false)) else "nie",
		"áno" if bool(rel.get("military_pact", false)) else "nie",
	]


func _run(result: Dictionary) -> void:
	if not result.get("ok", false):
		_info.text = "Chyba: %s" % str(result.get("error", "?"))
		return
	if result.has("chronicle"):
		action_done.emit()
	refresh()


func _on_gift() -> void:
	if _selected == "":
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_run(gm.diplomacy_manager.send_gift(_selected))


func _on_threat() -> void:
	if _selected == "":
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_run(gm.diplomacy_manager.threaten(_selected))


func _on_nap() -> void:
	_treaty("nap")


func _on_trade() -> void:
	_treaty("trade")


func _on_pact() -> void:
	_treaty("military_pact")


func _treaty(kind: String) -> void:
	if _selected == "":
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var f = gm.game_state.factions.get(_selected, {})
	var rel: Dictionary = {}
	if typeof(f) == TYPE_DICTIONARY:
		var rr = f.get("relations", {})
		if typeof(rr) == TYPE_DICTIONARY:
			rel = rr
	var cur: bool = bool(rel.get(kind, false))
	_run(gm.diplomacy_manager.set_treaty(_selected, kind, not cur))
