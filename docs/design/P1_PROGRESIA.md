# P1 Progresia — side-goals s odmenou a vizuálna progresia mapy

> **Toto je dizajnový kontrakt, nie implementácia.** Špecialisti (`rm-godot`,
> `rm-core`) čítajú tento súbor ako zdroj pravdy pre karty `t_ba3d04ce`
> (side-goals) a `t_cc9a8c3d` (vizuálna progresia mapy).
>
> **Rozlíšenie existujúceho stavu a plánu:** Každá sekcia nižšie uvádza,
> čo je HOTOVÉ v kóde (overiteľné dnes) a čo je IMPLEMENTAČNÝ KONTRAKT
> (musí byť implementované podľa týchto kritérií). Sekcia §Akceptačné
> kritériá zhŕňa overiteľné body pre každú kartu.

**Zdroje pravdy overené voči kódu (commit fix/p1-kontrakt-clean):**
- `docs/design/P1_KONTRAKT.md` — beaty A1-D1, threat markery, invarianty
- `docs/NAVRH_HERNY_ZAZITOK.md` §4, §5, §15.6 (Devín kánon)
- `docs/GAMEPLAY_LOOP.md` — fázy kampane
- `docs/VISUAL_DIRECTION.md` — farebná paleta, MapView fáza A/B
- `godot/ui/ObjectivesPanel.gd` — `compute_beats()`, riadky 112-245
- `godot/scenes/map/MapView.gd` — `_draw()`, riadky 204-413
- `godot/scripts/core/GameState.gd` — fieldy, `to_dict` / `from_dict`, riadky 1-136
- `godot/scripts/managers/EconomyManager.gd` — prosperity growth (+0.5/mesiac), riadok 40
- `godot/scripts/managers/DiplomacyManager.gd` — `send_gift`, `set_treaty`, `list_factions`
- `godot/scripts/managers/VictoryManager.gd` — `check_victory()`, riadky 13-55
- `godot/scripts/managers/EventManager.gd` — `resolve_choice()`, riadky 215-338
- `godot/data/events_catalog.json` — 13+ statických eventov

---

## 1. Side-goals s odmenou

### 1.1 Problém

Dnes sú `goals` v `ObjectivesPanel.compute_beats()` len `PackedStringArray`
viet — „Zbieraj zlato", „Priprav sa na rok 907". Žiadna podmienka splnenia,
žiadny pokrok, žiadna odmena. Text, ktorý sa nikdy nesplní, je dekorácia.

### 1.2 Dátový model — IMPLEMENTAČNÝ KONTRAKT (nie je v kóde)

Nový `GameState` field:

```
var side_goals: Dictionary = {}
```

- Kľúč = `goal_id` (snake_case, napr. `"sg_a1"`)
- Hodnota = `true` (splnený; raz splnený, ostáva splnený)
- `to_dict()`: `"side_goals": side_goals.duplicate(true)`
- `from_dict()`: `side_goals = data.get("side_goals", {}).duplicate(true) if typeof(data.get("side_goals")) == TYPE_DICTIONARY else {}`
- Default: `{}` (prázdny — nič splnené)
- Staré savey bez `side_goals` načítajú prázdny dict — backward-compat.

### 1.3 Vyhodnotenie — IMPLEMENTAČNÝ KONTRAKT (nie je v kóde)

Nová static funkcia v `ObjectivesPanel.gd`:

```gdscript
static func compute_side_goals(s) -> Array:
    # Vráti Array of Dictionary, každý s:
    #   id: String, beat: String, label: String,
    #   progress: String, done: bool, reward_text: String
```

- Volané z `refresh()` popri `compute_beats()`.
- `progress` je formátovacia reťazca s aktuálnou hodnotou a cieľom
  (napr. `"Pokladnica: 650/1200 zlatých"`).
- `done` sa vypočíta z `game_state` (nie z náhody).
- Pri splnení: `s.side_goals[id] = true` (one-shot).

### 1.4 Štruktúra side-goal záznamu

| Položka | Popis |
|---|---|
| **id** | snake_case, napr. `sg_a1` |
| **beat** | Ku ktorému beatu patrí: `A2`, `A3`, `A4`, `B1`, `B2`, `C2`, `C3`, `D1` |
| **active_window** | Rokové okno, kedy je cieľ viditeľný a hodnotiteľný |
| **label** | Slovenský názov (napr. „Byzantský dvor") |
| **condition** | Výraz čitateľný z `game_state` |
| **progress** | Formát s aktuálnou/cieľovou hodnotou |
| **cost** | Čo hráč obetuje (v akých menách, konkrétne čísla) |
| **reward** | Popis odmeny + mechanika (§1.6) |

### 1.5 Side-goals per fáza

#### Fáza I — Konsolidácia (902–906)

**SG-A1: Zlatá rezerva Mojmíra**

| | |
|---|---|
| Beat | A2 (year < 906, gold < 800) |
| Active window | year < 906 (902/01 – 905/12) |
| Condition | `resources.gold >= 1200` |
| Initial | resources.gold = 1000 (GameState riadok 19); s upkeepom ~200/mesiac klesá pod 800, potom rastie |
| Progress | `"Pokladnica: {gold}/1200 zlatých"` |
| Reward | Army wizard W2 ponúkne darmo template „Ťažká jazda" (normálne stojí –100 zlata). **Prejav v hre:** ArmyUI template panel ukazuje cenu 0 namiesto 100 pre ten template ak `side_goals["sg_a1"]`. Implementácia: `Main._show_army_wizard()` alebo `ArmyUI` číta `side_goals["sg_a1"]` a ak true, nastaví cenu = 0. |
| Cost | Hráč musí ušetriť 200 zlatých nad štart (1 000) napriek upkeepu (~200/mesiac) — to trvá ~12 mesiacov tlačenia „Ďalší mesiac". Každý mesiac je mesiac bez diplomacie/darov (oportunita: 3× gift = 150 zlata + 30 mood frakcie). |

**SG-A2: Byzantský dvor**

| | |
|---|---|
| Beat | A3–A4 (year < 907) |
| Active window | year < 907, month >= 2 (po tutorial beat A1) až year == 906 |
| Condition | `factions["byzantium"].mood >= 60` |
| Initial | byzantium.mood = 50 (DiplomacyManager riadok 30) |
| Progress | `"Byzancia: {mood}/60"` |
| Reward | `byz_bride_proposal_906` (existujúci event) → voľba „accept" dáva +5 prestíže navyše. **Prejav v hre:** po sobáši chronicle ukazuje „+5 prestíže navyše vďaka byzantskému dvoru". Implementácia: `EventManager.resolve_choice()` po aplikovaní effectu z katalógu skontroluje `game_state.side_goals.get("sg_a2", false)` a ak true a `event_id == "byz_bride_proposal_906"` a `choice_result == "accept"`, pridá `prestige: 5` do effectu. |
| Cost | Tri dary Byzancii: 3 × 50 zlata = −150 zlata (DiplomacyManager.send_gift, riadok 106). Každý mesiac bez daru hrozí, že iná frakcia klesne pod prah — ak mood akejkoľvek frakcie < 30, ObjectivesPanel ukazuje varovanie (riadok 284). Oportunita: −150 zlata mohlo ísť do armády (2× ťažká jazda). |

**SG-A3: Pohraničná stráž**

| | |
|---|---|
| Beat | A3 (year < 906) |
| Active window | year < 906, gold >= 800 (po A2) |
| Condition | Existuje armáda s `province_id` v `["zemplin", "uzhorod"]` a `owner == "moravia"` |
| Progress | `"{count}/1 armáda na východnej hranici"` (count = počet moravských armád v zemplín/uzhorod) |
| Reward | `hist_magyar_reports_902` (existujúci event) → voľba „scouts" dáva +5 zupaLoyalty zemplín navyše. **Prejav v hre:** event chronicle ukazuje extra lojalitu zemplín ak je hranica strážená. Implementácia: `EventManager.resolve_choice()` — ak `side_goals["sg_a3"]` a `event_id == "hist_magyar_reports_902"` a `choice == "scouts"`, pridá `zupaLoyalty: {"zemplin": 5}`. |
| Cost | Armáda v zemplín/uzhorod stojí: army upkeep (gold), army_food (jeden vojak = 1/50 food/mesiac, EconomyManager riadok 68). Po dobu ~12 mesiacov je armáda na hranici a nedá sa použiť inde (oportunita: bitka, obliehanie). |

#### Fáza II — Kríza (907)

**SG-B1: Devínska posádka**

| | |
|---|---|
| Beat | B1 (year == 907, !devine_resolved) |
| Active window | year == 907, !devine_resolved (maximálne 12 mesiacov, ukončené resolve Devína) |
| Condition | `army_wizard_done == true` |
| Progress | Ak `!army_wizard_done`: `"Wizard: nedokončený"`. Ak `army_wizard_done`: `"Wizard: hotový ✓"`. |
| Reward | Po Devíne (B2) sa zmení diplomacia s Maďarmi: `set_treaty("nap", "hungary")` dá +15 mood namiesto +6. **Prejav v hre:** po uzavretí NAP s Maďarmi chronicle ukazuje +15 namiesto +6. Implementácia: `DiplomacyManager.set_treaty()` — ak `game_state.side_goals.get("sg_b1", false)` a `faction_id == "hungary"` a `treaty == "nap"`, mood delta = +15 namiesto +6 (riadok 167). |
| Cost | Armádu z wizarda treba zaplatiť (template cost, zvyčajne −100 zlata) a udržiavať (upkeep ~50/mesiac). Wizard zaberá mesiace 906/06–907 (6 mesiacov), počas ktorých sa nedá robiť iná akcia v ArmyUI. |

**Poznámka:** `army_wizard_done` je v `GameState` (riadok 40), nie `army_wizard_step`
(inštančná premenná v Main.gd, neukladá sa). Progress ukazuje done/not-done,
nie krok wizardu — krok nie je čitateľný zo `game_state`.

**SG-B2: Záchrana Devína**

| | |
|---|---|
| Beat | B2 (devine_resolved == true) |
| Active window | Rok po Devíne: od `devine_resolved` do year >= 910 (ciel je dosiahnuteľný v ~2 rokoch ak hráč koná) |
| Condition | `provinces["devin"].loyalty >= 35` |
| Initial after Devín | devin.loyalty = 40 (kánon §15.6: 60 − 20) |
| Progress | `"Devín lojalita: {loyalty}/35"` |
| Reward | Devín prosperity growth +1.0/mesiac namiesto +0.5 (zotavenie je 2× rýchlejšie). **Prejav v hre:** Devín settlement marker (small → medium → large) sa posúva 2× rýchlejšie ako iné župy. Implementácia: `EconomyManager.process_economy()` — ak `game_state.side_goals.get("sg_b2", false)`, pre province_id == "devin" pridá +0.5 navyše (riadok 40: `prosperity = clampf(prosperity + 1.0, 0.0, 100.0)` namiesto `+ 0.5`). |
| Cost | Každý event choice, ktorý zvýši loyalty Devína, je choice, ktorý NEzvýši inú župu. Konkrétne: council event „odmeniť darmi" (riadok 365–386) dá +5 všetkým — ak ho použiješ pre Devín, je to v poriadku, ale ak si ho necháš na neskôr, Devín sa spamätáva pomalšie. Alternatívne: eventy s `zupaLoyalty` pre Devín sú vzácne (len council event). Hráč platí opportunity cost: omeškanie iných žúp. |

#### Fáza III — Prežitie (908–959)

**SG-C1: Užhorod stojí**

| | |
|---|---|
| Beat | C2 (915–919) |
| Active window | 915–919 (Bogata conspiracy window) |
| Condition | `provinces["uzhorod"].loyalty >= 40` |
| Initial | uzhorod.loyalty = 60 (z JSON); po Bogata chain môže klesnúť až na 30 |
| Progress | `"Užhorod: {loyalty}/40"` |
| Reward | `hist_bogata_conspiracy_915` (existujúci event) → voľba „watch" dáva +10 zupaLoyalty uzhorod namiesto 0. **Prejav v hre:** po Bogatovom sprisahaní chronicle ukazuje „Užhorod lojalita +10" ak je strážený. Implementácia: `EventManager.resolve_choice()` — ak `side_goals["sg_c1"]` a `event_id == "hist_bogata_conspiracy_915"` a `choice == "watch"`, pridá `zupaLoyalty: {"uzhorod": 10}`. |
| Cost | Udržať Užhorod nad 40 lojality počas 4 rokov (915–919) vyžaduje ~2 event choices zamerané na Užhorod namiesto iných žúp. Každý takýto choice nezvýši inú župu o 5–10 lojality. Oportunita: 10–20 lojality pre inú župu je 10–20 lojality pre Užhorod. |

**SG-C2: Kresťanská ríša**

| | |
|---|---|
| Beat | C3 (920–959) |
| Active window | 920–959 (38 rokov) |
| Condition | Počet žúp s `religion >= 55` >= 6 |
| Initial | 1 župa (morava: 55, z JSON). Ostatné župy: religion = 35–50. |
| Progress | `"{count}/6 žúp s kresťanskou vierou (religion >= 55)"` |
| Reward | **Zmena eventu `byz_bride_proposal_906`:**  keď je splnený SG-C2 a hráč vyberie voľbu „accept" v `byz_bride_proposal_906`, pridá sa +3 religion drift do provincie morava (okrem normálnych effectov). **Prejav v hre:** chronicle: „Byzantská nevesta posilňuje kresťanskú vieru na Morave." Implementácia: `EventManager.resolve_choice()` — ak `side_goals["sg_c2"]` a `event_id == "byz_bride_proposal_906"` a `choice == "accept"`, zavolá `_religion_shift(3)` (ale len na morava provinciu, nie na všetky). Toto je **bonus lookup v existujúcom evente**, nie nový event. |
| Cost | Zvýšiť 5 žúp z < 55 na >= 55. Religion drift je pomalý: v kóde `ReligionManager` (existuje v `godot/scripts/managers/ReligionManager.gd`) — mesačná šanca ~5% na jednu župu. Priemerný čas: ~20 mesiacov na župu = ~100 mesiacov = ~8 rokov. Počas týchto rokov hráč využíva eventy s `religionChange` effect (napr. byz_bride dáva +5), čo stojí −50 zlata alebo −5 lojality inde. Konkrétny rozpočet: ~5 eventov × 50 zlata = −250 zlata počas 30 rokov. |

#### Fáza IV — Cesta k 1000 (960+)

**SG-D1: Sto rokov Mojmíra**

| | |
|---|---|
| Beat | D1 (year >= 960) |
| Active window | year >= 960 |
| Condition | `resources.prestige >= 80` |
| Initial | prestige = 50 (GameState riadok 11); rastie cez eventy (coronation +10, papal +5, bride +3) a diplomacy (threaten +2) |
| Progress | `"Prestíž: {prestige}/80"` |
| Reward | **Zlepšená obchodná zmluva:** `set_treaty("trade", ANY_faction)` dáva +8 mood namiesto +6 A +3 prestíže navyše pri uzavretí. **Prejav v hre:** chronicle: „Obchodná zmluva posilňuje prestíž Moravy (+3)." Implementácia: `DiplomacyManager.set_treaty()` — ak `game_state.side_goals.get("sg_d1", false)` a `treaty == "trade"`, mood delta = +8 namiesto +6 (riadok 167) a prestige = current + int(resources.get("prestige",0)) + 3. Toto mení effectiveness existujúcej diplomatickej akcie, nepridáva novú. |
| Cost | Získať +30 prestíže (50 → 80). Jedna cesta: threaten (2 prestíže, −8 mood frakcie). Potrebných 15 threaten = −120 mood celkovo rozložené medzi frakcie. Každý threaten je mesiac bez giftu (oportunita: −10 mood za dar). Alternatíva: eventy — potrebné ~3 korunovačné eventy (každý +10 prestíže, ale sú zriedkavé, 1/20 random eventov). Konkrétny rozpočet: ~5–10 rokov cielenej diplomacie, −120 mood frakcií, ~500–1000 zlata na dary na udržanie vzťahov. |

**SG-D2: Posledná dynastia**

| | |
|---|---|
| Beat | D1 (year >= 960) |
| Active window | year >= 960 |
| Condition | `_count_living_dynasty() >= 3` (3+ žijúci Mojmírovci) |
| Progress | `"{count}/3 žijúci Mojmírovci"` |
| Reward | **Rozšírená rada županov:** Pri evente `council` (`_build_council_event`, EventManager riadok 357) pribudne štvrtá voľba „Rozšíriť dynastiu" — stojí −50 zlata, dáva +2 prestíže, +5 zupaLoyalty uzhorod a zemplin. **Prejav v hre:** v eventovom okne „Rada županov" je nová voľba ak je dynastia silná. Implementácia: `EventManager._build_council_event()` — ak `game_state.side_goals.get("sg_d2", false)`, pridá do choices kľúč `extend_dynasty` s efektom `{gold: -50, prestige: 2}` a `zupaLoyalty: {uzhorod: 5, zemplin: 5}`. Toto je modifikácia existujúceho eventu, nie nový event. |
| Cost | Udržať 3+ Mojmírovcov nažive počas 40+ rokov (960–1000). Každý šľachtic stojí upkeep (prestige * 2 gold/mesiac, EconomyManager riadok 57 — napr. 3 × 10 × 2 = 60 gold/mesiac). Každý succession event (smrť, sobáš) stojí lojalitu (−5 až −10 župy). Hrozba dynasty_extinct defétu (VictoryManager riadok 39) ak počty klesnú pod 1. Konkrétny rozpočet: udržať 3+ šľachticov 40+ rokov = ~28 800 gold na upkeep (60×12×40) + eventová lojalita −5 až −10 per event. |

### 1.6 Odmena — implementačný kontrakt

Odmeny sa aplikujú cez **side_goals flag lookup** v štyroch existujúcich systémoch.
Žiadny nový systém, žiadne nové eventy (okrem bonusovej voľby v council,
ktorá je modifikácia existujúceho), žiadne nové diplomatické akcie.

| Systém | Kde | Čo robí | Pre ktorý goal |
|---|---|---|---|
| `EventManager.resolve_choice()` | Po aplikovaní effectu z katalógu | Skontroluje `game_state.side_goals.get(goal_id, false)` a pridá bonus effect (extra prestige, zupaLoyalty, religion) | sg_a2 (+5 preštíže), sg_a3 (+5 zemplin), sg_c1 (+10 uzhorod), sg_c2 (+3 religion morava) |
| `DiplomacyManager.set_treaty()` | Pri výpočte mood delta | Skontroluje side_goals a zmení mood bonus | sg_b1 (nap hungary +15), sg_d1 (trade +8 mood +3 prestige) |
| `EconomyManager.process_economy()` | Pri prosperity growth pre devin | Skontroluje `side_goals["sg_b2"]` a pridá +0.5 bonus | sg_b2 (devin +1.0/mesiac) |
| `Main._show_army_wizard()` / `ArmyUI` | Pri wizard W2 template | Skontroluje `side_goals["sg_a1"]` a ponúkne template zadarmo | sg_a1 (cena 0) |
| `EventManager._build_council_event()` | Pri generovaní council eventu | Pridá štvrtú voľbu ak `side_goals["sg_d2"]` | sg_d2 (rozšíriť dynastiu) |

**Lookup table** (hardcoded v každom systéme ako match/if):

```
# EventManager.resolve_choice() bonus lookup:
if event_id == "byz_bride_proposal_906" and choice == "accept":
    if side_goals.get("sg_a2"):
        effect["prestige"] = int(effect.get("prestige", 0)) + 5
    if side_goals.get("sg_c2"):
        _religion_shift_province("morava", 3)

if event_id == "hist_magyar_reports_902" and choice == "scouts":
    if side_goals.get("sg_a3"):
        var zl = effect.get("zupaLoyalty", {})
        zl["zemplin"] = int(zl.get("zemplin", 0)) + 5
        effect["zupaLoyalty"] = zl

if event_id == "hist_bogata_conspiracy_915" and choice == "watch":
    if side_goals.get("sg_c1"):
        var zl2 = effect.get("zupaLoyalty", {})
        zl2["uzhorod"] = int(zl2.get("uzhorod", 0)) + 10
        effect["zupaLoyalty"] = zl2

# DiplomacyManager.set_treaty() bonus lookup:
if faction_id == "hungary" and treaty == "nap":
    var base_mood: float = 6.0
    if side_goals.get("sg_b1"):
        base_mood = 15.0
    f["mood"] = clampf(float(f.get("mood", 50.0)) + base_mood, ...)

if treaty == "trade":
    var base_mood: float = 6.0
    if side_goals.get("sg_d1"):
        base_mood = 8.0
        resources["prestige"] = int(resources.get("prestige", 0)) + 3

# EconomyManager.process_economy() bonus lookup:
var growth: float = 0.5
if province_id == "devin" and game_state.side_goals.get("sg_b2", false):
    growth = 1.0
prosperity = clampf(prosperity + growth, ...)

# EventManager._build_council_event() extra choice:
if game_state.side_goals.get("sg_d2", false):
    choices["extend_dynasty"] = {
        "id": "extend_dynasty",
        "text": "Rozšíriť dynastiu — poslať synov na východ",
        "effect": {"gold": -50, "prestige": 2},
        "zupaLoyalty": {"uzhorod": 5, "zemplin": 5}
    }
```

### 1.7 UI — zobrazenie v ObjectivesPanel — IMPLEMENTAČNÝ KONTRAKT

Side-goals sa zobrazia v `_goals_label` popri existujúcich beat goals.

Formát:

```
Fáza I — Konsolidácia (902–906)
• Prežiť ako dynastia do 1000
• Zbieraj zlato a jedlo („Ďalší mesiac")
• Priprav sa na rok 907

Vedľajšie ciele:
• Pokladnica: 650/1200 zlatých — odmena: ťažká jazda zadarmo
• Byzancia: 45/60 — odmena: +5 prestíže zo sobáša
• 0/1 armáda na východnej hranici — odmena: správy o Maďaroch
```

- Splnený side-goal sa zobrazí ako `✓ {label}` (zelenou, `C.SUCCESS`).
- Nesplnený sa zobrazí s progress textom.
- `army_wizard_done` side-goal (SG-B1) sa zobrazí len v Fáze II.
- Dnes `ObjectivesPanel` nemá farebné riadky — `C.SUCCESS` je cieľový stav,
  implementácia použije `add_theme_color_override("font_color", C.SUCCESS)` na
  Label text.

---

## 2. Vizuálna progresia mapy

### 2.1 Problém

Dnes mapa v 902 a mapa v 920 vyzerajú rovnako. `MapView._draw()` farbí polygón
podľa `faction_color(owner)` + `prosperity` settlement marker (riadky 322–325),
ale prosperita rastie len +0.5/mesiac a nič ju systematicky neznižuje. Po
Devíne 907 sa Devín loyalty zníži o −20 (kánon), ale vizuálne sa nič nezmení
okrem loyalty ringu a threat markeru.

### 2.2 Devastácia po Devíne 907 — IMPLEMENTAČNÝ KONTRAKT (nie je v kóde)

**Trigger:** `devine_resolved == true` (aplikuje sa jedenkrát, pri resolve).

**Postihnuté župy:**

| Župa | Prosperity delta | Loyalty delta | Zdroj |
|---|---|---|---|
| `devin` | −20 (40 → 20) | −20 (60 → 40) | Kánon §15.6 (loyalty) + tento kontrakt (prosperity) |
| `bratislava` | −10 (60 → 50) | 0 | Sused Devína — palivová línia |

**Implementácia prosperity delta:**
V `GameManager.run_devine_battle()` alebo `WarManager` po úspešnom resolve
(`devine_resolved = true`), aplikovať:

```gdscript
var devin = game_state.provinces["devin"]
devin["prosperity"] = clampf(float(devin.get("prosperity", 40)) - 20.0, 0.0, 100.0)
game_state.provinces["devin"] = devin

var bratislava = game_state.provinces["bratislava"]
bratislava["prosperity"] = clampf(float(bratislava.get("prosperity", 60)) - 10.0, 0.0, 100.0)
game_state.provinces["bratislava"] = bratislava
```

**Kánon:** Loyalty −20 je záväzná (§15.6). Prosperity −20/−10 je nová
mechanika — kánon ju nezakazuje, len nezahŕňa.

### 2.3 Vizuálne zmeny v MapView._draw() — IMPLEMENTAČNÝ KONTRAKT

**Pravidlá:**

1. **Prosperita svetlí/tmaví polygón** (non-art provinces, riadok 319+):

| Prosperity | Fill | Settlement marker |
|---|---|---|
| >= 70 | `fill.lightened(0.15)` | large (už existuje, riadok 323) |
| 30–69 | `fill` (normálny) | medium (už existuje) |
| < 30 | `fill.darkened(0.40)` | small (už existuje, riadok 326) |

Dnes MapView (riadok 328–330) robí len `fill = fill.lightened(0.08)` a
`fill.a = 0.92`. **Tento kontrakt** mení blok `else` (riadok 319) na:

```gdscript
var prosperity: float = float(pdata.get("prosperity", 50))
if prosperity >= 70:
    fill = fill.lightened(0.15)
elif prosperity < 30:
    fill = fill.darkened(0.40)
fill.a = 0.92
```

2. **Devastation tint** — Devín a Bratislava po Devíne:

Po `draw_colored_polygon(poly, fill)` (riadok 331):

```gdscript
if devine_resolved and (pid == "devin" or pid == "bratislava"):
    var dev_tint := Color(0.25, 0.05, 0.05, 0.25)  # crimzon tint nad fillom
    draw_colored_polygon(poly, dev_tint)
```

Tint je semi-transparentný — neprekrýva faction fill, len sa pridá cez neho.

3. **Recovery indikátor** — ak `side_goals["sg_b2"]` (Záchrana Devína):

Devín prosperity growth +1.0/mesiac (§1.5 SG-B2 reward). Settlement marker
sa posunie z small → medium → large 2× rýchlejšie ako bez bonusu.

### 2.4 Čitateľnosť bez legendy

Hint strip (riadok 405) sa zmení z:

```
Klikni na župu · zlatý kruh = výber · farba okraja = lojalita
```

na:

```
Klikni na župu · zlatý = výber · okruh = lojalita · bledosť = prosperita
```

Hráč vidí:
- **Tmavší polygón** = prosperita klesá (červenkastý tint po Devíne = skaza)
- **Svetlejší polygón** = prosperita rastie
- **Loyalty ring** (už existuje, riadok 364) = green/amber/crimson
- **Threat marker** (už existuje, riadok 370) = crimson arc pri loyalty < 30

Bez novej legendy. Tint a bledosť sú samopopisné — hráč po prvom Devíne
automaticky spája „Devín je tmavší" s „Devín padol".

### 2.5 Kolízia s threat markermi

| Prvok | Umiestnenie | Kolízia s tintom? |
|---|---|---|
| Devastation tint | Vnútri polygóna (fill) | Nie — tint je fill, threat marker je arc vonku |
| Threat marker (loyalty < 30) | max_r + 8.0 (mimo polygóna, riadok 370) | Nie — arc je mimo polygóna |
| Loyalty ring | max_r + 4.0 (riadok 364) | Nie — ring je mimo polygóna |
| Settlement marker | Na centre polygóna (riadok 343) | Tint je pod markerom — marker je stále viditeľný |

### 2.6 Nepostihnuté župy

Župy, ktoré nie sú Devín/Bratislava, sa nemenia vizuálne po Devíne. Ich
prosperita stúpa prirodzene (+0.5/mesiac cez EconomyManager). Hráč vidí
kontrast: Devín a Bratislava sú tmavé, ostatné svetlejšie. To je
vizuálna progresia — mapa sa mení podľa histórie.

---

## 3. Reprodukovateľné akceptačné postupy (nahrádza päť testov)

Každý test má: **vstup (fixture)** → **čo sa stane** → **očakávaný výstup** → **ako overiť**.

### 3.1 Headless overenie — GDScript UnitTest

| # | Názov | Fixture | Postup | Očakávaný výstup | Overenie |
|---|---|---|---|---|---|
| T1 | Side-goal serializácia | `GameState` s `side_goals = {"sg_a1": true}` | Zavolať `to_dict()`, potom `from_dict()` s tým dictom | `game_state.side_goals["sg_a1"] == true`; prázdny dict = `{}` | `test/integration/test_side_goals.gd` — `assert_eq(sg["sg_a1"], true)`; `assert_eq(typeof(empty_sg), TYPE_DICTIONARY)` |
| T2 | Side-goal cyklus SG-A1 | `GameState` so `year=903, month=6, gold=600` | Simulovať 7 mesiacov EconomyManager, každý mesiac skontrolovať `compute_side_goals()` | V mesiaci, kde gold >= 1200: `side_goals.progress == "Pokladnica: 12xx/1200"` a `done == true` | `test/integration/test_side_goal_cycle.gd` — `assert_true(side_goals[0].done)` |
| T3 | Devín prosperity delta | `GameState` s `devine_resolved=false`, devin.prosperity=40, bratislava.prosperity=60 | Zavolať `run_devine_battle()` (alebo ekvivalent) | `devin.prosperity == 20`, `bratislava.prosperity == 50` | `test/integration/test_devine_prosperity.gd` — `assert_eq(devin["prosperity"], 20)` |
| T4 | Bonus lookup EventManager | `GameState` so `side_goals={"sg_a2": true}`, event `byz_bride_proposal_906`, voľba `accept` | Zavolať `resolve_choice("accept")` | Effect obsahuje `prestige: 5` navyše oproti katalógu | `test/integration/test_side_goal_bonus.gd` — `assert_eq(effect["prestige"], extra_5)` |
| T5 | Bonus lookup DiplomacyManager | `GameState` so `side_goals={"sg_b1": true}`, faction=hungary, treaty=nap | Zavolať `set_treaty("hungary", "nap")` | `mood delta == +15` namiesto +6 | `test/integration/test_side_goal_bonus.gd` — `assert_eq(mood_after - mood_before, 15)` |

### 3.2 Manuálne vizuálne QA — snímky (jeden review artefakt)

| # | Scenár | Postup | Očakávaný vizuál | Ako zdokumentovať |
|---|---|---|---|---|
| V1 | Pred Devínom | Načítať hru 902/01, otvoriť mapu, screenshot | Všetky župy rovnomerne osvetlené, prosperity 50+ | screenshot `map_pre_devin.png` |
| V2 | Po Devíne | Spustiť Devín 907, screenshot po resolve | Devín polygón tmavší (prosperity 20 → `darkened(0.40)`), červenkastý tint. Bratislava stredne tmavá (prosperity 50 → normál). | screenshot `map_post_devin.png` |
| V3 | Prosperita >= 70 | Upraviť jednu župu na prosperity 70+ v save, screenshot | Polygón svetlejší `lightened(0.15)` oproti okoliu | screenshot `map_prosperity_high.png` |
| V4 | Neblokovanie threat markerov | Po Devíne otvoriť župu s loyalty < 30 | Crimson arc threat marker je viditeľný mimo polygóna, tint je vnútri | screenshot `map_threat_no_collision.png` |

Headless test (T1–T5) bežia automaticky cez `godot -s test/integration/`.
Skontrolovať: `cd godot && bash tools/check_all.sh | grep 'ALL PASS'`.

**Aktuálny stav regresie:** `check_all.sh` v tomto worktree vykazuje 4 FAIL
pre chýbajúci font `assets/fonts/CormorantGaramond-Bold.ttf`. Táto regresia
je spôsobená nekompletným asset checkoutom, nie touto kartou. M5/M6 smoke
a npm test prechádzajú.

---

## 4. Akceptačné kritériá

### Pre rm-godot — side-goals (t_ba3d04ce)

- [ ] `GameState.side_goals: Dictionary` existuje, default `{}`
- [ ] `side_goals` je v `to_dict()` aj `from_dict()` s default `{}`
- [ ] `ObjectivesPanel.compute_side_goals(s)` static funkcia existuje a vracia Array of Dictionary
- [ ] Každý side-goal má `id`, `beat`, `active_window`, `label`, `progress`, `done`, `reward_text`
- [ ] `progress` obsahuje aktuálnu hodnotu a cieľ (napr. „1200/1200")
- [ ] `done` sa vypočíta z `game_state` (nie z náhody)
- [ ] Pri splnení sa `side_goals[id] = true` (one-shot)
- [ ] Splnený side-goal sa zobrazí ako `✓ {label}` (zelenou, `C.SUCCESS`)
- [ ] Side-goals sa zobrazia v `_goals_label` popri beat goals
- [ ] Side-goals per fáza: I = 3 (A1, A2, A3), II = 2 (B1, B2), III = 2 (C1, C2), IV = 2 (D1, D2)
- [ ] Žiadny anglický UI reťazec
- [ ] `side_goals` prežije save/load
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS` + Devín attacker
- [ ] T1–T5 headless testy prechádzajú (`test/integration/test_side_goals.gd`, `test_side_goal_cycle.gd`, `test_devine_prosperity.gd`, `test_side_goal_bonus.gd`)

### Pre rm-godot — vizuálna progresia (t_cc9a8c3d)

- [ ] Po `devine_resolved` sa Devín prosperity zníži o −20 (40 → 20)
- [ ] Po `devine_resolved` sa Bratislava prosperity zníži o −10 (60 → 50)
- [ ] `MapView._draw()` — prosperity >= 70: `fill.lightened(0.15)`
- [ ] `MapView._draw()` — prosperity < 30: `fill.darkened(0.40)`
- [ ] `MapView._draw()` — `devine_resolved` && pid in ["devin", "bratislava"]: devastation tint (crimson, alpha 0.25)
- [ ] Tint je vnútri polygóna, threat marker arc je vonku — žiadna kolízia
- [ ] Settlement marker je viditeľný cez tint
- [ ] Hint strip zmenený: „Klikni na župu · zlatý = výber · okruh = lojalita · bledosť = prosperita"
- [ ] `side_goals["sg_b2"]` → Devín prosperity growth +1.0/mesiac (EconomyManager)
- [ ] Žiadny nový legend panel
- [ ] Threat markery (loyalty < 30, mood < 25) ostávajú čitateľné
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS`
- [ ] Dve snímky pred/po Devíne priložené k review (V1, V2 z §3.2)

### Pre rm-core (bonus lookup v EventManager / DiplomacyManager / EconomyManager / Main)

- [ ] `EventManager.resolve_choice()` — bonus lookup pre sg_a2 (+5 prestige), sg_a3 (+5 zemplin), sg_c1 (+10 uzhorod), sg_c2 (+3 religion morava)
- [ ] `DiplomacyManager.set_treaty()` — mood bonus pre sg_b1 (hungary nap: +15), sg_d1 (trade: +8 mood +3 prestige)
- [ ] `EconomyManager.process_economy()` — prosperity bonus pre devin ak sg_b2 (+1.0 namiesto +0.5)
- [ ] `EventManager._build_council_event()` — extra voľba pre sg_d2 (extend_dynasty)
- [ ] `Main._show_army_wizard()` / `ArmyUI` — cena 0 pre template ak sg_a1
- [ ] Žiadny nový event v katalógu, žiadna nová diplomatická akcia, žiadny nový treaty typ
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS` + Devín attacker
- [ ] T4, T5 headless testy prechádzajú

---

## 5. Invarianty a hranice

1. **Devín 907 kánon nemenný.** `winner == "attacker"`, loyalty −20,
   prestige −30, mood hungary +30. Prosperity −20/−10 je **nová** mechanika,
   kánon ju nezahŕňa — pridáva sa pre vizuálnu progresiu.
2. **Žiadny nový event v katalógu.** Side-goal odmeny sa aplikujú cez bonus lookup v
   existujúcich `resolve_choice()`, nie cez nové eventy v JSON.
3. **Žiadna nová diplomatická akcia.** Odmeny menia effectiveness existujúcich
   `send_gift` / `set_treaty`, nepridávajú nové akcie.
4. **Žiadny nový treaty typ.** `nap`, `trade`, `military_pact` ostávajú.
5. `side_goals` **raz splnený = navždy splnený.** Žiadny revert.
6. **SG-D2 extra voľba v council evente** je jediná výnimka z invariantu 2 —
   je to modifikácia existujúceho `_build_council_event()`, nie nový event v JSON.
7. **Scope P1 sa nezväčšuje.** Nové nápady (quest log, achievement system,
   multiple side-goal tiers) idú do triage karty pre P2.

---

## 6. Dotknuté súbory

| Súbor | Karta | Zmena | Stav |
|---|---|---|---|
| `godot/scripts/core/GameState.gd` | t_ba3d04ce | `side_goals` field + `to_dict`/`from_dict` | IMPLEMENTAČNÝ KONTRAKT |
| `godot/ui/ObjectivesPanel.gd` | t_ba3d04ce | `compute_side_goals()` static, zobrazenie v `refresh()` | IMPLEMENTAČNÝ KONTRAKT |
| `godot/scripts/managers/EventManager.gd` | rm-core | bonus lookup v `resolve_choice()`, extra choice v `_build_council_event()` | IMPLEMENTAČNÝ KONTRAKT |
| `godot/scripts/managers/DiplomacyManager.gd` | rm-core | mood bonus pre sg_b1 a sg_d1 v `set_treaty()` | IMPLEMENTAČNÝ KONTRAKT |
| `godot/scripts/managers/EconomyManager.gd` | rm-core | prosperity bonus pre devin ak sg_b2 | IMPLEMENTAČNÝ KONTRAKT |
| `godot/scenes/map/MapView.gd` | t_cc9a8c3d | prosperity fill tinting, devastation tint, hint strip | IMPLEMENTAČNÝ KONTRAKT |
| `godot/autoloads/GameManager.gd` | t_cc9a8c3d | prosperity delta po Devíne v `run_devine_battle()` | IMPLEMENTAČNÝ KONTRAKT |

---

## 7. Overenie invariantov (devine_resolved)

**Kánonický invariant overený smoke testom v aktuálnom kóde**
(`fix/p1-kontrakt-clean`):

| Invariant | Kód | Status |
|---|---|---|
| `winner == "attacker"` | Event katalóg: `hist_devine_battle_907` result = `"attacker"` | PASS |
| prestige −30 | Event katalóg: effect.prestige = −30 | PASS |
| loyalty −20 | Event katalóg: effect.zupaLoyalty.devin = −20 | PASS |
| mood hungary +30 | Event katalóg: effect.moodChanges.hungary.trust = +30 | PASS |
| guard max 1× za run | once=true v event katalógu | PASS |
| event RNG má vlastný seed | EventManager riadok 16: `event_rng.seed = game_state.event_rng_seed` | PASS |
| prosperity −20/−10 | **Nové** — nie v kóde, implementuje sa v t_cc9a8c3d | NIE |