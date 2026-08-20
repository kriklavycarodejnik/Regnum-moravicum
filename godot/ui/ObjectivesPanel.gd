# ui/ObjectivesPanel.gd
# Dynamické ciele + "čo robiť teraz" — horizontálny kompaktný panel NAD mapou.
extends PanelContainer

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const C = preload("res://assets/theme/colors.gd")

var _phase_label: Label
var _goals_label: Label
var _next_label: Label
var _state_label: Label


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
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	margin.add_child(h)

	# ─── Left column — Tvoje poslanie ───
	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 3)
	left_v.size_flags_horizontal = 3
	h.add_child(left_v)

	var title := Label.new()
	title.theme_type_variation = &"SubtitleLabel"
	title.add_theme_font_size_override("font_size", 15)
	title.text = "Tvoje poslanie"
	left_v.add_child(title)

	_phase_label = Label.new()
	_phase_label.theme_type_variation = &"MutedLabel"
	_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_v.add_child(_phase_label)

	_goals_label = Label.new()
	_goals_label.add_theme_font_size_override("font_size", 12)
	_goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_v.add_child(_goals_label)

	# ─── Right column — Teraz urob ───
	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 3)
	right_v.size_flags_horizontal = 2
	h.add_child(right_v)

	var next_title := Label.new()
	next_title.theme_type_variation = &"SubtitleLabel"
	next_title.add_theme_font_size_override("font_size", 15)
	next_title.text = "Teraz urob"
	right_v.add_child(next_title)

	_next_label = Label.new()
	_next_label.add_theme_font_size_override("font_size", 12)
	_next_label.add_theme_color_override("font_color", C.BYZANTINE_GOLD)
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_v.add_child(_next_label)

	_state_label = Label.new()
	_state_label.theme_type_variation = &"MutedLabel"
	_state_label.add_theme_font_size_override("font_size", 11)
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_v.add_child(_state_label)


func refresh() -> void:
	if _phase_label == null:
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
	var goal_lines: PackedStringArray = []
	var next_step: String

	if year < 907:
		phase_name = "Fáza I — Konsolidácia (902–906)"
		phase_hint = "Posilni ríšu pred príchodom Maďarov."
		goal_lines = PackedStringArray([
			"Prežiť ako dynastia do 1000",
			"Zbieraj zlato a jedlo („Ďalší mesiac“)",
			"Priprav sa na rok 907",
		])
		if year == 902 and month <= 2:
			next_step = "1) Ciele 2) Klikni župu 3) Ďalší mesiac"
		elif gold < 800:
			next_step = "Stlač „Ďalší mesiac“ — ekonomika doplní zdroje."
		else:
			next_step = "Pokračuj „Ďalší mesiac“. Okolo 907 spusti Devín."
	elif year == 907:
		phase_name = "Fáza II — Kríza (907)"
		phase_hint = "Bitka pri Devíne rozhoduje o prestíži."
		goal_lines = PackedStringArray([
			"Spusti scenár „Devín 907“",
			"Potom pokračuj mesačnými ťahmi",
		])
		next_step = "Stlač „Devín 907“ v nástrojoch dole."
	elif year < 960:
		phase_name = "Fáza III — Prežitie (908–959)"
		phase_hint = "Obnov ríšu, diplomaciu a armády."
		goal_lines = PackedStringArray([
			"Udrž lojalitu a jedlo pre armády",
			"Diplomacia: dary / zmluvy so susedmi",
			"Reaguj na udalosti rady",
		])
		next_step = "„Ďalší mesiac“ + záložka Diplomacia."
	else:
		phase_name = "Fáza IV — Cesta k 1000"
		phase_hint = "Legitimita, prestíž a prežitie dynastie."
		goal_lines = PackedStringArray([
			"Prežiť do roku 1000 s ≥1 župou",
			"Nenechaj vymrieť Mojmírovcov",
		])
		var left: int = 1000 - year
		next_step = "~%d r. · župy: %d · prestíž: %d" % [left, owned, prestige]

	_phase_label.text = "%s · %s" % [phase_name, phase_hint]
	_goals_label.text = " • " + "\n • ".join(goal_lines)

	# Diplomacy side-goal
	if year != 907:
		var dip_goal: Dictionary = _diplomacy_side_goal(gm)
		if str(dip_goal.get("goal", "")) != "":
			_goals_label.text += "\n • %s" % str(dip_goal.get("goal", ""))
			if float(dip_goal.get("mood", 100.0)) < 30.0:
				next_step = str(dip_goal.get("next_step", next_step))

	_next_label.text = next_step
	_state_label.text = "%d/%02d · Morava: %d žúp · zlato %d · jedlo %d" % [year, month, owned, gold, food]


func _diplomacy_side_goal(gm) -> Dictionary:
	if gm.diplomacy_manager == null:
		return {}
	var factions: Array = gm.diplomacy_manager.list_factions()
	var worst_mood := 100.0
	var worst_name := ""
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY or str(f.get("id", "")) == "hungary":
			continue
		var mood: float = float(f.get("mood", 50.0))
		if mood < worst_mood:
			worst_mood = mood
			worst_name = str(f.get("name", ""))
	if worst_name == "" or worst_mood >= 50.0:
		return {}
	return {
		"goal": "Diplomacia: %s má náladu len %.0f" % [worst_name, worst_mood],
		"mood": worst_mood,
		"next_step": "Dar frakcii %s v záložke Diplomacia (nálada %.0f)." % [worst_name, worst_mood],
	}


func _count_owned(s, faction: String) -> int:
	var n := 0
	for pid in s.provinces:
		var p = s.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == faction:
			n += 1
	return n