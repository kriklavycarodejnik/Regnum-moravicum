# assets/theme/regnum_theme_factory.gd
extends RefCounted

const C = preload("res://assets/theme/colors.gd")


static func build() -> Theme:
	var theme := Theme.new()
	var font_body: Font = _load_font("res://assets/fonts/Alegreya-Regular.ttf")
	var font_body_bold: Font = _load_font("res://assets/fonts/Alegreya-Bold.ttf")
	var font_title: Font = _load_font("res://assets/fonts/CormorantGaramond-SemiBold.ttf")
	var font_title_bold: Font = _load_font("res://assets/fonts/CormorantGaramond-Bold.ttf")
	if font_body:
		theme.default_font = font_body
	theme.default_font_size = 16
	theme.set_stylebox("panel", "PanelContainer", _oak_panel_style())
	theme.set_stylebox("normal", "Button", _button_style(C.OAK_MID, C.BYZANTINE_GOLD))
	theme.set_stylebox("hover", "Button", _button_style(Color("4A3828"), C.BYZANTINE_GOLD))
	theme.set_stylebox("pressed", "Button", _button_style(C.MORAVIA_CRIMSON, C.BYZANTINE_GOLD))
	theme.set_stylebox("disabled", "Button", _button_style(Color("1A140F"), C.IRON_GREY))
	theme.set_stylebox("focus", "Button", _button_style(C.OAK_MID, C.BYZANTINE_GOLD))
	theme.set_color("font_color", "Button", C.PARCHMENT)
	theme.set_color("font_hover_color", "Button", C.IVORY)
	theme.set_color("font_pressed_color", "Button", C.PARCHMENT)
	theme.set_color("font_disabled_color", "Button", C.TEXT_MUTED)
	if font_body:
		theme.set_font("font", "Button", font_body)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_color("font_color", "Label", C.PARCHMENT)
	if font_body:
		theme.set_font("font", "Label", font_body)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("default_color", "RichTextLabel", C.PARCHMENT)
	if font_body:
		theme.set_font("normal_font", "RichTextLabel", font_body)
		if font_body_bold:
			theme.set_font("bold_font", "RichTextLabel", font_body_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	theme.set_type_variation("TitleLabel", "Label")
	if font_title:
		theme.set_font("font", "TitleLabel", font_title)
	elif font_title_bold:
		theme.set_font("font", "TitleLabel", font_title_bold)
	theme.set_font_size("font_size", "TitleLabel", 32)
	theme.set_color("font_color", "TitleLabel", C.BYZANTINE_GOLD)
	theme.set_type_variation("SubtitleLabel", "Label")
	if font_title:
		theme.set_font("font", "SubtitleLabel", font_title)
	theme.set_font_size("font_size", "SubtitleLabel", 20)
	theme.set_color("font_color", "SubtitleLabel", C.BYZANTINE_GOLD)
	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", C.TEXT_MUTED)
	theme.set_font_size("font_size", "MutedLabel", 14)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = C.BG_DARKER
	pb_bg.set_corner_radius_all(6)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = C.MORAVIA_CRIMSON
	pb_fill.set_corner_radius_all(6)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	return theme


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res as Font
	return null


static func _oak_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C.OAK_DARK
	s.border_color = C.BORDER_SOFT
	s.set_border_width_all(1)
	s.set_corner_radius_all(14)
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(border.r, border.g, border.b, 0.45)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 16
	s.content_margin_top = 14
	s.content_margin_right = 16
	s.content_margin_bottom = 14
	return s

static func resource_chip_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.11, 0.07, 0.85)
	s.border_color = Color(C.BYZANTINE_GOLD.r, C.BYZANTINE_GOLD.g, C.BYZANTINE_GOLD.b, 0.3)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_top = 4
	s.content_margin_right = 8
	s.content_margin_bottom = 4
	return s
