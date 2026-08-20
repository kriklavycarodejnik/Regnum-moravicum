# ui/ObjectivesPanel.gd
# Dynamické ciele + "čo robiť teraz" — horizontálny kompaktný panel NAD mapou.
# Implementuje P1 §2.3 fázové beaty s diplomatickou väzbou.
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
    var dip_factions: Array = []
    if gm.diplomacy_manager != null:
        dip_factions = gm.diplomacy_manager.list_factions()
        if dip_factions == null:
            dip_factions = []

    var beats: Dictionary = compute_beats(s, dip_factions)

    _phase_label.text = "%s · %s" % [beats.get("phase_name", "?"), beats.get("phase_hint", "?")]
    _goals_label.text = " • " + "\n • ".join(beats.get("goals", PackedStringArray()))
    _next_label.text = str(beats.get("next_step", ""))
    _state_label.text = str(beats.get("state_line", ""))


# --- Testovateľná čistá funkcia pre beaty ---
# Vypočíta fázové beaty, ciele a next_step z herného stavu (GameState + dip_factions).
# Je statická – volateľná bez scény, ideálna pre smoke testy.
static func compute_beats(s, dip_factions: Array) -> Dictionary:
    var year: int = int(s.year)
    var month: int = int(s.month)
    var owned := 0
    for pid in s.provinces:
        var p = s.provinces[pid]
        if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == "moravia":
            owned += 1
    var gold: int = int(s.resources.get("gold", 0))
    var food: int = int(s.resources.get("food", 0))
    var prestige: int = int(s.resources.get("prestige", 0))
    var devine_resolved: bool = bool(s.devine_resolved)

    var phase_name: String
    var phase_hint: String
    var goals: PackedStringArray = []
    var next_step: String = ""

    # ─── Generic diplomacy side-goal (okrem hungary/moravia, mood < 50) ───
    var dip_goal: Dictionary = _compute_diplomacy_goal(dip_factions)
    var dip_goal_txt: String = str(dip_goal.get("goal", ""))
    var dip_mood: float = float(dip_goal.get("mood", 100.0))
    var dip_next_override: String = ""
    if dip_goal_txt != "" and dip_mood < 30.0:
        var fname: String = str(dip_goal.get("faction_name", ""))
        dip_next_override = "URGENTNÉ — dar frakcii %s v záložke Diplomacia (nálada %.0f)." % [fname, dip_mood]

    if year < 907:
        # ─── Fáza I — Konsolidácia (902–906) ───
        phase_name = "Fáza I — Konsolidácia (902–906)"
        phase_hint = "Posilni ríšu pred príchodom Maďarov."
        goals = PackedStringArray([
            "Prežiť ako dynastia do 1000",
            "Zbieraj zlato a jedlo („Ďalší mesiac\")",
            "Priprav sa na rok 907",
        ])
        if year < 906:
            if year == 902 and month <= 2:
                # Beat A1: úplný začiatok
                next_step = "1) Prečítaj si ciele 2) Klikni na Nitru 3) Stlač „Ďalší mesiac\""
            elif gold < 800:
                # Beat A2: málo zlata, ekonomika
                next_step = "Stlač „Ďalší mesiac\" — ekonomika dopĺňa zdroje."
            else:
                # Beat A3: dosť zlata, čaká sa
                next_step = "Pokračuj „Ďalší mesiac\". Okolo 906 sa priblíži Devín."
                # A3: Maďari mood < 30
                var hungary_mood_a3 := _get_faction_mood(dip_factions, "hungary")
                if hungary_mood_a3 >= 0.0 and hungary_mood_a3 < 30.0:
                    goals.append("Pozor: Maďari sa hnevajú — zváž dar v Diplomacii (nálada %.0f)." % hungary_mood_a3)
        else:  # year >= 906 and year < 907
            # Beat A4: Devín sa blíži
            next_step = "Blíži sa 907 — priprav armádu k Devínu (pozri notifikáciu)."
            # A4: Byzancia mood < 40
            var byzantium_mood_a4 := _get_faction_mood(dip_factions, "byzantium")
            if byzantium_mood_a4 >= 0.0 and byzantium_mood_a4 < 40.0:
                goals.append("Byzancia je chladná — sobáš môžete ohroziť (nálada %.0f)." % byzantium_mood_a4)

        # Diplomacy side-goal pre Phase I
        if dip_goal_txt != "":
            goals.append(dip_goal_txt)
            if dip_next_override != "":
                next_step = dip_next_override

    elif year == 907:
        if not devine_resolved:
            # Beat B1: Devín nespustený
            phase_name = "Fáza II — Kríza (907)"
            phase_hint = "Bitka pri Devíne rozhoduje o prestíži."
            goals = PackedStringArray([
                "Spusti scenár „Devín 907\"",
                "Potom pokračuj mesačnými ťahmi",
            ])
            next_step = "Stlač „Devín 907\" v nástrojoch dole."
        else:
            # Beat B2: Devín prebehol
            phase_name = "Fáza II — Kríza (907)"
            phase_hint = "Bitka pri Devíne je za nami."
            goals = PackedStringArray([
                "Devín padol — Maďari získali prestíž.",
                "Pokračuj mesačnými ťahmi.",
            ])
            next_step = "Devín padol. Pokračuj „Ďalší mesiac\"."
            # B2: zobraziť mood Maďarov (efekt +30 z kánonu)
            var hungary_mood_b2 := _get_faction_mood(dip_factions, "hungary")
            if hungary_mood_b2 >= 0.0:
                goals.append("Maďari: nálada %.0f (posilnení po Devíne)." % hungary_mood_b2)

    elif year < 960:
        # ─── Fáza III — Prežitie (908–959) ───
        phase_name = "Fáza III — Prežitie (%d–959)" % [year]
        phase_hint = "Obnov ríšu, diplomaciu a armády."
        goals = PackedStringArray([
            "Udrž lojalitu a jedlo pre armády",
            "Diplomacia: dary / zmluvy so susedmi",
            "Reaguj na udalosti rady",
        ])
        if year < 915:
            # Beat C1: obnova
            next_step = "Obnov ríšu: ekonomika a diplomacia."
        elif year < 920:
            # Beat C2: Bogata sprisahanie
            next_step = "Sleduj východné župy — Sprisahanie Bogata."
            # C2: lojalita Užhorodu < 40 → varovanie
            var uzh_prov = s.provinces.get("uzhorod", {})
            if typeof(uzh_prov) == TYPE_DICTIONARY:
                var uzh_loyalty: float = float(uzh_prov.get("loyalty", 50.0))
                if uzh_loyalty < 40.0:
                    goals.append("Užhorod je nestabilný (lojalita %.0f) — hrozí sprisahanie." % uzh_loyalty)
        else:
            # Beat C3: dlhodobé prežitie
            next_step = "Diplomacia a armády — udrž lojalitu."

        # Diplomacy side-goal pre Phase III
        if dip_goal_txt != "":
            goals.append(dip_goal_txt)
            if dip_next_override != "":
                next_step = dip_next_override

    else:  # year >= 960
        # ─── Fáza IV — Cesta k 1000 ───
        phase_name = "Fáza IV — Cesta k 1000"
        phase_hint = "Legitimita, prestíž a prežitie dynastie."
        goals = PackedStringArray([
            "Prežiť do roku 1000 s ≥1 župou",
            "Nenechaj vymrieť Mojmírovcov",
        ])
        var left: int = 1000 - year
        next_step = "~%d r. · župy: %d · prestíž: %d" % [left, owned, prestige]
        # D1: frakcie s mood < 40
        for f_d1 in dip_factions:
            if typeof(f_d1) == TYPE_DICTIONARY:
                var mood_d1: float = float(f_d1.get("mood", 50.0))
                if mood_d1 < 40.0:
                    var fid_d1: String = str(f_d1.get("id", ""))
                    goals.append("Diplomacia: %s má náladu %.0f" % [str(f_d1.get("name", fid_d1)), mood_d1])

    # State line (vždy rovnaký formát)
    var state_line: String = "%d/%02d · Morava: %d žúp · zlato %d · jedlo %d" % [year, month, owned, gold, food]

    return {
        "phase_name": phase_name,
        "phase_hint": phase_hint,
        "goals": goals,
        "next_step": next_step,
        "state_line": state_line,
    }


# Vráti mood frakcie z dip_factions. -1 ak frakcia nie je v zozname.
static func _get_faction_mood(dip_factions: Array, target_id: String) -> float:
    for f in dip_factions:
        if typeof(f) == TYPE_DICTIONARY and str(f.get("id", "")) == target_id:
            return float(f.get("mood", 50.0))
    return -1.0


# Nájde najhoršiu frakciu (okrem moravia a hungary) s mood < 50.
# Vracia {goal, mood, faction_name, faction_id, next_step} alebo {} žiadna.
static func _compute_diplomacy_goal(dip_factions: Array) -> Dictionary:
    var worst_mood := 100.0
    var worst_name := ""
    var worst_id := ""
    for f in dip_factions:
        if typeof(f) != TYPE_DICTIONARY:
            continue
        var fid: String = str(f.get("id", ""))
        # §2.4: vylúčiť hungary aj moravia
        if fid == "hungary" or fid == "moravia":
            continue
        var mood: float = float(f.get("mood", 50.0))
        if mood < worst_mood:
            worst_mood = mood
            worst_name = str(f.get("name", fid))
            worst_id = fid
    if worst_name == "" or worst_mood >= 50.0:
        return {}
    return {
        "goal": "Diplomacia: %s má náladu len %.0f" % [worst_name, worst_mood],
        "mood": worst_mood,
        "faction_name": worst_name,
        "faction_id": worst_id,
        "next_step": "Dar frakcii %s v záložke Diplomacia (nálada %.0f)." % [worst_name, worst_mood],
    }