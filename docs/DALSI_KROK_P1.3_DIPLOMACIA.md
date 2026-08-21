# Ďalší krok — P1.3: prepojenie Diplomacie na Objectives

> **Toto je inštrukcia pre implementáciu, nie hotový kód.** Určené pre
> agenta/reláciu, ktorá bude kódiť. Nadväzuje na `NAVRH_HERNY_ZAZITOK.md`
> (P1.3) a `M7` (P1.2/P1.4/P1.5 už hotové v `fd46371`).

---

## 1. Čo je cieľ

`godot/ui/ObjectivesPanel.gd` dnes zobrazuje len **statický text** o
diplomacii ("Diplomacia: dary / zmluvy so susedmi" vo Fáze III) — nič sa
neviaže na skutočný stav frakcií. Mechanika (`DiplomacyManager.send_gift`
/ `.threaten` / `.set_treaty`, `list_factions()`) funguje už od skoršej
práce (vrátane Byzancie ako 7. frakcie) — chýba len **prepojenie na
panel cieľov**, aby hráč videl konkrétny, dátami podložený dôvod otvoriť
záložku Diplomacia, nie len všeobecnú pripomienku.

## 2. Kde presne zasiahnuť

**Súbor:** `godot/ui/ObjectivesPanel.gd`

Pridať novú funkciu (napr. na koniec súboru, pred `_count_owned`):

```gdscript
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
		"goal": "• Diplomacia: %s má náladu len %.0f — dar alebo zmluva v záložke Diplomacia" % [worst_name, worst_mood],
		"mood": worst_mood,
		"next_step": "Otvor záložku Diplomacia a pošli dar frakcii %s (nálada %.0f — riziko rozkolu)." % [worst_name, worst_mood],
	}
```

**Prečo `id == "hungary"` vylúčené:** Maďari sú fixný historický
antagonista (kánon Devína 907 = útočník vždy vyhrá), nemá zmysel
nabádať hráča „zlepši im náladu" — nízka nálada Hungary je zámer, nie
problém na riešenie.

**Prečo prah `< 50.0`:** 50 je neutrálna základná hodnota vo
`_ensure_default_factions()` (franks/moravia/byzantium štartujú na 50,
bavaria 40, poland 30, bohemia 60) — pod touto hranicou je frakcia už
horšie než neutrálna, teda relevantná ako cieľ.

V `refresh()`, tesne pred `_phase.text = ...` (t.j. po zostavení
`goals`/`next_step` pre všetky 4 fázy, ale **mimo roku 907** — kríza
Devína má mať vlastný, nerozptýlený zoznam cieľov):

```gdscript
if year != 907:
	var dip_goal: Dictionary = _diplomacy_side_goal(gm)
	if str(dip_goal.get("goal", "")) != "":
		goals.append(str(dip_goal["goal"]))
		if float(dip_goal.get("mood", 100.0)) < 30.0:
			next_step = str(dip_goal["next_step"])
```

`next_step` sa prepíše len pri naozaj nízkej nálade (`< 30`) — pri miernom
poklesu (30–49) sa len pridá riadok do `goals`, aby to nezatienilo
dôležitejší „Teraz urob" krok (napr. v roku 902 stále "Prečítaj ciele →
klikni župu → Ďalší mesiac").

## 3. Akceptačné kritériá

- [ ] `PackedStringArray.append()` funguje na `goals` (Godot 4 to
      podporuje priamo, netreba konverziu na `Array`)
- [ ] V roku 907 sa diplomatický riadok **nezobrazuje** (Devín má vlastný
      fokus)
- [ ] Pri čerstvej hre (902, všetky nálady ≥ 50 okrem Hungary) sa
      diplomatický riadok **nezobrazuje** (žiadny falošný poplach hneď na
      začiatku)
- [ ] Zámerne zníž náladu frakcie (napr. cez `threaten` v Diplomacia tabe
      alebo priamym testom `diplomacy_manager.threaten("franks")`
      opakovane) → panel Cieľov ukáže nový riadok s menom frakcie a
      presným číslom nálady
- [ ] Pri náladu < 30 sa zmení aj „Teraz urob"

## 4. Ako overiť po implementácii (rovnaký postup ako doteraz v tejto vetve)

```bash
cd godot
godot --headless --path . scenes/main/Main.tscn --quit   # bez ERROR/SCRIPT ERROR
godot --headless --path . -s tools/smoke_test.gd          # SMOKE_PASS
godot --headless --path . -s tools/smoke_test.m6.gd       # SMOKE_M6_PASS
cd .. && npm run test                                      # 305/305, nedotknuté (zmena je len v godot/)
```

## 5. Stav

Toto je **posledná otvorená položka** z P1 backlogu
(`NAVRH_HERNY_ZAZITOK.md` P1.1–P1.5) — po tomto je celý pôvodný P0+P1
návrh z tejto vetvy hotový.
