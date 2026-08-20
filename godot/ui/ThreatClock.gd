# ui/ThreatClock.gd
# Threat clock — "Do Maďarov: N mesiacov" header nad mapou.
# Ukazuje odpočet do maďarskej invázie 907, potom stav po Devíne.
extends PanelContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")

var _label: Label
var _sublabel: Label


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	_build()
	refresh()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)

	_label = Label.new()
	_label.theme_type_variation = &"TitleLabel"
	_label.add_theme_font_size_override("font_size", 26)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)

	_sublabel = Label.new()
	_sublabel.theme_type_variation = &"MutedLabel"
	_sublabel.add_theme_font_size_override("font_size", 12)
	_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sublabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sublabel)


func refresh() -> void:
	if _label == null:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return
	var s = gm.game_state
	var y: int = int(s.year)
	var m: int = int(s.month)

	if s.devine_resolved and y < 907:
		_label.text = "Devín už rozhodol"
		_label.add_theme_color_override("font_color", C.TEXT_MUTED)
		_sublabel.text = "Pokračuj v ťahoch do roku 1000"
	elif y < 907:
		var months_left: int = (907 - y) * 12 + (7 - m)
		if months_left <= 0:
			months_left = 1
		_label.text = "Do Maďarov: %d mes." % months_left
		var urgency: Color = C.WARNING if months_left <= 12 else C.PARCHMENT
		_label.add_theme_color_override("font_color", urgency)
		_sublabel.text = "Priprav sa na krízu 907"
	elif y == 907:
		_label.text = "★ 907 — Bitka pri Devíne ★"
		_label.add_theme_color_override("font_color", C.MORAVIA_CRIMSON)
		_sublabel.text = "Spusti scenár Devín 907 z nástrojov"
	else:
		var years_left: int = maxi(0, 1000 - y)
		_label.text = "Po Devíne · ~%d r. do 1000" % years_left
		_label.add_theme_color_override("font_color", C.SUCCESS)
		_sublabel.text = "Prežitie dynastie · Ďalší mesiac"