# ui/ObjectivesPanel.gd
# Dynamické ciele + „čo robiť teraz“ podľa roku a stavu.
extends PanelContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")

var _title: Label
var _body: RichTextLabel
var _next: Label
var _phase: Label


func _ready() -> void:
	if theme == null:
		theme = _ThemeFactory.build()
	_build()
	refresh()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	_title = Label.new()
	_title.theme_type_variation = &"SubtitleLabel"
	_title.text = "Tvoje poslanie"
	v.add_child(_title)

	_phase = Label.new()
	_phase.theme_type_variation = &"MutedLabel"
	_phase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_phase)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 72)
	v.add_child(_body)

	var next_title := Label.new()
	next_title.text = "Teraz urob"
	next_title.theme_type_variation = &"SubtitleLabel"
	v.add_child(next_title)

	_next = Label.new()
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next.add_theme_color_override("font_color", C.BYZANTINE_GOLD)
	_next.add_theme_font_size_override("font_size", 15)
	v.add_child(_next)


func refresh() -> void:
	if _body == null:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or gm.game_state == null:
		return
	var s = gm.game_state
	var year: int = int(s.year)
	var month: int = int(s.month)
	var owned := _count_owned(s, "moravia")
	var gold: int = int(s.resources.get("gold", 0))
	var food: int = int(s.resources.get("food", 0))
	var prestige: int = int(s.resources.get("prestige", 0))

	var phase_name: String
	var phase_hint: String
	var goals: PackedStringArray = []
	var next_step: String

	if year < 907:
		phase_name = "Fáza I — Konsolidácia (902–906)"
		phase_hint = "Posilni ríšu pred príchodom Maďarov."
		goals = PackedStringArray([
			"• Drž aspoň 1 župu a živú dynastiu",
			"• Zbieraj zlato a jedlo (ekonomika beží každý mesiac)",
			"• Spoznaj mapu — klikni Nitra, Devín, Bratislava",
			"• Priprav sa na krízu roku 907",
		])
		if year == 902 and month <= 2:
			next_step = "1) Prečítaj ciele  2) Klikni župu na mape  3) Stlač „Ďalší mesiac“"
		elif gold < 800:
			next_step = "Stlač „Ďalší mesiac“ — ekonomika doplní zdroje. Sleduj zlato a jedlo hore."
		else:
			next_step = "Pokračuj „Ďalší mesiac“. Okolo 907 spusti scenár Devín (tlačidlo dole)."
	elif year == 907:
		phase_name = "Fáza II — Kríza Maďarov (907)"
		phase_hint = "Bitka pri Devíne rozhoduje o prestíži a osude západu ríše."
		goals = PackedStringArray([
			"• Spusti scenár „Devín 907“ (historická bitka)",
			"• Prečítaj výsledok v kronike a battle paneli",
			"• Potom pokračuj mesačnými ťahmi",
		])
		next_step = "Stlač „Devín 907“ — odohraj historickú bitku, potom „Ďalší mesiac“."
	elif year < 960:
		phase_name = "Fáza III — Prežitie (908–959)"
		phase_hint = "Obnov ríšu, diplomaciu a armády."
		goals = PackedStringArray([
			"• Udrž lojalitu žúp a jedlo pre armády",
			"• Diplomacia: dary / zmluvy so susedmi",
			"• Reaguj na udalosti rady (2 voľby)",
		])
		next_step = "Striedaj „Ďalší mesiac“ a záložku Diplomacia. Pri udalosti vždy vyber voľbu."
	else:
		phase_name = "Fáza IV — Cesta k roku 1000"
		phase_hint = "Legitimita, prestíž a prežitie dynastie."
		goals = PackedStringArray([
			"• Prežiť do roku 1000 s ≥1 župou",
			"• Prestíž a viera posilňujú legitimitu",
			"• Nenechaj vymrieť Mojmírovcov",
		])
		var left: int = 1000 - year
		next_step = "Zostáva ~%d rokov. Primárne: „Ďalší mesiac“. Župy: %d · prestíž: %d" % [left, owned, prestige]

	_phase.text = "%s\n%s" % [phase_name, phase_hint]
	_body.clear()
	_body.append_text("[b]Hlavný cieľ:[/b] Prežiť ako Mojmír II. / dynastia do roku [color=#C9A227]1000[/color].\n\n")
	for g in goals:
		_body.append_text(g + "\n")
	_body.append_text("\n[color=#7A6B55]Stav: %d/%02d · župy Moravy: %d · zlato %d · jedlo %d[/color]" % [
		year, month, owned, gold, food
	])
	_next.text = next_step


func _count_owned(s, faction: String) -> int:
	var n := 0
	for pid in s.provinces:
		var p = s.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == faction:
			n += 1
	return n
