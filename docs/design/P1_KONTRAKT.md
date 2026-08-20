# P1 kontrakt — eventy, beaty, hrozby

> **Toto je dizajnový kontrakt, nie implementácia.** Špecialisti (`rm-core`,
> `rm-godot`, `rm-content`) čítajú tento súbor ako zdroj pravdy pre svoje karty.
> Karta `t_bc55a2c2` ho produkuje; deti `t_c0f01d68`, `t_0c31d3fa`, `t_1813d684`,
> `t_13f3c199` ho konzumujú.

**Zdroje pravdy overené voči kódu:**
- `docs/NAVRH_HERNY_ZAZITOK.md` §4, §5, §15.6 ( invarianty )
- `docs/GAMEPLAY_LOOP.md` ( fázy kampane )
- `docs/design/P0_EVENTY.md` ( P0 eventy — mená, meny, kontrakt resolve_choice )
- `docs/design/P0_DESIGN_GATE.md` ( verdikt + 5 testov )
- `godot/scripts/managers/EventManager.gd` ( process_events, resolve_choice, _resolve_faction_id )
- `godot/scripts/core/GameState.gd` ( to_dict / from_dict, všetky fieldy )
- `godot/scripts/core/TickManager.gd` ( process_tick, poradie sub-reportov )
- `godot/scripts/managers/NarrationManager.gd` ( generate_chronicle, _PRIORITY, šablóny )
- `godot/scripts/managers/DiplomacyManager.gd` ( 7 frakcií, mood drift, zmluvy )
- `godot/scripts/managers/VictoryManager.gd` ( víťazstvá/prehry )
- `godot/ui/ObjectivesPanel.gd` ( 4 fázy, _diplomacy_side_goal )
- `godot/data/events_catalog.json` ( 13 statických eventov; 14. — council — je runtime v EventManager )
- `src/data/historicalEvents.ts` ( archivovaný zdroj — 14 event IDs )
- `src/core/engines/eventEngine.ts` ( archivovaný engine — podmienky, váhy )
- `src/scenarios/hungarianWar.ts` ( archivovaný scenár Devín 907 )

---

## 1. Katalóg 14 eventov — komplet

EventManager poskytuje 14 eventov. Z toho **13 je statických** v
`godot/data/events_catalog.json` ( overené: 11 v JSON + 2 opening eventy
pridané v P0.5 na integračnej vetve ). Štrnásty event, `council`, vzniká
**runtime** v `EventManager._build_council_event()` ( riadok 356 ) ako
8%-ný fallback — nie je v JSON. Celkový počet EventManager-accessible
eventov je teda **14**.

React `historicalEvents.ts` má 16 šablón ( 12 samostatných + 4 chainOnly
pokračovania ), z ktorých sa do Godotu portuje 14 — rozdiel je v tom, že
React `hist_hungarian_rumors_904` a `hist_byzantine_envoy_904` sú v Godote
zlúčené do opening eventu `hist_magyar_reports_902` a neskoršie byzantské
udalosti sú pokryté `byz_bride_proposal_906`.

### 1.1 Zoznam 14 event IDs ( záväzný )

| # | event_id | typ | rok/trigger | once | chainOnly | zdroj |
|---|----------|-----|-------------|------|-----------|-------|
| 1 | `hist_mojmir_coronation_902` | historical | 902/02 | true | false | P0.5 nový |
| 2 | `hist_magyar_reports_902` | historical | 902/06 | true | false | P0.5 nový |
| 3 | `hist_papal_legation_903` | historical | 903 | true | false | React |
| 4 | `byz_bride_proposal_906` | diplomatic | 906 | true | false | React |
| 5 | `byz_bride_wedding_907` | religious | chain | true | true | React |
| 6 | `byz_bride_insult_907` | diplomatic | chain | true | true | React |
| 7 | `hist_bogata_conspiracy_915` | historical | 915 | true | false | React |
| 8 | `bogata_trial_916` | diplomatic | chain | true | true | React |
| 9 | `bogata_uprising_917` | military | chain | true | true | React |
| 10 | `rand_bad_harvest` | random | yearMin 903 | false | false | React |
| 11 | `rand_border_raid` | military | yearMin 903 | false | false | React |
| 12 | `rand_noble_feud` | diplomatic | yearMin 903 | false | false | React |
| 13 | `rand_missionary_dispute` | religious | yearMin 903 | false | false | React |
| 14 | `council` | fallback | 8% šanca | false | false | EventManager._build_council_event |

**Poznámka:** React obsahuje aj `hist_hungarian_rumors_904`, `hist_byzantine_envoy_904`,
`hist_german_ultimatum_910`, `rand_traveling_merchant`, `rand_court_intrigue`.
Tieto sa do P1 **neportujú** — P1 scope je 14 eventov vyššie. Nové eventy nad
rámec idú do triage karty, nie sem ( §8 invarianty ).

### 1.2 Podmienky ( conditions )

Formát v JSON je `conditions: { year, month, yearMin }`. EventManager číta:

- `year` ( int ): ak > 0, musí sa zhodovať s `game_state.year`
- `month` ( int ): ak > 0, musí sa zhodovať s `game_state.month`
- `yearMin` ( int ): ak > 0, `game_state.year >= yearMin`

Pre reťazové eventy ( chainOnly: true ) je `conditions: {}` — spúšťajú sa
len cez `next_event` z nadradenej voľby.

**React podmienky, ktoré sa NEportujú do P1:**
- `factionMood` ( frakcia má mood min/max ) — EventManager.gd nemá matcher
- `nobleAttribute` ( atribút šľachtica min/max ) — nie v Godote
- `playerPrestige` — nie ako event condition
- `zupaLoyalty` ako condition — nie v EventManager.gd
- `zupaOwner` — nie
- `atWar` — nie
- `hasTreaty` — nie

Tieto podmienky z Reactu by vyžadovali nový condition engine. P1 ich
neimplementuje — všetky 14 eventov funguje len s year/month/yearMin.
Ak je potrebný pokročilejší condition matcher, zapiš ako triage kartu pre P2.

### 1.3 Váhy ( weight )

Platí len pre random eventy ( `type != "historical"`, `chainOnly: false` ).
`EventManager._try_random_event()` robí weighted pick cez `event_rng.randi_range(1, total_weight)`.

| event_id | weight | cooldownTicks |
|---|---|---|
| `rand_bad_harvest` | 15 | 24 |
| `rand_border_raid` | 12 | 15 |
| `rand_noble_feud` | 10 | 20 |
| `rand_missionary_dispute` | 10 | 20 |
| `council` (fallback) | — | — (8% šanca v `process_events` riadok 82) |

Council event je 8% šanca v `process_events()` **až po** tom, ako chain,
historical aj random zlyhajú. Nahrádza ho `_build_council_event()`.
Council nemá weight ani cooldown — je to fallback.

### 1.4 Reťazenia ( next_event )

Kľúč je `next_event` ( snake_case ). `EventManager.resolve_choice()` ( riadok 271 )
číta `choice_dict.has("next_event")` a `_try_chain_event()` ( riadok 108 )
matchuje `cat.get("id") == next_id` a `bool(cat.get("chainOnly", false))`.

| Nadradená voľba | next_event | Podmienka chainOnly |
|---|---|---|
| `byz_bride_proposal_906` → accept | `byz_bride_wedding_907` | true |
| `byz_bride_proposal_906` → decline | `byz_bride_insult_907` | true |
| `hist_bogata_conspiracy_915` → arrest | `bogata_trial_916` | true |
| `hist_bogata_conspiracy_915` → watch | `bogata_uprising_917` | true |

Po vyriešení choice s `next_event` sa `pending_event` nastaví na catálogo
nájdený event. Ak event s daným ID neexistuje alebo nie je `chainOnly: true`,
reťaz zlyhá a `pending_event` sa vynuluje.

### 1.5 Seeded RNG

**Záväzné invarianty:**

1. EventManager má vlastný `RandomNumberGenerator` ( `event_rng` ), inicializovaný
   z `game_state.event_rng_seed` ( default 42 ).
2. Po každej operácii, ktorá číta event_rng, sa stav zapíše späť do
   `game_state.event_rng_state` cez `_sync_rng_state()`.
3. Pri reloade ( from_dict ) sa `event_rng.state = game_state.event_rng_state`
   ak `event_rng_state != 0` ( riadok 19 EventManager.gd ).
4. DiplomacyManager má **samostatný** `rng: RandomNumberGenerator` ( mood drift ).
   NarrationManager má **samostatný** `rng` ( výber provincie v economy text ).
   Tieto RNG streamy sa **nemiešajú** s event_rng.
5. `game_state.event_rng_seed` a `game_state.event_rng_state` sú v `to_dict()` aj
   `from_dict()` ( riadky 59–60 a 108–109 GameState.gd ).

**Zákaz:**
- `randi()` / `randf()` / `randf_range()` mimo event_rng v EventManager
- Globálne RNG ( `randi()` bez seedu )
- Zmena seedu počas hry ( jedine SaveManager ho môže inicializovať )

### 1.6 No-immediate-repeat

`_record_last_event()` ( riadok 102 ) zaznamená `game_state.last_event_id`.
`_try_random_event()` ( riadok 184 ) preskočí event s rovnakým ID ako `last_event_id`.
`last_event_id` je v `to_dict()` / `from_dict()` ( riadok 61 a 110 ).

Toto je dočasná poistka, nie plnohodnotný cooldown systém. P1 ju zachováva.

### 1.7 Cooldowns

`event_cooldowns: Dictionary` v GameState ( riadok 34 ). Kľúč = event_id,
hodnota = `year * 12 + month` v momente resolve. V `_try_random_event()` sa
kontroluje `game_state.year * 12 + game_state.month < last + cooldown`.
`event_cooldowns` je v `to_dict()` / `from_dict()` ( riadok 58 a 107 ).

Cooldown sa nastavuje v `resolve_choice()` ( riadok 288 ) pre vyriešený event.
Council event ( fallback ) **nemá** cooldown — jeho 8% šanca je dostatočná
prietoková kontrola.

### 1.8 Triggered events

`triggered_events: Array` v GameState ( riadok 33 ). Záznam `once: true` eventov,
ktoré sa už stali. V `_try_historical_event()` ( riadok 145 ) sa kontroluje
`game_state.triggered_events.has(eid)`. V `to_dict()` / `from_dict()` ( riadok 57
a 105 ).

---

## 2. Fázové beaty v Objectives a väzba na diplomaciu

### 2.1 Existujúci stav

`ObjectivesPanel.gd` ( `godot/ui/ObjectivesPanel.gd` ) má 4 fázy hardcoded
v `refresh()`:

| Roky | Fáza | phase_name | phase_hint | goal_lines | next_step |
|---|---|---|---|---|---|
| 902–906 | I — Konsolidácia | "Fáza I — Konsolidácia (902–906)" | "Posilni ríšu pred príchodom Maďarov." | 3 ciele | zlatom/rokom podmienený |
| 907 | II — Kríza | "Fáza II — Kríza (907)" | "Bitka pri Devíne rozhoduje o prestíži." | 2 ciele | "Stlač „Devín 907"" |
| 908–959 | III — Prežitie | "Fáza III — Prežitie (908–959)" | "Obnov ríšu, diplomaciu a armády." | 3 ciele | "„Ďalší mesiac" + záložka Diplomacia." |
| 960+ | IV — Cesta k 1000 | "Fáza IV — Cesta k 1000" | "Legitimita, prestíž a prežitie dynastie." | 2 ciele | roky do 1000 |

Diplomatický side-goal je v `_diplomacy_side_goal()` — nájde najhoršiu frakciu
(mood < 50, ignoruje hungary) a pridá ju do goals + prepíše next_step ak mood < 30.

### 2.2 P1 kontrakt pre beaty

**Pravidlá:**

1. **Žiadny nový GameState field pre fázy.** Fáza sa odvodzuje z `year` ( int ),
   ktorý už existuje. Nepripúšťa `current_phase: String` alebo podobné.
2. **Žiadne nové pole pre diplomatický kontext.** `_diplomacy_side_goal()`
   číta `game_state.factions` ( Dictionary, už existuje ) cez
   `gm.diplomacy_manager.list_factions()`. P1 len mení logiku a texty.
3. **Ak by vznikol nový field** ( napr. `army_wizard_done: bool` pre §3 ),
   musí byť v `to_dict()` aj `from_dict()`.
4. **Žiadny anglický UI reťazec.** Všetky texty slovensky s diakritikou.
5. **Žiadna zmena Devín 907 kánonu.** Fáza II ( 907 ) zobrazí varovanie
   a odkaz na Devín button, ale nemení výsledok bitky.

### 2.3 Beat špecifikácia ( pre `rm-godot` t_0c31d3fa )

Každý beat musí mať:

| Položka | Popis |
|---|---|
| **Podmienka dokončenia** | Čo musí platiť v `game_state` aby sa beat považoval za splnený ( napr. `year >= 903`, `gold >= 800`, `devine_resolved == true` ) |
| **Text akcie** | Slovenský text pre `_next_label` ( "Teraz urob" ) |
| **Diplomatická väzba** | Ako sa beat týka frakcií ( text + logika v `_diplomacy_side_goal` ) |
| **Priorita** | Poradie zobrazenia ak je viac ako jeden aktívny beat |

#### Beat A — Konsolidácia ( 902–906 )

| Krok | Podmienka | next_step text | Diplomatická väzba |
|---|---|---|---|
| A1 | `year == 902 && month <= 2` | "1) Prečítaj si ciele 2) Klikni na Nitru 3) Stlač „Ďalší mesiac"" | Žiadna — hráč sa učí |
| A2 | `gold < 800 && year < 906` | "Stlač „Ďalší mesiac" — ekonomika dopĺňa zdroje." | Žiadna — budovanie |
| A3 | `gold >= 800 && year < 906` | "Pokračuj „Ďalší mesiac". Okolo 906 sa priblíži Devín." | Ak `hungary.mood < 30`: "Pozor: Maďari sa hnevali — zváž dar v Diplomacii." |
| A4 | `year >= 906 && month >= 1 && !devine_resolved` | "Blíži sa 907 — priprav armádu k Devínu (pozri notifikáciu)." | Ak `byzantium.mood < 40`: "Byzancia je chladná — sobáš môžete ohroziť." |

#### Beat B — Kríza ( 907 )

| Krok | Podmienka | next_step text | Diplomatická väzba |
|---|---|---|---|
| B1 | `year == 907 && !devine_resolved` | "Stlač „Devín 907" v nástrojoch dole." | Žiadna — bitka je kánon |
| B2 | `devine_resolved` | "Devín padol. Pokračuj „Ďalší mesiac"." | Po Devíne sa `hungary.mood` zvýši o +30 — zobraziť |

#### Beat C — Prežitie ( 908–959 )

| Krok | Podmienka | next_step text | Diplomatická väzba |
|---|---|---|---|
| C1 | `year > 907 && year < 915` | "Obnov ríšu: ekonomika a diplomacia." | Najhoršia frakcia mood < 50 → "Dar frakcii %s v Diplomacii (nálada %.0f)." |
| C2 | `year >= 915 && year < 920` | "Sleduj východné župy — Sprisahanie Bogata." | Ak `uzhorod.loyalty < 40`: "Užhorod je nestabilný — hrozí sprisahanie." |
| C3 | `year >= 920 && year < 960` | "Diplomacia a armády — udrž lojalitu." | Najhoršia frakcia mood < 30 → urgent |

#### Beat D — Legitimita ( 960+ )

| Krok | Podmienka | next_step text | Diplomatická väzba |
|---|---|---|---|
| D1 | `year >= 960` | "~%d rokov · župy: %d · prestíž: %d" | Frakcie s mood < 40 → zobraziť |

### 2.4 Diplomatická väzba ( kontrakt )

`_diplomacy_side_goal()` musí:

1. Získať `gm.diplomacy_manager.list_factions()` — vráti pole dictov s `id`, `name`, `mood`, `relations`.
2. Pre každú frakciu okrem `moravia` a `hungary` zistiť `mood`.
3. Ak `mood < 50`, pridať do goals: "Diplomacia: %s má náladu %.0f".
4. Ak `mood < 30`, prepísať `next_step`: "Dar frakcii %s v záložke Diplomacia (nálada %.0f).".
5. V Beat C2: čítať `game_state.provinces["uzhorod"].loyalty` — ak < 40, pridať
   goal o sprisahaní.

**Inžiniering:** Žiadny nový GameState field. Číta sa z existujúcich `factions`
( Dictionary ) a `provinces` ( Dictionary ). `ObjectivesPanel._count_owned()`
už existuje a funguje.

---

## 3. Onboarding armády pred Devínom 907

### 3.1 Existujúci stav

- `ArmyUI.gd` existuje v `godot/ui/ArmyUI.gd` — bočný panel s armádami.
- `HungarianWarScenario` ( React `hungarianWar.ts` ) definuje armády, veliteľov
  ( Árpád, Radomír ), terény ( river/field ).
- `GameManager.gd` má `run_devine_battle()` — spúšťa scenár.
- `devine_resolved: bool` v GameState ( riadok 32 ) — poistka proti 2x.
- Threat clock ( `StatusBar.gd` ) zobrazuje mesiace do 907.

### 3.2 P1 kontrakt pre army wizard ( pre `rm-godot` t_1813d684 )

**Wizard je UI sekvencia, nie nový systém.** Kroky:

| Krok | Trigger | Akcia | GameState |
|---|---|---|---|
| W1 | `year == 906 && month == 06` | Notifikácia: "Pošli armádu k Devínu" | Číta existujúce `armies` |
| W2 | Hráč klikne notifikáciu | Otvorí `ArmyUI` panel, zvýrazní tlačidlo "Vytvor armádu" | Žiadny nový field |
| W3 | Hráč vytvorí/vyberie armádu | Zvýrazní veliteľa ( ak existuje `army_templates` ) | Číta `army_templates` |
| W4 | Hráč potvrdí odoslanie | Zatvorí wizard, zobrazí "Armáda smeruje k Devínu" | Žiadny field |

**Nový GameState field:**

```
var army_wizard_done: bool = false
```

- `to_dict()`: pridať `"army_wizard_done": army_wizard_done`
- `from_dict()`: pridať `army_wizard_done = bool(data.get("army_wizard_done", false))`
- Wizard sa zobrazí len ak `!army_wizard_done && year >= 906`
- Po dokončení W4: `army_wizard_done = true`
- Save/load zachová stav — wizard sa nezopakuje.

**Kánon zachovaný:**
- Wizard **nemení** výsledok Devín 907 ( winner == attacker ).
- Wizard **neblokuje** spustenie Devínu — hráč ho môže preskočiť.
- `devine_resolved` kontroluje jednorázovosť bitky, nie wizardu.

**Texty ( slovensky s diakritikou, žiadny anglický UI reťazec ):**
- Notifikácia W1: "Pošli armádu k Devínu — Maďari sa zhromažďujú."
- W2 title: "Príprava na Devín"
- W2 body: "Rok 906. Maďarské družiny sa zhromažďujú za Karpatskými priesmykmi. Priprav armádu, kým prišla zima neuzavrie cesty."
- W3: "Vyber veliteľa — Radomír z Gemera je skúsený vojak."
- W4: "Armáda smeruje k Devínu. Bitka sa odohrá v roku 907."

### 3.3 Prepojenie s threat clock

Threat clock v `StatusBar.gd` už ukazuje "Do Maďarov: N mes.".
Po 907: "Do roku 1000: N rokov.".
Army wizard sa spúšťa cez notifikáciu, nie cez threat clock priamo —
threat clock je signalizácia, wizard je akcia.

---

## 4. Threat markery pre lojalitu, náladu a food hrozbu

### 4.1 Existujúci stav

- `MapView.gd` ( `godot/scenes/map/MapView.gd` ) zobrazuje 12 žúp.
- `game_state.provinces` ( Dictionary ) má pre každú župu: `owner_faction`,
  `loyalty` ( 0–100 ), `religion`, `prosperity`.
- `game_state.factions` ( Dictionary ) má pre každú frakciu: `name`, `mood` ( 0–100 ), `relations`.
- `game_state.resources.food` ( int ) — jedlo.

### 4.2 P1 kontrakt pre threat markery ( pre `rm-godot` t_13f3c199 )

**Tri typy markerov:**

| Marker | Prah | Zdroj dát | Vizuál |
|---|---|---|---|
| **Lojalita župy** | `provinces[id].loyalty < 30` | `game_state.provinces` | Crimson ikona na župe ( `moravia-crimson #8B1E2D` ) |
| **Nálada frakcie** | `factions[fid].mood < 25` ( okrem `hungary` a `moravia` — tieto frakcie nemajú mood marker ) | `game_state.factions` | Warning ikona na okraji mapy ( `warning #C9902F` ) |
| **Food hrozba** | `resources.food < 100` | `game_state.resources` | Warning chip v StatusBar ( už existuje štruktúra ) |

**Pravidlá:**

1. **Žiadny nový GameState field.** Markery sa odvodzujú z existujúcich hodnôt.
2. **Žiadny herný dôsledok.** Markery len signalizujú — nemenia lojalitu,
   náladu ani food.
3. **Prahy sú konštanty v MapView.gd**, nie v GameState:
   ```
   const THREAT_LOYALTY_THRESHOLD := 30.0
   const THREAT_MOOD_THRESHOLD := 25.0
   const THREAT_FOOD_THRESHOLD := 100
   ```
4. **Aktualizácia:** `MapView._ready()` a `MapView.refresh()` ( ak existuje )
   alebo signál z `tick_completed`. Po každom ťahu sa markery prekreslia.
5. **Odstránenie:** Ak hodnota stúpne nad prah, marker zmizne.
6. **Duplikáty:** Každá župa/frakcia môže mať len jeden marker. Pri aktualizácii
   sa najprv zničia staré a vytvoria nové ( alebo repozicujú ).

**Tooltip texty ( slovensky s diakritikou ):**

| Marker | Tooltip |
|---|---|
| Lojalita župy | "Lojalita %s: %.0f — hrozba vzbury" ( názov župy, hodnota ) |
| Nálada frakcie | "%s: nálada %.0f — hrozba konfliktu" ( názov frakcie, hodnota ) |
| Food | "Zásoby jedla: %d — hladomor" ( hodnota ) |

**Devín 907:** Marker lojality Devína po bitke ( `loyalty -20` per kánon )
sa zobrazí ako každý iný — žiadny špeciálny kód.

### 4.3 Farby ( z VISUAL_DIRECTION.md )

- `moravia-crimson #8B1E2D` — hostile / low loyalty
- `warning #C9902F` — warning / medium
- `success #5A9C5A` — positive ( nie pre threat )

---

## 5. GameState — existujúce a nové polia

### 5.1 Existujúce polia ( neprepisovať, len čítať )

| Field | Typ | zdroj | Použitie v P1 |
|---|---|---|---|
| `year` | int | GameState.gd:13 | Fázy, podmienky eventov |
| `month` | int | GameState.gd:14 | Podmienky eventov, threat clock |
| `provinces` | Dictionary | GameState.gd:15 | Threat markery lojality, zupaLoyalty |
| `factions` | Dictionary | GameState.gd:17 | Threat markery nálady, diplomacia |
| `resources` | Dictionary | GameState.gd:18 | Food hrozba, economy |
| `armies` | Dictionary | GameState.gd:26 | Army wizard |
| `army_templates` | Dictionary | GameState.gd:27 | Army wizard |
| `pending_event` | Variant | GameState.gd:29 | EventManager |
| `devine_resolved` | bool | GameState.gd:32 | Devín kánon |
| `triggered_events` | Array | GameState.gd:33 | once eventy |
| `event_cooldowns` | Dictionary | GameState.gd:34 | cooldown eventov |
| `event_rng_seed` | int | GameState.gd:35 | seeded RNG |
| `event_rng_state` | int | GameState.gd:36 | seeded RNG |
| `last_event_id` | String | GameState.gd:37 | no-repeat |
| `tutorial_step` | int | GameState.gd:38 | coach |
| `tutorial_done` | bool | GameState.gd:39 | coach |
| `chronicle` | Array | GameState.gd:28 | narácia |
| `game_over` | bool | GameState.gd:30 | víťazstvo/prehra |
| `ending` | Dictionary | GameState.gd:31 | víťazstvo/prehra |
| `nobles` | Dictionary | GameState.gd:16 | dynastia |

Všetky sú v `to_dict()` aj `from_dict()` ( riadky 42–64 a 67–112 ).

### 5.2 Nové polia pre P1

| Field | Typ | Karta | to_dict | from_dict |
|---|---|---|---|---|
| `army_wizard_done` | bool = false | t_1813d684 | áno | áno |

**Záväzné pravidlo:** Každý nový field, ktorý P1 pridáva, **musí** byť v
`to_dict()` aj `from_dict()` s default hodnotou zodpovedajúcou deklarácii.
Ak implementér zabudne, SaveManager vyrobí tichú stratu dát.

### 5.3 Polia, ktoré sa **nemajú** pridávať

| Návrh | Dôvod zamietnutia |
|---|---|
| `current_phase: String` | Fáza sa odvodzuje z `year` — nie je ju treba ukladať |
| `threat_markers: Dictionary` | Markery sú odvodené z existujúcich hodnôt |
| `event_log: Array` | `chronicle` už existuje a plní túto úlohu |
| `diplomacy_cache: Dictionary` | `factions` už obsahuje mood + relations |

---

## 6. Devín 907 kánon ( §15.6 NAVRH_HERNY_ZAZITOK.md — záväzné )

| Invariant | Hodnota | Zdroj |
|---|---|---|
| Víťaz | `winner == "attacker"` ( Maďari ) | NAVRH §15.6, VictoryManager |
| Frekvencia | max 1× za run ( `devine_resolved: bool` ) | GameState:32, P-1.1 |
| Prestíž | −30 | NAVRH §15.6, task body |
| Lojalita Devína | −20 | NAVRH §15.6, task body |
| Nálada Maďarov | +30 | NAVRH §15.6, task body |
| RNG | event_rng ( vlastný seed key ) | EventManager:8–20 |
| React src/ | archivovaný — len dátový zdroj | NAVRH §5 |

**Zákazy:**
- Nemeniť battle math ani "morálny" flip pre hráča
- Nespúšťať Devín manuálne pred 906 bez poistky
- Neopakovať auto-trigger 907 ak `devine_resolved == true`
- UI/kronika/kapitola musia hovoriť pravdu: kríza, prehra Moravy pri Devíne

---

## 7. React src/ — postavenie

`src/` je **archivovaný**. Pravidlá:

1. **Žiadne nové featury v React.** Godot je primár.
2. **src/ je zdroj dát a logiky na port.** Číta sa, neupravuje.
3. **Event IDs a mená frakcií** z `historicalEvents.ts` sa portujú do
   `events_catalog.json`. React `Bogatovci` fiktívna frakcia sa nahrádza
   `zupaLoyalty: {"uzhorod": ...}` ( P0_EVENTY.md §0.2 ).
4. **eventEngine.ts logika** ( conditions, weighted pick, cooldown ) je
   portovaná do EventManager.gd. React podmienky ako `factionMood`, `atWar`
   sa v P1 neportujú ( §1.2 ).
5. **hungarianWar.ts** je zdroj pre scenár Devín 907 ( armády, velitelia,
   terény ). V Godote je implementovaný cez `GameManager.run_devine_battle()`.

---

## 8. Invarianty a hranice P1

1. **Nezväčšovať scope P0.** P1 nepripúšťa P0.8 ani eventy nad 14.
   Dobré nápady nad rámec idú ako triage karty.
2. **Nemeniť záväzné balans čísel.** Devín 907 dôsledky ( −30/−20/+30 )
   sú v §15.6 záväzné.
3. **Nemeniť tick poradie.** TickManager.process_tick() poradie sub-reportov
   ( economy → nobility → diplomacy → war → events → succession → religion →
   victory → armies → campaign → chronicle ) je záväzné.
4. **Nemeniť NarrationManager._PRIORITY.** Poradie sub-reportov v narácii
   ( event → war → diplomacy → succession → religion → nobility → economy →
   armies → campaign → victory ) je záväzné.
5. **Nemeniť faction IDs.** Sedmička `moravia, franks, bavaria, hungary,
   poland, bohemia, byzantium` je záväzná.
6. **Nemeniť province IDs.** Dvanástka `bratislava, devin, gemer, hont,
   morava, nitra, novohrad, spis, tekov, trencin, uzhorod, zemplin` je záväzná.

---

## 9. Zoznam dotknutých súborov

### Súbory, ktoré P1 modifikuje ( pre implementátorov )

| Súbor | Karta | Zmena |
|---|---|---|
| `godot/data/events_catalog.json` | t_c0f01d68 ( rm-core ) | 13 statických eventov: conditions, weights, chains ( council je runtime v EventManager ) |
| `godot/scripts/managers/EventManager.gd` | t_c0f01d68 ( rm-core ) | Conditions, weights, chain logic, RNG ( už má základ z P0 ) |
| `godot/scripts/core/GameState.gd` | t_c0f01d68 + t_1813d684 | `army_wizard_done` field + to_dict/from_dict |
| `godot/ui/ObjectivesPanel.gd` | t_0c31d3fa ( rm-godot ) | Fázové beaty, diplomatická väzba |
| `godot/ui/ArmyUI.gd` | t_1813d684 ( rm-godot ) | Army wizard kroky |
| `godot/scenes/map/MapView.gd` | t_13f3c199 ( rm-godot ) | Threat markery |
| `godot/ui/StatusBar.gd` | t_13f3c199 ( rm-godot ) | Food threat chip ( ak chýba ) |
| `godot/scenes/main/Main.gd` | t_1813d684 ( rm-godot ) | Wizard trigger, notifikácia |

### Súbory, ktoré sa **neupravujú** v P1

| Súbor | Dôvod |
|---|---|
| `godot/scripts/core/TickManager.gd` | Poradie sub-reportov je záväzné |
| `godot/scripts/managers/NarrationManager.gd` | _PRIORITY a šablóny sú záväzné ( P0 fix 4a bol hotový ) |
| `godot/scripts/managers/DiplomacyManager.gd` | Frakcie a mood drift fungujú, nemenné |
| `godot/scripts/managers/VictoryManager.gd` | Víťazstvá/prehry sú záväzné |
| `godot/scripts/managers/BattleManager.gd` | Battle math je záväzný |
| `godot/scripts/managers/WarManager.gd` | War logic je záväzná |
| `src/` ( React ) | Archivovaný — len čítať |
| `docs/NAVRH_HERNY_ZAZITOK.md` | Zdroj pravdy, nemenný |

---

## 10. Akceptačné kritériá

### Pre rm-core ( t_c0f01d68 — port 14 eventov )

- [ ] `events_catalog.json` obsahuje presne 13 statických eventov z §1.1 ( council je runtime v `EventManager._build_council_event()` )
- [ ] Každý event má `id`, `type`, `title`, `body`, `art_id`, `conditions`, `choices`
- [ ] `once: true` eventy sa neopakujú ( `triggered_events` kontrola )
- [ ] `chainOnly: true` eventy sa nespustia cez historical/random scan
- [ ] `next_event` ( snake_case ) odkazuje na existujúci chainOnly event
- [ ] Bogata reťaz používa `zupaLoyalty: {"uzhorod": ...}`, nie `moodChanges: {"hungary": ...}`
- [ ] Event RNG je na vlastnom seed key ( `event_rng_seed` / `event_rng_state` )
- [ ] Rovnaký seed → rovnaký výsledok ( deterministický )
- [ ] `army_wizard_done` je v `to_dict()` aj `from_dict()`
- [ ] Všetky texty slovensky s diakritikou
- [ ] Žiadny anglický UI reťazec
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS` + Devín attacker
- [ ] `resolve_choice()` vracia `event_id`, `choice_result`, `context` podľa P0_EVENTY.md §9.5

### Pre rm-godot ( t_0c31d3fa — fázové beaty )

- [ ] `ObjectivesPanel.refresh()` zobrazí správnu fázu podľa `year`
- [ ] Každá fáza má `phase_name`, `phase_hint`, `goal_lines`, `next_step` v slovenčine
- [ ] `_diplomacy_side_goal()` číta `list_factions()` a zobrazí najhoršiu frakciu
- [ ] Ak `mood < 30`, `next_step` sa prepíše na diplomatickú akciu
- [ ] Žiadny anglický UI reťazec
- [ ] Žiadny nový GameState field ( okrem `army_wizard_done` z t_1813d684 )
- [ ] Prechod medzi fázami funguje po `process_next_month`
- [ ] Save/load zachová fázu ( odvodenú z `year` )

### Pre rm-godot ( t_1813d684 — army wizard )

- [ ] Notifikácia "Pošli armádu k Devínu" sa zobrazí v 906/06
- [ ] Wizard sa otvorí len ak `!army_wizard_done && year >= 906`
- [ ] Po dokončení W4: `army_wizard_done = true`
- [ ] Wizard sa nezopakuje po save/load
- [ ] Wizard **neblokuje** spustenie Devín 907
- [ ] `devine_resolved` ostáva jediná poistka pre bitku
- [ ] `army_wizard_done` je v `to_dict()` aj `from_dict()`
- [ ] Všetky texty slovensky s diakritikou
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS` + Devín attacker

### Pre rm-godot ( t_13f3c199 — threat markery )

- [ ] Marker lojality sa zobrazí pri `provinces[id].loyalty < 30`
- [ ] Marker nálady sa zobrazí pri `factions[fid].mood < 25` ( okrem hungary a moravia )
- [ ] Marker food sa zobrazí pri `resources.food < 100`
- [ ] Markery zmiznú, keď hodnota stúpne nad prah
- [ ] Žiadny duplikát markeru pre tú istú župu/frakciu
- [ ] Tooltipy slovensky s diakritikou
- [ ] Žiadny herný dôsledok ( signalizácia len )
- [ ] Žiadny nový GameState field
- [ ] Markery prežijú reload mapy/save
- [ ] `SMOKE_PASS` + `SMOKE_M6_PASS`

---

## 11. Testy

### Smoke ( už existujúce, musia ostať zelené )

```
cd godot && bash tools/check_all.sh
```

Očakávaný výstup: `SMOKE_PASS`, `SMOKE_M6_PASS`, Devín attacker.

### Nové testy pre P1

| Test | Súbor | Overuje |
|---|---|---|
| Eventy 14 | `test/integration/test_event_catalog_p1.gd` | Všetkých 14 IDs, conditions, chains |
| Seeded RNG | `test/integration/test_event_rng_p1.gd` | Rovnaký seed → rovnaký výsledok |
| Army wizard | `test/integration/test_army_wizard.gd` | army_wizard_done serializácia |
| Threat markers | `test/integration/test_threat_markers.gd` | Prahy, odstránenie, duplikáty |
| Objectives fáz | `test/integration/test_objectives_phases.gd` | Prechod 902 → 907 → 908 → 960 |

---

## 12. Narration hook kontrakt ( pre rm-content / rm-core )

`EventManager.resolve_choice()` musí vracať ( už implementované v P0, P1 zachováva ):

```
{
    "ok": bool,
    "effect": Dictionary,
    "chronicle": String,
    "event_id": String,           // pending.get("id", "")
    "choice_result": String,      // choice_id argument, bez transformácie
    "context": {
        "year": int,
        "province_ids": Array,   // kľúče zupaLoyalty
        "faction_ids": Array,    // kľúče moodChanges, rezolvované cez _resolve_faction_id()
        "next_event": String     // choice_dict.get("next_event", "")
    }
}
```

Overenie v `smoke_test.m6.gd` podľa tabuľky v P0_EVENTY.md §9.5.

---

## 13. Jazyk a texty

1. **Slovenčina s diakritikou** pre všetky player-facing texty.
2. **Žiadny anglický UI reťazec** v žiadnom `.gd` súbore, ktorý sa zobrazuje
   hráčovi.
3. **Historický register** bez archaizujúceho kýču. Krátke vety.
4. **Žiadne emoji** v hernom texte.
5. **Názvy žúp a frakcií** podľa `NarrationManager` konštant:
   - `PROVINCE_NAMES` ( 12 žúp )
   - `PROVINCE_LOCATIVES` ( 12 lokálov )
   - `FACTION_NAMES` ( 7 frakcií )
