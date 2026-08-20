# ui/ObjectivesPanel.gd
# Dynamické ciele + "čo robiť teraz" — horizontálny kompaktný panel NAD mapou.
# Obsahuje testovateľnú statickú compute_beats() metódu pre beaty A1–D1.
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
	# Explicit opaque panel backdrop so it never appears transparent over map.
	var panel_style := C.create_panel_style()
	add_theme_stylebox_override("panel", panel_style)
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

	var beat := compute_beats(s, gold, owned, prestige)

	_phase_label.text = "%s · %s" % [beat.phase_name, beat.phase_hint]
	_goals_label.text = " • " + "\n • ".join(beat.goals)
	_next_label.text = beat.next_step
	_state_label.text = "%d/%02d · Morava: %d žúp · zlato %d · jedlo %d" % [year, month, owned, gold, food]


# ─────────────────────────────────────────────────────────────────────
# Statická compute_beats — testovateľná, bez závislosti na scéne.
# Volaj z -s skriptov aj UnitTestov: ObjectivesPanel.compute_beats(gs)
# ─────────────────────────────────────────────────────────────────────
static func compute_beats(s, gold: int = -1, owned: int = -1, prestige: int = -1) -> Dictionary:
	var year: int = int(s.year)
	var month: int = int(s.month)
	var devine_resolved: bool = s.devine_resolved

	# Infer chýbajúce argumenty z GameState
	if gold < 0:
		gold = int(s.resources.get("gold", 0))
	if owned < 0:
		owned = _count_owned_static(s, "moravia")
	if prestige < 0:
		prestige = int(s.resources.get("prestige", 0))

	var phase_name: String
	var phase_hint: String
	var goals: PackedStringArray = []
	var next_step: String

	# ─── Fáza I — Konsolidácia (902–906) ───
	if year < 907:
		phase_name = "Fáza I — Konsolidácia (902–906)"
		phase_hint = "Posilni ríšu pred príchodom Maďarov."
		goals = PackedStringArray([
			"Prežiť ako dynastia do 1000",
			"Zbieraj zlato a jedlo („Ďalší mesiac“)",
			"Priprav sa na rok 907",
			])

		# A1: tutorial (year==902 && month<=2)
		if year == 902 and month <= 2:
			next_step = "1) Ciele 2) Klikni župu 3) Ďalší mesiac"

		# A2: economy (year<906 && gold<800)
		elif year < 906 and gold < 800:
			next_step = "Stlač „Ďalší mesiac“ — ekonomika doplní zdroje."

		# A3: waiting (year<906 && gold>=800)
		elif year < 906:
			next_step = "Pokračuj „Ďalší mesiac“. Okolo 906 sa priblíži Devín."
			# A3 diplomatická väzba: ak hungary.mood<30 → varovanie
			var hungary_mood := _get_faction_mood(s, "hungary")
			if hungary_mood >= 0.0 and hungary_mood < 30.0:
				goals.append("Pozor: Maďari sa hnevajú — zváž dar v Diplomacii.")

		# A4: approach 907 — explicit mesačný gate (year>=906 && month>=1 && !devine_resolved),
		# aby neplatný stav 906/00 nezobrazoval „Blíži sa 907“.
		elif year >= 906 and month >= 1 and not devine_resolved:
			next_step = "Blíži sa 907 — priprav armádu k Devínu (pozri notifikáciu)."
			# A4 diplomatická väzba: ak byzantium.mood<40 → varovanie
			var byzantium_mood := _get_faction_mood(s, "byzantium")
			if byzantium_mood >= 0.0 and byzantium_mood < 40.0:
				goals.append("Byzancia je chladná — sobáš môžete ohroziť.")

		# A4 resolved / neplatná 906/00: ešte sa nepribližuj k 907
		else:
			if devine_resolved:
				next_step = "Pokračuj „Ďalší mesiac“ — Devín je vyriešený."
			else:
				next_step = "Pokračuj „Ďalší mesiac“."

	# ─── Fáza II — Kríza (907) ───
	elif year == 907:
		phase_name = "Fáza II — Kríza (907)"
		phase_hint = "Bitka pri Devíne rozhoduje o prestíži."
		goals = PackedStringArray([
			"Spusti scenár „Devín 907“",
			"Potom pokračuj mesačnými ťahmi",
		])

		# B1: Devín button (year==907 && !devine_resolved)
		if not devine_resolved:
			next_step = "Stlač „Devín 907“ v nástrojoch dole."

		# B2: Devín padol (devine_resolved)
		else:
			goals.append("Devín padol — Maďarská nálada +30 (kánon).")
			next_step = "Devín padol. Pokračuj „Ďalší mesiac“."

	# ─── Fáza III — Prežitie (908–959) ───
	elif year < 960:
		phase_name = "Fáza III — Prežitie (908–959)"
		phase_hint = "Obnov ríšu, diplomaciu a armády."
		goals = PackedStringArray([
			"Udrž lojalitu a jedlo pre armády",
			"Diplomacia: dary / zmluvy so susedmi",
			"Reaguj na udalosti rady",
		])

		# C1: early post-907 (908–914)
		if year < 915:
			next_step = "Obnov ríšu: ekonomika a diplomacia."

		# C2: Bogata conspiracy window (915–919)
		elif year < 920:
			next_step = "Sleduj východné župy — Sprisahanie Bogata."
			# C2 diplomatická väzba: ak uzhorod.loyalty<40 → sprisahanie
			var uzh_loyalty := _get_province_loyalty(s, "uzhorod")
			if uzh_loyalty >= 0.0 and uzh_loyalty < 40.0:
				goals.append("Užhorod je nestabilný — hrozí sprisahanie.")

		# C3: late prežitie (920–959)
		else:
			next_step = "Diplomacia a armády — udrž lojalitu."

	# ─── Fáza IV — Cesta k 1000 (960+) ───
	else:
		phase_name = "Fáza IV — Cesta k 1000"
		phase_hint = "Legitimita, prestíž a prežitie dynastie."
		goals = PackedStringArray([
			"Prežiť do roku 1000 s ≥1 župou",
			"Nenechaj vymrieť Mojmírovcov",
		])
		var left: int = 1000 - year
		# D1: roky do 1000
		next_step = "~%d r. · župy: %d · prestíž: %d" % [left, owned, prestige]

	# ─── Generický diplomatický side-goal ───
	var dip_lines := _diplomacy_side_goal_static(s)
	for dl in dip_lines:
		goals.append(dl)

	# Next_step override ak niektorá frakcia (okrem hungary/moravia) má mood<30,
	# ale len mimo roku 907 (v 907 majú prioritu B1/B2 texty).
	if year != 907:
		var urgent_next := _diplomacy_urgent_next_step_static(s)
		if urgent_next != "":
			next_step = urgent_next

	return {
		"phase_name": phase_name,
		"phase_hint": phase_hint,
		"goals": goals,
		"next_step": next_step,
	}


# ─── Statické pomocné funkcie (volané z compute_beats) ───
static func _get_faction_mood(s, faction_id: String) -> float:
	if s.factions == null or typeof(s.factions) != TYPE_DICTIONARY or not s.factions.has(faction_id):
		return -1.0
	var f = s.factions[faction_id]
	if typeof(f) != TYPE_DICTIONARY:
		return -1.0
	return float(f.get("mood", 50.0))


static func _get_province_loyalty(s, province_id: String) -> float:
	if s.provinces == null or typeof(s.provinces) != TYPE_DICTIONARY or not s.provinces.has(province_id):
		return -1.0
	var p = s.provinces[province_id]
	if typeof(p) != TYPE_DICTIONARY:
		return -1.0
	return float(p.get("loyalty", 50.0))


static func _diplomacy_side_goal_static(s) -> PackedStringArray:
	if s.factions == null or typeof(s.factions) != TYPE_DICTIONARY:
		return PackedStringArray()
	var worst_mood := 100.0
	var worst_name := ""
	for fid in s.factions:
		if fid == "hungary" or fid == "moravia":
			continue
		var f = s.factions[fid]
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var mood: float = float(f.get("mood", 50.0))
		if mood < worst_mood:
			worst_mood = mood
			worst_name = str(f.get("name", fid))
	if worst_name == "" or worst_mood >= 50.0:
		return PackedStringArray()
	if worst_mood < 30.0:
		return PackedStringArray(["⚠ URGENTNÉ: %s má náladu len %.0f — hrozí konflikt!" % [worst_name, worst_mood]])
	return PackedStringArray(["Diplomacia: %s má náladu %.0f" % [worst_name, worst_mood]])


static func _diplomacy_urgent_next_step_static(s) -> String:
	# Vráti urgent next_step text ak nejaká frakcia (okrem hungary/moravia) má mood<30
	if s.factions == null or typeof(s.factions) != TYPE_DICTIONARY:
		return ""
	var worst_mood := 100.0
	var worst_name := ""
	for fid in s.factions:
		if fid == "hungary" or fid == "moravia":
			continue
		var f = s.factions[fid]
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var mood: float = float(f.get("mood", 50.0))
		if mood < worst_mood:
			worst_mood = mood
			worst_name = str(f.get("name", fid))
	if worst_name == "" or worst_mood >= 30.0:
		return ""
	return "Dar frakcii %s v záložke Diplomacia (nálada %.0f)." % [worst_name, worst_mood]


static func _count_owned_static(s, faction: String) -> int:
	var n := 0
	for pid in s.provinces:
		var p = s.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == faction:
			n += 1
	return n


# ─── Inštančné metódy (zachované pre existujúcu volaciu logiku) ───
func _diplomacy_side_goal(gm) -> Dictionary:
	if gm.diplomacy_manager == null:
		return {}
	var factions: Array = gm.diplomacy_manager.list_factions()
	var worst_mood := 100.0
	var worst_name := ""
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY or str(f.get("id", "")) == "hungary" or str(f.get("id", "")) == "moravia":
			continue
		var mood: float = float(f.get("mood", 50.0))
		if mood < worst_mood:
			worst_mood = mood
			worst_name = str(f.get("name", ""))
	if worst_name == "" or worst_mood >= 50.0:
		return {}
	if worst_mood < 30.0:
		return {
			"goal": "⚠ URGENTNÉ: %s má náladu len %.0f — hrozí konflikt!" % [worst_name, worst_mood],
			"mood": worst_mood,
			"next_step": "Dar frakcii %s v záložke Diplomacia (nálada %.0f)." % [worst_name, worst_mood],
		}
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