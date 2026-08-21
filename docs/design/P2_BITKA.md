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
        "faction_id": "madari",    # kanonické ID — BattleFormulas.gd:20 ho používa pre jazdecký buff (\"madari\")
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

Používa výhradne existujúci mechanizmus `EventManager._lookup_and_apply_mood()` (EventManager.gd:443-460). Definuje sa cez pole `moodChanges` v choice dict-e (rovnaký formát ako dnes):

```json
"moodChanges": {
    "hungary": {
        "anger": 8
    }
}
```

`_lookup_and_apply_mood()` interpretuje `anger` ako `mood -= anger * 0.3` (EventManager.gd:458-459). Výsledok je clamped na `[0.0, 100.0]`.

**Neexistuje žiadne samostatné pole `hungary.anger` v GameState.** GameState uchováva `factions["hungary"]["mood"]` (float 0–100). `moodChanges` je dočasný dict v choice, nie perzistentné pole. Všetky mood dôsledky bitky sú aplikované cez jediný `_lookup_and_apply_mood({...})` volanie po `_finish_battle()`, s jediným delta podľa výsledku.

Mood delta pred aplikáciou `_lookup_and_apply_mood()` — použije sa jediná hodnota `anger` podľa výsledku (nie násobok pôvodných moodChanges):

| Výsledok | `anger` hodnota odoslaná do `moodChanges` | Výsledný mood delta (po `anger * 0.3`) |
|---|---|---|
| Víťazstvo | `anger: +8` | mood −2.4 |
| Remíza | `anger: +4` | mood −1.2 |
| Prehra | `anger: −8` | mood +2.4 |
| Rout útočníka | `anger: −16` | mood +4.8 |

Clamping je implicitný v `_lookup_and_apply_mood()` — výsledok mood je vždy `clampf(mood, 0.0, 100.0)`. Bitka nikdy nespôsobí mood mimo [0, 100].

### 3.4 Armádne straty

**Ako BattleManager modifikuje armády počas bitky:**

`BattleManager.resolve_phase_round()` (BattleManager.gd:72-92) inkrementálne upravuje `_active_battle["attacker"]["size"]`, `["defender"]["size"]`, `["attacker"]["morale"]`, `["defender"]["morale"]` priamo v battle dict-e po každej fáze. Po `resolve_decision()` (BattleManager.gd:95-107) je finálny stav armád v `_active_battle` autoritatívny.

**Polia `phase_logs`, ktoré sa sčítavajú:**

Každý `phase_log` obsahuje:
- `attacker_losses` (int) — straty útočníka v tejto fáze
- `defender_losses` (int) — straty obrancu v tejto fáze
- `attacker_morale_change` (float) — zmena morálky útočníka
- `defender_morale_change` (float) — zmena morálky obrancu

Len `attack` a `counterattack` fázy (phase 1 a 2) obsahujú tieto polia. `decision` fáza (log s `"phase": "decision"`) obsahuje iba `{"phase": "decision", "winner": winner}` — žiadne loss/morale polia. Neexistujú žiadne iné polia na sčítanie.

**Aplikácia na GameState:**

Z `resolve_phased_battle_choice()` — metóda dostane v `outcome` dict-e `army_id`, `fallback` flag a `battle` (celý `_active_battle`). Postup:

1. `final_size = int(outcome["battle"]["attacker"]["size"])`
2. `final_morale = float(outcome["battle"]["attacker"]["morale"])`

Ak **nie je fallback** (`fallback == false` a `army_id != ""`):
- `GameState.armies[army_id].size = maxi(0, final_size)` (int, zaokrúhlené nadol)
- `GameState.armies[army_id].morale = clampf(final_morale, 0.0, 100.0)` (float)
- Ak `final_size <= 0`: zavolá `ArmyManager.disband_army(army_id)`. Táto metóda (ArmyManager.gd:113-122) nastaví záznamu `status = "disbanded"` a následne **odstráni** kľúč z `game_state.armies`. Po zavolaní záznam neexistuje — žiaden `status == "disbanded"` záznam v dict-e nezostane.

Ak **je fallback** (`fallback == true` alebo `army_id == ""`):
- Straty sa **neaplikujú** na GameState. Armáda nemá perzistentné `army_id`. Hráč vidí straty v `phase_logs`, ale perzistentné armády nie sú dotknuté.

**Overenie pomocou phase_logs** (voliteľné, pre debugging):
```
total_losses = sum(
    log["attacker_losses"]
    for log in _active_battle["phase_logs"]
    if log.has("attacker_losses")
)
```
Tento súčet sa v normálnom toku nepoužíva — `resolve_phase_round()` už inkrementálne udržiava finálny stav. Súčet existuje len pre kontrolu konzistencie v testoch.

### 3.5 Prehľad dôsledkov

Dôsledky v tabuľke nižšie ukazujú konečnú hodnotu po aplikácii outcome matice z §3.1–3.3 na `choice.effect`. Mood dôsledky sú uvedené v §3.3, nie v tejto tabuľke — aplikujú sa vždy cez jediné `moodChanges` volanie.

| Event | Voľba | Víťazstvo | Prehra | Rout (attacker) | Remíza |
|---|---|---|---|---|---|
| rand_border_raid | chase | gold −10, prestige +2, gemer +5 | gold 0, prestige −2, gemer 0 | gold 0, prestige −5, gemer −5 | gold −5, prestige −1, gemer +2 |
| rand_border_raid | fortify | (textová, bez bitky) gold −15, prestige −1, gemer +8 | — | — | — |
| bogata_uprising_917 | crush | gold −40, prestige +4, uzhorod −30 | gold 0, prestige −2, uzhorod 0 | gold 0, prestige −5, uzhorod +30 | gold −20, prestige −1, uzhorod −15 |
| bogata_uprising_917 | negotiate | (textová, bez bitky) prestige −2, uzhorod +10 | — | — | — |

### Akceptačné kritérium 3

Headless test: po bitke `rand_border_raid.chase` s vynúteným víťazstvom (armáda 2000 vs 300) je `game_state.resources.prestige == 52`, `game_state.provinces["gemer"]["loyalty"] == 73.0`, `game_state.factions["hungary"]["mood"] == 47.6` (pokles o `8*0.3=2.4`). Po prehranej bitke (armáda 50 vs 300) je prestige == 48, gemer.loyalty == 68.0 (nezmenené), hungary.mood == 52.4 (nárast o 2.4). `pending_event == null` po aplikácii. `event_cooldowns` obsahuje `"rand_border_raid"`.

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
# Volá sa z Main.gd._finish_battle() po dokončení bitky — PRÁVE RAZ
func resolve_phased_battle_choice(choice: Dictionary, outcome: Dictionary) -> Dictionary:
    # outcome obsahuje: battle (celý _active_battle), result (victory|defeat|...),
    #                   army_id, province_id, fallback, event_id
    var result = outcome.get("result", "defeat")
    
    # 1. Aplikovať resource effect modifikovaný výsledkom (§3.1)
    # 2. Aplikovať zupaLoyalty modifikovaný výsledkom (§3.2)
    # 3. Aplikovať moodChanges podľa výsledku (§3.3)
    # 4. Aplikovať armádne straty (ak nie fallback) (§3.4)
    # 5. Nastaviť cooldown na event_id
    # 6. Odstrániť pending_event (game_state.pending_event = null)
    # 7. Vrátiť chronicle text
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
    _pending_battle_choice = {
        "choice": choice,
        "event_id": event_id,
        "choice_id": choice.get("id", ""),
        "army_id": player_army.get("id", ""),  # "" = fallback
        "province_id": province_id,
        "fallback": player_army.get("id", "").begins_with("_temp_"),
        "applied": false  # idempotentný guard
    }
    
    # Spustiť phased battle
    _active_battle = GameManager.battle_manager.begin_phased_battle(player_army, enemy_army, terrain)
    _battle_round = 0
    next_month_btn.disabled = true
    skirmish_btn.disabled = true
    battle_view.call("show_actions", true)
    battle_view.visible = true
    # Nastaviť nadpis a art z eventu
    var pending = GameManager.get_pending_event()
    var event_title = pending["title"] if pending else "Bitka"
    var event_art_id = pending.get("art_id", "") if pending else ""
    _set_hero_art(event_art_id, event_title)

# V _finish_battle() pribudne:
func _finish_battle(last_action: String) -> void:
    var bm = GameManager.war_manager.battle_manager
    var enemy_action = bm.pick_ai_action(_active_battle["defender"])
    _active_battle = bm.resolve_decision(_active_battle, last_action, enemy_action)
    
    if _pending_battle_choice != null and not _pending_battle_choice.get("applied", false):
        # Aplikovať efekty podľa výsledku bitky — PRÁVE RAZ
        var outcome_result = _classify_outcome(_active_battle)
        var outcome = {
            "battle": _active_battle,
            "result": outcome_result,
            "army_id": _pending_battle_choice["army_id"],
            "province_id": _pending_battle_choice["province_id"],
            "fallback": _pending_battle_choice["fallback"],
            "event_id": _pending_battle_choice["event_id"]
        }
        var final_report = GameManager.resolve_phased_battle_choice(
            _pending_battle_choice["choice"],
            outcome
        )
        _pending_battle_choice["applied"] = true  # idempotentný guard
        _append_chronicle(final_report.get("chronicle", ""))
        GameManager.event_manager._sync_rng_state()
    
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
Main.gd: _on_choice_a() volá GameManager.resolve_event_choice("chase")
    ↓
EventManager.resolve_choice("chase")
    ↓ choice má pole "battle"
    ↓
Návrat {triggers_battle: true, choice: {...}, pending_event: ..., event_id: "rand_border_raid"}
    ↓ pending_event NIE JE vymazaný
    ↓ efekty NIE SÚ aplikované
    ↓ cooldown NIE JE nastavený
    ↓
Main.gd: _start_phased_battle_from_event(result)
    ↓ _pending_battle_choice = {choice, event_id, choice_id, army_id, province_id, fallback, applied: false}
    ↓ call BattleManager.begin_phased_battle()
    ↓ zobrazí BattleView s event title a art
    ↓
HRÁČ VYBERIE TAKTIKU (kolo 1 → attack) → BattleManager.resolve_phase_round()
    ↓ fáza 1: attack — attacker_losses/defender_losses uložené do phase_logs
    ↓
HRÁČ VYBERIE TAKTIKU (kolo 2 → melee) → BattleManager.resolve_phase_round()
    ↓ fáza 2: counterattack — ďalšie losses v phase_logs
    ↓ rout? → áno/nie
    ↓
Main.gd: _finish_battle()
    ↓ BattleManager.resolve_decision()
    ↓
    if _pending_battle_choice != null AND applied == false:
    ↓
GameManager.resolve_phased_battle_choice(choice, outcome)
    ↓ Aplikuje resource effect modifikovaný výsledkom (§3.1)
    ↓ Aplikuje zupaLoyalty modifikovaný výsledkom (§3.2)
    ↓ Aplikuje moodChanges podľa výsledku bitky (§3.3)
    ↓ Aplikuje armádne straty (len ak nie fallback) (§3.4)
    ↓ Nastaví cooldown na event_id
    ↓ VYMAŽE pending_event (game_state.pending_event = null)
    ↓ Vráti chronicle text
    ↓
    _pending_battle_choice["applied"] = true  # idempotentný guard
    ↓
Main.gd: _append_chronicle(), _refresh_ui()
```

### Akceptačné kritérium 5

Po výbere `chase` v `rand_border_raid` evente nie sú `game_state.resources`, `game_state.provinces["gemer"]["loyalty"]` ani `game_state.factions["hungary"]["mood"]` modifikované **pred** začiatkom bitky. Po dokončení bitky (cez `_finish_battle()`) sú modifikované podľa výsledku — **práve raz**. Ak `_finish_battle()` dostane druhý signál (napr. cez retreat v druhom ťahu), `_pending_battle_choice["applied"] == true` zabráni opätovnej aplikácii efektov. Ak hráč neklikne žiadnu taktiku a event ostane v `pending_event`, pri ďalšom ťahu `_on_next_month()` znovu zobrazí ten istý event (lebo `pending_event` nebol vymazaný).

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
        "faction_id": "madari",  # "madari" je kanonické ID — BattleFormulas.gd:20 ho používa pre jazdecký buff
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

Všetky testy používajú headless Godot test s deterministicky nastaveným `game_state` a explicitne vynútenými výsledkami bitky pomocou fiktívnych (obrovských/nulových) armád. Žiadny test nespúšťa `process_events()` náhodne — `pending_event` je nastavený priamo v kóde.

### Pomocné funkcie (zdieľané pre všetky testy)

```gdscript
# Vytvorenie deterministic choice dict ako keby ho vrátil events_catalog
func _make_chase_choice() -> Dictionary:
    return {
        "id": "chase",
        "text": "Vyslať jazdu na prenasledovanie nájazdníkov",
        "effect": {"gold": -10, "prestige": 2},
        "zupaLoyalty": {"gemer": 5},
        "moodChanges": {"hungary": {"anger": 8}},
        "battle": {"enemy_army": "border_raiders"}
    }

func _make_crush_choice() -> Dictionary:
    return {
        "id": "crush",
        "text": "Poslať kráľovské vojsko potlačiť vzburu",
        "effect": {"gold": -40, "prestige": 4},
        "zupaLoyalty": {"uzhorod": -30},
        "battle": {"enemy_army": "bogata_rebels"}
    }

func _make_enemy_army(id: String) -> Dictionary:
    if id == "border_raiders":
        return {"faction_id": "madari", "size": 300, "morale": 65.0,
                "composition": {"infantry": 0.2, "cavalry": 0.7, "archers": 0.1},
                "commander": {"skill": 3}}
    elif id == "bogata_rebels":
        return {"faction_id": "moravia", "size": 600, "morale": 55.0,
                "composition": {"infantry": 0.8, "cavalry": 0.05, "archers": 0.15},
                "commander": {"skill": 2}}
    return {}

func _terrain_for(province_id: String) -> String:
    return game_state.provinces.get(province_id, {}).get("terrain", "field")

func _simulate_phases(battle: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    # Phase 1: attack
    var p1_action = "attack"
    var p1_def_action = "melee"
    battle = bm.resolve_phase_round(battle, "attack", p1_action, p1_def_action)
    # Phase 2: counterattack
    var p2_action = "melee"
    var p2_def_action = bm.pick_ai_action(battle["defender"])
    battle = bm.resolve_phase_round(battle, "counterattack", p2_action, p2_def_action)
    # Decision
    var dec_action = "melee"
    var dec_def_action = bm.pick_ai_action(battle["defender"])
    battle = bm.resolve_decision(battle, dec_action, dec_def_action)
    return battle
```

### Test 1: Prerozprávanie — víťazstvo v bitke

**Cieľ:** Overiť, že hráč po víťaznej bitke získa prestíž, lojalitu a stratí zlato podľa očakávania.

**Postup:**

```gdscript
# 1. Nastaviť startovný stav
var gs = game_state
gs.year = 905
gs.month = 6
gs.resources = {"gold": 1000, "food": 100, "wood": 100, "stone": 100, "iron": 100, "prestige": 50}
gs.provinces["gemer"]["loyalty"] = 68.0
gs.provinces["gemer"]["terrain"] = "hill"
gs.factions["hungary"]["mood"] = 50.0

# 2. Nastaviť pending_event — aby existoval pre GameManager.get_pending_event()
gs.pending_event = {"id": "rand_border_raid", "title": "Nájazd na hranicu Gemera",
    "text": "Rýchla jazdecká družina vtrhla cez južné priesmyky do Gemera...",
    "art_id": "event_border_raid",
    "choices": {"chase": _make_chase_choice(), "fortify": {"id": "fortify", "text": "...", "effect": {}}}}

# 3. Vytvoriť hráčovu armádu — VEĽKÁ, aby sme vynútili víťazstvo (deterministické)
gs.armies["moravia_levy_1"] = {
    "id": "moravia_levy_1", "faction_id": "moravia", "province_id": "gemer",
    "size": 2000, "morale": 90.0,
    "composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
    "commander": {"skill": 5}, "status": "active"
}

# 4. Spustiť phased battle
var bm = GameManager.battle_manager
var enemy = _make_enemy_army("border_raiders")
var terrain = _terrain_for("gemer")  # "hill"
var battle = bm.begin_phased_battle(gs.armies["moravia_levy_1"], enemy, terrain)

# 5. Simulovať obe kolá a rozhodnutie
battle = _simulate_phases(battle, bm.rng)

# 6. Overiť, že útočník vyhral (vôd 2000 vs 300 by mal vždy vyhrať)
assert(battle["winner"] == "attacker")

# 7. Aplikovať efekty cez resolve_phased_battle_choice
var choice = _make_chase_choice()
var outcome = {
    "battle": battle,
    "result": "victory",
    "army_id": "moravia_levy_1",
    "province_id": "gemer",
    "fallback": false,
    "event_id": "rand_border_raid"
}
GameManager.resolve_phased_battle_choice(choice, outcome)

# 8. Overiť dôsledky
assert(gs.resources["prestige"] == 52)          # 50 + 2 (1.0×)
assert(gs.resources["gold"] == 990)             # 1000 − 10 (1.0×)
assert(gs.provinces["gemer"]["loyalty"] == 73.0)  # 68 + 5 (1.0×)
assert(gs.factions["hungary"]["mood"] == 47.6)  # 50 − 2.4 (anger 8×0.3)
assert(gs.pending_event == null)                # vymazaný po aplikácii
assert(gs.event_cooldowns.has("rand_border_raid"))  # cooldown nastavený
```

**Očakávaný výstup:** Hráč (alebo test) môže povedať: "V roku 905, v Gemeri, moja milícia porazila nájazdníkov, Gemer mi zostal verný a získal som 2 prestíž."

**Overenie bez autora:** Spustenie headless testu s uvedeným kódom. Všetky asserty prejdú.

---

### Test 2: Cena — prehra v bitke

**Cieľ:** Overiť, že prehra bolí v prestíži a posilní Maďarov.

**Postup:**

```gdscript
# 1. Nastaviť startovný stav
var gs = game_state
gs.year = 905
gs.month = 6
gs.resources = {"gold": 1000, "food": 100, "wood": 100, "stone": 100, "iron": 100, "prestige": 50}
gs.provinces["gemer"]["loyalty"] = 68.0
gs.provinces["gemer"]["terrain"] = "field"
gs.factions["hungary"]["mood"] = 50.0
gs.pending_event = {"id": "rand_border_raid", "title": "Nájazd na hranicu Gemera", ...}

# 2. Vytvoriť SLABÚ hráčovu armádu — aby sme vynútili prehru
gs.armies["moravia_levy_1"] = {
    "id": "moravia_levy_1", "faction_id": "moravia", "province_id": "gemer",
    "size": 50, "morale": 30.0,   # extrémne slabá
    "composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
    "commander": {"skill": 1}, "status": "active"
}

# 3. Bitka — s veľkým enemy
var bm = GameManager.battle_manager
var enemy = _make_enemy_army("border_raiders")  # 300 vojakov
var terrain = _terrain_for("gemer")  # "field"
var battle = bm.begin_phased_battle(gs.armies["moravia_levy_1"], enemy, terrain)

# 4. Simulovať
battle = _simulate_phases(battle, bm.rng)

# 5. Overiť prehru
assert(battle["winner"] == "defender")

# 6. Aplikovať defeat efekty
var choice = _make_chase_choice()
var outcome = {
    "battle": battle,
    "result": "defeat",
    "army_id": "moravia_levy_1",
    "province_id": "gemer",
    "fallback": false,
    "event_id": "rand_border_raid"
}
GameManager.resolve_phased_battle_choice(choice, outcome)

# 7. Overiť dôsledky
assert(gs.resources["prestige"] == 48)          # 50 − 2 (absolútna penalizácia)
assert(gs.resources["gold"] == 1000)            # 1000 − 0 (0.0×)
assert(gs.provinces["gemer"]["loyalty"] == 68.0)  # 68 + 0 (0.0×)
assert(gs.factions["hungary"]["mood"] == 52.4)  # 50 + 2.4 (anger −8 → mood += 2.4)
# Armáda utrpela straty
var final_size = gs.armies.get("moravia_levy_1", {}).get("size", 0)
assert(final_size < 50)  # reálne straty
```

**Očakávaný výstup:** Hráč vie povedať: "Prehra ma stála 2 prestíž, Maďari sú odvážnejší a moja armáda je zdecimovaná."

**Overenie bez autora:** Spustenie headless testu. Všetky asserty prejdú.

---

### Test 3: Predvídateľnosť

**Cieľ:** Overiť, že choice s `"battle"` poľom je hráčovi signalizovaný ešte pred bitkou — text voľby a prítomnosť `battle` v katalógu.

**Postup:**

```gdscript
# Headless test: overenie events_catalog.json kontraktu
var chase_choice = find_choice_by_id("rand_border_raid", "chase")
assert(chase_choice.has("battle"))
assert(chase_choice["battle"]["enemy_army"] == "border_raiders")

var fortify_choice = find_choice_by_id("rand_border_raid", "fortify")
assert(not fortify_choice.has("battle"))  # pasívna voľba nemá battle flag

var crush_choice = find_choice_by_id("bogata_uprising_917", "crush")
assert(crush_choice.has("battle"))
assert(crush_choice["battle"]["enemy_army"] == "bogata_rebels")

var negotiate_choice = find_choice_by_id("bogata_uprising_917", "negotiate")
assert(not negotiate_choice.has("battle"))

# Overenie že text chase choice obsahuje signál boja
assert("prenasledovanie" in chase_choice["text"].to_lower() or "jazdu" in chase_choice["text"].to_lower())
```

**Očakávaný výstup:** Chase aj Crush majú `"battle"` pole a ich text evokuje boj. Fortify a Negotiate ho nemajú.

**Overenie bez autora:** Spustenie headless testu. Všetky asserty prejdú.

---

### Test 4: Špecifickosť

**Cieľ:** Overiť, že texty eventov nie sú zameniteľné a terény provincií sú historicky vhodné.

**Postup:**

```gdscript
# 1. Prečítať event body z katalógu — overiť unikátnosť
var military_events = filter_by_type(catalog, "military")
var bodies = military_events.map(func(e): return e.get("body", e.get("text", "")))
assert(bodies.size() == bodies.uniq().size(), "Military event bodies must be unique")

# 2. Overiť špecifický text pre rand_border_raid
var raid = find_event_by_id("rand_border_raid")
assert("Gemera" in raid["body"] or "gemer" in raid["body"].to_lower())
assert("priesmyk" in raid["body"].to_lower())

# 3. Overiť špecifický text pre bogata_uprising_917
var uprising = find_event_by_id("bogata_uprising_917")
assert("Bogata" in uprising["body"] or "bogata" in uprising["body"].to_lower())
assert("Užskej" in uprising["body"] or "uzhorod" in uprising["body"].to_lower())

# 4. Overiť terény provincií
assert(gs.provinces["gemer"]["terrain"] in ["hill", "field"])  # aspoň jeden z povolených
assert(gs.provinces["uzhorod"]["terrain"] == "field")
assert(gs.provinces["devin"]["terrain"] == "fortress")
assert(gs.provinces["spis"]["terrain"] == "forest")

# 5. Overiť, že BattleFormulas používa správny buff pre madari na field
var comp = {"infantry": 0.0, "cavalry": 1.0, "archers": 0.0}
var factor = BattleFormulas.composition_factor(comp, "field", "madari")
# HUNGARIAN_CAVALRY_FIELD = 1.40, cavalry unit_terrain field = 1.0
# factor = 1.0 * 1.40 = 1.40
assert(abs(factor - 1.40) < 0.001)
```

**Očakávaný výstup:** Texty odkazujú na konkrétne mená a miesta (Gemera, Bogata, Užská). Terény sú historicky konzistentné. Maďarský jazdecký buff na field je aktívny.

**Overenie bez autora:** Spustenie headless testu s mockovaným events_catalog.json a province dátami. Všetky asserty prejdú.

---

### Test 5: Tempo — ťah 3 ≠ ťah 8

**Cieľ:** Overiť, že na začiatku hry (bez armád) sa používa fallback a straty nie sú perzistentné, zatiaľ čo neskôr (s armádou) sa straty aplikujú na reálnu armádu.

**Postup (dva scenáre v jednom teste):**

```gdscript
# ── SCENÁR A: ťah 3 (bez perzistentných armád) ──
var gs = game_state
gs.year = 903
gs.month = 1
gs.armies = {}  # žiadne armády
gs.resources = {"gold": 1000, "food": 100, "wood": 100, "stone": 100, "iron": 100, "prestige": 50}
gs.provinces["gemer"] = {"id": "gemer", "name": "Gemer", "terrain": "hill", "loyalty": 68.0}
gs.factions["hungary"]["mood"] = 50.0
gs.pending_event = {"id": "rand_border_raid", "title": "...", ...}

var bm = GameManager.battle_manager
var enemy = _make_enemy_army("border_raiders")
var terrain = _terrain_for("gemer")  # "hill"

# Fallback armáda (z Main.gd _build_fallback_army)
var fallback = {"id": "_temp_gemer_10836", "faction_id": "moravia",
    "size": 400, "morale": 60.0,
    "composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
    "commander": {"skill": 3}}

var battle = bm.begin_phased_battle(fallback, enemy, terrain)
battle = _simulate_phases(battle, bm.rng)

# Fallback je slabý — očakávame prehru útočníka
# Aplikovať defeat efekty s fallback=true
var choice = _make_chase_choice()
var outcome = {
    "battle": battle,
    "result": "defeat",
    "army_id": "",        # fallback nemá perzistentné ID
    "province_id": "gemer",
    "fallback": true,
    "event_id": "rand_border_raid"
}
GameManager.resolve_phased_battle_choice(choice, outcome)

assert(gs.armies.size() == 0)          # fallback nepridal armádu
assert(gs.resources["prestige"] == 48)  # 50 − 2 za prehru (absolútna penalizácia)
assert(gs.provinces["gemer"]["loyalty"] == 68.0)  # zupaLoyalty 0.0× pri prehre

# ── SCENÁR B: ťah 8 (s reálnou armádou) ──
gs.year = 908
gs.month = 1
gs.armies["moravia_levy_1"] = {
    "id": "moravia_levy_1", "faction_id": "moravia", "province_id": "gemer",
    "size": 1500, "morale": 85.0,
    "composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
    "commander": {"skill": 5}, "status": "active"
}
gs.resources["prestige"] = 50
gs.factions["hungary"]["mood"] = 50.0

var original_size = gs.armies["moravia_levy_1"]["size"]  # 1500
var original_morale = gs.armies["moravia_levy_1"]["morale"]  # 85.0

battle = bm.begin_phased_battle(gs.armies["moravia_levy_1"], enemy, terrain)
battle = _simulate_phases(battle, bm.rng)

# S 1500 vojakmi by mal útočník vyhrať (deterministicky vďaka veľkosti)
# Ale kontrolujeme aj prehru — aspoň overíme, že straty sa aplikujú
if battle["winner"] == "attacker":
    outcome = {"battle": battle, "result": "victory", "army_id": "moravia_levy_1",
        "province_id": "gemer", "fallback": false, "event_id": "rand_border_raid"}
    GameManager.resolve_phased_battle_choice(_make_chase_choice(), outcome)
    assert(gs.resources["prestige"] >= 50)  # 50 + nejaké (minimálne 50, max 52)
else:
    outcome = {"battle": battle, "result": "defeat", "army_id": "moravia_levy_1",
        "province_id": "gemer", "fallback": false, "event_id": "rand_border_raid"}
    GameManager.resolve_phased_battle_choice(_make_chase_choice(), outcome)

# Overenie, že reálna armáda utrpela straty
var final_size = gs.armies.get("moravia_levy_1", {}).get("size", 0)
assert(final_size < original_size)  # reálne straty
assert(gs.armies.has("moravia_levy_1"))  # stále existuje (size > 0)
```

**Očakávaný výstup:** Ťah 3 → fallback 400 vojakov, prehra, žiadne perzistentné straty, prestíž −2. Ťah 8 → reálna armáda 1500 vojakov, straty sa aplikujú na `moravia_levy_1`, armáda stále existuje.

**Overenie bez autora:** Spustenie headless testu s dvoma scenármi. Všetky asserty prejdú.

---

## 8. Čo implementácia mení v kóde

### EventManager.gd

- `resolve_choice()`: pred aplikáciou efektov skontrolovať `choice_dict.has("battle")`. Ak áno, vrátiť `{triggers_battle: true, choice: choice_dict, event_id: ..., pending_event: ...}` bez aplikácie resource/zupaLoyalty/moodChanges efektov, bez vymazania `pending_event` a bez nastavenia cooldownu.

### GameManager.gd

- Nová metóda `resolve_phased_battle_choice(choice: Dictionary, outcome: Dictionary) -> Dictionary`.
- `outcome` dict obsahuje: `battle` (celý `_active_battle`), `result` (victory|defeat|rout_attacker|stalemate), `army_id`, `province_id`, `fallback` (bool), `event_id`.
- Táto metóda implementuje outcome maticu z §3: modifikuje resource/zupaLoyalty/moodChanges podľa `result`, aplikuje armádne straty (len ak `fallback == false`), nastaví cooldown na `event_id`, vymaže `pending_event`, vráti chronicle text.

### Main.gd

- `_on_choice_a()` / `_on_choice_b()`: ak `result.triggers_battle == true`, zavolať `_start_phased_battle_from_event(result)` namiesto normálneho toku.
- Nová metóda `_start_phased_battle_from_event(result)` — extrahuje provinciu (`_extract_province_from_choice`), armádu (`_find_player_army` alebo `_build_fallback_army`), enemy (`_load_enemy_army`), terén (z province). Uloží `_pending_battle_choice` ako dict s poliami: `choice`, `event_id`, `choice_id`, `army_id`, `province_id`, `fallback` (bool), `applied` (false).
- Nové premenné: `_pending_battle_choice` (Dictionary|Null, null ak nie je aktívna bitka z eventu).
- `_finish_battle()`: ak `_pending_battle_choice != null && _pending_battle_choice["applied"] == false`, zavolať `resolve_phased_battle_choice(_pending_battle_choice["choice"], outcome)` a chronicle. Potom nastaviť `_pending_battle_choice["applied"] = true`.
- Nová metóda `_classify_outcome(battle) -> String` (victory/stalemate/defeat/rout_attacker/rout_defender) — pozri pseudokód v §5.2.
- Nová metóda `_find_player_army(province_id) -> Dictionary` — hľadá v `GameState.armies` prvú armádu s `faction_id == "moravia"`, `province_id` zhodným, `status != "disbanded"`.
- Nová metóda `_build_fallback_army(province_id) -> Dictionary` — vráti dočasnú armádu so `size: 400, morale: 60.0` a `id: "_temp_<province>_<timestamp>"`.
- Nová metóda `_load_enemy_army(enemy_id) -> Dictionary` — číta `data/enemy_armies.json`.
- Nová metóda `_extract_province_from_choice(choice) -> String` — zoberie prvý kľúč z `zupaLoyalty` (ak existuje), inak hľadá v `battle` alebo vracia prázdny string.

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