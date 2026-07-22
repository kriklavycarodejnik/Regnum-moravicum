# ui/DiplomacyPanel.gd
extends VBoxContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")

signal action_done(chronicle_line: String)

var _list: VBoxContainer
var _info: Label
var _selected: String = ""
var gift_btn: Button
var threat_btn: Button
var nap_btn: Button
var trade_btn: Button
var pact_btn: Button


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	_build()
	call_deferred("refresh")


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var header := Label.new()
	header.text = "Diplomacia"
	header.theme_type_variation = &"SubtitleLabel"
	add_child(header)

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
	b.custom_minimum_size = Vector2(0, 44)
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
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		var mood: float = float(f.get("mood", 50))
		var stance := "nepriateľ" if mood < 35.0 else ("spojenec" if mood > 65.0 else "neutrál")
		b.text = "%s · %.0f (%s)" % [str(f.get("name", f.get("id", "?"))), mood, stance]
		var fid: String = str(f.get("id", ""))
		b.pressed.connect(_on_select.bind(fid))
		_list.add_child(b)
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
		return
	var rel: Dictionary = f.get("relations", {}) if typeof(f.get("relations", {})) == TYPE_DICTIONARY else {}
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
		action_done.emit(str(result["chronicle"]))
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
	if typeof(f) == TYPE_DICTIONARY and typeof(f.get("relations", {})) == TYPE_DICTIONARY:
		rel = f.get("relations", {})
	var cur: bool = bool(rel.get(kind, false))
	_run(gm.diplomacy_manager.set_treaty(_selected, kind, not cur))
