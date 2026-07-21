# Godot 4 – Architecture Proposal v1.3 (Opravená finálna verzia)

**Projekt:** Regnum Moravicum  
**Dátum:** 21. 7. 2026  
**Stav:** Finálny návrh po kritickej analýze (v1.2 → v1.3)

---

## 1. Timeline – explicitné rozhodnutie

- **MVP horizont:** 902 – 1000 (1200 tickov)
- **Plný kánon** (902–1300 + nástupnícka kríza 1152–1158) sa ponecháva ako cieľ pre neskoršie fázy projektu.
- **Možný štart 894** zostáva otvorenou otázkou (pozri sekciu 11e).

---

## 2. Štruktúra priečinkov (aktualizovaná)

```
regnum_moravicum/
├── assets/
│   ├── maps/
│   ├── units/
│   ├── ui/
│   └── effects/
├── data/
│   ├── factions/
│   ├── units/
│   ├── terrains/
│   ├── events/
│   ├── provinces/
│   ├── narration/
│   └── initial_state/
├── scenarios/
│   └── hungarian_war/
├── scenes/
│   ├── main/
│   ├── map/
│   ├── battle/
│   ├── ui/
│   └── managers/
├── scripts/
│   ├── core/
│   ├── systems/
│   ├── utils/
│   └── resources/
├── autoloads/
└── project.godot
```

---

## 3. Hlavné manažéry (finálny zoznam)

| Manažér              | Zodpovednosť                              | Priorita |
|----------------------|-------------------------------------------|----------|
| `GameManager`        | Hlavný stav hry (RefCounted)              | P0       |
| `TickManager`        | Riadenie ticku a fáz (RefCounted)         | P0       |
| `NarrationManager`   | Generovanie kroniky + anti-repetition     | P0       |
| `NobilityManager`    | Správa šľachty, dedenie, smrť             | P0       |
| `EconomyManager`     | Zdroje, upkeep, ekonomická simulácia      | P0       |
| `SaveManager`        | Serializácia, seeded RNG, verziovanie     | P0       |
| `MapManager`         | Mapa a župy                               | P0       |
| `BattleManager`      | Fázový boj + auto-resolve                 | P0       |
| `WarManager`         | Vojenské kampane                          | P0       |
| `DiplomacyManager`   | Diplomatické akcie + AI drift             | P0       |
| `EventManager`       | Generovanie a riešenie udalostí           | P0       |
| `SuccessionManager`  | Nástupníctvo dynastie                     | P0       |
| `ReligionManager`    | Náboženská os                             | P0       |
| `VictoryManager`     | Podmienky výhry/prehry                    | P0       |

**Poznámka k autoloadom (§3 vs §9):**  
Len `GameManager` a `TickManager` sú tenké Node wrappery (Autoload). Všetky ostatné manažéry sú čisté `RefCounted` inštancie vlastnené GameManagerom.

---

## 3a. Implementačné vlny (M1–M4)

| Vlna | Obsah | Cieľ |
|------|-------|------|
| **M1 – Jadro** | GameManager, TickManager, SaveManager (seeded RNG), MapManager (statická mapa) | Základný tick + ukladanie |
| **M2 – Simulácia + narácia** | EconomyManager, NobilityManager, EventManager, **NarrationManager** | Ekonomika + kronika |
| **M3 – Konflikt** | BattleManager (port Phase 2 spec), WarManager, DiplomacyManager | Boj a diplomacia |
| **M4 – Meta** | SuccessionManager, ReligionManager, VictoryManager, Hungarian War | Víťazstvo a dynastia |

**Kľúčové:** NarrationManager patrí už do **M2** — narácia je USP a nesmie čakať na koniec vývoja.

---

## 4. Tick systém – opravený

### 4.1 Atomický časový pokrok

```gdscript
func advance_time():
    month += 1
    if month > 12:
        month = 1
        year += 1
```

### 4.2 Finálne poradie fáz

```gdscript
func process_tick():
    advance_time()

    age_nobles()
    decay_moods()
    decay_religion_axis()
    grow_prosperity()
    grow_prestige()
    add_recruitment_pool()
    pay_upkeep()
    check_rebellions()
    process_succession()
    process_diplomacy()
    process_wars()
    process_events()
    generate_chronicle()
    check_victory_conditions()
    generate_chronicle_endgame()   # ← nové
```

---

## 5. NarrationManager – TickReport pattern

**Vstup:**  
NarrationManager nikdy nesiahne priamo do stavu iných manažérov. Všetky fakty ticku dostáva cez štruktúrovaný `TickReport` (event bus).

**Výstup:**  
- Kronika
- Anti-repetition logika (priorita, cooldown, variabilita)
- Šablóny rozdelené podľa kategórií (battle, diplomacy, event, succession)

**Prenos existujúcich šablón:**  
126+ šablón z Phase 2 špecifikácie sa prenáša, nie tvorí od nuly.

**Build-time validácia:**  
Šablóny sa validujú voči anachronizmus blacklistu z World Bible.

---

## 6. NobilityManager

- Správa šľachty, dedenie a smrť
- Väzba na **prestíž** (smrť populárneho šľachtica znižuje prestíž)
- Väzba na **diplomáciu** (zmena vzťahov po smrti vládcu)

---

## 7. SaveManager

- Deterministický RNG (`RandomNumberGenerator`) s ukladaním `seed` + `state`
- Zodpovedný za **verziovanie save formátu** a automatické migrácie
- Autosave na konci roka (každých 12 tickov)
- Ukladanie do `user://` sandboxu (iOS)

---

## 8. BattleManager

Vychádza priamo z existujúceho **trojfázového špecifikácie** Phase 2 (melee → ranged → flank, counter-matica, morale/rout, Hungarian War scenár).

---

## 9. Oddelenie logiky od zobrazenia

- Všetky herné systémy = **čisté `RefCounted` triedy**
- Žiadne Node závislosti v logike
- Toto pravidlo je **vynútené** a umožňuje headless simulátor na balancing

---

## 10. Testing stratégia

- Oficiálne: **gdUnit4**
- Prenos existujúcich M1–M4 testov z Vitestu
- **Golden-master test determinizmu:** rovnaký seed → identická kronika po N tickoch (chráni RNG, tick poradie aj šablónový engine)
- Testy bežia headless (`godot --headless`)

---

## 11. iOS špecifiká

- Touch-first UI (veľkosti hotspotov, žiadne hover stavy)
- Safe areas
- Optimalizácia výkonu na starších zariadeniach

---

## 11a. Rozhodnutie o React/TS vetve (P0)

- React/TS prototyp sa **archivuje** dňom schválenia tohto dokumentu.
- Nové featury sa do React vetvy nepridávajú.
- **Phase 2 battle spec** = zdroj pravdy pre mechaniky.
- **HTML mockup** = UI/UX referencia.
- Ani jedno nie je kódová základňa pre Godot 4.

---

## 11b. Data pipeline Notion → JSON

- Zdroj pravdy pre dizajnové dáta = **Notion databázy** (frakcie, župy, postavy, udalosti).
- Export skript Notion API → JSON v `data/`.
- JSON sa **needituje ručne**.
- **Podmienka:** dokončiť dva otvorené TODO kánonu (konverzia Relations, rescale atribútov 0–100) pred prvým exportom.

---

## 11c. Migrácia vizuálneho systému

- 28-ikonový kanonický SVG sprite → definovať exportné rozlíšenia (@1x/@2x/@3x pre iOS).
- Fonty: Cormorant Garamond + Alegreya (+ Alegreya Sans) → import + test slovenskej diakritiky.
- „Age of History 2 vibe“ sa musí zosúladiť s **Vizuálnou bibliou** — nesmie vzniknúť tretí paralelný štýl.

---

## 11d. Autoloady vs RefCounted (vyriešený rozpor)

- Autoloady = len tenké Node wrappery: **GameManager** a **TickManager**.
- Všetky ostatné manažéry = čisté `RefCounted` inštancie vlastnené GameManagerom.

---

## 11e. Otvorené rozhodnutia pred implementáciou

1. **Štart kampane:** 894 vs. 902
2. **Dokončenie Notion TODO** (Relations konverzia, rescale atribútov 0–100) pred data exportom
3. **Formálna archivácia React vetvy** v Notione

---

## 12. Záver

Architektúra v1.3 je **pripravená na štart implementácie vlny M1**.

---

*Document prepared as final deliverable after multi-agent + critical review process.*