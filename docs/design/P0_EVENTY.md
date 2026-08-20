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
| **Lojalita župy** | `zupaLoyalty` → `game_state.provinces[id].loyalty` | **bare province id** (`nitra`, `trencin`, `morava`, `gemer`, `zemplin`, `devin`, ...) — **nie** `zupa_nitra` |
| **Vzťah s frakciou** | `moodChanges` → `game_state.factions[id].mood` | **iba** týchto 7 id existuje: `moravia, franks, bavaria, hungary, poland, bohemia, byzantium`. Nikdy nepíš `moodChanges` na meno, ktoré nie je táto sedmička. |
| **Náboženská os** | `religionChange` | Rím ↔ Konštantínopol, jediný kanál pre "cyrilometodský" konflikt (žiadna taká frakcia neexistuje) |
| **Čas / budúca možnosť** | `next_event` (snake_case!) | odklad ceny, nie jej zrušenie — pozri §1.4 |

### 0.1 Dve chyby v existujúcom katalógu, ktoré táto špecifikácia opravuje

1. **Bogata reťaz používa `hungary` mood namiesto lojality Užskej župy.** Bogatovci sú
   moravský rod z **Užskej župy** (`uzhorod`), nie Maďari. Pôvodný TS mal vlastnú fiktívnu
   frakciu `Bogatovci`, ktorá sa v Godote nedá resolvovať — namiesto dopĺňania ďalšej
   neexistujúcej frakcie použi `zupaLoyalty: {"uzhorod": ...}`. Detail v §4.
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
| **Zdvorilo odmietnuť, zachovať cyrilometodské dedičstvo** | `religionChange: +5` (k Bl<br>zancii/tradícii), `franks.mood -5` | žiadny prestíž | Hráč, ktorý stavia na byzantskom spojenectve (pozri event 2) a je ochotný platiť franskou nevôľou už teraz |

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
| **Usporiadať skromný obrad** | žiadny gold | `prestige +3`, `byzantium.mood trust +5` |

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
| **Sledovať a zhromažďovať dôkazy** | `zupaLoyalty: {"uzhorod": -5}` | žiadny prestíž teraz; `next_event: bogata_uprising_917` — **cena odložená, nie zrušená** |

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
| **Rokovať o kapitulácii výmenou za amnestiu** | `prestige -2` | `zupaLoyalty: {"uzhorod": +10}`, žiadny gold |

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
| **Posilniť miestnu posádku, nechať nájazdníkov ujsť** | `gold -15` | `zupaLoyalty: {"gemer": +8}`, `hungary.mood` nezmenené |

**Prečo nie je jedna zjavne lepšia:** prenasledovanie je lacnejšie a dáva prestíž, ale
**dráždi Maďarov v mene, ktorá sa spätne prejaví pri Devíne** — hráč, ktorý pozná threat
clock, vie, že provokovať nepriateľa, ktorý o pár rokov aj tak zaútočí, je stávka, nie
voľná výhra. Posádka je drahšia, ale neutrálna k jedinému nepriateľovi, ktorý napokon
vyhráva vždy (§15.6 invariant) — takže "lepšia" voľba závisí od toho, či hráč verí, že
prestíž teraz stojí za skoré napnutie vzťahu s víťazom 907.

---

## 6. Rada županov — vylepšenie existujúceho fallbacku (`council`, `EventManager._build_council_event`)

**Beat A→C — najčastejší recurring event, ide cez celú hru.** Aktuálne má 2 voľby, obe
platia iba zlatom za rôzne množstvo prestíže (lineárne, nezaujímavé — porušuje test #2
aj #4). Nahraď 3 voľbami, každá iná mena, každá iný typ hráča.

| Voľba | Cena | Dôsledok | Typ hráča |
|---|---|---|---|
| **Odmeniť verných županov darmi** | `gold -400` | `prestige +8`, `zupaLoyalty` **všetky** župy `+5` | Staviteľ konsenzu — plytké, ale široké |
| **Investovať do opevnení pohraničných žúp** (Gemer, Novohrad, Užhorod, Zemplín) | `gold -250` | `prestige +2`, `zupaLoyalty: {"gemer": +10, "novohrad": +10, "uzhorod": +10, "zemplin": +10}` | Hráč, ktorý si pripravuje obranu pred rokom 907 alebo po ňom |
| **Odmietnuť žiadosti, zvýšiť dane** | `prestige -5`, `zupaLoyalty` **všetky** župy `-15` | `gold +200` | Autokrat, ktorý ťaží ekonomiku na úkor dôvery |

**Prečo nie je jedna zjavne lepšia:** dary sú drahé a plytké, opevnenia sú lacnejšie ale
úzko cielené, dane sú jediná voľba, ktorá *získava* zlato — ale za cenu širokej nedôvery.
Žiadna voľba nemá najlepší pomer vo všetkých menách naraz.

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
| **Rozsúdiť v prospech Nitry (staršie právo)** | `zupaLoyalty: {"trencin": -10}` | `prestige +1`, `zupaLoyalty: {"nitra": +10}` |
| **Rozsúdiť v prospech Trenčína (novšie osídlenie)** | `zupaLoyalty: {"nitra": -10}` | `prestige +1`, `zupaLoyalty: {"trencin": +10}` |
| **Nechať spor bez rozsudku** | `prestige -2`, `zupaLoyalty: {"nitra": -5, "trencin": -5}` | žiadny gold — král sa nezaviaže nikomu |

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
| **Podporiť latinský obrad** | `zupaLoyalty: {"morava": -6}` | `religionChange -8` (k Rímu), `franks.mood trust +8` |
| **Podporiť slovanský (byzantský) obrad** | `franks.mood trust -5` | `religionChange +8` (k Byzancii/tradícii), `byzantium.mood trust +8`, `zupaLoyalty: {"morava": +6}` |
| **Zakázať verejné spory oboch strán** | `zupaLoyalty: {"morava": -3}` (obe strany sa cítia nevypočuté) | `prestige +1`, žiadny posun náboženskej osi |

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

## 10. Akceptačné kritériá pre `rm-content`

- [ ] 8 event-rodín presne podľa ID vyššie, žiadny deviaty.
- [ ] Žiadny `moodChanges` na frakciu mimo `moravia, franks, bavaria, hungary, poland, bohemia, byzantium`.
- [ ] Bogata reťaz (3, 3.1–3.3) používa `zupaLoyalty: {"uzhorod": ...}`, nie `hungary` mood.
- [ ] Všetky `next_event` odkazy použijú kľúč `next_event` (snake_case), nikdy `nextEvent`.
- [ ] Border raid (5) má cenu v dvoch rôznych menách pre obe voľby — žiadna voľba nesmie
      byť lacnejšia AJ výnosnejšia súčasne ako druhá.
- [ ] Rada županov (6) má 3 voľby, každá inú menu ako primárnu cenu.
- [ ] Neúroda (4) a Border raid (5) menujú konkrétnu župu v texte (Zemplín, Gemer) —
      žiadne "jedna zo žúp".
- [ ] Každý event emituje narration hook (`event_id, context, choice_result`) overený
      v `smoke_test.m6.gd`.
- [ ] Žiadna zmena Devín 907 invariantov (§15.6 `NAVRH_HERNY_ZAZITOK.md`), žiadna zmena
      RNG mechaniky (to je `t_7a0d3266`, samostatná karta pre `rm-core`).
