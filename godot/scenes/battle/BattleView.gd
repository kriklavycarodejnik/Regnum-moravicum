# scenes/battle/BattleView.gd
# Jednoduchý battle chrome — dusk + text fáz (siluety neskôr).
extends Control

const C = preload("res://assets/theme/colors.gd")
const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")

var _title: Label
var _body: RichTextLabel
var _art: TextureRect

func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	custom_minimum_size = Vector2(0, 120)
	_build()
	hide_battle()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C.SKY_DUSK_BOT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_top = 6
	v.offset_right = -8
	v.offset_bottom = -6
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"SubtitleLabel"
	_title.text = "Bitka"
	v.add_child(_title)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(0, 80)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.visible = false
	v.add_child(_art)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)

func show_outcome(title: String, outcome: Dictionary, art_path: String = "") -> void:
	visible = true
	if _title:
		_title.text = title
	if _art:
		if art_path != "" and ResourceLoader.exists(art_path):
			_art.texture = load(art_path) as Texture2D
			_art.visible = true
		else:
			_art.visible = false
	if _body:
		_body.clear()
		var winner: String = str(outcome.get("winner", outcome.get("result", "?")))
		_body.append_text("Výsledok: [b]%s[/b]\n" % winner)
		var logs = outcome.get("phase_logs", [])
		if typeof(logs) == TYPE_ARRAY:
			for log in logs:
				if typeof(log) != TYPE_DICTIONARY:
					continue
				var phase: String = str(log.get("phase", "?"))
				if phase in ["attack", "counterattack"]:
					_body.append_text("· %s — A %d / D %d (ratio %.2f)\n" % [
						phase,
						int(log.get("attacker_losses", 0)),
						int(log.get("defender_losses", 0)),
						float(log.get("ratio", 0.0))
					])
				elif phase == "decision":
					_body.append_text("· decision: %s\n" % str(log.get("winner", "?")))
		if outcome.has("chronicle"):
			_body.append_text("\n%s\n" % str(outcome.get("chronicle")))

func hide_battle() -> void:
	visible = false
	if _body:
		_body.clear()