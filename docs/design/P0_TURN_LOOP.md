# P0 — Ťahová slučka: TurnReport, Coach, Threat clock, CTA/help strip

> Návrh, nie implementácia. Platí pre karty P0.1 (`t_bd5086f8`), P0.2 (`t_84bebe39`),
> P0.3 (`t_a81e3d07`), P0.6 (`t_6f7e8a11`). Nezväčšuje scope P0 — P0.4 (Devín kapitola)
> a P0.5 (briefing) sú hotové/light-touch, P0.7 (port eventov) a P0.8 (odmietnutý)
> sa tu nedotýkajú. Punch-list z `docs/UPRAVY_PO_P0_IMPLEMENTACII.md` (next_event,
> moodChanges, zupaLoyalty, ChoiceC, PROVINCE_DEVIN) je mimo tejto karty — ponechať
> pre samostatnú úlohu.
>
> **Invarianty (nemeniteľné, `docs/NAVRH_HERNY_ZAZITOK.md` §4.1 / §15.6):**
> Devín 907 = `winner == "attacker"` vždy, max 1× za run, dôsledky −30 prestíž /
> −20 lojalita Devína / +30 mood Maďarov, event RNG má vlastný seed key,
> `src/` (React) je archív dát, UI sa v ňom nemení.

---

## 0. AS-IS (čo už existuje v kóde, neduplikovať)

| Prvok | Stav v `godot/scenes/main/Main.gd` |
|---|---|
| TurnReport card | Existuje (`_show_turn_report`), auto-dismiss 4 s, Δ farebné, chronicle text |
| Coach overlay | Existuje (`_show_coach_overlay`), ale postupuje len cez interné tlačidlo „Ďalej“/„Rozumiem“ — **nie cez skutočné akcie hráča** (klik na Nitru, klik na Ďalší mesiac) |
| Threat clock | Existuje v `_update_story_line()` — text s odpočtom mesiacov, žiadna farebná eskalácia |
| ObjectivesPanel | Existuje (`ui/ObjectivesPanel.gd`), ale je v `SidePanel` (bočný panel), nie nad mapou ako vlastný riadok |
| CTA / help strip | ObjectivesPanel má „Teraz urob“, `story_line` má vlastný generický chvost „· ťah = Ďalší mesiac“ — **dve nezávislé miesta, riziko nesúladu** |

Táto špecifikácia opravuje presne tieto 4 medzery. Nepíšeme nový systém, upravujeme existujúci.

---

## 1. TurnReport — čo hráč vidí po každom ťahu

### 1.1 Poradie obsahu (nie výpis čísel — príbeh → dôkaz → dôsledok → akcia)

Karta `TurnReportCard` sa zobrazí po **každom** `process_next_month()`, aj bez eventu.
Poradie prvkov v karte (top-down):

1. **Hlavička**: „Ťah {rok}/{mesiac:02d}“ (existuje)
2. **Naračná veta (1–2 vety)** — `report.chronicle`, ak je prázdna, fallback:
   „Mesiac prešiel v tichu — župani vyberajú dane a hľadia na úrodu.“
   (nie generické „nič sa nestalo“ — vždy pomenúva, kto/čo koná)
3. **Δ zdrojov** — farebné chipy (existuje, `_Colors.SUCCESS` / `_Colors.WARNING`)
4. **Dôsledok mimo zlata** (nová, podmienená) — ak posledná voľba/event zmenila
   `loyalty`/`mood`/`religion`, jeden riadok menovite: „Devín: lojalita −5“ alebo
   „Bogatovci: nálada −10“. Zdroj: `choice_dict`/`effect` z `EventManager.resolve_choice`
   alebo z `HungarianWarScenario` výsledku, ak sa v danom ťahu spracoval.
   Bez takejto zmeny sa riadok nezobrazuje (nie „žiadny dôsledok“ text — ticho preskočiť).
5. **CTA riadok** — „Teraz urob: {ObjectivesPanel.get_cta()}“ — **rovnaký string**,
   ako help strip (§4). Nie preformulovaná kópia.

### 1.2 Trvanie a zatvorenie

- Auto-dismiss po **8 s** (nie 4 s — 4 s nestíha prečítať naráciu + Δ + CTA).
- Klik kdekoľvek na kartu ju zatvorí okamžite (existuje).
- Karta nesmie blokovať `next_month_btn` (nie modálna).

### 1.3 Akceptačné kritériá (rm-qa, bez dizajnéra)

- [ ] Po každom stlačení „Ďalší mesiac“ sa `TurnReportCard` pridá do stromu (aj keď
      `report.get("event", {})` je prázdny a žiadny event neprebehol).
- [ ] Karta obsahuje presne 5 možných blokov v poradí z §1.1; blok 4 (dôsledok)
      je podmienený — pri ťahu bez zmeny mood/loyalty/religion sa nevykresľuje.
- [ ] CTA text v karte sa reťazovo (`==`) rovná `objectives_panel.get_cta()`
      zavolanému bezprostredne pred vykreslením karty.
- [ ] `smoke_test.m6.gd` overuje: po zavolaní `GameManager.process_next_month()`
      existuje neprázdny `report["chronicle"]` ALEBO fallback vetu produkuje
      `Main._show_turn_report` (headless-friendly: test na úrovni reportu, nie scény).
- [ ] `Main.tscn` headless boot bez Parse Error (existujúca podmienka z `check_all.sh`).

---

## 2. Coach — 3 kroky, hráč ROBÍ, nečíta

### 2.1 Zásadná oprava voči AS-IS

Súčasný overlay je **plnoplošný modálny blok** s vlastnými tlačidlami „Ďalej“ —
hráč len číta a klika cez coach, nie cez hru. To je presne generický tutoriál,
ktorý si test #1 (prerozprávanie) a zadanie karty zakazujú.

**Fix:** `CoachOverlay` (dim ColorRect) musí mať `mouse_filter = MOUSE_FILTER_IGNORE`.
Krok postupuje len cez **skutočný herný signál**, nie cez tlačidlo v overlayi
(okrem kroku 2, kde je „pozri“ pasívny a jedno potvrdenie je prijateľné — pozri nižšie).
Šípka (jednoduchý `Label`/`TextureRect` so znakom „→“ alebo `icon_scroll`) sa
umiestni na `target.get_global_rect()` stred okraja pozorovaného prvku.

### 2.2 Presné kroky, texty a triggery

| Krok | Text (presne, žiadna zmena bez dizajnéra) | Cieľ šípky | Trigger na postup |
|---|---|---|---|
| 1/3 | „Klikni na Nitru — srdce tvojej ríše a sídlo rodu Mojmírovcov.“ | `MapView` marker „nitra“ | `map_view.province_selected` signál s `province_id == "nitra"` |
| 2/3 | „Toto je tvoje poslanie: udržať Nitru a dynastiu Mojmírovcov do roku 1000. Pozri si ho hore nad mapou.“ | `ObjectivesPanel` (po presune nad mapu, §3) | Jediné prijateľné tlačidlo v overlayi: „Rozumiem“ (pasívny krok — nemá reálnu hernú akciu, ktorá by „pozretie“ reprezentovala) |
| 3/3 | „Stlač „Ďalší mesiac“ dole — každý mesiac posunie tvoju vládu bližšie k roku 907, keď prídu Maďari.“ | `NextMonthButton` | `next_month_btn.pressed` signál (existujúci handler `_on_next_month` sa spustí normálne AJ ukončí tutoriál — nie oddelený click-through) |

- Krok 1 a krok 3 **musia** používať existujúce herné signály (žiadne nové coach-only
  tlačidlá). Krok 2 je jediná výnimka, pretože „pozrieť si panel“ nemá overiteľnú
  akciu — ale text je jedna veta, nie vysvetlenie pravidiel.
- Tlačidlo „Preskočiť“ ostáva viditeľné vo všetkých 3 krokoch, `mouse_filter = STOP`
  (jediný interaktívny prvok coach vrstvy okrem kroku 2 ack).
- Po kroku 3 (skutočný `next_month_btn.pressed`): `tutorial_done = true`,
  `tutorial_step = 3`, overlay zmizne, hra pokračuje bežným tokom `_on_next_month`
  (žiadna duplicitná logika mesiaca).

### 2.3 Perzistencia

- `GameState.tutorial_done` (existuje) — pri `true` sa `_show_coach_overlay()`
  v `_ready()` vôbec nezavolá (existujúca podmienka, zachovať).

### 2.4 Akceptačné kritériá (rm-qa)

- [ ] `CoachOverlay` dim node má `mouse_filter == Control.MOUSE_FILTER_IGNORE`
      (grep-ovateľné v `Main.gd`).
- [ ] Volanie `_on_province_selected("nitra")` pri `tutorial_step == 0` a
      `tutorial_done == false` zvýši `tutorial_step` na `1` (unit test v
      `godot/test/integration/` alebo priame overenie v `smoke_test.m6.gd`).
- [ ] Volanie `_on_next_month()` pri `tutorial_step == 2` nastaví
      `tutorial_done == true` po dobehnutí (nie pred).
- [ ] Nová hra (fresh `GameState`) s `tutorial_done == false` zobrazí overlay;
      `tutorial_done == true` (napr. po `from_dict` s týmto flagom) overlay
      nezobrazí — assert v smoke teste, žiadny visual diff potrebný.
- [ ] Texty krokov sa zhodujú presne s tabuľkou §2.2 (string compare).

---

## 3. Threat clock — ako sa hrozba ohlasuje

### 3.1 Layout — ObjectivesPanel nad mapu (explicitná požiadavka P0.3 §3)

`ObjectivesPanel` sa presúva z `UI/Body/SidePanel` do **nového samostatného riadku**
`UI/ObjectivesRow` medzi `UI/StatusBarRow` a `UI/Body`, na plnú šírku okna
(`size_flags_horizontal = SIZE_EXPAND_FILL`). `SidePanel` prestáva obsahovať
`ObjectivesPanel` (žiadna duplicita v strome scény).

### 3.2 Predvídateľnosť — odpočet, nie náhoda

Odpočet k 907 je viditeľný **od začiatku hry** (902), nie iba tesne pred krízou —
hráč nemá byť nikdy prekvapený. Text a farba sa menia podľa počtu mesiacov,
zdroj dát je existujúci výpočet v `_update_story_line()`:

| Mesiacov do 907 (`months_left`) | Farba | Text |
|---|---|---|
| > 36 | `TEXT_SECONDARY` | „Do Maďarov: {N} mesiacov“ |
| 13–36 | `WARNING` (`#C9902F`) | „Do Maďarov: {N} mesiacov“ |
| 1–12 | `MORAVIA_CRIMSON`, bold | „Do Maďarov: {N} mesiacov“ |
| Devín vyriešený, rok < 907 (skip-exploit prípad) | `BYZANTINE_GOLD` | „Devín už rozhodol — Maďari zvíťazili. Morava ide ďalej.“ |
| Po 907 (bežný priebeh) | `TEXT_SECONDARY`/`WARNING` podľa existujúcej threat-strip logiky | „Po Devíne · zostáva ~{roky} r. do 1000“ |

`months_left` sa počíta presne ako v `_update_story_line()`:
`(907 - year) * 12 + (7 - month)`. Hranice pásiem sú viazané na túto hodnotu,
nie na rok — kalendárny rozsah sa nesmie v kóde ani v UI aproximovať rokom.
Príklad prechodov (na overenie hranice v teste):

- `902/01` → 66 mes. (pásmo „> 36“)
- `904/06` → 37 mes. (posledný mesiac pásma „> 36“)
- `904/07` → 36 mes. (prvý mesiac pásma „13–36“, farba sa práve zmenila na `WARNING`)
- `906/06` → 13 mes. (posledný mesiac pásma „13–36“)
- `906/07` → 12 mes. (prvý mesiac pásma „1–12“, farba sa práve zmenila na `MORAVIA_CRIMSON`)

Existujúce modály pri 906/01 („Blíži sa invázia“) a 907/01 („Devín volá“) sa
nemenia — sú súčasťou tejto eskalácie, nie duplicitné.

### 3.3 Akceptačné kritériá (rm-qa)

- [ ] `ObjectivesPanel` je priamym potomkom `UI` (nie `SidePanel`) v `Main.tscn`,
      v riadku medzi `StatusBarRow` a `Body`.
- [ ] Panel je viditeľný ako samostatný riadok nad mapou pri **1280×720** aj
      **1920×1080** — `size_flags_horizontal` obsahuje `SIZE_EXPAND_FILL`
      (kontrolovateľné bez spustenia hry, statická kontrola `.tscn`).
- [ ] Farba threat-clock labelu sa mení presne na hraniciach 36/12 mesiacov —
      unit test volajúci `_update_story_line()` s mockovaným `year`/`month`
      a assert na `story_line.get_theme_color("font_color")` alebo ekvivalent.
- [ ] Po `devine_resolved == true` a `year < 907` text obsahuje „Devín už rozhodol“
      (existujúci case, len farba sa dopĺňa).

---

## 4. CTA + help strip — jedna veta, jeden zdroj pravdy

### 4.1 Princíp

Dnes existujú **dve** nezávislé miesta s odporúčaním ďalšieho kroku:
`ObjectivesPanel._next.text` („Teraz urob“) a `story_line` chvost („· ťah = Ďalší mesiac“).
Riziko: pri zmene jedného sa druhé rozíde a hráč dostane dva rôzne pokyny.

**Fix:** jediný zdroj pravdy. `ObjectivesPanel` dostáva verejnú metódu:

```gdscript
func get_cta() -> String:
    return _next.text
```

`Main.gd` dostáva nový node `HelpStrip` (Label, `BYZANTINE_GOLD` farba, umiestnený
v `UI/PrimaryRow` nad/vedľa `NextMonthButton`), ktorý po každom `_refresh_ui()`
nastaví:

```gdscript
help_strip.text = "Teraz urob: " + objectives_panel.get_cta()
```

`story_line` (§3) prestáva obsahovať generický CTA chvost „· ťah = Ďalší mesiac“ —
zostáva čisto threat clock + threat strip (§3), CTA žije výhradne v `HelpStrip`
a v TurnReporte (§1.1 bod 5), oba čítajú z rovnakej metódy.

### 4.2 Akceptačné kritériá (rm-qa)

- [ ] `ObjectivesPanel.get_cta()` existuje a vracia neprázdny string pre každú
      fázu hry (902, 907, 908–959, 960+) — test volá `refresh()` pre rôzne
      `year`/`month` a assertuje `get_cta() != ""`.
- [ ] Po `_refresh_ui()` platí `help_strip.text == "Teraz urob: " + objectives_panel.get_cta()`
      (reťazcová rovnosť, nie vizuálna kontrola).
- [ ] TurnReport CTA riadok (§1.1 bod 5) sa rovná tomu istému `get_cta()` výstupu
      v rámci toho istého ťahu.
- [ ] `story_line.text` neobsahuje substring „ťah = Ďalší mesiac“ (starý generický
      chvost je odstránený, nie duplicitný s HelpStrip).

---

## 5. Päť testov — ako táto špecifikácia prechádza

| Test | TurnReport | Coach | Threat clock | CTA/help strip |
|---|---|---|---|---|
| **1. Prerozprávanie** | Hráč po 10 min vie povedať „v 904 mi rada v Nitre zobrala 500 zlata za dary“ — narácia je menovitá, nie Δ tabuľka | „Klikol som na Nitru, videl som poslanie, stlačil Ďalší mesiac“ — reálna sekvencia akcií, nie prečítaný text | „Vedel som, že Maďari prídu, počítal som mesiace od 902“ | „Vždy som vedel, čo robiť ďalej — jedna veta, nie hádanie medzi dvoma panelmi“ |
| **2. Cena** | Blok 4 (§1.1) ukazuje menovitý dôsledok (lojalita/nálada), nie len plus-zlato | Krok 3 core-loop (Ďalší mesiac) je *skutočná* herná akcia s reálnymi následkami tiku, nie coach-simulácia | Odpočet nie je zadarmo — každý mesiac bez prípravy (armáda, diplomacia) je mesiac bližšie ku kríze | CTA niekedy hovorí „diplomacia, nie Ďalší mesiac“ (§ dip side-goal v `ObjectivesPanel`) — sync nezjednodušuje hru na jedno tlačidlo |
| **3. Predvídateľnosť** | Δ a dôsledok sa objavia hneď po ťahu, nie neskôr skryté v kronike | Coach nikdy nezablokuje hráča navždy — 3 kroky, skip vždy dostupný | Farebná eskalácia 36/12 mesiacov = hráč vidí krízu prichádzať zavčasu, žiadny „RNG bez varovania“ | Rovnaká veta na dvoch miestach = žiadny rozpor, ktorý by pôsobil ako nespravodlivosť |
| **4. Špecifickosť** | Fallback text menuje „úrodu“ a „župany“, nie univerzálne „nič sa nestalo“ | Texty menujú Nitru, Mojmírovcov, rok 907, Maďarov — nie generické „Vitaj v hre“ | Text menuje „Maďarov“, nie „nepriateľa“; menuje rok 907 explicitne | CTA text je vždy fázovo-špecifický (`ObjectivesPanel.refresh()` už generuje kontextové vety, len sa teraz nezduplikuje) |
| **5. Tempo** | Ťah 3 (`902/03`): fallback narácia, žiadny dôsledok blok. Ťah 8 (`902/08`): pravdepodobnejší event, threat clock už beží | Coach dobehne v ťahu 1 — ťah 3 aj 8 ho už nevidia (`tutorial_done`) | Ťah 3 (`902/03`, 64 mes. do 907): farba neutrálna (>36 mes.). Ťah 8 (`902/08`, 59 mes. do 907): farba stále neutrálna, ale odpočet je nižší a hráč to vidí — vizuálne odlišné tempo bez zmeny pásma | Ťah 3 CTA: „Klikni župu / stlač Ďalší mesiac“ (Fáza I intro). Ťah 8 CTA: môže byť diplomatický side-goal, ak nálada klesla — odlišný text, nie rovnaká veta dokola |

---

## 6. Zmeny súborov (očakávaný rozsah pre rm-godot)

| Súbor | Zmena |
|---|---|
| `godot/scenes/main/Main.gd` | Coach overlay mouse_filter fix + real-signal triggery; TurnReport poradie/8s/CTA riadok; `HelpStrip` node + refresh; `story_line` bez CTA chvosta |
| `godot/scenes/main/Main.tscn` | `ObjectivesPanel` presun z `SidePanel` do nového `UI/ObjectivesRow`; nový `HelpStrip` Label v `UI/PrimaryRow` |
| `godot/ui/ObjectivesPanel.gd` | `get_cta()` verejná metóda |
| `godot/tools/smoke_test.m6.gd` | Nové kontroly z §1.3/§2.4/§3.3/§4.2 (reťazcové/hodnotové assert, nie visual) |

Žiadna zmena `EventManager.gd`, `WarManager.gd`, `HungarianWarScenario.gd`,
`events_catalog.json` ani invariantov Devína — mimo scope tejto karty.

---

## 7. Mimo scope (nápady na neskôr, nezapisovať do P0)

- Skutočné rozšírenie „dôsledok mimo zlata“ na všetky eventy vyžaduje `moodChanges`
  fix z `docs/UPRAVY_PO_P0_IMPLEMENTACII.md` §1.2 — bez neho bude blok 4 v TurnReporte
  reálne viditeľný len pri eventoch, ktoré už `effect`/`zupaLoyalty` posielajú.
  Netreba blokovať P0.2 na tomto — blok 4 je podmienený a ticho sa nezobrazí, keď
  dáta chýbajú.
- Threat clock ako vizuálny marker priamo na mape (ikonka pri Devíne, ktorá sa
  zväčšuje) je P1 nápad (`M6_UI_ART_SCOPE.md` P3 map markers) — nepatrí do P0.3.
- Coach krok 2 („pozri poslanie“) ako naozaj overiteľná akcia (napr. vyžadovať scroll
  alebo hover) je zbytočná komplikácia pre P0 — jedno potvrdenie je dosť.
