# scenes/battle/BattleView.gd
# Battle chrome — dusk + silhouettes + text phase + optional art plate.
extends Control

signal action_chosen(action: String)

const C = preload("res://assets/theme/colors.gd")
const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")

var _title: Label
var _body: RichTextLabel
var _art: TextureRect
var _sil_left: TextureRect
var _sil_right: TextureRect
var _actions_row: HBoxContainer

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
	# Silhouette row (left attacker, right defender)
	var sil_row := HBoxContainer.new()
	sil_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sil_row.add_theme_constant_override("separation", 16)
	_sil_left = TextureRect.new()
	_sil_left.custom_minimum_size = Vector2(64, 100)
	_sil_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sil_left.visible = false
	sil_row.add_child(_sil_left)
	var vs := Label.new()
	vs.text = "⚔"
	vs.add_theme_font_size_override("font_size", 24)
	vs.add_theme_color_override("font_color", C.BYZANTINE_GOLD)
	sil_row.add_child(vs)
	_sil_right = TextureRect.new()
	_sil_right.custom_minimum_size = Vector2(64, 100)
	_sil_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sil_right.visible = false
	sil_row.add_child(_sil_right)
	v.add_child(sil_row)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(0, 60)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.visible = false
	v.add_child(_art)
	# Action buttons (M8.3 phased battle)
	_actions_row = HBoxContainer.new()
	_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_row.add_theme_constant_override("separation", 8)
	for a in ["melee", "ranged", "flank", "retreat"]:
		var b := Button.new()
		b.text = {"melee": "Priamy útok", "ranged": "Streľba", "flank": "Obchvat", "retreat": "Ústup"}[a]
		b.pressed.connect(func(): action_chosen.emit(a))
		_actions_row.add_child(b)
	_actions_row.visible = false
	v.add_child(_actions_row)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)

func show_outcome(title: String, outcome: Dictionary, art_id: String = "") -> void:
	visible = true
	show_actions(false)
	if _title:
		_title.text = title
	
	# Determine silhouettes based on art_id / battle context
	var is_devin: bool = (art_id == "battle_danube_composition" or "Devín" in title or "devin" in title.to_lower())
	if is_devin:
		# Devín 907: magyar horse (left=attacker) vs moravian shieldwall (right=defender)
		if _sil_left != null:
			_sil_left.texture = ArtCatalog.texture("sil_magyar_horse")
			_sil_left.visible = _sil_left.texture != null
		if _sil_right != null:
			_sil_right.texture = ArtCatalog.texture("sil_shieldwall")
			_sil_right.visible = _sil_right.texture != null
	else:
		# Generic skirmish: infantry vs archer/cavalry
		if _sil_left != null:
			_sil_left.texture = ArtCatalog.texture("sil_infantry")
			_sil_left.visible = _sil_left.texture != null
		if _sil_right != null:
			_sil_right.texture = ArtCatalog.texture("sil_cavalry")
			_sil_right.visible = _sil_right.texture != null
	
	if _art:
		if art_id != "":
			var tex: Texture2D = ArtCatalog.texture(art_id)
			if tex != null:
				_art.texture = tex
				_art.visible = true
			else:
				_art.visible = false
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

func show_actions(visible_flag: bool) -> void:
	if _actions_row:
		_actions_row.visible = visible_flag

func hide_battle() -> void:
	visible = false
	if _body:
		_body.clear()
	if _sil_left:
		_sil_left.visible = false
	if _sil_right:
		_sil_right.visible = false
