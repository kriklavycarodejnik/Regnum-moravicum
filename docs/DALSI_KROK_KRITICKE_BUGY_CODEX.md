# Ďalší krok — KRITICKÉ: 3 bugy z Codex review na PR #6

> **Stav implementácie (overené k 21. 8. 2026, commit `9898b1c`):**
> - **Nález 1 (VYRIEŠENÉ):** `GameManager.gd:123-142` — implementovaná podpora pre `TYPE_ARRAY` aj `TYPE_DICTIONARY` v `get_pending_event()`. Voľby sa správne načítavajú z katalógu.
> - **Nález 2 (VYRIEŠENÉ):** `EventManager.gd:139-140` — `_try_historical_event()` explicitne preskakuje eventy s `req_year == 0` (`if req_year == 0: continue`), zabraňuje tak nežiaducemu zablokovaniu behu na náhodných eventoch.
> - **Nález 3 (VYRIEŠENÉ):** `MainMenu.gd:47` — `_on_new()` volá `GameManager.reset()` pred prepnutím scény do Briefingu.
> - **Čo z dokumentu ešte platí / zostáva otvorené:** Všetky 3 kritické bugy sú kompletne opravené v codebase (`GameManager.gd:123-146`, `EventManager.gd:130-150`, `MainMenu.gd:46-49`). Dokument slúži ako historická referencia review a popisu fixov.

**Pôvod:** automatizovaný review `@chatgpt-codex-connector[bot]` na
[PR #6](https://github.com/kriklavycarodejnik/Regnum-moravicum/pull/6),
nezávisle overené v aktuálnom kóde (`HEAD = ad0b082`) — všetky 3 nálezy
potvrdené, nie falošný poplach.

---

## 1. (KRITICKÉ) `GameManager.get_pending_event()` zahadzuje voľby z portovaných eventov

**Súbor:** `godot/autoloads/GameManager.gd:112-134`

**Problém:** Táto funkcia berie `pending.get("choices", {})` a spracuje ich
len ak je to `TYPE_DICTIONARY`:
```gdscript
var choices_dict = pending.get("choices", {})
var choices_array = []
if typeof(choices_dict) == TYPE_DICTIONARY:
    for choice_id in choices_dict.keys():
        ...
```
Ale **všetkých 16 eventov v `events_catalog.json` má `choices` ako
`Array`**, nie Dictionary (over: `python3 -c "import json; d=json.load(open('godot/data/events_catalog.json')); print(type(d[0]['choices']))"` → `list`). Len fallback „Rada županov" (`_build_council_event()`
v `EventManager.gd`) má `choices` ako Dictionary.

**Dôsledok:** pre každý event z katalógu vráti táto funkcia `choices: []`
→ `Main._show_event()` skryje všetky tlačidlá voľby a zablokuje
`next_month_btn`/`skirmish_btn`/`devine_btn` → hráč sa nemá ako pohnúť
ďalej.

### Fix

Nahradiť blok na riadkoch 122-132 (`godot/autoloads/GameManager.gd`):

```gdscript
var choices_v = pending.get("choices", {})
var choices_array = []
if typeof(choices_v) == TYPE_ARRAY:
    for choice in choices_v:
        if typeof(choice) == TYPE_DICTIONARY:
            choices_array.append({
                "id": str(choice.get("id", "")),
                "label": str(choice.get("text", choice.get("label", ""))),
                "effect": choice.get("effect", {})
            })
elif typeof(choices_v) == TYPE_DICTIONARY:
    for choice_id in choices_v.keys():
        var choice = choices_v[choice_id]
        if typeof(choice) == TYPE_DICTIONARY:
            choices_array.append({
                "id": choice_id,
                "label": choice.get("text", ""),
                "effect": choice.get("effect", {})
            })
```

Zachováva pôvodnú Dictionary vetvu (fallback council event) a pridáva
Array vetvu (katalógové eventy). Tvar výstupu (`{"id", "label", "effect"}`
v `choices_array`) ostáva nezmenený — `Main._show_event()`/`_normalize_event()`
netreba meniť.

---

## 2. (KRITICKÉ) `EventManager._try_historical_event()` — `year: 0` sa vyhodnotí ako zhoda

**Súbor:** `godot/scripts/managers/EventManager.gd:102-122`

**Problém:**
```gdscript
var req_year: int = int(conds.get("year", 0)) if typeof(conds) == TYPE_DICTIONARY else 0
if req_year != 0 and y != req_year:
    continue
```
6 „random"-typových eventov (`rand_bad_harvest`, `rand_traveling_merchant`,
`rand_noble_feud`, `rand_border_raid`, `rand_missionary_dispute`,
`rand_court_intrigue`) má v JSONe **explicitne** `"year": 0` (nie chýbajúci
kľúč — over: `conditions` majú `{'yearMin': 903, 'year': 0}`). Pri
`req_year == 0` je `req_year != 0` vždy `false`, takže sa **nikdy
neskipne** — prvý takýto event v poradí katalógu (`rand_bad_harvest`) sa
vyberie ako „historický" pri **každom mesiaci od roku 902**, ešte pred
tým, než sa vôbec spustí vážený výber v `_try_random_event()`.

**Dôsledok (v kombinácii s bodom 1):** od druhého ťahu (902/02) sa vždy
vyberie `rand_bad_harvest`, jeho `choices` sa vyprázdnia bugom č. 1, hráč
nemá čo kliknúť → **hra sa zasekne natrvalo v druhom mesiaci.** Zvyšných
5 random eventov sa navyše nikdy nedostane na rad, pretože `rand_bad_harvest`
matchne skôr, než sa cyklus vôbec dostane k váženému výberu.

### Fix

Nahradiť riadky 108-110 (`godot/scripts/managers/EventManager.gd`):

```gdscript
var req_year: int = int(conds.get("year", 0)) if typeof(conds) == TYPE_DICTIONARY else 0
if req_year == 0:
    continue
if y != req_year:
    continue
```

Event bez skutočného `year` v podmienkach už nikdy nebude posudzovaný
ako „dátumovaný historický" — korektne prepadne do `_try_random_event()`,
kde ho zachytí `yearMin`/`weight`/`cooldownTicks` logika, presne ako bolo
zamýšľané. Nemení to spracovanie `chainOnly` eventov (tie sa aj tak
riešia cez `_try_chain_event()`, nie cez tento scan).

---

## 3. `MainMenu._on_new()` — GameManager sa nereštartuje pri Novej hre

**Súbor:** `godot/scenes/menu/MainMenu.gd:46-48`

**Problém:**
```gdscript
func _on_new() -> void:
    get_tree().change_scene_to_file("res://scenes/briefing/Briefing.tscn")
```
`GameManager` je autoload (singleton) — `_bootstrap()` (`godot/autoloads/GameManager.gd:27`)
beží len raz, pri štarte hry (`_ready()`). „Nová hra" len prepne scénu,
nikdy nezresetuje `game_state`. Ak sa hráč v rámci jedného behu procesu
vráti do menu (napr. cez `Main._on_menu()`, ktorý `GameManager.save()`-ne
a prepne scénu) a klikne „Nová hra" znova, ďalšia hra pokračuje zo
starého roku/zdrojov/frakcií namiesto čerstvého štartu v roku 902.

### Fix

**1)** V `godot/autoloads/GameManager.gd` pridať verejnú metódu (napr. za
`load_save()`):
```gdscript
func reset() -> void:
    _bootstrap()
```
(`_bootstrap()` je bezpečné zavolať opakovane — vytvára `game_state` aj
všetky managery úplne odznova cez `.new()`, žiadne signály sa v nej
nepripájajú.)

**2)** V `godot/scenes/menu/MainMenu.gd::_on_new()`:
```gdscript
func _on_new() -> void:
    GameManager.reset()
    get_tree().change_scene_to_file("res://scenes/briefing/Briefing.tscn")
```

---

## Akceptačné kritériá

- [ ] Nová hra, klikni „Ďalší mesiac" 3-4×, kým nepríde event z katalógu
      (napr. `rand_bad_harvest` alebo dátumovaný `hist_papal_legation_903`
      v roku 903) → **musia byť viditeľné a klikateľné voľby**, nie prázdny
      panel
- [ ] Za viac ako 12 odohraných mesiacov by sa mali objaviť **rôzne**
      eventy (nielen `rand_bad_harvest` opakovane) — over v kronike
- [ ] Historické dátumované eventy (903, 904, 906, 910, 915) stále
      fungujú presne vo svojom roku (nezregresovalo bodom 2)
- [ ] Odohraj kus hry → Menu → Nová hra → over, že `story_line`/`StatusBar`
      ukazuje rok 902, zlato 1000, žiadne staré eventy v kronike

## Ako overiť (rovnaký postup ako doteraz)

```bash
cd godot
bash tools/check_all.sh   # 4 kontroly jedným príkazom (M8.1)
```
Plus **manuálne** prehratie aspoň 6-12 ťahov v Main.tscn — toto je presne
trieda bugu, ktorú `check_all.sh`/smoke testy nezachytia (testujú len
počiatočný stav pri 902/01, nie priebeh hry cez viac ťahov).

## Odporúčanie na budúce zabránenie tejto triede chýb

Zvážiť rozšírenie `smoke_test.gd` o krok, ktorý zavolá
`GameManager.process_next_month()` v cykle (napr. 24×) a po každom
volaní, ak `GameManager.has_pending_event()`, over
`GameManager.get_pending_event().choices.size() > 0`. Toto by bolo
bod 1+2 odhalilo automaticky, bez závislosti na externom code review.
