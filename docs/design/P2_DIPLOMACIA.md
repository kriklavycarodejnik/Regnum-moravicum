# P2: Diplomacia s dôsledkami

Karta D1. Implementujú C3 (`rm-core`, condition matcher) a C4 (`rm-godot`,
následky). Tento špec je záväzný pre obe; čísla v ňom sa nesmú meniť bez
návrhu na zmenu (karta, nie komentár).

## Invarianty (záväzné, z `NAVRH_HERNY_ZAZITOK.md` §4.1 a §15.6)

| | |
|--|--|
| Devín 907 | `winner == "attacker"` (Maďari) **vždy**. Kánon sa nemení — mení sa len okolie (nájazdy pred 907, varovania). |
| Devín frekvencia | max 1× za run (`devine_resolved`) |
| Dôsledky Devína | −30 prestíž / −20 lojalita Devína / +30 mood Maďarov — nemeniť |
| RNG | seeded cez SaveManager; DiplomacyManager už dnes dostáva zdieľaný `rng` z `GameManager` (GameManager.gd:60) — všetky nové hody idú cezň |
| React | archív — zdroj dát, nie miesto na úpravy |

---

## Stav (overené v kóde, nie v dokumentoch)

- `DiplomacyManager._ensure_default_factions()` definuje **7 frakcií**:
  moravia (mood 100), franks (50), bavaria (40), hungary (20), poland (30),
  bohemia (60), **byzantium (50)**. Hungary štartuje nepriateľsky — to je
  zámer, nie chyba.
- Akcie: `send_gift(faction_id, gold_cost = 50)` → −50 zlata, +10 nálady;
  `threaten(faction_id)` → +2 prestíže, −8 nálady (30 % šanca len −3,
  DiplomacyManager.gd:135); `set_treaty(faction_id, treaty, enabled)` →
  zadarmo, +6 nálady pri uzavretí. Zmluvy: `nap`, `trade`, `military_pact`.
- `process_diplomacy()` (volá TickManager.gd:90 každý mesiac): drift nálady
  −2 až +2 cez `rng.randf_range(-2.0, 2.0)`; nap drží drift ≥ 0,
  trade +0.5, military_pact +0.25. Nič iné nerobí.
- `DiplomacyPanel.gd` má **5 tlačidiel** (dar, hrozba, neútočná zmluva,
  obchod, vojenský pakt) a pásma nálad natvrdo: < 35 „nepriateľ",
  > 65 „spojenec" (riadok 122).
- `events_catalog.json` (13 eventov): v `conditions` existujú **len** kľúče
  `year`, `month`, `yearMin`. Overiteľné: EventManager.gd:137-181 nečíta
  nič iné. Žiadny event sa nepýta na náladu, prestíž ani lojalitu.
- `ObjectivesPanel.compute_beats()` už má reaktívny diplomatický riadok
  (`_diplomacy_side_goal_static`, varovanie pri najhoršej nálade < 50) —
  to je varovanie, nie splniteľný cieľ.
- `GameState.to_dict()/from_dict()` už serializuje `factions` (náladu aj
  `relations`) — vzťahy prežijú save/load dnes. Chýba stav cieľov.

**Problém:** hráč má päť diplomatických tlačidiel, ktoré stoja zlato, a ich
jediný následok je posunuté číslo v paneli. Cena bez odmeny — vlastný gate
to zakazuje. Nálada je dnes dekorácia: nič ju nečíta.

---

## 1. Prahové pásma nálady (záväzné pre celú hru)

Jedna sada prahov všade — matcher, UI, ciele. Žiadne druhé pásmo inde.

| Pásmo | Nálada | Význam |
|---|---|---|
| nepriateľská | 0–24,99 | hrozba konfliktu; akcie zlyhávajú |
| chladná | 25–49,99 | riziko; diplomatické ultimáta |
| neutrálna | 50–74,99 | bežný stav |
| spojenec | 75–100 | odomyká priaznivé eventy |

Porovnania sú inklusívne: `min` = `mood >= min`, `max` = `mood <= max`.

**Zjednotenie UI:** DiplomacyPanel mení pásma z 35/65 na **25/75**
(riadok 122: `"nepriateľ" if mood < 25.0 else ("spojenec" if mood >= 75.0 else "neutrál")`).

### Akceptačné kritérium 1

V kóde ani v dátách sa nevyskytuje iná definícia diplomatických pásiem než
25/75 (vyhľadaním `35.0`/`65.0` v DiplomacyPanel.gd sa nenájde nič;
condition matcher v C3 používa tie isté čísla v textoch varovaní).

---

## 2. Kanál A — nálada vstupuje do podmienok eventov (C3)

### 2.1 Syntax nových podmienok (kontrakt pre `events_catalog.json`)

Všetky podmienky v `conditions` sú AND — musia platiť všetky súčasne.

```jsonc
"conditions": {
    "yearMin": 903,                                   // existujúce
    "faction_mood": {                                 // NOVÉ
        "faction_id": "hungary",
        "min": 25.0,                                  // voliteľné, mood >= min
        "max": 45.0                                   // voliteľné, mood <= max
    },
    "prestige_min": 60,                               // NOVÉ, resources.prestige >= N
    "prestige_max": 100,                              // NOVÉ, voliteľné
    "province_loyalty": {                             // NOVÉ (syntax pre budúce eventy)
        "province": "uzhorod",
        "min": 30.0,
        "max": 60.0
    },
    "flag": "devine_resolved",                        // NOVÉ: bool pole GameState == true
    "not_flag": "army_wizard_done"                    // NOVÉ: bool pole GameState == false
}
```

`faction_mood` prijíma aj skrátený tvar `"faction_mood": {"hungary": {"max": 45}}` —
matcher normalizuje oboje; odporúčaný je dlhý tvar s `faction_id`.

**Pravidlá vyhodnotenia (C3, záväzné):**

1. Matcher sa volá v **oboch** cestách výberu — `_try_historical_event()`
   aj `_try_random_event()` (dnes každá kontroluje podmienky inline a
   rôzne; refaktor do jednej funkcie `_conditions_met(cat) -> bool`).
   Bez toho by `byz_bride_proposal_906` pri nálade < 40 preskočila
   historická cesta, ale vytiahol by ju random pool (má presný rok 906).
2. Neznámy kľúč v `conditions` (iný než year, month, yearMin, faction_mood,
   prestige_min, prestige_max, province_loyalty, flag, not_flag) → event sa
   **nevyberie** a `push_warning` s id eventu. Nikdy nie tichý prechod.
3. Chýbajúca frakcia/provincia v GameState → podmienka neplatí (nie chyba).
4. Vyhodnotenie je čisté čítanie GameState — žiadny `randf`.

### 2.2 Konkrétne podmienky v existujúcom katalógu

| Event | Podmienka | Odôvodnenie |
|---|---|---|
| `rand_border_raid` | + `"faction_mood": {"faction_id": "hungary", "max": 45}` | Nájazdy len keď sú Maďari chladní alebo nepriateľskí. Hráč, ktorý ich upokojí nad 45, má pokoj — viditeľná odmena za diplomaciu. |
| `byz_bride_proposal_906` | + `"faction_mood": {"faction_id": "byzantium", "min": 40}` | ObjectivesPanel už dnes varuje „Byzancia je chladná — sobáš môžete ohroziť" (riadok 164) — dnes to klame, ponuka príde vždy. Po tejto zmene varovanie platí. |

Žiadny iný existujúci event podmienky nedostáva.

### 2.3 Nové eventy (záväzný text — implementátor preberá doslovne)

Oba zápisy do `events_catalog.json` sú štandardný JSON (bez komentárov).

**`dip_magyar_envoy_tribute`** — odomknutý pri **nepriateľskej** nálade
Maďarov (trestný kanál):

```json
{
  "id": "dip_magyar_envoy_tribute",
  "type": "diplomatic",
  "title": "Maďarské posolstvo žiada tribút",
  "body": "Do Nitry vstúpila družina z potiskej stepi. Nežiadajú audienciu ani poctu — žiadajú zlato. Staršina rodu Árpáda hovorí tlmocníkovým hlasom: jazda, ktorá stráži vaše hranice, si zaslúži odmenu. Ak pokladnica neodpovie, odpovedia kone. Dvor mlčí — každý počul o dedinách za Dunajom, ktoré s odpoveďou meškali.",
  "art_id": "event_border_raid",
  "conditions": {
    "yearMin": 903,
    "faction_mood": {"faction_id": "hungary", "max": 25}
  },
  "once": false,
  "cooldownTicks": 24,
  "weight": 8,
  "choices": [
    {
      "id": "pay",
      "text": "Zaplatiť tribút — 60 zlata za pokoj na hranici",
      "effect": {"gold": -60},
      "moodChanges": {"hungary": {"trust": 50}}
    },
    {
      "id": "refuse",
      "text": "Odmietnuť — Morava neplatí za to, čo jej patrí",
      "effect": {"prestige": 3},
      "moodChanges": {"hungary": {"anger": 20}}
    }
  ]
}
```

`trust: 50` = nálada +15 (cez `_lookup_and_apply_mood`, EventManager.gd:452);
`anger: 20` = nálada −6. Odmietnutie tlačí Maďarov hlbšie pod prah 25 —
tribút sa o dva roky (cooldown 24) vráti, alebo prídu nájazdy.

**`dip_byzantium_imperial_gift`** — odomknutý pri **spojencovi** a vysokej
prestíži (odmenový kanál):

```json
{
  "id": "dip_byzantium_imperial_gift",
  "type": "diplomatic",
  "title": "Cisársky dar z Konštantínopola",
  "body": "Posolstvo Leva VI. vstupuje do Nitry s vozmi hodvábu a striebra. Cisár nazýva Mojmíra bratom a posiela dar vládcovi, ktorý drží poriadok na Dunaji. Byzantskí kupci sa vracajú na moravské trhy a ich mince znejú v mešciach županov. Dvor vie, že dar má cenu — franskí poslovia sa o ňom dozvedia do mesiaca.",
  "art_id": "event_byzantine_marriage",
  "conditions": {
    "yearMin": 904,
    "faction_mood": {"faction_id": "byzantium", "min": 75},
    "prestige_min": 60
  },
  "once": true,
  "cooldownTicks": 0,
  "weight": 6,
  "choices": [
    {
      "id": "accept",
      "text": "Prijať dar a potvrdiť priateľstvo",
      "effect": {"gold": 80, "prestige": 2},
      "moodChanges": {"franks": {"anger": 10}}
    },
    {
      "id": "decline",
      "text": "Vrátiť dar — Morava neprijíma záväzky",
      "effect": {"prestige": 1},
      "moodChanges": {"byzantium": {"trust": -10}}
    }
  ]
}
```

Obe voľby platia v inej mene: prijať = franks −3 nálady (cena spojenectva
s Byzanciou), odmietnuť = byzantium −3 nálady (strata spojenca).

### Akceptačné kritérium 2

- Unit testy matchera (C3): `hungary.mood = 44` → podmienka `max: 45` platí;
  `46` → neplatí. `byzantium.mood = 39` → `byz_bride_proposal_906` nevybraný
  historickou **ani** random cestou; `40` → vybraný. `prestige = 59` →
  `dip_byzantium_imperial_gift` neplatí; `60` → platí. Neznámy kľúč
  `"moodMax": 30` → event preskočený + warning.
- `events_catalog.json` obsahuje práve tieto štyri `faction_mood`/`prestige_min`
  väzby (rand_border_raid, byz_bride_proposal_906, dip_magyar_envoy_tribute,
  dip_byzantium_imperial_gift) a žiadne iné.

---

## 3. Kanál B — nálada vstupuje do hrozieb

**Devín 907 sa nemení.** HungarianWarScenario, `winner == "attacker"`,
dôsledky −30/−20/+30, vlastný seed — nedotýkať sa. Mení sa okolie pred 907.

### 3.1 Reťazec hrozby

| hungary.mood | Čo sa deje | Kde to hráč vidí vopred |
|---|---|---|
| ≥ 45 | Nájazdy sa neťahajú (`rand_border_raid` zamknutý podmienkou) | panel Diplomacia: efektový riadok (§5) |
| 25–44,99 | `rand_border_raid` aktívny (cooldown 15, weight 12 — bez zmien) | ThreatClock sublabel: „Maďari sú nepokojní — južná hranica nie je bezpečná." (farba `C.WARNING`) |
| 0–24,99 | Nájazdy aktívne **plus** ultimátum `dip_magyar_envoy_tribute` (cooldown 24, weight 8) | ThreatClock sublabel: „Maďarský hnev rastie — čakaj posolstvo alebo nájazd." (farba `C.MORAVIA_CRIMSON`) |

**Predvídateľnosť:** ani jedno riziko neprichádza bez signálu. Signály sú
tri a všetky číselné: (a) mood Maďarov v paneli Diplomacia, (b) sublabel
ThreatClocku pod odpočtom „Do Maďarov: N mesiacov", (c) ultimátum samotné —
ak príde, píše sa v ňom, čo nasleduje, keď pokladnica neodpovie.

ThreatClock.gd: v vetve `y < 907` (riadok 58) prepisuje `_sublabel.text`
podľa `hungary.mood` **pred** štandardným textom „Priprav sa na krízu 907" —
t.j. sublabel má teraz tri stavy, nie jeden.

### 3.2 Čo sa po Devíne nemení

`winner == "attacker"` zvýši hungary.mood o +30 (existujúci dôsledok). Ak to
hry ukončí krízu, nálada sa môže dostať nad 45 a nájazdy ustania — to je
žiaduci stav po kánonickej prehre, nie zmena kánonu.

### Akceptačné kritérium 3

- Deterministický headless: `hungary.mood = 50` (driftom držaná nad 45
  darom) → 12 mesačných ťahov, `rand_border_raid` sa neobjaví ako
  `pending_event` ani raz.
- `hungary.mood = 20`, čerstvý stav 903 → 12 ťahov s fixným seedom (implementátor
  ho zvolí a zapíše do testu): v postupnosti id sa objaví aspoň raz
  `rand_border_raid` alebo `dip_magyar_envoy_tribute`. Rovnaký seed dvakrát
  = identická postupnosť.
- Devín: existujúci smoke/Devín test prechádza bez zmien (winner attacker,
  1×, −30/−20/+30).

---

## 4. Kanál C — splniteľný diplomatický cieľ (ObjectivesPanel)

Existujúci `_diplomacy_side_goal_static` je varovanie („frakcia X má náladu
Y"). Pribúda **cieľ s dátumom, progresom a odmenou**.

### 4.1 Cieľ: Obchodné cesty (trade_routes)

> Uzavri obchodnú zmluvu s **2 rôznymi susedmi** pred rokom 907.

- **Progres** sa počíta vždy nanovo z aktuálnych zmlúv: počet frakcií
  (okrem moravia) s `relations.trade == true`. Neukladá sa counter, ktorý by
  mohol driftovať.
- **Odmena pri splnení:** prestíž +5, jednorazovo, len ak `year < 907`
  a `done == false`. Aplikuje `set_treaty()` v momente uzavretia druhej
  zmluvy — nie compute_beats (statická funkcia stav nemení).
- **Trvalý efekt:** každá obchodná zmluva prináša **+3 zlata mesačne**
  (pozri §5 — cena zmluvy sa vráti za 10 mesiacov). Zrušenie zmluvy príjem
  odoberie.
- Po roku 907 cieľ zmizne z panela bez trestu — nesplnenie bolí cez
  stratený príjem, nie cez bič.

### 4.2 GameState

Nové pole:

```gdscript
var diplomacy_goals: Dictionary = {}
# {"trade_routes": {"done": bool, "year_completed": int}}
```

Pole vstupuje do `to_dict()` aj `from_dict()` (medzi `army_wizard_done`
a koniec — poradie je jedno, musí byť oboje).

### 4.3 Zobrazenie v compute_beats()

Fáza I (902–906), okrem roku 907:

- nesplnené: `goals.append("Obchodné cesty: %d/2 zmlúv (do roku 907)")`
- splnené: `goals.append("Obchodné cesty stoja — +3 zlata mesačne za každú zmluvu")`

Fáza II (907): cieľ sa **nezobrazuje** — Devín má mať vlastný, nerozptýlený
fokus. (Poznámka: existujúci generický diplomatický riadok
`_diplomacy_side_goal_static` sa v 907 zobrazuje ďalej — to je vedomá
odchýlka, nie precedens pre nový cieľ.)
Fáza III+: cieľ sa nezobrazuje (obchodné zmluvy ostanú viditeľné v paneli
Diplomacia cez `relations`).

### Akceptačné kritérium 4

- Čerstvá hra → `set_treaty("bohemia", "trade", true)` →
  `set_treaty("poland", "trade", true)` → prestíž stúpne presne o 5,
  `diplomacy_goals["trade_routes"]["done"] == true`, `compute_beats()` vracia
  riadok „Obchodné cesty stoja…". Tretia obchodná zmluva prestíž nepridá.
- Rovnaký postup v roku 907 a neskôr → prestíž +5 sa neudelí.
- `compute_beats()` je stále čistá statická funkcia — nemení GameState
  (overiteľné: volanie dvakrát s rovnakým stavom vráti rovnaký dict a stav
  sa nezmení).

---

## 5. Ceny akcií — tabuľka (mení DiplomacyManager)

Žiadna akcia nesmie byť jednoznačne najlepšia; každá platí aspoň v jednej
mene. Zmluvy dnes stoja 0 zlata — to je odmena bez ceny a končí.

| Akcia | Cena | Efekt | Riziko / podmienka |
|---|---|---|---|
| Dar | −50 zlata | +10 nálady. Frakcii s náladou **< 30** len **+5** (nedôvera — dar vyzerá ako úplatok). Dar **Maďarom** navyše **−2 prestíže** (tribút je hanba). | žiadne |
| Hrozba | žiadna | +2 prestíže, −8 nálady | Ak má cieľ náladu **< 35**: 40 % šanca, že vyjde naopak — **−12 nálady a −1 prestíže** (poníženie). Hod cez zdieľaný seeded `rng`. |
| Neútočná zmluva | **−20 zlata** | +6 nálady, drift ≥ 0 | žiadne |
| Obchodná zmluva | **−30 zlata** | +6 nálady, **+3 zlata mesačne** v `process_diplomacy()` (`report["trade_income"]`) | návratnosť 10 mesiacov |
| Vojenský pakt | **−40 zlata** | +6 nálady, drift +0.25 | vyžaduje náladu **≥ 50**; pod ňou `ok: false` s chybou „…odmieta pakt, nálada pod 50". Tlačidlo je pod 50 disabled s textom „Vojenský pakt (vyžaduje náladu 50)". |

Detaily implementácie:

- `send_gift()`: delta +10/+5 podľa nálady cieľa; hungary dostane −2
  prestíže. Chronicle string musí uvádzať **skutočnú** deltu (dnes natvrdo
  „nálada +10", riadok 123).
- `threaten()`: dnešná vetva „občas menej efektívne" (−3) sa ruší. Nová
  logika: `if rng.randf() < 0.4 and mood < 35.0` → neúspech (−12, −1
  prestíž), inak úspech (−8, +2 prestíž).
- `set_treaty()`: pri `enabled == true` strhne cenu podľa tabuľky (gold
  guard rovnaký štýl ako `send_gift`); pri `enabled == false` cena sa
  nevracia (zrušenie bolí). Military_pact guard podľa nálady. Obchodná
  zmluva pri `enabled == true` skontroluje cieľ trade_routes (§4).
- `process_diplomacy()`: na konci pripočíta `+3` zlata za každú frakciu
  s `relations.trade == true` a zapíše `report["trade_income"]`. Drift
  a treaty modifikátory ostávajú bez zmien.
- Tlačidlá DiplomacyPanelu nesú ceny v texte: „Neútočná zmluva (−20 zlata)",
  „Obchodná zmluva (−30 zlata, +3 zlata/mes.)", „Vojenský pakt (−40 zlata)".
  Hrozba: „Hrozba — pod náladou 35 riskuješ".

### Akceptačné kritérium 5

- `send_gift("hungary")` pri nálade 20 → gold −50, hungary.mood +5 (nie
  +10), prestíž −2. `send_gift("franks")` pri nálade 50 → +10.
- `threaten()` na frakcii s náladou 30: s dvoma rôznymi fixnými stavmi
  `rng.state` (implementátor oba zapíše) — jeden hod vráti úspech
  (−8/+2), druhý neúspech (−12/−1).
- `set_treaty("franks", "military_pact", true)` pri nálade 40 →
  `ok: false`, error obsahuje zmienku o prahu 50, gold nezmenený.
- Po uzavretí obchodnej zmluvy: ďalší `process_diplomacy()` zvýši gold o 3.
- Zrušenie obchodnej zmluvy: nasledujúci `process_diplomacy()` nepridá nič.

---

## 6. Ako sa hráč dozvie, že to funguje — viditeľnosť mimo panela

Samotný panel nestačí. Následok musí byť vidno aj tam, kde hráč trávi ťahy.

### 6.1 ThreatClock sublabel (kanál hrozby)

Podľa §3.1 — hráč vidí „Maďarský hnev rastie" priamo pod odpočtom
„Do Maďarov: N mesiacov" bez toho, aby otvoril Diplomaciu.

### 6.2 TurnReport / narácia (prekročenie pásma)

`process_diplomacy()` porovná pásmo nálady pred driftom a po ňom. Pri
prekročení prahu 25 smerom nadol alebo 75 smerom nahor zapíše do reportu:

```gdscript
report["threshold_crossed"] = {"faction_id": fid, "crossed": "below_25"}  # alebo "above_75"
```

`NarrationManager._generate_diplomacy_text()` (NarrationManager.gd:163)
číta `threshold_crossed` **pred** dnešnou vetvou podľa kľúča v
`mood_changes` a vráti vetu:

| frakcia / smer | veta (záväzné znenie) |
|---|---|
| hungary below_25 | „Z potiskej stepi sa ozýva dusot koní — maďarské družiny sa zbiehajú pri brodoch." |
| bavaria below_25 | „Regensburg mlčí — bavorský vojvoda sťahuje družiny k hranici na Inn." |
| franks below_25 | „Východofranské posolstvá prestali zdraviť — dunajská hranica stíchla." |
| poland below_25 | „Z poľských hradísk prichádzajú chladné odkazy — Vislania prestali platiť do Nitry." |
| bohemia below_25 | „Český knieža odvolal svojich hostí z nitrianskeho dvora." |
| byzantium below_25 | „Konštantínopol stiahol svojich kupcov z moravských trhov." |
| hungary above_75 | „Maďarskí staršinovia poslali do Nitry kone ako zálohu mieru." |
| byzantium above_75 | „Cisár Lev VI. posiela Mojmírovi list, v ktorom ho nazýva bratom." |
| franks above_75 | „Východofranskí poslovia priniesli prísľub pokoja na Dunaji." |
| ostatné above_75 | „%s posiela do Nitry priateľské posolstvo — takýto list dvor dávno nedostal." (s menom frakcie) |

### 6.3 Efektový riadok v paneli Diplomacia

Pod `_info` (po výbere frakcie) nový riadok. Záväzné texty — hovoria
presne to, čo podmienky v katalógu, nič navyše:

| frakcia | riadok |
|---|---|
| hungary | „Pod 45 hrozia nájazdy. Pod 25 prídu žiadať tribút." |
| byzantium | „Pod 40: sobášna ponuka v 906 nepríde. Nad 75 a prestíž 60: cisár posiela dary." |
| franks, bavaria, poland, bohemia | „Nálada ovplyvňuje mesačný drift, vojenský pakt vyžaduje aspoň 50." |

Žiadna frakcia nesmie mať riadok, ktorý sľubuje efekt neexistujúci
v katalógu alebo v kóde.

### Akceptačné kritérium 6

- Hungary.mood klesne driftom pod 25 → v tom istom ťahu TurnReport obsahuje
  vetu „Z potiskej stepi…" (alebo ju zobrazí chronika), ThreatClock sublabel
  ukazuje „Maďarský hnev rastie…".
- Výber frakcie hungary v paneli zobrazí efektový riadok z tabuľky.
- Snímka pre Q1: stav pred a po prekročení prahu (ThreatClock + panel).

---

## 7. Save/load

- `factions` (mood + relations) sa už dnes serializuje — nemeniť.
- Nové `diplomacy_goals` vstupuje do `to_dict()`/`from_dict()` (§4.2).
- Po loade musí `process_diplomacy()` naďalej pripisovať obchodný príjem
  (číta `relations` z načítaného stavu — žiadna ďalšia práca).
- Starý save bez `diplomacy_goals` sa načíta s `{}` (from_dict default).

### Akceptačné kritérium 7

Headless: nová hra → obchodná zmluva s bohemia → save → load →
`relations["trade"] == true` pre bohemia, `diplomacy_goals` prázdny alebo
konzistentný, nasledujúci `process_diplomacy()` pripíše +3 zlata.
Potom druhá zmluva (poland) → prestige +5 → save → load →
`diplomacy_goals["trade_routes"]["done"] == true` a tretia zmluva už
prestíž nezvýši.

---

## 8. Headless scenár (overenie bez autora)

```text
# S = seedovaný GameState (902/1), E = EventManager, D = DiplomacyManager

# SCENÁR 1 — podmienky držia nájazdy mimo
hungary.mood = 55 (darom udržiavať nad 45 počas testu)
12× process_next_month so seedom S1
assert: "rand_border_raid" sa neobjavil v pending_event

# SCENÁR 2 — hnev pritiahne hrozbu
hungary.mood = 20, čerstvý 903
12× process_next_month so seedom S2 (implementátor fixuje, zapíše)
assert: postupnosť obsahuje aspoň raz rand_border_raid
        alebo dip_magyar_envoy_tribute; druhý beh = identická postupnosť

# SCENÁR 3 — ultimátum a jeho dôsledok
vynútiť pending_event = dip_magyar_envoy_tribute, mood hungary = 20
resolve_choice("pay")   → gold −60, hungary.mood == 35 (20 + 50*0.3)
resolve_choice("refuse") (čerstvý stav) → prestige +3, hungary.mood == 14 (20 − 20*0.3)

# SCENÁR 4 — byzantská vetva
byzantium.mood = 39, year = 906 → byz_bride_proposal_906 nevybraný
byzantium.mood = 40, year = 906 → vybraný (historická cesta)

# SCENÁR 5 — cieľ + save/load (podľa §7)

# SCENÁR 6 — kánon nedotknutý
existujúci Devín test: winner == "attacker", devine_resolved 1×,
prestige −30, devin loyalty −20, hungary mood +30 — všetko bez zmien
```

---

## 9. Čo implementácia mení v kóde

### C3 (`feat/p2-condition-matcher`)

- `EventManager.gd`: nová `_conditions_met(cat) -> bool`; volaná
  v `_try_historical_event()` aj `_try_random_event()`; neznáma podmienka =
  skip + warning. Existujúce eventy bez nových podmienok sa správajú
  identicky (deterministický test s katalógom bez nových väzieb).

### C4 (`feat/p2-diplomacia-dosledky`)

- `DiplomacyManager.gd`: ceny a riziká akcií (§5), trade_income a
  threshold_crossed v `process_diplomacy()`, kontrola cieľa trade_routes
  v `set_treaty()`.
- `DiplomacyPanel.gd`: pásma 25/75, efektový riadok (§6.3), ceny v textoch
  tlačidiel, disabled vojenský pakt pod náladou 50.
- `ThreatClock.gd`: sublabel podľa hungary.mood (§3.1).
- `ObjectivesPanel.gd`: riadok trade_routes v `compute_beats()` (§4.3) —
  len statická vetva, inštancia sa nemení.
- `GameState.gd`: + `diplomacy_goals` + serializácia.
- `NarrationManager.gd`: vetvy `threshold_crossed` (§6.2).
- `events_catalog.json`: 2 podmienky na existujúcich eventoch (§2.2) +
  2 nové eventy (§2.3).

### Bez zmien

`HungarianWarScenario`, `WarManager`, `BattleManager`, `SaveManager`
(serializuje celý state dict — nové pole prejde samo, ak je v to_dict).

### Kolízne súbory (hotspot)

- `events_catalog.json` mení súčasne C2 (doport 5 eventov) aj C4. Obe karty
  visia na integračnej karte — merge v poradí C2 → C4, druhý sa rebase-uje.
- `NarrationManager.gd` mení C1 aj C4. To isté pravidlo: C1 prvý, C4 rebase.

---

## 10. Päť testov

1. **Prerozprávanie.** „V roku 904 prišli Maďari žiadať tribút. Zaplatil som
   60 zlata a dva roky bol pokoj. Keď sa ich nálada opäť pokazila, vypálili
   Gemer." Hráč rozpráva s menami (Árpád, Lev VI.), rokmi a dôvodmi — nie so
   štatistikami.
2. **Cena.** Dar stojí 50 zlata a pri Maďaroch aj 2 prestíže; hrozba môže
   stáť prestíž; zmluvy stoja zlato. Žiadna akcia nie je zadarmo a žiadna
   nie je jednoznačne najlepšia (dar Maďarom = pokoj za hanbu; hrozba =
   prestíž za riziko; obchod = gold teraz za gold neskôr).
3. **Predvídateľnosť.** Každé riziko má signál vopred: mood v paneli,
   sublabel ThreatClocku, ultimátum ako posledné varovanie. Zlyhanie hrozby
   nie je náhoda bez varovania — hráč vidí náladu < 35 a text tlačidla.
4. **Špecifickosť.** Leva VI., Regensburg, brod na Dunaji, Potisie, Vislania —
   žiadna veta nie je prenosná do inej stredovekej hry.
5. **Tempo.** Ťah 3 (903–904): ultimáta a nájazdy. Ťah 8 (906): sobášna
   vetva závisí od byzantskej nálady. Po 907: cisársky dar ako nová kapitola.
   Medzníky sú rôzne, nie sú to isté +10 nálady dookola.

---

## 11. Otvorené otázky (triage pre P3, nie do tohto scope)

- Vojny frakcií podľa nálady (WarManager vyhlási konflikt pri mood < 15) —
  vyžaduje vojnový systém mimo P2.
- Podmienené eventy pre Poľsko a Čechy (dnes bez vlastných podmienok) — až
  po doporte obsahu C2.
- Obchodná zmluva viazaná na prosperitu župy — ekonomická väzba, nie
  diplomatická.
- Frakčné osobnosti (bavorský vojvoda Luitpold, Lev VI. ako aktér listov) —
  obsah, nie mechanika.
