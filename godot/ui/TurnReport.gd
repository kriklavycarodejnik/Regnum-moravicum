# ui/TurnReport.gd
# Mesačný report po ťahu — Δ zdroje + narácia + CTA.
extends PanelContainer

const _RESOURCE_SK: Dictionary = {
	"gold": "Zlato",
	"food": "Jedlo",
	"wood": "Drevo",
	"stone": "Kameň",
	"iron": "Železo",
	"prestige": "Prestíž",
}

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")

signal continue_pressed

var _title: Label
var _delta: RichTextLabel
var _narration: RichTextLabel
var _cta: Button


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	_build()
	# Reset size so children determine panel height
	custom_minimum_size = Vector2(600, 0)
	hide()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	_title = Label.new()
	_title.theme_type_variation = &"SubtitleLabel"
	_title.text = "Mesiac uzavretý"
	v.add_child(_title)

	_delta = RichTextLabel.new()
	_delta.bbcode_enabled = true
	_delta.fit_content = true
	v.add_child(_delta)

	_narration = RichTextLabel.new()
	_narration.bbcode_enabled = true
	_narration.fit_content = true
	_narration.custom_minimum_size = Vector2(0, 60)
	v.add_child(_narration)

	_cta = Button.new()
	_cta.custom_minimum_size = Vector2(0, 48)
	_cta.text = "Pokračovať"
	_cta.pressed.connect(func(): continue_pressed.emit(); hide())
	v.add_child(_cta)


func show_report(report: Dictionary) -> void:
	_title.text = "Mesiac %d/%02d uzavretý" % [report.get("year", 0), report.get("month", 0)]
	var delta_text = ""
	var res = report.get("resources_delta", {})
	for k in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		var d = res.get(k, 0)
		if d != 0:
			delta_text += "[color=#C9A227]%s %+d[/color]  " % [_RESOURCE_SK.get(k, ""), d]
	_delta.text = delta_text.strip_edges()
	if _delta.text == "":
		_delta.text = "Zdroje sa nezmenili."
	_narration.text = str(report.get("narration", "Mesiac uplynul v tichu dvorov a polí."))
	show()