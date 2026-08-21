# P2: Fázová bitka mimo cvičnej

## Stav

Fázová bitka nie je nová stavba. Je hotová a zapojená len na jednom mieste:

- `BattleManager.begin_phased_battle()`, `resolve_phase_round()`, `pick_ai_action()` existujú a sú deterministické (`test_battle_manager.gd` overuje zhodu pri rovnakom seede).
- `BattleView` má akčné tlačidlá (útok / streľba / obchvat / ústup) a vie vykresliť `phase_logs`.
- `Main.gd:737 _on_skirmish()` je jediný volajúci. Dve kolá + rozhodnutie, pevná zostava 1000 vs 800, terén natvrdo `field`.

**Problém:** Hráč sa k jedinému taktickému rozhodnutiu v hre dostane cez tlačidlo *Cvičná bitka*, ktoré nemá následky. Skutočné vojenské strety (`rand_border_raid`, `bogata_uprising_917`) sa riešia textom a číslami cez `EventManager.resolve_choice()` — hráč nevidí BattleView, nevyberá taktickú akciu, len klikne voľbu a číta výsledok.

---

## 1. Ktoré strety idú cez fázovú bitku

### Kritérium

Len **eventy typu `military`** a len tie voľby, ktoré majú nové pole `"battle"` v choice dict-e.

### Rozhodnutie

| Event | Typ | Triggeruje phased battle | Zdôvodnenie |
|---|---|---|---|
| `rand_border_raid` | military | Áno — voľba `chase` (`battle: {enemy_army: "border_raiders"}`) | Hráč aktívne vyháňa jazdu — taktické rozhodnutie dáva zmysel |
| `rand_border_raid` | military | Nie — voľba `fortify` | Pasívna obrana, žiadny boj |
| `bogata_uprising_917` | military | Áno — voľba `crush` (`battle: {enemy_army: "bogata_rebels"}`) | Kráľovské vojsko potláča vzburu |
| `bogata_uprising_917` | military | Nie — voľba `negotiate` | Diplomatické riešenie, žiadny boj |
| **Devín 907** | kanon | **Nie** | Zostáva na `HungarianWarScenario.resolve_devine_battle()`. Invariant §4.1: `winner=="attacker"`, max 1× za run, dôsledky −30 prestíž / −20 lojalita Devína / +30 mood Maďarov, event RNG má vlastný seed. Toto NEOTVÁRAJ. |

### Akceptačné kritérium 1

`events_catalog.json` obsahuje pre `rand_border_raid.chase` a `bogata_uprising_917.crush` nové pole `"battle": {"enemy_army": "<id>"}`. Žiadny iný choice dict v katalógu nemá pole `battle`. Devín 907 nie je v events_catalog (je v HungarianWarScenario).

---

## 2. Odkiaľ sa berie zostava a terén

### 2.1 Hráčova armáda (attacker)

Z `GameState.armies`. Hľadá sa prvá armáda, ktorá spĺňa:
- `faction_id == "moravia"`
- `province_id` == provincia eventu (napr. `gemer` pre `rand_border_raid`)
- `status != "disbanded"`

Ak existuje viacero, berie sa prvá podľa abecedného poradia kľúčov (deterministické).

**Fallback (žiadna armáda na provincii):** Použije sa dočasná armáda:

```gdscript
{
    "id": "_temp_%s_%d" % [province_id, game_state.year * 12 + game_state.month],
    "faction_id": "moravia",
    "size": 400,
    "morale": 60.0,
    "composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
    "commander": {"skill": 3}
}
```

Táto armáda **nie je** uložená do `GameState.armies`. Straty fallback armády sa neaplikujú (neexistuje `army_id` na update). Hráč vidí straty v `phase_logs`, ale neovplyvnia perzistentné armády.

### 2.2 Nepriateľská armáda (defender)

Z `choice.battle.enemy_army` v event katalógu. Pre každý `enemy_army` id je definovaný záznam v novom `data/enemy_armies.json`:

```json
{
    "border_raiders": {
        "faction_id": "hungary",
        "size": 300,
        "morale": 65.0,
        "composition": {"infantry": 0.2, "cavalry": 0.7, "archers": 0.1},
        "commander": {"skill": 3}
    },
    "bogata_rebels": {
        "faction_id": "moravia",
        "size": 600,
        "morale": 55.0,
        "composition": {"infantry": 0.8, "cavalry": 0.05, "archers": 0.15},
        "commander": {"skill": 2}
    }
}
```

### 2.3 Terén

Z nového poľa `terrain` v province JSON. Každá provincia dostane:

```json
{
    "id": "gemer",
    "name": "Gemer",
    "terrain": "hill",
    ...
}
```

**Povolené hodnoty:** `field`, `forest`, `fortress`, `river`, `hill` (zozhod s `BattleConfig.TERRAIN_MODIFIERS`).

**Predvolená hodnota:** `"field"` (ak pole chýba).

**Mapovanie provincií:**

| Provincia | Terén | Zdôvodnenie |
|---|---|---|
| morava | field | Centrálna nížina |
| bratislava | river | Dunaj, hranica |
| devin | fortress | Hradný vrch, dôležitá pevnosť |
| nitra | river | Nitra je na rieke |
| trencin | hill | Považie, kopcovitý terén |
| tekov | field | Pohronie, mierna nížina |
| hont | hill | Stredné Slovensko, pahorkatina |
| novohrad | hill | Juh stredného Slovenska |
| gemer | hill | Slovenské rudohorie |
| spis | forest | Sever, lesnatý |
| zemplin | forest | Východ, lesnatý |
| uzhorod | field | Východná hranica, nížina |

### Akceptačné kritérium 2

Pre každú provinciu v `data/provinces/*.json` existuje pole `terrain` s jednou z hodnôt `field/forest/fortress/river/hill`. `data/enemy_armies.json` obsahuje záznamy pre `border_raiders` a `bogata_rebels`. `BattleConfig.TERRAIN_MODIFIERS` má záznam pre každý použitý terénny typ (overené v `BattleConfig.gd:7-13`).

---

## 3. Čo hráč pri prehre stratí a čo pri výhre získa

Žiadna nová mena. Všetky dôsledky používajú existujúce meny: `gold`, `prestige`, `zupaLoyalty`, `moodChanges` na frakcie, armády (`size`, `morale`).

### 3.1 Resource efekty

`choice.effect` (gold, prestige) sa **neaplikuje** priamo v `resolve_choice()`, ale až po skončení bitky — modifikovaný podľa výsledku:

| Výsledok | gold multiplikátor | prestige multiplikátor |
|---|---|---|
| Víťazstvo (attacker) | 1.0× | 1.0× |
| Remíza (stalemate) | 0.5× | −1 (absolútna penalizácia) |
| Prehra (defender) | 0.0× | −2 (absolútna penalizácia) |
| Rout (defender rout) | 0.0× | −5 (absolútna penalizácia) |

**Príklad:** `rand_border_raid.chase` má `effect: {gold: -10, prestige: 2}`.
- Víťazstvo: gold −10, prestige +2
- Prehra: gold 0, prestige −2

### 3.2 Lojalita župy (`zupaLoyalty`)

Aplikuje sa vždy (aj pri prehre) — ale **iba ak** event ju definuje. Multiplikátor:

| Výsledok | zupaLoyalty multiplikátor |
|---|---|
| Víťazstvo | 1.0× |
| Remíza | 0.5× |
| Prehra | 0.0× |
| Rout (defender) | 0.0× |
| Rout (attacker) | −1.0× (obrátený efekt) |

**Príklad:** `rand_border_raid.chase` má `zupaLoyalty: {gemer: 5}`.
- Víťazstvo: gemer +5
- Prehra: gemer 0
- Rout útočníka: gemer −5

### 3.3 Nálada frakcie (`moodChanges`)

Používa existujúci mechanizmus `EventManager._lookup_and_apply_mood()`. Definuje sa cez pole `moodChanges` v choice dict-e (rovnaký formát ako dnes):

```json
"moodChanges": {
    "hungary": {
        "anger": 8
    }
}
```

`_lookup_and_apply_mood()` interpretuje `anger` ako `mood -= anger * 0.3` (existujúci kód v EventManager.gd:458-459). Výsledok je clamped na `[0.0, 100.0]`.

**Neexistuje žiadne samostatné pole `hungary.anger` v GameState.** GameState uchováva `factions["hungary"]["mood"]` (float 0–100). `moodChanges` je dočasný dict v choice, nie perzistentné pole.

Multiplikátor moodChanges podľa výsledku bitky:

| Výsledok | moodChanges multiplikátor |
|---|---|
| Víťazstvo | 1.0× |
| Remíza | 0.5× |
| Prehra | −1.0× (obrátený efekt — Maďari sú odvážnejší) |
| Rout útočníka | −2.0× |

### 3.4 Armádne straty

**Reálna armáda** (existuje v `GameState.armies`):

Po každej fáze bitky `BattleManager.resolve_phase_round()` upravuje `attacker.size`, `defender.size`, `attacker.morale`, `defender.morale` priamo v battle dicate (riadky 76-79 BattleManager.gd). Po rozhodnutí (`resolve_decision`) máme finálny stav oboch armád.

**Aplikácia na GameState:**

```
final_attacker = _active_battle["attacker"]  # po resolve_decision()
total_losses = army_original_size - final_attacker["size"]
```

Pravidlá:
- `GameState.armies[army_id].size` = `maxi(0, final_attacker["size"])` (int)
- `GameState.armies[army_id].morale` = `clampf(final_attacker["morale"], 0.0, 100.0)` (float)
- Ak je `final_attacker["size"] <= 0`, armáda sa označí ako disbanded (odstráni z `GameState.armies`).

**Dočasná fallback armáda:** Straty sa neaplikujú na GameState. Armáda nemá perzistentné `army_id`. Hráč vidí phase_logs, ale perzistentné armády nie sú dotknuté.

**Sumácia strát z phase_logs** (pre kontrolu/overenie):
```
total_losses = sum(phase_log.attacker_losses for phase_log in _active_battle["phase_logs"] if phase_log.has("attacker_losses"))
```

Každý `phase_log` obsahuje polia `attacker_losses` (int), `defender_losses` (int), `attacker_morale_change` (float), `defender_morale_change` (float). Súčet týchto polí nie je priamo aplikovaný — `resolve_phase_round()` už inkrementálne aktualizuje armádny dict (riadky 76-79 BattleManager.gd). Finálny stav armády po `resolve_decision()` je autoritatívny.

### 3.5 Prehľad dôsledkov

| Event | Voľba | Výhra | Prehra | Rout (attacker) |
|---|---|---|---|---|
| rand_border_raid | chase | gold −10, prestige +2, gemer +5, hungary.anger +8 | gold 0, prestige −2, gemer 0, hungary.anger −8 | gold 0, prestige −5, gemer −5, hungary.anger −16 |
| rand_border_raid | fortify | (textová, bez bitky) gold −15, prestige −1, gemer +8 | — | — |
| bogata_uprising_917 | crush | gold −40, prestige +4, uzhorod −30 | gold 0, prestige −6, uzhorod 0 | gold 0, prestige −9, uzhorod +30 |
| bogata_uprising_917 | negotiate | (textová, bez bitky) prestige −2, uzhorod +10 | — | — |

### Akceptačné kritérium 3

Headless test: po bitke `rand_border_raid.chase` s vynúteným víťazstvom je `game_state.resources.prestige` o 2 vyššie, `game_state.provinces["gemer"]["loyalty"]` o 5 vyššie, `game_state.factions["hungary"]["mood"]` o `8*0.3=2.4` nižšie. Po prehranej bitke je prestige o 2 nižšie, gemer.loyalty nezmenené, hungary.mood o `8*0.3=2.4` vyššie.

---

## 4. Ako sa cvičná bitka odlíši od skutočnej

| Vlastnosť | Cvičná | Skutočná |
|---|---|---|
| **Nadpis v BattleView** | "Cvičná bitka · Nitra" | "Nájazd na hranicu Gemera" (title eventu) |
| **Notifikácia po bitke** | "Cvičná bitka hotová — späť k mesačným ťahom." | "Gemerský nájazd odrazený — +2 prestíž" (dynamický podľa výsledku) |
| **Následky** | Žiadne (nevolá `resolve_choice()`) | Aplikuje resource/zupaLoyalty/moodChanges modifikované výsledkom |
| **Armády** | Pevná 1000 vs 800 | Z GameState.armies + enemy_armies.json |
| **Terén** | `field` natvrdo | Z province.terrain |
| **Dostupnosť** | Tlačidlo v UI (vždy) | Cez event voľbu |
| **Chronicle zápis** | Nie | Áno (cez `_append_chronicle` po aplikácii efektov) |

**Vizuálny rozdiel pre hráča:**
- Cvičná: tlačidlo "Cvičná bitka" v UI paneli, nadpis "Cvičná bitka · Nitra"
- Skutočná: Event dialog s textom "Vyslať jazdu na prenasledovanie nájazdníkov" → po kliknutí sa otvorí BattleView s názvom eventu

### Akceptačné kritérium 4

Po kliknutí na tlačidlo "Cvičná bitka" BattleView zobrazí nadpis "Cvičná bitka · Nitra" a notifikáciu "... — späť k mesačným ťahom." GameState nie je modifikovaný (resources, armies, provinces ostávajú nezmenené). Po výbere `chase` v `rand_border_raid` evente BattleView zobrazí "Nájazd na hranicu Gemera" a po skončení sa modifikuje GameState.

---

## 5. Kontrolný tok — presný stavový autom

### 5.1 Súčasný problém

`EventManager.resolve_choice()` (riadky 232-355) dnes:
1. Aplikuje resource efekty (gold, food, prestige atď.) okamžite
2. Aplikuje `zupaLoyalty` okamžite
3. Aplikuje `moodChanges` okamžite
4. Nastaví cooldown
5. Vymaže `pending_event` (ak nie je chain)
6. Vráti `{ok, effect, chronicle, event_id, choice_result, context}`

Pre battle voľbu toto **nesmie** platiť — efekty sa musia aplikovať až po výsledku bitky.

### 5.2 Nový kontrakt

#### EventManager.resolve_choice() — zmena

Ak má vybraný `choice_dict` pole `"battle"`, `resolve_choice()` **nesmie** aplikovať resource efekty, zupaLoyalty, moodChanges, ani vymazať `pending_event`. Namiesto toho vráti:

```gdscript
{
    "ok": true,
    "triggers_battle": true,
    "event_id": "rand_border_raid",
    "choice": {                              # celý choice dict pre neskoršie spracovanie
        "id": "chase",
        "text": "...",
        "effect": {"gold": -10, "prestige": 2},
        "zupaLoyalty": {"gemer": 5},
        "moodChanges": {"hungary": {"anger": 8}},
        "battle": {"enemy_army": "border_raiders"}
    },
    "pending_event": <pôvodný event dict>
}
```

- `pending_event` **nie je** vymazaný — ostáva v `game_state.pending_event` až do `_finish_battle()`.
- Cooldown sa **nenastavuje** — nastaví sa až v `_finish_battle()` po aplikácii efektov.
- Chronicle sa **nevyplňuje** — vyplní sa až po bitke.
- Resource efekty, zupaLoyalty, moodChanges sa **neaplikujú**.

#### GameManager

Nový signál/metóda:

```gdscript
# Volá sa z Main.gd po dokončení bitky
func resolve_phased_battle_choice(choice: Dictionary, outcome: Dictionary) -> Dictionary:
    # 1. Aplikovať efekty modifikované výsledkom (podľa tabuľky v §3)
    # 2. Nastaviť cooldown na event_id
    # 3. Vymazať pending_event
    # 4. Vrátiť chronicle text
```

Táto metóda je volaná z `Main.gd._finish_battle()` — nie z EventManageru.

#### Main.gd — nový tok

```gdscript
func _on_choice_a() -> void:
    var choice_id = "chase"  # alebo podľa UI
    var result = GameManager.resolve_event_choice(choice_id)
    
    if result.get("triggers_battle", false):
        # Spustiť phased battle
        _start_phased_battle_from_event(result)
    else:
        # Normálny tok (textové riešenie)
        _on_choice_resolved(result)

func _start_phased_battle_from_event(result: Dictionary) -> void:
    var choice = result["choice"]
    var event_id = result["event_id"]
    var province_id = _extract_province_from_choice(choice)  # z zupaLoyalty kľúčov
    
    # Hráčova armáda
    var player_army = _find_player_army(province_id)  # z GameState.armies
    if player_army.is_empty():
        player_army = _build_fallback_army(province_id)
    
    # Nepriateľská armáda
    var enemy_id = choice["battle"]["enemy_army"]
    var enemy_army = _load_enemy_army(enemy_id)  # z enemy_armies.json
    
    # Terén
    var terrain = GameManager.game_state.provinces.get(province_id, {}).get("terrain", "field")
    
    # Uložiť kontext pre _finish_battle()
    _pending_battle_choice = choice
    
    # Spustiť phased battle
    _active_battle = GameManager.battle_manager.begin_phased_battle(player_army, enemy_army, terrain)
    _battle_round = 0
    next_month_btn.disabled = true
    skirmish_btn.disabled = true
    battle_view.call("show_actions", true)
    battle_view.visible = true
    # Nastaviť nadpis podľa eventu
    var event_title = GameManager.event_manager.get_pending_event_title()
    _set_hero_art(event_art_id, event_title)

# V _finish_battle() pribudne:
func _finish_battle(last_action: String) -> void:
    var bm = GameManager.war_manager.battle_manager
    var enemy_action = bm.pick_ai_action(_active_battle["defender"])
    _active_battle = bm.resolve_decision(_active_battle, last_action, enemy_action)
    
    if _pending_battle_choice != null:
        # Aplikovať efekty podľa výsledku bitky
        var outcome_result = _classify_outcome(_active_battle)
        var final_report = GameManager.resolve_phased_battle_choice(
            _pending_battle_choice,
            {"outcome": _active_battle, "result": outcome_result}
        )
        _append_chronicle(final_report.get("chronicle", ""))
        GameManager.event_manager._sync_rng_state()
        _pending_battle_choice = null
    
    next_month_btn.disabled = false
    battle_view.call("show_actions", false)
    _show_battle(event_title, _active_battle, event_art_id)
    _log_battle_phases(_active_battle)
    _refresh_ui()

func _classify_outcome(battle: Dictionary) -> String:
    var winner = battle.get("winner", "")
    var routed = battle.get("routed", "")
    if routed == "attacker":
        return "rout_attacker"
    elif routed == "defender":
        return "rout_defender"
    elif winner == "attacker":
        return "victory"
    elif battle.get("result") == "stalemate":
        return "stalemate"
    else:
        return "defeat"
```

### 5.3 Sekvenčný diagram stavových prechodov

```
HRÁČ KLIKNE choice "chase"
    ↓
EventManager.resolve_choice("chase")
    ↓ choice má pole "battle"
    ↓
Návrat {triggers_battle: true, choice: {...}, pending_event: ..., event_id: "rand_border_raid"}
    ↓ pending_event NIE JE vymazaný
    ↓ efekty NIE SÚ aplikované
    ↓
Main.gd: _start_phased_battle_from_event(result)
    ↓ hľadá armádu, enemy, terén
    ↓ call BattleManager.begin_phased_battle()
    ↓ zobrazí BattleView
    ↓
HRÁČ VYBERTE TAKTIKU (kolo 1) → BattleManager.resolve_phase_round()
    ↓
HRÁČ VYBERTE TAKTIKU (kolo 2) → BattleManager.resolve_phase_round()
    ↓ rout? → áno/nie
    ↓
Main.gd: _finish_battle()
    ↓ BattleManager.resolve_decision()
    ↓
GameManager.resolve_phased_battle_choice(choice, outcome)
    ↓ Aplikuje resource effect modifikovaný výsledkom
    ↓ Aplikuje zupaLoyalty modifikovaný výsledkom
    ↓ Aplikuje moodChanges modifikovaný výsledkom
    ↓ Nastaví cooldown na event_id
    ↓ VYMAŽE pending_event (game_state.pending_event = null)
    ↓ Vráti chronicle text
    ↓
Main.gd: _append_chronicle(), _refresh_ui()
```

### Akceptačné kritérium 5

Po výbere `chase` v `rand_border_raid` evente nie sú `game_state.resources`, `game_state.provinces["gemer"]["loyalty"]` ani `game_state.factions["hungary"]["mood"]` modifikované **pred** začiatkom bitky. Po dokončení bitky (cez `_finish_battle()`) sú modifikované podľa výsledku. Ak hráč neklikne žiadnu taktiku a event ostane v `pending_event`, pri ďalšom ťahu `process_events()` vráti ten istý event (lebo `pending_event` nebol vymazaný).

---

## 6. Zmeny v dátových súboroch

### 6.1 `data/provinces/*.json`

+ pole `terrain` (string) — default `"field"` ak chýba.

### 6.2 `data/events_catalog.json`

+ pole `"battle"` v choice dict:

```json
// rand_border_raid.chase (cca riadok 400)
{
    "id": "chase",
    "text": "Vyslať jazdu na prenasledovanie nájazdníkov",
    "effect": {"gold": -10, "prestige": 2},
    "zupaLoyalty": {"gemer": 5},
    "moodChanges": {"hungary": {"anger": 8}},
    "battle": {"enemy_army": "border_raiders"}
}

// bogata_uprising_917.crush (cca riadok 325)
{
    "id": "crush",
    "text": "Poslať kráľovské vojsko potlačiť vzburu",
    "effect": {"gold": -40, "prestige": 4},
    "zupaLoyalty": {"uzhorod": -30},
    "battle": {"enemy_army": "bogata_rebels"}
}
```

### 6.3 `data/enemy_armies.json` (nový súbor)

```json
{
    "border_raiders": {
        "faction_id": "hungary",
        "size": 300,
        "morale": 65.0,
        "composition": {"infantry": 0.2, "cavalry": 0.7, "archers": 0.1},
        "commander": {"skill": 3}
    },
    "bogata_rebels": {
        "faction_id": "moravia",
        "size": 600,
        "morale": 55.0,
        "composition": {"infantry": 0.8, "cavalry": 0.05, "archers": 0.15},
        "commander": {"skill": 2}
    }
}
```

### 6.4 Žiadne zmeny v GameState

`GameState.gd` ostáva nezmenený. Nepribúda žiadne nové pole. Všetky potrebné údaje už existujú (`armies`, `provinces`, `factions`, `resources`, `pending_event`, `event_cooldowns`).

---

## 7. Päť testov — reprodukovateľné postupy

### Test 1: Prerozprávanie

**Postup:**
1. V headless testi nastav `game_state.year = 905, game_state.month = 6`.
2. Nastav `game_state.armies["moravia_levy_1"]["province_id"] = "gemer"` (presuň armádu do Gemera).
3. Vytvor armádu enemy_armies.json pre `border_raiders` (v testi mockni `_load_enemy_army`).
4. EventEngine test: zavolaj `event_manager.process_events()`, over že dostaneš `rand_border_raid`.
5. Zavolaj `event_manager.resolve_choice("chase")`, over `triggers_battle == true`.
6. Zavolaj `battle_manager.begin_phased_battle(player_army, border_raiders, "hill")` (Gemera terén = hill).
7. Zavolaj `battle_manager.resolve_phase_round(battle, "attack", "melee", "flank")`.
8. Zavolaj `battle_manager.resolve_decision(battle, "melee", "ranged")`.
9. Zavolaj `resolve_phased_battle_choice(choice, outcome)`.
10. Over, že `game_state.resources.prestige >= 52` (štart 50 + 2 za výhru).
11. Prečítaj chronicle: mal by obsahovať text ako "Nájazd na hranicu Gemera odrazený".

**Očakávaný výstup:**
Hráč (alebo test) vie povedať: "V roku 905, v Gemeri, moja milícia bola slabšia ako nájazdníci, vyhral som vďaka lepšiemu terénu, Gemer mi zostal verný a získal som 2 prestíž."

**Overenie v kóde:**
```
assert(game_state.resources.prestige >= 52)
assert(game_state.provinces["gemer"]["loyalty"] >= 70)  # +5 z choice.effect
assert(event_manager._catalog_has_event("rand_border_raid"))  # overenie, že event existoval
```

### Test 2: Cena

**Postup:**
1. V headless testi spusti `rand_border_raid` > `chase` > **prehra** (vynútiť nízku effective_strength pre útočníka — napr. nastaviť `player_army.size = 50`, `enemy.size = 800`).
2. Zavolaj `resolve_phased_battle_choice(choice, {outcome: battle, result: "defeat"})`.
3. Over, že:
   - `game_state.resources.prestige == 48` (štart 50 − 2)
   - `game_state.resources.gold == 1000` (štart — zlatý efekt je 0.0× pri prehre)
   - `game_state.provinces["gemer"]["loyalty"] == 68` (štart 68 — zupaLoyalty 0.0×)
   - `game_state.factions["hungary"]["mood"]` je o `8*0.3=2.4` vyššie (obrátený efekt)

**Očakávaný výstup:**
Každé rozhodnutie niečo stojí — prehra bolí v prestíži a posilní Maďarov.

**Overenie v kóde:**
```
assert(game_state.resources.prestige == 48)
assert(game_state.provinces["gemer"]["loyalty"] == 68)
assert(abs(game_state.factions["hungary"]["mood"] - 52.4) < 0.001)
```

### Test 3: Predvídateľnosť (hráč vie, že ide bojovať)

**Postup:**
1. V hlavnom Godot projekte spusti hru.
2. Klikaj "Ďalší mesiac" až kým sa neobjaví event "Nájazd na hranicu Gemera".
3. V EventDialogu vidíš dve voľby:
   - "Vyslať jazdu na prenasledovanie nájazdníkov" (chase) — **táto povedie k bitke**
   - "Posilniť miestnu posádku, nechať nájazdníkov ujsť" (fortify) — táto je textová

**Očakávaný výstup:**
Z textu voľby "Vyslať jazdu" hráč priamo vyvodí, že pôjde do boja. Nie je prekvapený, že sa zrazu otvorí BattleView. Riziko (prehra v bitke) je signalizované už výberom tejto voľby.

**Overenie:**
```
# V headless testi nad events_catalog.json:
var chase_choice = find_choice_by_id("rand_border_raid", "chase")
assert(chase_choice.has("battle"))  # choice má battle flag
assert(chase_choice["battle"]["enemy_army"] == "border_raiders")
```

### Test 4: Špecifickosť (text nie je zameniteľný)

**Postup:**
1. Prečítaj event body v `events_catalog.json` pre `rand_border_raid`:
   - "Rýchla jazdecká družina vtrhla cez južné priesmyky do Gemera..."
2. Prečítaj event body pre `bogata_uprising_917`:
   - "Odložený zásah priniesol trpké plody a rod Bogata vyhlásil v Užskej župe otvorenú vzburu..."
3. Over, že tieto texty odkazujú na konkrétne župy, mená a situácie — nedajú sa prilepiť do akejkoľvek inej stredovekej hry.
4. Over v `data/provinces/*.json`, že `gemer` má `terrain: "hill"` a `uzhorod` má `terrain: "field"`.

**Očakávaný výstup:**
BattleConfig používa hungarský jazdecký buff na field (`HUNGARIAN_CAVALRY_FIELD = 1.40`), moravskú pevnostnú obranu (`MORAVIAN_FORTRESS_DEF = 1.30`), province majú historické terény aj mená. Text eventov je neoddeliteľne spätý s konkrétnou históriou Veľkej Moravy.

**Overenie:**
```
# Každý event typu military má unikátny body text (kontrola duplicit):
var military_events = filter_by_type(catalog, "military")
var bodies = military_events.map(func(e): return e["body"])
assert(bodies.size() == bodies.uniq().size())
```

### Test 5: Tempo (ťah 3 ≠ ťah 8)

**Postup:**
1. V headless testi nastav game_state na rok 903, mesiac 1 (žiadne armády okrem default).
2. Vytvor event `rand_border_raid` s voľbou `chase`.
3. Zavolaj `resolve_choice("chase")` — fallback armáda má `size: 400, morale: 60.0`.
4. Simuluj prehru (vynútiť slabú armádu). Over, že hráč stratil prestíž a lojalitu Gemera neklesla (fallback effect sa neaplikuje na province).
5. O 5 rokov (908): vytvor reálnu armádu `moravia_levy_1` v Gemeri s `size: 1500, morale: 85.0`.
6. Znovu spusti `rand_border_raid`, `chase`.
7. Over, že `resolve_phased_battle_choice` použije reálnu armádu (1500 vojakov, morálka 85).
8. Over, že straty sa aplikujú na `game_state.armies["moravia_levy_1"]["size"]`.

**Očakávaný výstup:**
Ťah 3: hráč nemá armádu → fallback 400 vojakov → prehra → bez strát na perzistentných armádach. Ťah 8: hráč má 1500 vojakov → môže vyhrať → straty sa aplikujú na reálnu armádu.

**Overenie:**
```
# Ťah 3
var original_army_count = game_state.armies.size()
# ...simuluj prehru...
assert(game_state.armies.size() == original_army_count)  # fallback nepridal armádu

# Ťah 8
var original_size = game_state.armies["moravia_levy_1"]["size"]
# ...simuluj bitku...
assert(game_state.armies["moravia_levy_1"]["size"] < original_size)  # reálne straty
```

---

## 8. Čo implementácia mení v kóde

### EventManager.gd

- `resolve_choice()`: pred aplikáciou efektov skontrolovať `choice_dict.has("battle")`. Ak áno, vrátiť `{triggers_battle: true, choice: choice_dict, ...}` bez aplikácie efektov a bez vymazania `pending_event`.

### GameManager.gd

- Nová metóda `resolve_phased_battle_choice(choice: Dictionary, outcome: Dictionary) -> Dictionary`.
- Táto metóda implementuje maticu z §3 (multipliers for victory/stalemate/defeat/rout).

### Main.gd

- `_on_choice_a()` / `_on_choice_b()`: ak `result.triggers_battle`, zavolať `_start_phased_battle_from_event(result)` namiesto normálneho toku.
- Nová metóda `_start_phased_battle_from_event(result)` — extrahuje provinciu, armádu, enemy, terén.
- Nové premenné: `_pending_battle_choice` (Dictionary, null ak nie je aktívna bitka z eventu).
- `_finish_battle()`: ak `_pending_battle_choice != null`, zavolať `resolve_phased_battle_choice()` a chronicle.
- Nová metóda `_classify_outcome(battle) -> String` (victory/stalemate/defeat/rout_attacker/rout_defender).
- Nová metóda `_find_player_army(province_id) -> Dictionary`.
- Nová metóda `_build_fallback_army(province_id) -> Dictionary`.
- Nová metóda `_load_enemy_army(enemy_id) -> Dictionary` (číta `data/enemy_armies.json`).
- Nová metóda `_extract_province_from_choice(choice) -> String` (zoberie prvý kľúč z `zupaLoyalty`).

### Žiadne zmeny

- `GameState.gd` — bez zmien.
- `BattleManager.gd` — bez zmien.
- `BattleView.gd` — bez zmien (už podporuje všetky potrebné veci).
- `BattleConfig.gd` — bez zmien (už podporuje všetky terény).
- `WarManager.gd` — bez zmien (Devín 907 nedotknutý).

---

## 9. Otvorené otázky (triage na neskôr)

Tieto otázky sú mimo scope P2. Ak sa objavia počas implementácie, vytvor samostatnú kartu.

- **Ako sa správa BattleView, ak hráč klikne Ústup?** Retreat je už v action_buttons (Main.gd batuje `retreat` do `_finish_battle`). Dnes `retreat` spustí `resolve_decision` s `attacker_action="retreat"` — funguje, ale retreat v prvom ťahu by mal byť "boj bez boja" (vysoké straty, -morale). Toto je už implementované v BattleManager (RETREAT_LOSSES, RETREAT_MORALE_PENALTY).
- **Aké art_id sa používa pre battle eventy?** `rand_border_raid` má `art_id: "event_border_raid"`, `bogata_uprising_917` má `"event_border_raid"`. Môže byť potrebný nový art.
- **Má byť event `pending_event` vymazaný, ak hráč počas bitky zatvorí hru?** Áno — pending_event ostáva až do `_finish_battle()`. Pri reload-e sa event znovu zobrazí.