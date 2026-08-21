# P1 Design Gate — 10-minútová trasa po P1

> Verdikt dizajnovej kontroly. Zdroj: prečítaný kód + texty z `godot/`,
> trasa 902 → 907 → 915 podľa `docs/NAVRH_HERNY_ZAZITOK.md` §4.
> Overené voči `docs/design/P1_KONTRAKT.md`, `docs/GAMEPLAY_LOOP.md`,
> `docs/VISUAL_DIRECTION.md`, `docs/M6_UI_ART_SCOPE.md`.

---

## Verdikt: PASS

5 z 5 testov prešlo. P0 fixy (4a, 4b, 5) overené ako reálne opravené v kóde.
P1 pridáva hĺbku bez rozšírenia scope — beaty, side-goals, army wizard,
threat markery sú všetky implementované a prepojené na existujúci GameState.

Dva drobné nálezy mimo P1 scope idú do triage pre P2 (§6 nižšie).

---

## Trasa (čítaná z kódu)

1. **Menu** → `MainMenu.tscn` (Nová hra / Načítať / Koniec)
2. **Briefing + Coach 1-2-3** → overlay na `Main.tscn`
3. **902/02** → `hist_mojmir_coronation_902` (P0.5 opening event) — prvé rozhodnutie
4. **902/06** → `hist_magyar_reports_902` (P0.5 opening event) — druhé rozhodnutie
5. **903** → `hist_papal_legation_903` — pápežské posolstvo
6. **904–905** → random eventy (cooldown 15–24) + 8 % council fallback
7. **906/01** → Devín warning modal („Blíži sa invázia")
8. **906/06** → Klikateľná notifikácia „Pošli armádu k Devínu" → Army wizard W1
9. **906** → `byz_bride_proposal_906` — byzantská ponuka sobáša → reťaz (wedding/insult)
10. **907/01** → Devín prepare modal („Devín volá")
11. **907** → Manuálne spustiť Devín → `resolve_devine_battle()` → winner=attacker
    → dôsledky (prestíž −30, lojalita Devína −20, mood Maďarov +30) → epilogue
12. **908–914** → Fáza III beat C1, diplomatické side-goaly, random eventy
13. **915** → `hist_bogata_conspiracy_915` → reťaz (trial_916 / uprising_917)
14. **960+** → Fáza IV beat D1 — roky do 1000

---

## Test 1: Prerozprávanie — PASS

Hráč po 10 minútach rozpráva: „Začal som v 902 ako Mojmír II. Hneď v druhom
mesiaci som sa dal korunovať — vybral som skromný obrad, lebo som chcel šetriť
na Maďarov. V šiestom mesiaci prišli správy o maďarských jazdcoch za Karpatmi,
poslal som vyzvedačov. V 903 prišlo pápežské posolstvo — odmietol som. V 906
ponúkol Lev VI. nevestu, prijal som a v 907 sme spravili svadbu. V 907 prišli
Maďari k Devínu a prelomili riečnu obranu. Prestíž padla o 30. V 915 sa Bogata
sprisahali v Užskej župe — zatkol som vodcov a v 916 ich súdil."

Mená: Mojmír II, Lev VI, Bogata, Radomír z Gemera (army wizard W3).
Roky: 902, 903, 906, 907, 915, 916.
Lokácie: Nitra, Devín, Užhorod, Gemer, Zemplín, Karpatské priesmyky.

Eventy sú historicky zakotvené a konkrétne. Reťazové eventy (wedding → 907,
trial → uprising) posúvajú príbeh dopredu, nie ho nemelia.

---

## Test 2: Cena — PASS

Každá voľba platí aspoň v jednej mene. Žiadna odmena bez ceny.

- Korunzácia: grand → gold −50, prestige +5 | modest → prestige +1, nitra +10
- Maďarské správy: scouts → gold −20, hungary anger −5, zemplin +5 | ignore → prestige −2, hungary anger +5
- Pápežské posolstvo: rome → prestige +3, religion −15, franks +trust | decline → religion +5, franks +anger
- Byzantská nevesta: accept → religion +10, byzantium +trust | decline → byzantium −trust, +anger
- Svadba: grand → gold −60, prestige +8 | modest → prestige +3
- Bogata: arrest → prestige +5, uzhorod −15 | watch → uzhorod −5 → povstanie
- Súd: exile → prestige +2, uzhorod +5 | death → prestige −3, uzhorod −20 | pardon → prestige −1, uzhorod +25
- Povstanie: crush → gold −40, prestige +4, uzhorod −30 | negotiate → prestige −2, uzhorod +10
- Neúroda: open → food −20, gold −10, zemplin +8 | ignore → food −10, prestige −3, zemplin −12
- Nájazd: chase → gold −10, prestige +2, gemer +5, hungary +anger | fortify → gold −15, prestige −1, gemer +8
- Spor županov: nitra/trencin loyalty swap | no ruling → prestige −2, obe −5
- Misijný spor: latin → religion −8, morava −6, franks +trust | byzantine → religion +8, morava +6, franks −trust, byzantium +trust | ban → prestige +1, morava −3
- Council: gifts → gold −400 | fortify → gold −100, prestige −4 | taxes → gold +200, all loyalty −15

Reťazové eventy odkladajú cenu, nie ju rušia. Army wizard stojí čas (4 kroky)
a viaže sa na existujúcu armádu s veliteľom — nie je to free akcia.

---

## Test 3: Predvídateľnosť — PASS

Threat clock viditeľný od prvého ťahu v `StatusBar.gd`:
„Do Maďarov: N mes." pred 907, „Do roku 1000: N rokov." po 907.

Signálna eskalácia:
- 906/01 → warning modal („Blíži sa invázia") — `Main.gd:_show_devin_modal("warning")`
- 906/06 → klikateľná notifikácia („Pošli armádu k Devínu") cez `push_action("...", "army_wizard")`
- 907/01 → prepare modal („Devín volá") — `_show_devin_modal("prepare")`

Army wizard W1–W4 je signal-driven sekvencia — hráč ju spustí klinikom na
notifikáciu, nie prekvapením. Wizard neblokuje Devín (`devine_resolved` je
jediná poistka pre bitku).

Threat markery na mape:
- Lojalita župy < 30 → crimson arc okolo polygónu (`MapView.gd:370`)
- Nálada frakcie < 25 → warning circle na okraji mapy (`MapView.gd:448`)
- Food < 100 → warning chip v StatusBar (`StatusBar.gd:102`)

Hráč vidí hrozby vizuálne aj v UI texte. Žiadne prekvapenie.

---

## Test 4: Špecifickosť — PASS

### Overenie P0 fixov (neberiem ako dané)

**Bod 4a (NarrationManager odpojený) — OPRAVENÉ.**
`NarrationManager.generate_chronicle()` (riadok 67) teraz iteruje cez
`_PRIORITY` pole sub-reportov. Pre každý sub-report s nepráznym `type` zavolá
`_dispatch_type()`. TickManager `process_tick()` (riadok 106) posiela celý
report so všetkými sub-reportmi. Smoke test `smoke_test.m6.gd:534–637`
explicitne overuje, že economy / event / war / mixed sub-reporty produkujú
non-prázdny text, nie fallback.

**Bod 4b (šablóny generické) — OPRAVENÉ.**
Šablóny obsahujú moravské mená, lokácie a register:
- economy: „Sypárnice v Nitre sa plnia, no župan z Gemera poslal posla so žiadosťou o zrno."
- diplomacy: „Posolstvo z Regensburgu mlčí — bavorský vojvoda si meria Moravu a vyčkáva na slabosť."
- war: „Maďarské čaty vpadli do dvorcov v Zemplíne — odsúdené pohraničné župy volajú po pomoci."
- religion: „Kňazi v Nitre vedú spory — latinský obrad súperí so staroslovienčinou a ľud pozorne počúva."
- nobility: „…z rodu Mojmírovcov skonal v Nitre — dvor nosí smútok a zvony bijú."
- armies: „Oddiel %s stráca %d bojovníkov pre nedostatok zásob na pohraničí."
- campaign: „Obliehanie %s pokračuje — obrancovia na hradbách počítajú ubúdajúce zásoby."

Žiadna šablóna nie je zameniteľná s inou stredovekou hrou bez zmeny.
Dal by sa ten text použiť v Crusader Kings alebo Battle Brothers? Nie —
„Regensburg", „Gemera", „staroslovienčina", „Mojmírovcov" sú viazané na
Veľkú Moravu.

### Bod 4c: Economy text — drobná nekonzistencia (P2 triage, nie blokér)

`_generate_economy_text()` (riadok 146) vždy spomína „župan z Gemera" bez
ohľadu na to, ktorá župa je v locatíve. Ak rng vyberie Gemer samotný, text
číta: „Sypárnice v Gemeri sa plnia, no župan z Gemera poslal posla so
žiadosťou o zrno." — to je rozporné (Gemer má plné sypárnice, ale gemerský
župan žiada o zrno). Neprechádza testom špecifickosti, lebo text je stále
moravský a konkrétny, ale je logicky nekonzistentný. → P2 triage.

---

## Test 5: Tempo — PASS

### Overenie P0 fixu (mŕtvy rok 902)

**Bod 5 (mŕtvy rok 902) — OPRAVENÉ.**
`events_catalog.json` obsahuje dva opening eventy s `year: 902`:
- `hist_mojmir_coronation_902` (902/02, once: true) — prvé rozhodnutie v ťahu 2
- `hist_magyar_reports_902` (902/06, once: true) — druhé rozhodnutie v ťahu 6

Hráč dostáva prvé rozhodnutie v ťahu 2, nie ťahu 13. Žiadne 12 mŕtvych
ťahov. Tempo ťahu 2 (korunzácia) ≠ tempo ťahu 6 (maďarské správy) ≠ tempo
ťahu 8 (ekonomika).

### Tempo po P1

Ťahy sa líšia v každej fáze:

| Fáza | Ťah | Čo sa deje | Čo hráč vidí |
|------|-----|------------|--------------|
| I (902–906) | 2 | Korunzácia | Event s 2 voľbami, cena v gold/prestige |
| I | 6 | Maďarské správy | Event s 2 voľbami, spojenie s threat clock |
| I | 12 | Ekonomika | TurnReport Δ + narácia (province-specific) |
| I | 906/06 | Army wizard W1 | Notifikácia + overlay s 4 krokmi |
| II (907) | 907/01 | Devín prepare | Modal + threat marker na mape |
| II | 907 | Devín bitka | BattleView + epilogue + prestíž −30 |
| III (908–914) | bežný | Side-goaly | ObjectivesPanel: najhoršia frakcia, urgent CTA |
| III | 915 | Bogata | Event → reťaz trial_916 / uprising_917 |
| IV (960+) | bežný | D1 beat | „~N r. · župy: N · prestíž: N" |

Beat štruktúra (A1–D1 v `ObjectivesPanel.compute_beats()`) zaručuje, že
každá fáza má iný `next_step`, iné `goals` a inú `phase_hint`. Hráč nikdy
nevidí rovnaký „Teraz urob" v dvoch rôznych fázach.

### Drobný tempo problém (P2 triage, nie blokér)

`NarrationManager._apply_anti_repetition()` (riadok 116) drží zoznam 12
posledných šablón. Ak sa rovnaká šablóna objaví znova, vráti "". Pre economy
text, ktorý má ~12 variantov (podľa provincie), po 12 ťahoch všetky varianty
vyčerpajú zoznam a ďalšie economy narácie vracajú "" → fallback
„Mesiac uplynul v tichu dvorov a polí." v `Main.gd:1063`.

Tento fallback sa môže objaviť v 908–914, keď nestrielia random eventy
(cooldown 15–24) ani council (8 %). Odhadom 30–40 % ťahov v tejto fáze.
Nie je to 12 mŕtvych ťahov ako v P0 — side-goaly a ObjectivesPanel stále
poskytujú smer — ale fallback text je vizuálne rovnaký. → P2 triage:
buď viac economy variantov, alebo vypnúť anti-repetition pre economy.

---

## Súhrn

| Test | Verdikt | Poznámka |
|------|---------|----------|
| Prerozprávanie | PASS | Mená, roky, lokácie — všetko konkrétne |
| Cena | PASS | Každá voľba platí v ≥1 mene; reťaze odkladajú, nerušia |
| Predvídateľnosť | PASS | Threat clock + modaly + army wizard notifikácia + vizuálne markery |
| Špecifickosť | PASS | P0 fixy 4a/4b overené v kóde; šablóny moravské; 1 drobná nekonzistencia → P2 |
| Tempo | PASS | P0 fix 5 overený; opening eventy + beat štruktúra; anti-repetition fallback → P2 |

5 z 5 PASS. Žiadny bod na prepracovanie v rámci P1 scope.

---

## P2 triage nálezy (mimo P1, nie blokéri)

| # | Nález | Špecialista | Súbor |
|---|-------|-------------|-------|
| P2-1 | Economy text vždy spomína „župan z Gemera" bez ohľadu na vybranú župu — logicky nekonzistentné, keď rng vyberie Gemer | rm-content | `NarrationManager.gd:146` |
| P2-2 | Anti-repetition (12 šablón) vyčerpá economy varianty po 12 ťahoch → fallback „tichu dvorov" v 908–914, keď nestrielia eventy | rm-core | `NarrationManager.gd:116` |

Tieto sa zapisujú ako triage karty pre P2, nie do prebiehajúcej P1 práce.

---

## Metóda overenia

Každý test je overený čítaním kódu, nielen headless smoke testami.
Headless test (`check_all.sh` 7/7 PASS) overuje logiku, ale vizuál neoveruje
— to bola chyba P0 gate. Preto som pre každý player-facing prvok sledoval
cestu od dát po UI uzol:

1. **NarrationManager** → `generate_chronicle()` vracia text → `TickManager.process_tick():106` ho vloží do `report["chronicle"]` → `Main.gd:_show_turn_report_via_node():1059` ho vloží do `TurnReport.show_report({"narration": chronicle_line})` → `TurnReport.gd:79` nastaví `_narration.text` → hráč číta.
2. **ObjectivesPanel** → `compute_beats()` vracia Dictionary → `refresh():102` nastaví `_phase_label.text`, `_goals_label.text`, `_next_label.text`, `_state_label.text` → hráč vidí panel nad mapou.
3. **Army wizard** → `Main.gd:_show_army_wizard()` vytvorí `PanelContainer` s `Label.text` a `Button.text` → runtime test `review_wizard_runtime.gd:49` overuje `count_named(main, "ArmyWizardOverlay") == 1` (reálny UI uzol).
4. **Threat markery** → `MapView.gd:_draw()` volá `draw_arc(center, max_r + 8.0, ..., C.MORAVIA_CRIMSON, 3.0)` pre loyalty < 30 a `draw_circle(center, marker_r, C.WARNING)` pre mood < 25 → kreslí sa na mape. `StatusBar.gd:102` nastaví `_food_warning.visible` pre food < 100.
5. **Devín 907 kánon** → `smoke_test.gd:117` overuje `outcome.get("winner") == "attacker"` a `gs.devine_resolved == true` po resolve. `smoke_test.gd:341` overuje auto-trigger 907 cez `process_wars`.

Limitácia: nemám GUI na overenie skutočného renderovania. Ale kódové cesty
sú sledované od dát po UI vlastnosť — fallback text, overlay uzol, draw
call. Žiadny z týchto prvkov nie je „logika bez UI".
