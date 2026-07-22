# Úpravy po implementácii P-1.1 + P0 (audit voči commitu 8d5e464)

> **Toto je audit, nie implementácia.** Kód sa nemení bez explicitného go.
> Nadväzuje na `NAVRH_HERNY_ZAZITOK.md` (v1.3) — Devín kánon je uzavretý
> (Maďari/útočník vždy vyhrajú), P-1.1 a P0.1–P0.7 boli commitnuté v
> `8d5e464 feat(P-1.1+P0): Devín guard + event catalog + threat clock + TurnReport Δ`.
>
> Tento zoznam vznikol priamym čítaním kódu **po** tomto commite
> (`Main.gd`, `WarManager.gd`, `EventManager.gd`,
> `godot/data/events_catalog.json`, `HungarianWarScenario.gd`,
> `GameState.gd`) — nie z popisu commit message.

---

## 1. Kritické bugy — obsah sa reálne nespustí

### 1.1 `nextEvent` (camelCase) vs `next_event` (snake_case) — reťazové eventy sú mŕtve

**Súbory:** `godot/data/events_catalog.json`, `godot/scripts/managers/EventManager.gd:87,213`

Port z TS zachoval kľúč `"nextEvent"` v JSON katalógu (4× — `byz_bride_proposal_906` obe voľby,
plus referencie v `bogata_trial_916`/pôvodne cez `hist_bogata_conspiracy_915`). Ale
`EventManager.gd` číta všade `next_event` (snake_case):

```gdscript
# _try_chain_event(), riadok 87
var next_id: String = str(ev.get("next_event", ""))   # v JSON je "nextEvent" → vždy ""

# resolve_choice(), riadok 213
if choice_dict.has("next_event"):                       # v JSON je "nextEvent" → nikdy true
```

**Dôsledok:** všetky 4 reťazové eventy (`byz_bride_wedding_907`,
`byz_bride_insult_907`, `bogata_trial_916`, `bogata_uprising_917`) sú
**nedosiahnuteľný mŕtvy obsah** — hráč nikdy neuvidí svadbu/urážku
Konštantínopolu ani súd/povstanie Bogatovcov, hoci text pre ne existuje.

**Fix:** zjednotiť na jeden kľúč — buď premenovať `nextEvent` → `next_event`
v `events_catalog.json` (4 miesta), alebo opraviť `EventManager.gd` na
`"nextEvent"`. Odporúčam premenovať JSON (snake_case je konvencia zvyšku
GDScript kódu v tomto projekte).

- [ ] Zjednotiť kľúč `next_event`/`nextEvent` v JSON aj GDScript
- [ ] Manuálne overiť v hre: rok 906 → prijať ponuku sobáša → rok 907 → svadba sa naozaj spustí

### 1.2 `moodChanges` (nálady frakcií) sa stratili pri porte — a `resolve_choice()` ich ani nevie spracovať

**Súbory:** `godot/data/events_catalog.json`, `godot/scripts/managers/EventManager.gd:176-252`

Pôvodný `src/data/historicalEvents.ts` mal takmer pri každej voľbe
`moodChanges` (napr. `{'Cyrilometodskí Kňazi': {trust: -5}}`,
`{'Byzantskí Poslovia': {loyalty: 10, trust: 5}}`, efekty na
`Bogatovci`, `Nemeckí Kolonisti`, `Župani`). V `events_catalog.json` sa
**nevyskytuje ani raz** (0 výskytov) a `EventManager.resolve_choice()`
nemá žiadnu vetvu, ktorá by `moodChanges` aplikovala na
`game_state.factions` (na rozdiel od `resources` a `religionChange`,
ktoré sa aplikujú).

**Dôsledok:** polovica pôvodného zámeru eventov — že rozhodnutia menia
vzťah s konkrétnymi frakciami, nie len zlato/prestíž — sa v Godot verzii
nestala. Eventy fungujú, ale sú plytšie než ich pôvodný TS náprotivok.

**Fix (dvojkrokový):**
- [ ] Doplniť `moodChanges` do `events_catalog.json` z pôvodného
      `historicalEvents.ts` (kopírovať dáta, faction názvy zladiť s
      `DiplomacyManager._ensure_default_factions()` — pozor, tam sú faction
      id ako `"franks"`, `"bavaria"`, `"hungary"` atď., nie plné mená ako
      v TS zdroji — potrebné mapovanie názov→id)
- [ ] V `EventManager.resolve_choice()` doplniť vetvu, ktorá pre
      `choice_dict.get("moodChanges", {})` upraví `game_state.factions[fid].mood`
      (rovnaká logika ako `DiplomacyManager.send_gift`/`threaten`)

### 1.3 `zupaLoyalty` efekt je v dátach, ale kód ho nečíta

**Súbory:** `godot/data/events_catalog.json` (`hist_hungarian_rumors_904`), `EventManager.gd:176-252`

Voľba „Posilniť opevnenia Devína a Nitry“ má v JSON
`"zupaLoyalty": {"devin": 5, "nitra": 5}`, ale `resolve_choice()` túto
vetvu nikde nespracúva — efekt je tichý no-op (hráč zaplatí 50 zlata,
ale sľúbený bonus lojality sa nedostaví).

**Fix:**
- [ ] V `resolve_choice()` doplniť aplikáciu `zupaLoyalty` na
      `game_state.provinces[pid].loyalty` (podobne ako `zupaLoyaltyChanges`
      pattern v pôvodnom TS `eventEngine.ts`)
- [ ] Over, že `"devin"` ako province id skutočne existuje v
      `game_state.provinces` po načítaní z `data/provinces/` (pozri 2.1 —
      súvisiaci nález o province „devin“)

### 1.4 Event panel má len 2 tlačidlá — 2 z 16 eventov majú 3 voľby

**Súbory:** `godot/scenes/main/Main.gd:277-289` (`_show_event`), `events_catalog.json`

`rand_missionary_dispute` (Spor misionárov) a `bogata_trial_916` (Súd nad
sprisahancami) majú v katalógu 3 voľby, ale `Main.gd` má natvrdo
zadrôtované len `choice_a_btn`/`choice_b_btn` (žiadne `ChoiceC`).
Tretia voľba sa v UI vôbec nezobrazí — hráč o nej nevie a nemôže ju
vybrať.

**Fix:**
- [ ] Pridať `ChoiceC` tlačidlo do `EventPanel.tscn` + `Main.gd`
      (`@onready var choice_c_btn`, signál, viditeľnosť podľa
      `choices.size() >= 3`)
- [ ] Alternatíva s menším zásahom: skrátiť tieto 2 eventy na 2 voľby pri
      porte (menej verné originálu, ale rýchlejšie) — **neodporúčam**,
      tretia voľba (napr. „Zakázať verejné spory oboch strán“ — neutrálna
      cesta) je herne zaujímavá práve preto, že nie je len A/B

---

## 2. Nezrovnalosti súvisiace s Devín 907 (canon už uzavretý, ale mechanika má diery)

### 2.1 Province „devin“ existuje v dátach, ale bitka aj tak odmeňuje „bratislava“

**Súbory:** `godot/data/provinces/devin.json` (existuje), `godot/scripts/scenarios/HungarianWarScenario.gd:31,106`

`docs/FEEDBACK_INTEGRATION.md` (staršia analýza, M5) eviduje ako
**✅ Hotovo**: *„Devín natvrdo stotožnený s Bratislavou → pridaná
samostatná provincia `devin`.“* Provincia v dátach naozaj existuje
(`data/provinces/devin.json`). Ale `HungarianWarScenario.gd` stále má:

```gdscript
const PROVINCE_DEVIN := "bratislava"          # riadok 31 — nezmenené
...
for province_id in ["nitra", "bratislava"]:    # riadok 106 — "devin" chýba
```

**Dôsledok:** odmena za víťazstvo pri Devíne (keby k nej niekedy došlo —
pozri kánon: nemala by, ale kód na to má vetvu) aj `set_occupier`
volanie po bitke stále cielia na `"bratislava"`, nie na vlastnú
province `"devin"`. Oprava z `FEEDBACK_INTEGRATION.md` je teda **neúplná
napriek zápisu „Hotovo“** — dobré miesto na opravu súbežne s P0.7
event-content prácou vyššie, keďže rovnaký problém (province id „devin“)
sa týka aj bodu 1.3.

**Fix:**
- [ ] `PROVINCE_DEVIN := "devin"` (over, že `province_id "devin"` má
      správnych `neighbors` v `map_layout.json`/`devin.json`, inak sa
      pokazí `are_adjacent`/`set_occupier`)
- [ ] Loyalty-reward loop: `["nitra", "devin"]` alebo `["nitra", "bratislava", "devin"]`
      podľa toho, čo je herne zamýšľané (rozhodni, či Bratislava má byť
      súčasťou odmeny, alebo len Nitra + Devín)
- [ ] Aktualizovať `FEEDBACK_INTEGRATION.md` bod 4 — buď opraviť status,
      alebo dopísať poznámku, že fix bol čiastočný

### 2.2 Manuálne tlačidlo „Devín 907“ nemá vekové obmedzenie na klik — len kozmetický text

**Súbor:** `godot/scenes/main/Main.gd:187-201,382-388`

`_on_devine()` sa dá spustiť v **ktoromkoľvek roku** (napr. 902) — jediná
ochrana je `devine_resolved` flag (P-1.1, funguje správne). Text tlačidla
sa mení na „★ odporúčané“ len v rokoch 906–908 (`_refresh_ui`,
riadok 385), ale to hráča fyzicky nezastaví kliknúť skôr.

**Dôsledok:** ak hráč klikne v roku 902, bitka sa odohrá (Maďari vyhrajú,
kánon platí), `devine_resolved = true` sa nastaví — **ale**
`WarManager.process_wars()` auto-trigger pri 907/07 sa korektne
nespustí (guard funguje). Problém je nižšie, v UI:

`_update_story_line()` (riadok 118-131) **nekontroluje `devine_resolved`**
a naďalej počíta „Do maďarskej invázie: ~N mes.“ smerom k roku 907, aj
keď sa bitka už odohrala v roku 902. Hráč dostane mätúci, neplatný
odpočet ku kríze, ktorá sa už stala.

**Fix (vyber jeden, alebo oba):**
- [ ] A) Zablokovať/skryť `devine_btn` pred rokom 906 (`disabled = y < 906`
      v `_refresh_ui`) — najjednoduchšie, zachová dramaturgiu
- [ ] B) V `_update_story_line()` pridať vetvu `if gs.devine_resolved:`
      → iný text („Devín už rozhodol osud roku 907 — ďalej smerom k 1000“)
      namiesto odpočtu k udalosti, ktorá už prebehla

Odporúčam **A** ako primárny fix (lacnejšie, rieši príčinu) a **B** ako
poistku pre prípad, že sa flag niekedy nastaví mimo poradia (napr. cez
load starého save).

### 2.3 Guard proti opakovaniu je duplikovaný na 3 miestach, nie na 1

**Súbory:** `Main.gd:188`, `WarManager.gd:31,59-61`

Kontrola `devine_resolved` je teraz v `Main._on_devine()`, vo
`WarManager.process_wars()` aj vo `WarManager.resolve_devine_battle()` —
funkčne to funguje (defense-in-depth), ale najnižšia vrstva
(`HungarianWarScenario.resolve_devine_battle()`) guard **nemá**. Akýkoľvek
budúci kód, ktorý by volal scenár priamo (obchádzajúc `WarManager`), by
bug P-1.1 znovu zaviedol.

**Fix (nízka priorita, cleanup):**
- [ ] Presunúť autoritatívnu kontrolu do
      `HungarianWarScenario.resolve_devine_battle()` samotného; volania z
      `WarManager` môžu zostať ako rýchly early-return, ale nemali by byť
      jediné miesto pravdy

---

## 3. P0 položky, ktoré commit len pripravil, nie dokončil

Commit message k `8d5e464` sám priznáva rozsah — dôležité je nezapočítať
tieto body ako hotové v ďalšom pláne:

### 3.1 P0.1 — Coach na mape: 0 % hotovo, len dáta

**Stav:** `GameState.gd` má `tutorial_step: int = 0` a
`tutorial_done: bool = false` (uložené aj v save), ale **nič v kóde ich
nečíta ani nezapisuje** (mimo `to_dict`/`from_dict`). Neexistuje overlay
scéna, dimovanie, šípka na Nitru ani „Krok 1/3“ text z pôvodného návrhu
(sekcia 4.2 v `NAVRH_HERNY_ZAZITOK.md`).

- [ ] Zostáva postaviť celý coach overlay (samostatná úloha, nie fix)

### 3.2 P0.4 — Devín kapitola: len 2 toast notifikácie, nie modal/epilóg

**Stav:** `_on_next_month()` teraz posiela `_notify(...)` pri roku
906/01 a 907/01 (riadky 170-173 v `Main.gd`). Pôvodná požiadavka bola
**modal** 906–907 s epilogue textom po vyriešení (sekcia P0.4 v
pôvodnom návrhu) — toast, ktorý zmizne za pár sekúnd, je presne ten typ
slabého signálu, ktorý mal modal nahradiť. Tlačidlo „Devín 907“ navyše
stále sedí v `ToolsRow` vedľa „Cvičná bitka“ rovnakou vizuálnou váhou —
antivzor „Devín v Tools navždy = cheat/debug“ z pôvodnej kritiky (v1.1,
bod 5) **stále platí**.

- [ ] Zostáva postaviť skutočný modal/kapitolu (samostatná úloha)

### 3.3 P0.2 — TurnReport: funguje ako text, nie ako samostatný UI prvok

**Stav:** Δ zdrojov sa teraz počíta správne (`res_before`/`res_after`
diff, riadky 138-152 v `Main.gd`) a pripája sa na koniec kronikového
riadku + toast. Toto je lacnejšie než pôvodný návrh (sticky card, sekcia
4.1), a možno to stačí — ale je to vedomý kompromis, nie plná
implementácia P0.2. Δ je teraz v texte typu
`[902/03] Mesiac uplynul v tichu dvorov a polí. Δ: gold+12, food+8`,
zapratanom do scrollovacieho logu, nie vizuálne oddelené.

- [ ] Rozhodnúť: stačí textová Δ, alebo dostavať sticky card z pôvodného
      mockupu? (Odporúčanie: textová Δ je dostatočná pre demo, sticky
      card nechať na P1, ak sa ukáže, že hráči Δ v texte prehliadajú)

---

## 4. Odporúčané poradie opráv

| Poradie | Čo | Prečo prvé/posledné |
|---|---|---|
| 1 | 1.1 `nextEvent`/`next_event` | 1 riadok/4 miesta, okamžite odomkne 4 eventy zadarmo |
| 2 | 2.1 `PROVINCE_DEVIN := "devin"` | Súvisí s 1.3, malý zásah, opravuje aj nesprávny stav vo `FEEDBACK_INTEGRATION.md` |
| 3 | 2.2A Vekový gate na `devine_btn` | Zabraňuje reálnemu UX zmätku, malý zásah |
| 4 | 1.3 `zupaLoyalty` v `resolve_choice()` | Stredný zásah, dokončí P0.7 obsahovo |
| 5 | 1.2 `moodChanges` v `resolve_choice()` + doplnenie dát | Najväčší zásah v tejto skupine, ale najviac herného prínosu |
| 6 | 1.4 tretie tlačidlo voľby (`ChoiceC`) | UI zásah, netlačí sa, kým eventy 2/3-choice reálne nenastanú v hre |
| 7 | 2.3 presun guardu do scenára | Cleanup, nie funkčná chyba |
| 8 | 3.1 / 3.2 / 3.3 | Toto už nie sú „opravy“, ale zvyšné P0 stavebné práce — plánovať ako novú prácu, nie rýchly fix |

---

## 5. Čo je overené v poriadku (nerozoberať znova)

- P-1.1 (max 1× Devín) — funguje, `devine_resolved` flag je správne
  nastavovaný a čítaný na všetkých treba vstupných bodoch (2.3 je len
  cleanup, nie bug).
- Devín kánon (`winner == "attacker"`) — nezmenené, žiadny z vyššie
  uvedených fixov sa ho nedotýka.
- P0.3 (threat clock text) — funguje presne podľa návrhu, jediná chyba
  je nadväznosť na predčasné vyriešenie Devína (2.2B).
- 12 z 16 portovaných eventov (bez `nextEvent`/`moodChanges`/`zupaLoyalty`
  efektov) funguje ako zamýšľané — podmienky, cooldowny aj vážený výber
  fungujú správne.

---

## 6. Ďalší krok

Toto je punch list, nie implementačný plán s odhadom — polož mi, prosím,
rozsah:

1. **`oprav všetko`** — spracujem 4.1–4.7 v poradí vyššie ako jeden batch
2. **`len kritické bugy (1.1–1.4)`** — obsahové/UI bugy, nechať P0.1/P0.4
   stavebné práce na neskôr
3. **`len 1.1 + 2.2A`** — najlacnejší rez (odomkne eventy, zastaví
   zmätočný UX pri predčasnom Devíne)
4. iný rez podľa čísel vyššie

Bez tvojho go nezačínam kód.
