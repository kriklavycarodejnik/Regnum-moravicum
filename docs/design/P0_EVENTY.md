# P0.5 — Zamknutých 8 eventov: voľby, ceny, dôsledky

> **Toto je zadanie pre `rm-content`, nie implementácia.** Texty píš presne podľa tejto
> tabuľky — mechaniky (voľby, ceny, meny, ID) sú tu rozhodnuté a nedohadúvajú sa znova.
> Ak niečo v tomto dokumente odporuje kódu, nahlás to komentárom na karte, nemeň si to sám.

**Zdroje pravdy:** `docs/NAVRH_HERNY_ZAZITOK.md` §4/§15.6 · `docs/GAMEPLAY_LOOP.md` ·
`src/data/historicalEvents.ts` (zdroj ID a pôvodného textu) · `godot/data/events_catalog.json`
(aktuálny stav portu) · `godot/scripts/managers/EventManager.gd` (`resolve_choice`, `_resolve_faction_id`).

**Rozsah:** presne 8 eventov (rodiny vrátane reťazových pokračovaní) zo zadania `t_56378676`.
Žiadny deviaty event, žiadne P0.8. Nové nápady nad rámec idú do triage karty, nie sem.

---

## 0. Meny cien (platí pre všetky eventy nižšie)

| Mena | Kde sa prejaví | Poznámka |
|---|---|---|
| **Zlato / jedlo** | `resources.gold`, `resources.food` (`effect`) | okamžitá, viditeľná v TurnReport Δ |
| **Prestíž** | `resources.prestige` | medzinárodná/dynastická vážnosť |
| **Lojalita župy** | `zupaLoyalty` → `game_state.provinces[id].loyalty` | **bare province id**, vždy explicitný dict `{"province_id": delta}` — kánonický zoznam 12 id je v §0.1. **Nie** `zupa_nitra`, nikdy skratka "všetky" |
| **Vzťah s frakciou** | `moodChanges` → `game_state.factions[id].mood` | **iba** týchto 7 id existuje: `moravia, franks, bavaria, hungary, poland, bohemia, byzantium`. Nikdy nepíš `moodChanges` na meno, ktoré nie je táto sedmička. |
| **Náboženská os** | `religionChange` | Rím ↔ Konštantínopol, jediný kanál pre "cyrilometodský" konflikt (žiadna taká frakcia neexistuje) |
| **Čas / budúca možnosť** | `next_event` (snake_case!) | odklad ceny, nie jej zrušenie — pozri §3.1 |

### 0.1 Kánonický zoznam všetkých žúp (province id)

**Presne týchto 12 id** (zdroj: `godot/data/provinces/*.json`, potvrdené v `smoke_test.m6.gd`
riadkom `layout 12 provinces`):

```
bratislava, devin, gemer, hont, morava, nitra, novohrad, spis, tekov, trencin, uzhorod, zemplin
```

`EventManager._resolve...`/`resolve_choice()` (riadky 215–224 v `EventManager.gd`) číta
`zupaLoyalty` iba ako explicitný dict `{"province_id": delta}` — **nepodporuje** žiadne
kľúčové slovo "všetky" ani wildcard. Kdekoľvek nižšie táto špecifikácia hovorí "všetky župy",
znamená to, že implementácia musí literálne vypísať všetkých 12 kľúčov v dict-e.

**Devín je zahrnutý** v každom "všetky župy" efekte — je to bežná provincia z pohľadu
recurring eventov ako rada županov. Bitka pri Devíne 907 je samostatný scenár
(`HungarianWarScenario.resolve_devine_battle()`), nie event z `events_catalog.json` —
tieto dva systémy sa nekrížia a nekolidujú.

### 0.2 Dve chyby v existujúcom katalógu, ktoré táto špecifikácia opravuje

1. **Bogata reťaz používa `hungary` mood namiesto lojality Užskej župy.** Bogatovci sú
   moravský rod z **Užskej župy** (`uzhorod`), nie Maďari. Pôvodný TS mal vlastnú fiktívnu
   frakciu `Bogatovci`, ktorá sa v Godote nedá resolvovať — namiesto dopĺňania ďalšej
   neexistujúcej frakcie použi `zupaLoyalty: {"uzhorod": ...}`. Detail v §3.
2. **`next_event` musí byť `next_event` (snake_case), nie `nextEvent`.** `EventManager.gd`
   číta len `next_event` (riadky 87, 234). V `events_catalog.json` je to už takto opravené —
   ak dopisuješ nové reťaze, použi rovnaký kľúč, inak je pokračovanie mŕtvy kód.

---

## 1. Pápežské posolstvo — `hist_papal_legation_903`

**Beat A — Konsolidácia (rok 903).** Prvý event, ktorý hráč vôbec uvidí. Učí, že voľba je
nenávratná mena, nie kvíz — bez akéhokoľvek UI vysvetľovania.

**Kontext:** Rím ponúka cirkevnú podporu za uznanie rímskej jurisdikcie. Neexistuje
frakcia "Cyrilometodskí kňazi" — cena za odmietnutie ide cez `religionChange` +
vzťah so susedmi, nie cez fiktívnu domácu frakciu.

| Voľba | Cena | Dôsledok | Pre koho je táto voľba správna |
|---|---|---|---|
| **Prijať posolstvo, priblížiť sa Rímu** | `religionChange: -15` (k Rímu), `franks.mood +5` | `prestige +3` | Hráč, ktorý chce rýchlu medzinárodnú legitimitu a franské/bavorské susedstvo za priateľa skôr než prídu Maďari |
| **Zdvorilo odmietnuť, zachovať cyrilometodské dedičstvo** | `religionChange: +5` (k Byzancii/tradícii), `franks.mood -5` | žiadna prestíž | Hráč, ktorý stavia na byzantskom spojenectve (pozri event 2) a je ochotný platiť franskou nevôľou už teraz |

**Prečo nie je jedna zjavne lepšia:** Rím dáva okamžitý prestíž, ale otvára franské
priateľstvo za cenu vzťahu s Byzanciou, ktorá o 3 roky ponúkne sobáš (event 2) — hráč,
ktorý si vyberie Rím teraz, si sťažuje najlepšiu odpoveď na byzantskú ponuku neskôr.
To je cena zaplatená v mene "budúca možnosť", nie v čísle na obrazovke.

---

## 2. Byzantská ponuka sobáša (s vetvami) — `byz_bride_proposal_906` → `byz_bride_wedding_907` / `byz_bride_insult_907`

**Beat B — Napätie pred Devínom (rok 906 → rozuzlenie 907).** Toto je zámerne posadené
na rok, v ktorom Maďari napadnú Devín. Sobáš alebo urážka sa vyriešia **v tom istom roku**,
ako Morava prehrá pri Devíne — hráč prežíva svadbu/urážku a vojenskú katastrofu ako jeden
príbeh, nie dve oddelené správy.

### 2.1 Ponuka (906)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Prijať ponuku sobáša** | `religionChange +10` (k Byzancii) | `byzantium.mood: trust +15, loyalty +10`; `next_event: byz_bride_wedding_907` |
| **Zdvorilo odmietnuť** | `byzantium.mood: trust -15, anger +10` | `next_event: byz_bride_insult_907` |

### 2.2 Ak prijal → Svadba (907)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Osláviť veľkolepou hostinou** | `gold -60` | `prestige +8`, `byzantium.mood loyalty +10`, `moravia.mood trust +5` |
| **Usporiadať skromný obrad** | žiadne zlato | `prestige +3`, `byzantium.mood trust +5` |

**Cena, ktorú text musí vysloviť nahlas:** rok 907 je rok, keď Maďari útočia na Devín.
Každé zlato padnuté do svadobnej hostiny **chýba vo vojnovej pokladnici v tom istom roku**.
Skromný obrad nie je "menej dobrá" voľba — je to voľba hráča, ktorý si všimol threat clock.

### 2.3 Ak odmietol → Urážka (907)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Vyslať ospravedlňujúce posolstvo s darmi** | `gold -40` | `byzantium.mood trust +10, anger -10` |
| **Neustupovať** | trvalá strata vzťahu | `prestige +1`, `byzantium.mood anger +10` (natrvalo horšie ako pred urážkou) |

**Prečo nie je jedna zjavne lepšia:** Neustupovanie je "lacnejšie" v zlate, ale izoluje
Moravu od Byzancie presne v roku, keď by pomoc odkiaľkoľvek bola k úžitku pri Devíne —
zaplatené v mene, ktorá sa neukáže v žiadnom čísle na obrazovke, len v tom, čo hráč vie.

---

## 3. Sprisahanie rodu Bogata (s vetvami) — `hist_bogata_conspiracy_915` → `bogata_trial_916` / `bogata_uprising_917`

**Beat C — Po Devíne, Prežitie (rok 915–917).** Prvý veľký vnútorný test **po** vonkajšej
katastrofe: ríša sa ešte nezotavila z roku 907 a už musí riešiť vlastnú šľachtu.

**Oprava voči súčasnému katalógu:** Bogatovci sú rod z **Užskej župy**. Všetky
`moodChanges: {"hungary": ...}` v tejto reťazi nahraď `zupaLoyalty: {"uzhorod": ...}`.
Maďari s touto vnútornou vzburou nemajú nič spoločné.

### 3.1 Sprisahanie (915)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Preventívne zatknúť vodcov** | `zupaLoyalty: {"uzhorod": -15}` | `prestige +5`; `next_event: bogata_trial_916` |
| **Sledovať a zhromažďovať dôkazy** | `zupaLoyalty: {"uzhorod": -5}` | žiadna prestíž teraz; `next_event: bogata_uprising_917` — **cena odložená, nie zrušená** |

### 3.2 Ak zatkol → Súd (916)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Odsúdiť na vyhnanstvo** | — | `prestige +2`, `zupaLoyalty: {"uzhorod": +5}` |
| **Odsúdiť na smrť** | `prestige -3` | `zupaLoyalty: {"uzhorod": -20}` — trvalá jazva, ale sprisahanci sú mimo hry navždy |
| **Udeliť milosť za vernosť** | `prestige -1` | `zupaLoyalty: {"uzhorod": +25}` — najvyššia lojalita, ale text musí naznačiť: budúci sprisahanci vedia, že zrada sa odpúšťa |

### 3.3 Ak sledoval → Povstanie (917)

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Poslať kráľovské vojsko potlačiť vzburu** | `gold -40`, `zupaLoyalty: {"uzhorod": -30}` | `prestige +4` |
| **Rokovať o kapitulácii výmenou za amnestiu** | `prestige -2` | `zupaLoyalty: {"uzhorod": +10}`, žiadne zlato |

**Prečo nie je jedna zjavne lepšia:** Zatknutie teraz bolí lojalitu hneď, ale rozhodne rýchlo.
Sledovanie neplatí nič teraz, ale o 2 roky príde plná vzbura — drahšia v zlate aj lojalite
súčasne. To je test #2 (cena) aj #3 (predvídateľnosť) v jednom: hráč vie, že odklad nie je
zdarma, pretože `next_event` mu to práve povedal.

---

## 4. Neúroda v Zemplíne — `rand_bad_harvest`

**Beat C — Prežitie (opakovaný, cooldown 24 mesiacov od `yearMin 903`).**

**Špecifickosť:** vždy **Zemplín** (`zemplin`) — periférna, najvzdialenejšia župa od Nitry.
Nie "jedna zo žúp" (generický text zakázaný pravidlami projektu). Fixný cieľ namiesto
dynamického výberu = žiadny nový systém, žiadne rozšírenie scope P0.

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Otvoriť kráľovské sklady pre Zemplín** | `food -20, gold -10` | `zupaLoyalty: {"zemplin": +8}` |
| **Nechať Zemplín, nech si poradí sám** | `prestige -3` | `food -10`, `zupaLoyalty: {"zemplin": -12}` |

**Prečo nie je jedna zjavne lepšia:** prvá voľba je drahšia v dvoch menách naraz
(jedlo+zlato) za istú lojalitu; druhá je lacnejšia v zlate, ale platí prestížou aj
lojalitou. Nie je tu žiadna voľba, ktorá platí menej vo všetkom.

---

## 5. Nájazd na hranicu — `rand_border_raid`

**Beat A→C — prvý výskyt v Konsolidácii, opakuje sa cez celú Prežitie fázu (`yearMin 903`, cooldown 15 mes.).**

**Oprava voči súčasnému katalógu:** aktuálne je "vyslať jazdu" **strogo lepšia** voľba
(menej zlata, viac prestíže) — to je presne zakázaný vzor "jedna možnosť je zjavne
najlepšia". Fix nižšie pridáva cenu do inej meny.

**Špecifickosť:** cieľ nájazdu je vždy **Gemer** — južná pohraničná župa, najbližšie
k maďarskému nebezpečenstvu, ktoré threat clock už ukazuje. Toto dáva voľbe váhu:
hráč vie, že Maďari prídu, a rozhoduje sa, ako s nimi zaobchádzať *skôr*, než prídu naozaj.

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Vyslať jazdu na prenasledovanie nájazdníkov** | `gold -10`, `hungary.mood anger +8` | `prestige +2`, `zupaLoyalty: {"gemer": +5}` |
| **Posilniť miestnu posádku, nechať nájazdníkov ujsť** | `gold -15`, `prestige -1` | `zupaLoyalty: {"gemer": +8}`, `hungary.mood` nezmenené |

**Prečo nie je jedna zjavne lepšia:** obe voľby platia v dvoch menách.
Prenasledovanie je lacnejšie v zlate a dáva prestíž, ale **dráždi Maďarov** — hráč,
ktorý pozná threat clock, vie, že provokovať nepriateľa, ktorý o pár rokov aj tak
zaútočí, je stávka, nie voľná výhra. Posádka je drahšia v zlate a stojí prestíž (kráľ
nechá nájazdníkov ujsť — vyzerá pasívne), ale nezvýši napätie s Maďarmi a posilní
vernosť Gemera. "Lepšia" voľba závisí od toho, či hráč verí, že prestíž a úspora zlata
teraz stojí za skoré napnutie vzťahu s víťazom 907.

---

## 6. Rada županov — vylepšenie existujúceho fallbacku (`council`, `EventManager._build_council_event`)

**Beat A→C — najčastejší recurring event, ide cez celú hru.** Aktuálne má 2 voľby, obe
platia iba zlatom za rôzne množstvo prestíže (lineárne, nezaujímavé — porušuje test #2
aj #4). Nahraď 3 voľbami — **primárna mena každej voľby je iná** (zlato / prestíž / lojalita
župy), nie len iná suma tej istej meny.

| Voľba | Primárna cena | Vedľajšia cena | Dôsledok | Typ hráča |
|---|---|---|---|---|
| **Odmeniť verných županov darmi** — `choice_result: gifts` | `gold -400` | — | `prestige +8`, `zupaLoyalty: {"bratislava": 5, "devin": 5, "gemer": 5, "hont": 5, "morava": 5, "nitra": 5, "novohrad": 5, "spis": 5, "tekov": 5, "trencin": 5, "uzhorod": 5, "zemplin": 5}` | Staviteľ konsenzu — plytké, ale široké |
| **Investovať do opevnení pohraničných žúp** (Gemer, Novohrad, Užhorod, Zemplín) — `choice_result: fortify` | `prestige -4` (dvor vyzerá slabý, keď míňa na hradby namiesto veľkoleposti) | `gold -100` | `zupaLoyalty: {"gemer": 10, "novohrad": 10, "uzhorod": 10, "zemplin": 10}` | Hráč, ktorý si pripravuje obranu pred rokom 907 alebo po ňom |
| **Odmietnuť žiadosti, zvýšiť dane** — `choice_result: taxes` | `zupaLoyalty: {"bratislava": -15, "devin": -15, "gemer": -15, "hont": -15, "morava": -15, "nitra": -15, "novohrad": -15, "spis": -15, "tekov": -15, "trencin": -15, "uzhorod": -15, "zemplin": -15}` | — | `gold +200` | Autokrat, ktorý ťaží ekonomiku na úkor dôvery |

**Presný strojový zápis (pre `rm-content`, nedohadúvať):** `zupaLoyalty` je vždy explicitný
dict `{"province_id": delta}`. `gifts` a `taxes` vypisujú všetkých 12 kľúčov z §0.1;
`fortify` vypisuje iba 4 (`gemer`, `novohrad`, `uzhorod`, `zemplin`). Nikdy skratka typu
"všetky" — `EventManager.resolve_choice()` iteruje iba cez kľúče, ktoré sú v dict-e prítomné
(`godot/scripts/managers/EventManager.gd:219-224`). Devín je v `gifts` a `taxes` zahrnutý —
je to bežná provincia z hľadiska rady županov, nezávisle od scenára Devín 907.

**Prečo nie je jedna zjavne lepšia:** dary sú drahé v zlate a plytké v efekte; opevnenia
platia prestížou (dvor vyzerá slabo, že rieši hranice namiesto dvorskej veľkoleposti) a
menším zlatom, ale sú úzko cielené; dane sú jediná voľba, ktorá *získava* zlato — za cenu
širokej nedôvery v každej jednej župe. Tri odlišné primárne meny znamenajú, že žiadny typ
hráča nemá univerzálne najlepšiu voľbu — staviteľ konsenzu, obranca hraníc a autokrat si
vyberajú inak.

**Textová požiadavka:** nesmie znieť ako "kráľovská rada zasadá". Použi meno konkrétneho
županstva relevantného k danej voľbe (napr. "županka spiš namieta, že dary idú len Nitre").

---

## 7. Spor o pasienky medzi Nitrou a Trenčínom — `rand_noble_feud` (flavor 1)

**Beat A — Konsolidácia (rok 903–905, prvý výskyt).** Učí, že vnútorná politika žúp má
váhu skôr, než prídu veľké krízy. Nitra a Trenčín sú reálne susediace župy
(`nitra.json.neighbors` obsahuje `trencin`) — spor o hranicu pasienkov je geograficky
pravdivý, nie vymyslený.

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Rozsúdiť v prospech Nitry (staršie právo)** — `choice_result: nitra_side` | `zupaLoyalty: {"trencin": -10}` | `prestige +1`, `zupaLoyalty: {"nitra": +10}` |
| **Rozsúdiť v prospech Trenčína (novšie osídlenie)** — `choice_result: trencin_side` | `zupaLoyalty: {"nitra": -10}` | `prestige +1`, `zupaLoyalty: {"trencin": +10}` |
| **Nechať spor bez rozsudku** — `choice_result: no_ruling` | `prestige -2`, `zupaLoyalty: {"nitra": -5, "trencin": -5}` | žiadne zlato — kráľ sa nezaviaže nikomu |

**Prečo nie je jedna zjavne lepšia:** prvé dve sú zrkadlové — zisk jednej župy je presne
strata druhej, takže voľba závisí od toho, ktorú župu hráč strategicky potrebuje (Nitra
je bohatšia a bližšie k dvoru, Trenčín je vzdialenejší a jeho nespokojnosť bolí menej
okamžite, ale dlhšie). Tretia je drahšia v prestíži a platí v oboch župach naraz —
cena za to, že sa kráľ nezaviaže.

---

## 8. Spor o obrad — `rand_missionary_dispute` (flavor 2)

**Beat C — Prežitie → Legitimita (opakovaný, `yearMin 903`, cooldown 20 mesiacov).**
Historicky ukotvené: po smrti Metoda (885) a vyhnaní Gorazda a ďalších žiakov (886) je
cyrilometodská tradícia v roku 902+ už menšinová a defenzívna voči latinským misionárom
z Bavorska. Neexistuje frakcia "kňazi" — cena ide cez `religionChange` a lojalitu
**Moravy** (`morava` — pôvodná moravská župa, srdce tradície), nie cez fiktívnu frakciu.

| Voľba | Cena | Dôsledok |
|---|---|---|
| **Podporiť latinský obrad** — `choice_result: latin` | `zupaLoyalty: {"morava": -6}` | `religionChange -8` (k Rímu), `franks.mood trust +8` |
| **Podporiť slovanský (byzantský) obrad** — `choice_result: byzantine` | `franks.mood trust -5` | `religionChange +8` (k Byzancii/tradícii), `byzantium.mood trust +8`, `zupaLoyalty: {"morava": +6}` |
| **Zakázať verejné spory oboch strán** — `choice_result: ban` | `zupaLoyalty: {"morava": -3}` (obe strany sa cítia nevypočuté) | `prestige +1`, žiadny posun náboženskej osi |

**Prečo nie je jedna zjavne lepšia:** prvé dve sú opäť zrkadlové (Rím vs. Byzancia, franská
vs. byzantská priazeň, morava loyalty hore/dole), tretia je "bezpečná" v tom, že nikoho
neurazí frontálne, ale platí za to nulovým posunom náboženskej osi — a tá os sa počíta
do legitimity smerom k roku 1000 (Beat Legitimita). Bezpečná voľba dnes je cena zaplatená
v premeškanej príležitosti neskôr.

---

## 9. Mapovanie na 10-minútovú trasu (test #5 — tempo)

| Beat | Roky (herné) | Eventy | Čo sa mení oproti predchádzajúcemu beatu |
|---|---|---|---|
| **A — Coach & prvé ťahy** | 902–905 | Pápežské posolstvo (903), Spor Nitra/Trenčín (flavor 1), prvý Border raid, prvá Rada županov | Nízke stávky, učí menu cien |
| **B — Napätie pred Devínom** | 906–907 | Byzantská ponuka sobáša + Svadba/Urážka | Stávky stúpajú — voľby teraz priamo ovplyvňujú, ako pripravená je Morava na Devín |
| **C — Po Devíne, Prežitie k 1000** | 908–960+ | Sprisahanie Bogata + Súd/Povstanie, recurring Neúroda/Border raid/Rada županov, Spor o obrad | Vnútorná politika po katastrofe; Spor o obrad naväzuje na Legitimitu smerom k 1000 |

Ťah 3 (Beat A) je o tom, že voľba niečo stojí. Ťah 8 (Beat C) je o tom, že minulé voľby
(kam sa priklonila náboženská os, aká je lojalita Užhorodu po Bogatovi) sa vracajú ako
vstupné podmienky ďalších eventov — to je rozdiel v tempe, nie kozmetika.

---

## 9.5 Narration hook — presný strojový kontrakt

**Prečo je to potrebné:** `EventManager.resolve_choice()` (`godot/scripts/managers/EventManager.gd:178`)
dnes vracia iba `{"ok", "effect", "chronicle"}` — chýbajú `event_id` a `context`, ktoré
kronika (`NarrationManager`) a smoke test potrebujú, aby vedeli, **ktorý** event a **ktorá**
voľba sa stali, nielen aké číslo padlo. Toto je zadanie pre implementáciu (`rm-core`/`rm-content`),
nie pre `rm-design` — nasledujúca tabuľka je špecifikácia, podľa čoho sa dá overiť test.

**Kontrakt (platí pre všetkých 8 eventov nižšie, žiadna výnimka):**

`resolve_choice(choice_id)` musí vrátiť navyše:
- `event_id: String` — `pending.get("id", "")` eventu, ktorý bol práve vyriešený (dostupné
  už v metóde ako `eid`, len sa nevracia).
- `choice_result: String` — presne ten `choice_id`, ktorý bol argumentom volania (žiadna
  transformácia, žiadny preklad na text).
- `context: Dictionary` s vždy prítomnými kľúčmi:
  - `"year": int` — `game_state.year` v momente rozhodnutia,
  - `"province_ids": Array` — kľúče `zupaLoyalty` z vybranej voľby (`[]`, ak voľba žiadnu neriešila),
  - `"faction_ids": Array` — kľúče `moodChanges` z vybranej voľby, **rezolvované cez
    `_resolve_faction_id()`** (`[]`, ak voľba žiadnu neriešila),
  - `"next_event": String` — hodnota `choice_dict.get("next_event", "")` (prázdny string, ak voľba nereťazí).

**Overenie v `smoke_test.m6.gd`:** pre každý z 8 event_id nižšie test zavolá
`resolve_choice()` s každým platným `choice_id` a assertuje: `result.event_id == <očakávaný>`,
`result.choice_result == <zvolené choice_id>`, `result.context.has("province_ids")`,
`result.context.has("faction_ids")`, a pri reťazových eventoch `result.context.next_event == <next_event id>`.

| # | `event_id` | Platné `choice_result` hodnoty | `context.province_ids` (neprázdne pre) | `context.faction_ids` (neprázdne pre) | `context.next_event` (neprázdne pre) |
|---|---|---|---|---|---|
| 1 | `hist_papal_legation_903` | `rome`, `decline` | — | `rome` → `["franks"]`; `decline` → `["franks"]` | — |
| 2.1 | `byz_bride_proposal_906` | `accept`, `decline` | — | oba → `["byzantium"]` | `accept` → `byz_bride_wedding_907`; `decline` → `byz_bride_insult_907` |
| 2.2 | `byz_bride_wedding_907` | `grand`, `modest` | — | oba → `["byzantium"]` (+ `moravia` pri `grand`) | — |
| 2.3 | `byz_bride_insult_907` | `apologize`, `stand` | — | oba → `["byzantium"]` | — |
| 3.1 | `hist_bogata_conspiracy_915` | `arrest`, `watch` | oba → `["uzhorod"]` | — | `arrest` → `bogata_trial_916`; `watch` → `bogata_uprising_917` |
| 3.2 | `bogata_trial_916` | `exile`, `death`, `pardon` | všetky tri → `["uzhorod"]` | — | — |
| 3.3 | `bogata_uprising_917` | `crush`, `negotiate` | oba → `["uzhorod"]` | — | — |
| 4 | `rand_bad_harvest` | `open`, `ignore` | oba → `["zemplin"]` | — | — |
| 5a | `rand_border_raid` | `chase` | `["gemer"]` | `["hungary"]` | — |
| 5b | `rand_border_raid` | `fortify` | `["gemer"]` | `[]` | — |
| 6a | `council` | `gifts` | `["bratislava","devin","gemer","hont","morava","nitra","novohrad","spis","tekov","trencin","uzhorod","zemplin"]` | `[]` | — |
| 6b | `council` | `fortify` | `["gemer","novohrad","uzhorod","zemplin"]` | `[]` | — |
| 6c | `council` | `taxes` | `["bratislava","devin","gemer","hont","morava","nitra","novohrad","spis","tekov","trencin","uzhorod","zemplin"]` | `[]` | — |
| 7 | `rand_noble_feud` | `nitra_side`, `trencin_side`, `no_ruling` | všetky tri → `["nitra", "trencin"]` | — | — |
| 8 | `rand_missionary_dispute` | `latin`, `byzantine`, `ban` | všetky tri → `["morava"]` | `latin` → `["franks"]`; `byzantine` → `["byzantium"]` | — |

**Poznámka k voľbám #6 a #7:** existujúci `_build_council_event()` má dnes `choice_result`
id `gifts`/`fortify` — tabuľka vyžaduje pridať tretiu voľbu s id `taxes` (§6 vyššie).
`rand_noble_feud` v katalógu má dnes id `law`/`ignore` — nahraď ich `nitra_side`/`trencin_side`/`no_ruling`,
aby zodpovedali 3 voľbám z §7 (súčasný katalóg má len 2, čo je tiež nesúlad, ktorý táto
špecifikácia opravuje).

---

## 10. Akceptačné kritériá pre `rm-content`

- [ ] 8 event-rodín presne podľa ID vyššie, žiadny deviaty.
- [ ] Žiadny `moodChanges` na frakciu mimo `moravia, franks, bavaria, hungary, poland, bohemia, byzantium`.
- [ ] Bogata reťaz (3, 3.1–3.3) používa `zupaLoyalty: {"uzhorod": ...}`, nie `hungary` mood.
- [ ] Všetky `next_event` odkazy použijú kľúč `next_event` (snake_case), nikdy `nextEvent`.
- [ ] Border raid (5) má cenu v dvoch rôznych menách pre obe voľby: `chase` platí zlatom
      a vzťahom s Maďarmi (`hungary.mood anger +8`), `fortify` platí zlatom a prestížou
      (`prestige -1`) — žiadna voľba nesmie byť lacnejšia AJ výnosnejšia súčasne ako druhá.
- [ ] Rada županov (6) má 3 voľby (`gifts`, `fortify`, `taxes`), každú inú menu ako primárnu
      cenu; `zupaLoyalty` v `gifts` a `taxes` vypisuje všetkých 12 kľúčov z §0.1 explicitne,
      `fortify` vypisuje 4 kľúče (`gemer`, `novohrad`, `uzhorod`, `zemplin`) — žiadne
      "všetky", žiadny wildcard (`EventManager` ho nepodporuje).
- [ ] Spor o pasienky (7) má 3 voľby s `choice_result` `nitra_side`/`trencin_side`/`no_ruling`
      (nie pôvodné `law`/`ignore` z katalógu).
- [ ] Neúroda (4) a Border raid (5) menujú konkrétnu župu v texte (Zemplín, Gemer) —
      žiadne "jedna zo žúp".
- [ ] Každý z 8 eventov (vrátane všetkých vetiev/reťazí) emituje presne `event_id`,
      `choice_result`, `context` podľa kontraktu §9.5 — overené v `smoke_test.m6.gd`
      podľa tabuľky §9.5, nie voľnou checkbox vetou.
- [ ] Žiadna zmena Devín 907 invariantov (§15.6 `NAVRH_HERNY_ZAZITOK.md`), žiadna zmena
      RNG mechaniky (to je `t_7a0d3266`, samostatná karta pre `rm-core`).
