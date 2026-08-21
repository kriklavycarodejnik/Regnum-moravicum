# P0 Design Gate — 10-minútová trasa

> Verdikt dizajnovej kontroly. Zdroj: prečítaný kód + texty z `godot/`,
> trasa z `docs/NAVRH_HERNY_ZAZITOK.md` §4.

---

## Verdikt: PREPRACOVAŤ

3 z 5 testov prešli. 2 padli — oba sú opraviteľné v P0 bez rozšírenia scope.

---

## Trasa (čítaná z kódu)

1. **Menu** → `MainMenu.tscn` (New / Load / Quit)
2. **Briefing + Coach 1-2-3** → overlay na `Main.tscn`:
   - Krok 1: „Klikni na Nitru" (klik na mapu)
   - Krok 2: „Tvoje poslanie" (acknowledge)
   - Krok 3: „Stlač Ďalší mesiac" (press Next Month)
3. **Ďalší mesiac ×12** (rok 902) → TurnReport s Δ zdrojov + rovnaká narácia. Žiadne eventy.
4. **903/01** → Pápežské posolstvo (historický event, year 903). Prvý reálny výber.
5. **903–905** → sporadické random eventy (cooldown 15–24 tickov) + 8% council fallback.
6. **906** → Byzantská ponuka sobáša (historický event) + Devín warning modal (906/01) + notifikácia (906/06).
7. **907/01** → Devín prepare modal. Devín button aktívny.
8. **907** → Manuálne spustiť Devín → `HungarianWarScenario.resolve_devine_battle()` → winner=attacker → dôsledky (prestíž −30, lojalita Devína −20, mood Maďarov +30) → epilogue modal.
9. **908+** → pokračovanie smerom k 1000, Bogata (915), sporadické random eventy.

---

## Test 1: Prerozprávanie — PASS

Hráč po 10 minútach rozpráva: „Začal som v 902 ako Mojmír II. V 903 prišlo pápežské
posolstvo — odmietol som, lebo som chcel zachovať cyrilometodské dedičstvo. V 906
ponúkol Lev VI. nevestu — prijal som a spravili sme veľkolepú svadbu. V 907 prišli
Maďari k Devínu a prelomili riečnu obranu. Prestíž padla o 30. V 915 sa Bogata
sprisahali v Užskej župe — zatkol som vodcov."

Mená (Mojmír II, Lev VI, Bogata), roky (902, 903, 906, 907, 915), lokácie (Nitra,
Devín, Užská župa). Eventy sú historicky zakotvené a konkrétne.

---

## Test 2: Cena — PASS

Každá voľba platí aspoň v jednej mene:

- Pápežské posolstvo: prijať → religion −15, franks +trust | odmietnuť → religion +5, franks +anger
- Byzantská nevesta: prijať → religion +10, byzantium +trust | odmietnuť → byzantium −trust, +anger
- Svadba: grand → gold −60, prestige +8 | modest → prestige +3 (menej)
- Bogata: arrest → prestige +5, uzhorod −15 | watch → uzhorod −5, reťaz → povstanie
- Súd: exile → uzhorod +5 | death → prestige −3, uzhorod −20 | pardon → prestige −1, uzhorod +25
- Neúroda: open → food −20, gold −10 | ignore → food −10, prestige −3, zemplin −12
- Council: gifts → gold −400 | fortify → gold −100, prestige −4 | taxes → gold +200, all loyalty −15

Žiadna voľba bez ceny. Reťazové eventy (next_event) odkladajú cenu, nie ju rušia.

---

## Test 3: Predvídateľnosť — PASS

Threat clock viditeľný od prvého ťahu: „Do Maďarov: N mesiacov."
Farba eskaluje: TEXT_SECONDARY → WARNING (≤36 mes.) → MORAVIA_CRIMSON + bold (≤12 mes.).
906/01 → warning modal („Blíži sa invázia").
906/06 → notifikácia („Pošli armádu k Devínu").
907/01 → prepare modal („Devín volá").
Devín button zamknutý pred 906, text ukazuje „(od roku 906)".
Hráč vidí hrozbu 5 rokov vopred. Žiadne prekvapenie.

---

## Test 4: Špecifickosť — PREPRACOVAŤ

### Bod 4a: NarrationManager je odpojený — každý TurnReport je rovnaký

**Čo je zle:** `TickManager.process_tick()` (riadok 106) volá
`narration.generate_chronicle(report)` s celým tick reportom. Ten report má
kľúče `year`, `month`, `economy`, `nobility`, ... ale **nemá** kľúč `"type"`.
`NarrationManager.generate_chronicle()` (riadok 23) robí `match report.get("type", "")`
a default vetka vráti `""`. Takže NarrationManager **vždy** vráti prázdny reťazec.
`Main.gd:_show_turn_report_via_node()` (riadok 784) použije fallback:
„Mesiac uplynul v tichu dvorov a polí." — **60+ krát za hru, pri každom ťahu**.

**Čím nahradiť:** TickManager nech iteruje cez sub-reporty (economy, nobility,
war, event, ...) a zavolá `generate_chronicle()` na každý jednotlivo (tie
majú `"type"` kľúč), alebo NarrationManager nech akceptuje celý report a vyberie
najzaujímavejší sub-report podľa jeho `"type"`. Cieľ: aspoň 3-4 rôzne narácie
za 10 ťahov namiesto jednej fallback vety.

**Špecialista:** `rm-core` (systémový fix v `TickManager.gd` / `NarrationManager.gd`)

### Bod 4b: NarrationManager šablóny sú generické

**Čo je zle:** Keby NarrationManager fungoval, jeho šablóny sú zameniteľné
s hocijakou stredovekou hrou:

- `_generate_diplomacy_text`: „Diplomatické vzťahy sa menia..." — nič moravské.
- `_generate_war_text`: „Vojna pokračuje..." — nič moravské.
- `_generate_armies_text`: „Armády sú pripravené." — nič moravské.
- `_generate_economy_text`: „Provincia %s: prosperita %.1f%% (upkeep: %d zlata)" — debug log, nie narácia.
- `_generate_religion_text`: „Náboženská situácia: %s" — generic.

**Čím nahradiť:** Každá šablóna nech obsahuje mená, lokácie a moravský register.
Príklady (šablóna → konkrétna náhrada):

- economy: „Sypárnice v Nitre sa plnia, ale župan z Gemera poslal posla s žiadosťou o zŕn."
- diplomacy: „Posolstvo z Regensburgu mlčí — bavorský vojvoda si meria Moravu."
- war: „Maďarské čaty obťažujú pohraničné dvorce v Zemplíne — odsúdené župy volajú po pomoci."
- armies: „Družiny v Nitre cvičia na dvore, zbrojmajster Krištof prisahá, že meče sú ostré."
- religion: „Kňazi v Nitre sa hádajú — latinsky alebo slovansky — a ľud počúva."

**Špecialista:** `rm-content` (prepísanie šablón v `NarrationManager.gd`)

---

## Test 5: Tempo — PREPRACOVAŤ

### Bod 5: Rok 902 — 12 mŕtvych ťahov

**Čo je zle:** Všetky random eventy v `events_catalog.json` majú `yearMin: 903`.
Všetky historické eventy majú `year: 903+`. Council event (fallback) je 8 %
za mesiac. V roku 902 (12 ťahov) hráč stlačí „Ďalší mesiac" 12× s rovnakým
výsledkom: rovnaká narácia (fallback), rovnaké Δ zdrojov (ekonomika produkuje
rovnaké množstvo každý mesiac), žiadny event (okrem ~64 % šanca na jeden council
za celý rok). Tempo ťahu 3 = tempo ťahu 8 = nič, len čísla rastú a threat clock
počíta.

**Čím nahradiť:** Dva opening eventy v roku 902:

1. **„Korunzácia Mojmíra II."** (902/02, once, year: 902) — výber medzi
   veľkolepou korunzáciou (gold −50, prestige +5) a skromnou (prestige +1,
   lojalita Nitry +10). Nastaví tempo a predstaví menu cien.
2. **„Prvé správy o Maďaroch"** (902/06, once, year: 902) — výber medzi
   vyslaním vyzvedačov (gold −20, info) a ignorovaním (prestige −2, mood
   Maďarov −5). Spojí threat clock s konkrétnym dôsledkom.

Tieto eventy majú `year: 902` a `once: true` — žiadny cooldown, žiadny
random pool. Garantované, nie náhodné. Hráč dostane prvé rozhodnutie
v ťahu 2, nie ťahu 13.

**Špecialista:** `rm-content` (nové eventy v `events_catalog.json` + texty)

---

## Súhrn

| Test | Verdikt | Bod |
|------|---------|-----|
| Prerozprávanie | PASS | — |
| Cena | PASS | — |
| Predvídateľnosť | PASS | — |
| Špecifickosť | PREPRACOVAŤ | 4a: NarrationManager odpojený (rm-core) · 4b: šablóny generické (rm-content) |
| Tempo | PREPRACOVAŤ | 5: rok 902 mŕtvy — 2 opening eventy (rm-content) |

3 body na prepracovanie, 2 špecialisti (rm-core, rm-content), žiadny nový scope.
Po oprave bodov 4a + 4b + 5 je 10-minútová trasa hrateľná a zároveň zaujímavá.
