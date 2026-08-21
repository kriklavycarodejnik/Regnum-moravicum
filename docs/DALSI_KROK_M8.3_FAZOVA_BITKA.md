# Ďalší krok — M8.3: Fázová bitka s voľbami hráča

> **Stav implementácie (overené k 21. 8. 2026, commit `9898b1c`):**
> - `BattleManager.gd:57-108`: implementované metódy `begin_phased_battle()`, `resolve_phase_round()` a `resolve_decision()`.
> - `BattleManager.gd:110-120`: implementovaná pomocná metóda `pick_ai_action()`.
> - `Main.gd:737-779`: integrované volanie fázovej bitky pre Skirmish (`_on_skirmish()`, `_on_battle_action()`, `_finish_battle()`).
> - `BattleView.gd:70-86, 128-145, 156-159`: implementované akčné tlačidlá (`_actions_row`, `show_actions()`) a vykresľovanie `phase_logs`.
> - **Čo z dokumentu ešte platí / zostáva otvorené:** Fázová bitka je plne funkčná pre Skirmish (`BattleView.gd:70-86, 128-145, 156-159`), pričom aktuálny flow v `Main.gd:737-779` je napojený výhradne na `_on_skirmish()`, takže jej prípadné širšie nasadenie mimo cvičnej bitky zostáva otvorené (riešené samostatnou kartou). Sekcie 0, 1 a pôvodné návrhy nižšie slúžia ako dokumentácia a história rozhodnutí.

---

## 0. Dôležité zistenie — toto NIE JE stavba od nuly

Pri príprave tohto plánu som zistil, že **formulová/config vrstva pre
fázovú bitku už existuje a je čiastočne otestovaná** — len ju nič
nevolá:

- `godot/scripts/battle/BattleConfig.gd` — `ACTION_COUNTER` (melee >
  ranged > flank > melee, presne rock-paper-scissors), `BASE_LOSS_RATE`
  per fáza (`attack`/`counterattack`/`decision`), `ROUT_THRESHOLD`,
  `RETREAT_LOSSES`, RNG rozsahy — všetko hotové, komentár hovorí
  "Port of src/battle/config.ts — source of truth from Phase 2 spec"
- `godot/scripts/battle/BattleFormulas.gd` — `get_action_modifier()`,
  `evaluate_phase()` (straty + zmena morálky pre jedno kolo),
  `evaluate_decision_phase()` (finálny víťaz), `apply_terrain_morale()`,
  `check_rout()` — všetko hotové
- `godot/test/battle/test_battle_formulas.gd` — existujúce gdUnit4 testy
  pokrývajú `calculate_effective_strength`, `get_action_modifier`
  (action counter matrix), `apply_terrain_morale`, `composition_factor`,
  terénne bonusy — formulová vrstva je teda dôveryhodná
- `godot/scenes/battle/BattleView.gd::show_outcome()` **už dnes** vie
  vykresliť `phase_logs` (riadky 111-125) — len ich nikdy nedostane,
  lebo nič ich nevytvára

**Čo chýba:** `BattleManager.gd` má dnes len `auto_resolve()` — jeden
hod kockou bez fáz. Chýba orchestrácia (zavolať `evaluate_phase()`
opakovane, zbierať `phase_logs`, kontrolovať rout) a UI na to, aby
hráč mohol medzi kolami vybrať akciu. **Toto je teda úloha typu
„dokáblovať existujúci systém", nie „navrhni a postav nový" — podobne
ako P0.7 (eventy) a P1.3 (diplomacia) skôr v tejto vetve.** Preto je
odhad nižšie, než pôvodných 1-2 dni.

---

## 1. Rozsah

**Len Skirmish (cvičná bitka).** Devín 907 zostáva na existujúcom
`HungarianWarScenario.resolve_devine_battle()` / `auto_resolve()`
jednorazovom hode — má chránený kánon (`winner == "attacker"`,
`test_devine_907.gd`), ktorý sme si v tejto relácii výslovne potvrdili
ako záväzný. Fázové voľby doňho nezasahujú.

---

## 2. `BattleManager.gd` — pridať orchestráciu (nie meniť `auto_resolve`)

**Súbor:** `godot/scripts/managers/BattleManager.gd`

Pridať tri nové funkcie (ponechať `auto_resolve`/`_evaluate_battle_result`
nezmenené — Devín aj Skirmish's staré volania nech ďalej fungujú, kým sa
Main.gd neprepne na nový flow):

```gdscript
func begin_phased_battle(attacker: Dictionary, defender: Dictionary, terrain: String = "field") -> Dictionary:
	var morale := Formulas.apply_terrain_morale(attacker, defender, terrain)
	var atk := attacker.duplicate(true)
	var def := defender.duplicate(true)
	atk["morale"] = morale["attacker_morale"]
	def["morale"] = morale["defender_morale"]
	return {
		"attacker": atk,
		"defender": def,
		"terrain": terrain,
		"phase_logs": [],
		"routed": ""  # "attacker" | "defender" | "" keď nikto neutiekol
	}


func resolve_phase_round(battle: Dictionary, phase: String, attacker_action: String, defender_action: String) -> Dictionary:
	var atk: Dictionary = battle["attacker"]
	var def: Dictionary = battle["defender"]
	var log: Dictionary = Formulas.evaluate_phase(atk, def, phase, attacker_action, defender_action, battle["terrain"], rng)
	atk["size"] = maxi(0, int(atk.get("size", 0)) - int(log["attacker_losses"]))
	def["size"] = maxi(0, int(def.get("size", 0)) - int(log["defender_losses"]))
	atk["morale"] = clampf(float(atk.get("morale", 50)) + float(log["attacker_morale_change"]), 0.0, 100.0)
	def["morale"] = clampf(float(def.get("morale", 50)) + float(log["defender_morale_change"]), 0.0, 100.0)
	log["phase"] = phase
	log["attacker_action"] = attacker_action
	log["defender_action"] = defender_action
	battle["attacker"] = atk
	battle["defender"] = def
	var logs: Array = battle["phase_logs"]
	logs.append(log)
	battle["phase_logs"] = logs
	if Formulas.check_rout(atk["morale"]):
		battle["routed"] = "attacker"
	elif Formulas.check_rout(def["morale"]):
		battle["routed"] = "defender"
	return battle


func resolve_decision(battle: Dictionary, attacker_action: String = "melee", defender_action: String = "melee") -> Dictionary:
	var winner: String
	if battle.get("routed", "") != "":
		winner = "defender" if battle["routed"] == "attacker" else "attacker"
	else:
		var dec: Dictionary = Formulas.evaluate_decision_phase(battle["attacker"], battle["defender"], attacker_action, defender_action, battle["terrain"], rng)
		winner = dec["winner"]
		var logs: Array = battle["phase_logs"]
		logs.append({"phase": "decision", "winner": winner})
		battle["phase_logs"] = logs
	battle["winner"] = winner
	battle["result"] = _evaluate_battle_result(winner, Formulas.calculate_effective_strength(battle["attacker"], true, battle["terrain"]), Formulas.calculate_effective_strength(battle["defender"], false, battle["terrain"]))
	return battle
```

**AI voľba pre obrancu** (jednoduchá, podľa zloženia armády — pridať ako
súkromnú funkciu, volať z `Main.gd` alebo priamo tu):
```gdscript
func pick_ai_action(army: Dictionary) -> String:
	var comp: Dictionary = army.get("composition", {})
	var cav: float = float(comp.get("cavalry", 0.0))
	var arc: float = float(comp.get("archers", 0.0))
	if float(army.get("morale", 50.0)) <= C.ROUT_THRESHOLD + 10:
		return "retreat"
	if cav >= arc and cav >= float(comp.get("infantry", 0.0)):
		return "flank"
	if arc > cav and arc > float(comp.get("infantry", 0.0)):
		return "ranged"
	return "melee"
```

---

## 3. `BattleView` — pridať 4 akčné tlačidlá

**Súbory:** `godot/scenes/battle/BattleView.gd` (build sa robí kódom, nie
`.tscn` — na rozdiel od `EventPanel`/`ChoiceC` tu netreba upravovať
scénu, `BattleView._build()` vytvára uzly programovo)

**⚠️ Poučenie z Issue #4 (ChoiceC):** ak by sa tlačidlá pridávali do
`.tscn` súboru namiesto `_build()`, MUSÍ sa upraviť aj scéna, nie len
skript — tu to riziko nehrozí, lebo `BattleView` si celý strom stavia
sama v `_build()`.

Pridať signál a 4 tlačidlá pod `_body`:
```gdscript
signal action_chosen(action: String)
...
var _actions_row: HBoxContainer

# v _build(), pred v.add_child(_body):
_actions_row = HBoxContainer.new()
_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
_actions_row.add_theme_constant_override("separation", 8)
for a in ["melee", "ranged", "flank", "retreat"]:
	var b := Button.new()
	b.text = {"melee": "Priamy útok", "ranged": "Streľba", "flank": "Obchvat", "retreat": "Ústup"}[a]
	b.pressed.connect(func(): action_chosen.emit(a))
	_actions_row.add_child(b)
v.add_child(_actions_row)

func show_actions(visible_flag: bool) -> void:
	_actions_row.visible = visible_flag
```
Volať `show_actions(true)` pred každým kolom, `show_actions(false)`
pri finálnom výsledku (v `show_outcome()`, na začiatku).

---

## 4. `Main.gd` — prepojiť flow (nahradiť telo `_on_skirmish()`)

**Súbor:** `godot/scenes/main/Main.gd:176-184` (aktuálny `_on_skirmish`)

Nový flow (round-based, riadený signálom z `BattleView`):
```gdscript
var _active_battle: Dictionary = {}
var _battle_round: int = 0

func _on_skirmish() -> void:
	var attacker := {"faction_id": "moravia", "size": 1000, "morale": 80.0,
		"composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1}, "commander": {"skill": 5}}
	var defender := {"faction_id": "hungary", "size": 800, "morale": 70.0,
		"composition": {"infantry": 0.5, "cavalry": 0.4, "archers": 0.1}, "commander": {"skill": 4}}
	_active_battle = GameManager.war_manager.battle_manager.begin_phased_battle(attacker, defender, "field")
	_battle_round = 0
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	battle_view.call("show_actions", true)
	_set_hero_art("nitra_master_hero", "Cvičná bitka · Nitra")
	battle_view.visible = true

func _on_battle_action(action: String) -> void:
	var bm = GameManager.war_manager.battle_manager
	if _battle_round < 2:
		var phase := "attack" if _battle_round == 0 else "counterattack"
		var enemy_action := bm.pick_ai_action(_active_battle["defender"])
		_active_battle = bm.resolve_phase_round(_active_battle, phase, action, enemy_action)
		_battle_round += 1
		if _active_battle.get("routed", "") != "" or _battle_round >= 2:
			_finish_battle(action)
		else:
			battle_view.call("show_actions", true)
	else:
		_finish_battle(action)

func _finish_battle(last_action: String) -> void:
	var bm = GameManager.war_manager.battle_manager
	var enemy_action := bm.pick_ai_action(_active_battle["defender"])
	_active_battle = bm.resolve_decision(_active_battle, last_action, enemy_action)
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	battle_view.call("show_actions", false)
	_show_battle("Cvičná bitka pri Nitre", _active_battle, "nitra_master_hero")
	_log_battle_phases(_active_battle)
	_notify("Cvičná bitka hotová — späť k mesačným ťahom.")
```

V `_ready()` pripojiť signál (vedľa ostatných `.connect()` volaní):
```gdscript
if battle_view and battle_view.has_signal("action_chosen"):
	battle_view.action_chosen.connect(_on_battle_action)
```

**Poznámka:** `battle_manager` je dnes `var battle_manager` na
`WarManager` (`godot/scripts/managers/WarManager.gd:11`, priradené v
`_init()`), dostupný cez `GameManager.war_manager.battle_manager` —
over presný prístup pred písaním kódu (mohol sa medzitým zmeniť).

---

## 5. Akceptačné kritériá

- [ ] Klik „Cvičná bitka" → zobrazí sa `BattleView` so 4 tlačidlami
      akcií, hra je zablokovaná (next_month/skirmish/devine disabled)
- [ ] Po výbere akcie v kole 1 → vidno straty/moráli v `phase_logs`
      (rovnaký formát, aký `BattleView.show_outcome()` už dnes vie
      vykresliť), zobrazia sa tlačidlá pre kolo 2
- [ ] Ak niektorá strana klesne pod `ROUT_THRESHOLD` (20 morálky),
      bitka sa ukončí predčasne (routed), bez druhého kola
- [ ] Po 2 kolách (alebo routnutí) sa spustí `resolve_decision()`,
      zobrazí sa finálny výsledok, tlačidlá hry sa znova povolia
- [ ] Devín 907 (`_on_devine()`) je **nezmenený** — stále
      `run_devine_battle()`, stále `winner == "attacker"`
- [ ] `action_modifier` matica (melee>ranged>flank>melee) sa reálne
      prejaví — over že voľba kontra súperovej akcii dá lepší pomer
      strát než rovnaká akcia

## 6. Ako overiť

```bash
cd godot
bash tools/check_all.sh
```
Plus manuálne: spusti Skirmish, prejdi obe kolá, over že `test/battle/`
testy (`test_battle_formulas.gd`, `test_battle_manager.gd`) stále
prechádzajú — nová orchestrácia im nemá zasahovať do existujúcich
funkcií.

## 7. Odhad

Vzhľadom na bod 0 — formuly a config sú hotové a otestované, chýba len
orchestrácia (BattleManager, ~40 riadkov), UI tlačidlá (BattleView,
~20 riadkov) a flow v Main.gd (~40 riadkov). Realisticky niekoľko hodín
sústredenej práce, nie 1-2 dni.
