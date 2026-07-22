# assets/theme/regnum_theme_factory.gd
# Runtime Theme builder (vrstva C) — oak / parchment / gold / crimson.
class_name RegnumThemeFactory
extends RefCounted


static func build() -> Theme:
	var theme := Theme.new()

	var font_body: Font = _load_font("res://assets/fonts/Alegreya-Regular.ttf")
	var font_body_bold: Font = _load_font("res://assets/fonts/Alegreya-Bold.ttf")
	var font_title: Font = _load_font("res://assets/fonts/CormorantGaramond-SemiBold.ttf")
	var font_title_bold: Font = _load_font("res://assets/fonts/CormorantGaramond-Bold.ttf")

	if font_body:
		theme.default_font = font_body
	theme.default_font_size = 16

	# --- PanelContainer ---
	var panel := _oak_panel_style()
	theme.set_stylebox("panel", "PanelContainer", panel)

	# --- Button ---
	theme.set_stylebox("normal", "Button", _button_style(RegnumColors.OAK_MID, RegnumColors.BYZANTINE_GOLD))
	theme.set_stylebox("hover", "Button", _button_style(Color("4A3828"), RegnumColors.BYZANTINE_GOLD))
	theme.set_stylebox("pressed", "Button", _button_style(RegnumColors.MORAVIA_CRIMSON, RegnumColors.BYZANTINE_GOLD))
	theme.set_stylebox("disabled", "Button", _button_style(Color("1A140F"), RegnumColors.IRON_GREY))
	theme.set_stylebox("focus", "Button", _button_style(RegnumColors.OAK_MID, RegnumColors.BYZANTINE_GOLD))
	theme.set_color("font_color", "Button", RegnumColors.PARCHMENT)
	theme.set_color("font_hover_color", "Button", RegnumColors.IVORY)
	theme.set_color("font_pressed_color", "Button", RegnumColors.PARCHMENT)
	theme.set_color("font_disabled_color", "Button", RegnumColors.TEXT_MUTED)
	if font_body:
		theme.set_font("font", "Button", font_body)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_constant("outline_size", "Button", 0)

	# --- Label ---
	theme.set_color("font_color", "Label", RegnumColors.PARCHMENT)
	if font_body:
		theme.set_font("font", "Label", font_body)
	theme.set_font_size("font_size", "Label", 16)

	# --- RichTextLabel ---
	theme.set_color("default_color", "RichTextLabel", RegnumColors.PARCHMENT)
	if font_body:
		theme.set_font("normal_font", "RichTextLabel", font_body)
		if font_body_bold:
			theme.set_font("bold_font", "RichTextLabel", font_body_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)

	# --- Title helper types (použi theme_type_variation v scénach) ---
	theme.set_type_variation("TitleLabel", "Label")
	if font_title:
		theme.set_font("font", "TitleLabel", font_title)
	elif font_title_bold:
		theme.set_font("font", "TitleLabel", font_title_bold)
	theme.set_font_size("font_size", "TitleLabel", 32)
	theme.set_color("font_color", "TitleLabel", RegnumColors.BYZANTINE_GOLD)

	theme.set_type_variation("SubtitleLabel", "Label")
	if font_title:
		theme.set_font("font", "SubtitleLabel", font_title)
	theme.set_font_size("font_size", "SubtitleLabel", 20)
	theme.set_color("font_color", "SubtitleLabel", RegnumColors.BYZANTINE_GOLD)

	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", RegnumColors.TEXT_MUTED)
	theme.set_font_size("font_size", "MutedLabel", 14)

	# --- ProgressBar (morale atď.) ---
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = RegnumColors.BG_DARKER
	pb_bg.set_corner_radius_all(6)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = RegnumColors.MORAVIA_CRIMSON
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
	s.bg_color = RegnumColors.OAK_DARK
	s.border_color = RegnumColors.BORDER_SOFT
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
	s.content_margin_top = 10
	s.content_margin_right = 16
	s.content_margin_bottom = 10
	return s
