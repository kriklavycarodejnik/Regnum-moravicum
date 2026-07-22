# Regnum Moravicum — Generovanie grafiky + implementácia (plán)

> **For Hermes:** Use subagent-driven-development / batch implement after user approves.  
> Plan only — neimplementovať, kým user nepovie „spusti“.

**Goal:** Z kanonu `docs/ART_PROMPT_CANON.md` dostať schválené master assety a zapojiť ich do Godot 4 UI/mapy/eventov tak, aby hra prestala vyzerať ako placeholder a držala jednotný Veľkomoravský vizuál (902–1000).

**Architecture:** Tri vrstvy (A narrative / B game world / C UI). Najprv zamknúť **Visual Style Master + hex Theme**, potom master assety (portréty, lokality, emblém), potom Godot theme/fonts/ikony, potom map + battle chrome, nakoniec event/chronicle plates. AI generovanie ide cez prompt kanon → ručný approve → import do `godot/assets/`.

**Tech Stack:** Godot 4.3 (primár), GDScript, Theme resources, DynamicFont (Cormorant Garamond + Alegreya), PNG/WebP + SVG ikony; AI: Flux Pro (BG) + multi-turn image edit (portréty); kanon: `docs/ART_PROMPT_CANON.md`, `docs/VISUAL_DIRECTION.md`. Web/React (`src/styles/global.css`) len **parity tokens** v neskorej fáze — MVP cieľ je Godot.

**Repo root:** `/Users/home/projects/regnum-moravicum-official/`

---

## Kritická analýza a doplnenie plánu (2026-07-22, po overení repozitára)

> Overené priamo v repu (nie len z popisu plánu): `godot/` je oveľa ďalej než tabuľka „Čo už je“ naznačuje (M1–M5 manažéri, 12 province JSON, gdUnit test suity battle/integration/m4/m5/scenarios), `src/styles/global.css` už má takmer identickú hex paletu ako kánon, a existuje reálny konflikt medzi `docs/VERIFICATION.md` a kánonom Devín 907. Nálezy nižšie menia poradie/obsah niektorých taskov.

### P0 — blokuje alebo protirečí kánonu

| # | Nález | Dopad | Akcia |
|---|-------|-------|-------|
| P0-1 | `docs/VERIFICATION.md` §8.1 popisoval očakávaný výsledok testu ako „Morava vyhráva Devín 907“ — priamy rozpor s kánonom (Notion, `ART_PROMPT_CANON.md`), s `FEEDBACK_INTEGRATION.md` (ktorý sám cituje historický fakt maďarského víťazstva) aj s existujúcim testom `test/integration/test_devine_907.gd` (assertuje `winner == "attacker"`, t.j. Maďari). Keby budúci agent implementoval `test_historical_accuracy.gd` doslova podľa pôvodného znenia, zakódoval by opačný historický výsledok. | Vysoké — priamo sa dotýka Task 6/11 (battle art nesmie byť moravský triumf) | **Opravené priamo teraz** — `VERIFICATION.md` §8.1 prepísané na „Maďari vyhrávajú Devín 907“. |
| P0-2 | `godot/data/provinces/devin.json` má `"religion": "pagan"` (string), zatiaľ čo všetkých ostatných 11 provincií má `religion` ako číslo 0–100 (napr. `bratislava.json: 50`). Typová nekonzistencia pravdepodobne rozbije `ReligionManager` aritmetiku (decay/priemer) hneď ako sa Devín zapojí do simulácie. | Blokuje Task 10 (Map scéna číta province dáta) | **Nová úloha Task 0b nižšie** — treba rozhodnúť číselnú hodnotu (návrh: 50, konzistentné s Bratislavou) a opraviť. |
| P0-3 | Susedský graf nie je symetrický: `devin.json.neighbors = [bratislava, nitra]`, ale `bratislava.json.neighbors` aj `nitra.json.neighbors` Devín neobsahujú. `docs/godot/CANON_PROVINCES.md` pritom tvrdí „overená symetria“ ako zdroj pravdy pre `WarManager`/mapu v M3. | Blokuje Task 10 (settlement markery, mapové prepojenia) | **Task 0b** — doplniť `devin` do `neighbors` v `bratislava.json` a `nitra.json`. |
| P0-4 | `godot/scripts/ui/ArmyUI.gd` + `.tscn` je mŕtvy, rozbitý duplikát skutočného `godot/ui/ArmyUI.gd`/`.tscn` (referencuje neexistujúci `res://scripts/GameManager.gd`, EN labely, TODO namiesto move/battle/siege logiky — reálny `GameManager` autoload je v `res://autoloads/GameManager.gd`). Presne ten typ „paralelných konkurenčných systémov“, ktorý sa v projekte opakovane vracia. | Riziko, že Task 8 (Restyle ArmyUI) omylom upraví/generuje z nesprávnej kópie | **Task 0b** — zmazať/archivovať `godot/scripts/ui/ArmyUI.gd` + `.tscn` pred Task 8. |

### P1 — plán by spôsobil rework, ak sa nedoplní

| # | Nález | Doplnenie |
|---|-------|-----------|
| P1-1 | `ArmyUI.tscn` (ani jedna z kópií) nie je nikde inštancovaná — `Main.tscn` na ňu neodkazuje vôbec. Task 8 „Restyle ArmyUI“ by tak upravoval scénu neviditeľnú v reálnej hre. | Task 9 musí explicitne inštancovať `godot/ui/ArmyUI.tscn` do nového `SidePanel` — doplnené do Task 9 nižšie. |
| P1-2 | `Main.tscn`/`Main.gd` má dnes plocho zapojené funkčné háky priamo v jednom Control node: `NextMonthButton`, `SkirmishButton`, `DevineButton`, `EventPanel` + `ChoiceA/ChoiceB`, `Chronicle` — všetko cez `@onready $UI/...` cesty. `smoke_test.gd` je headless a netestuje scénový strom, takže rozbitie týchto väzieb pri Task 9 prestavbe chytí len ručný test. | Task 9 doplnený o explicitnú požiadavku zachovať/premigrovať všetky existujúce node cesty a signálové väzby, + manuálny click-test checklist. |
| P1-3 | `godot/docs/CANON_PROVINCES.md` (21.7.) uvádza tabuľku 11 provincií bez Devína — o deň neskôr (`FEEDBACK_INTEGRATION.md` fix #4) pribudla samostatná `devin.json`, takže dokument je voči dátam zastaraný (12 provincií, nie 11). | Task 0b doplniť riadok `devin` do `CANON_PROVINCES.md`. |
| P1-4 | Task 14 (Web parity) navrhuje „ak ešte žije React shell“ ako voliteľné neskoršie zosúladenie fontov — ale `godot/docs/GODOT4_ARCHITECTURE_PROPOSAL.md` §11a už explicitne rozhodol: „React/TS prototyp sa archivuje... Nové featury sa do React vetvy nepridávajú.“ Navyše overené: `src/styles/global.css` už má identickú hex paletu ako kánon (moravia-crimson, byzantine-gold, parchment, oak-dark/mid — všetko sedí), takže jediné čo by ostalo je práca na archivovanej vetve. | Task 14 nižšie preznačený na **ARCHIVED — nerobiť**, nie „optional/YAGNI“. |

### P2 — drobné/dokumentačné

| # | Nález |
|---|-------|
| P2-1 | Tabuľka „Čo už je“ podhodnocuje stav Godot vetvy — v skutočnosti existujú M1–M5 manažéri (`Economy/Nobility/Narration/Event/Diplomacy/War/Battle/Succession/Religion/Victory/Army/Campaign Manager`), 12 province JSON a gdUnit test suity (`test/battle`, `test/integration`, `test/m4`, `test/m5`, `test/scenarios`). Grafika sa teda zapája do živej, testovanej simulácie, nie do prázdneho stubu — nič to nemení na taskoch, len na očakávaniach toho, kto plán preberie. |
| P2-2 | V repu neexistuje žiadny súbor 28-icon SVG sprite spomínaný v Notion pamäti — existuje zatiaľ len ako koncept/špecifikácia, nie ako dodané assety. Task 7 (AI generovanie 12→28 ikon) teda nič neduplikuje, len treba vedieť, že sa začína od nuly, nie migráciou existujúceho súboru. |

---

## Kontext / predpoklady

### Čo už je

| Vec | Stav |
|-----|------|
| Art kanon | `docs/ART_PROMPT_CANON.md` (Block A/B/C, hex, ready prompts §9) |
| Visual direction | `docs/VISUAL_DIRECTION.md` |
| Web CSS tokens | `src/styles/global.css` — hex už blízko kanonu; fonty ešte Georgia/system |
| Godot | `godot/` — Main + ArmyUI placeholder, **žiadne herné art assety** (iba `icon.svg` + gdUnit). Pozor: logika je ďalej než art vrstva — M1–M5 manažéri (Economy/Nobility/Narration/Event/Diplomacy/War/Battle/Succession/Religion/Victory/Army/Campaign), 12 province JSON, gdUnit testy (battle/integration/m4/m5/scenarios) už existujú a bežia (viď P2-1). |
| Legacy image gen | `~/projects/regnum-moravicum/image_gen.py` (FAL Flux) — voliteľný tool, nie zdroj pravdy |
| Sim/M5 | tick, battle, army… — grafika na to nadväzuje, nemenit hernú logiku |

### Predpoklady

1. Primárna platforma vizuálu MVP = **Godot 4**, nie React.
2. AI output nikdy nejde rovno do `main` bez **Approved** (ľudský OK alebo explicitný agent checkpoint).
3. Kánon Devín 907: vizuál **maďarský tlak / kríza**, nie moravské víťazstvo.
4. Prompty EN, UI texty SK.
5. User preferuje **celý batch** pri kóde; pri art approve môže byť gate po Style Master + po každej priorite masterov.

### Mimo scope (YAGNI teraz)

- Spine/3D, plný sprite sheet animácií jednotiek (fáza B neskôr)
- 24+ variant pozadí pred schválením Style Master
- Notion sync
- App Store polish / i18n mimo SK

---

## Cieľové adresáre (vytvoriť)

```
godot/
  assets/
    fonts/                  # .ttf/.otf Cormorant + Alegreya (+ license txt)
    theme/
      regnum_theme.tres
      colors.gd             # const Color hex z kanonu
    icons/
      ui/                   # 28-icon set (64/128 + 256 master mimo repo optional)
      factions/             # erby / štíty
    portraits/              # mojmir_ii, theodora, arpad…
    locations/              # nitra, devin, bratislava, court…
    events/                 # battle_danube, chronicle plates…
    map/                    # terrain blobs, settlement markers (B)
    battle/                 # silhouettes, banners (B)
  ui/
    theme/                  # ak treba scény panelov
    components/             # ResourceBar, PanelOak, …
  scenes/
    main/
    map/
    battle/
    chronicle/
docs/
  ART_PROMPT_CANON.md       # už je
  VISUAL_DIRECTION.md       # už je
  ASSET_MANIFEST.md         # NOVÉ — ID, path, status, seed, prompt ref
tools/
  art/                      # optional: gen scripts, import checklist
    ASSET_CHECKLIST.md
    prompts/                # kópia ready prompts ak treba CLI
```

---

## Fázy (prehlad)

| Fáza | Názov | Výstup | Odhad |
|------|--------|--------|--------|
| **G0** | Infra + tokens | priečinky, `colors.gd`, Theme stub, manifest | 0.5 d |
| **G1** | Style lock | Visual Style Master Approved + seed/ref | 0.5–1 d (AI+review) |
| **G2** | Master assety A | 3 portréty, 4 lokality, emblém, battle cover | 1–2 d |
| **G3** | UI C v Godote | fonty, theme, ArmyUI restyle, resource chips, 12–28 ikon | 1–2 d |
| **G4** | Map + Battle B | čitateľná mapa scéna, battle backdrop + siluety | 1–2 d |
| **G5** | Narrative wire-up | event/chronicle zobrazí Approved plates | 0.5–1 d |
| **G6** | Polish + DoD | contrast, import settings, README art pipeline | 0.5 d |

**Celkom MVP vizuál:** ~5–8 pracovných dní podľa rýchlosti AI approve.

---

## Definition of Done (vizuálny milestone)

- [ ] `godot/assets/theme/regnum_theme.tres` používa kanon hex + Cormorant/Alegreya  
- [ ] Visual Style Master + kľúčové masters v `ASSET_MANIFEST.md` = **Approved**  
- [ ] Main / ArmyUI nie je default grey Control — oak/parchment/gold/crimson  
- [ ] Aspoň 12 UI ikon v jednom line weight  
- [ ] Map scéna: biome farby z tokenov, settlement markery, faction tint  
- [ ] Battle scéna: dusk sky gradient + 2 strany siluet + emblem  
- [ ] 1 event plate (Devín/Dunaj) zapojená do UI bez porušenia kánonu výsledku  
- [ ] Žiadny production asset mimo Block A/B/C pravidiel  
- [ ] Smoke/UI nespada; gdUnit existujúce testy logiky netreba meniť kvôli artu  

---

## Step-by-step úlohy

### Task 0: Asset manifest + priečinky

**Objective:** Jedno miesto pravdy pre status assetov.

**Files:**
- Create: `docs/ASSET_MANIFEST.md`
- Create: `godot/assets/{fonts,theme,icons/ui,icons/factions,portraits,locations,events,map,battle}/.gitkeep`
- Create: `tools/art/ASSET_CHECKLIST.md`

**Manifest stĺpce (minimálne):**

```markdown
| id | layer | type | path | status | source_prompt | seed | notes |
|----|-------|------|------|--------|---------------|------|-------|
| regnum_visual_style_master | A | style_master | godot/assets/events/regnum_visual_style_master_v1.webp | Planned | ART_PROMPT_CANON §9.1 | | |
| mojmir_ii_master_portrait | A | portrait | godot/assets/portraits/mojmir_ii_master_portrait_v1.webp | Planned | §9.6 | | |
...
```

**Statuses:** `Planned → Generating → Review → Approved → Implemented`

**Verify:** `find godot/assets -type d | sort` ukáže strom.

**Commit:** `chore(art): asset dirs + manifest scaffold`

---

### Task 0b: Data integrity + dedup fixes (NOVÉ — z kritickej analýzy, blokuje Task 8/10)

**Objective:** Odstrániť zistené P0 nezrovnalosti pred tým, ako sa na dáta/scény naviaže grafika.

**Files:**
- Modify: `godot/data/provinces/devin.json` — `religion: "pagan"` → numerická hodnota (návrh: `50`, konzistentné s Bratislavou; potvrdiť s userom ak má iný zámer)
- Modify: `godot/data/provinces/bratislava.json` — doplniť `"devin"` do `neighbors`
- Modify: `godot/data/provinces/nitra.json` — doplniť `"devin"` do `neighbors`
- Modify: `godot/docs/CANON_PROVINCES.md` — doplniť riadok `devin` (12 provincií, nie 11)
- Delete/Archive: `godot/scripts/ui/ArmyUI.gd`, `godot/scripts/ui/ArmyUI.tscn` (mŕtvy duplikát — reálna verzia je `godot/ui/ArmyUI.*`)

**Verify:**
- Pre každú `data/provinces/*.json`: `religion` je vždy číslo 0–100
- Susedský graf je symetrický (A má B v neighbors ⇔ B má A) — skript alebo ručná kontrola
- `godot/scripts/ui/` neobsahuje žiadny `ArmyUI.*` po zmazaní
- gdUnit `test/m4`, `test/m5`, `test/integration/test_devine_907.gd` stále prechádzajú

**Commit:** `fix(data): devin province symmetry + religion type + dedupe ArmyUI`

---

### Task 1: Godot color tokens

**Objective:** Hex z kanonu ako GDScript constants (žiadne magic numbers v UI).

**Files:**
- Create: `godot/assets/theme/colors.gd`

**Implementácia (cieľový tvar):**

```gdscript
# godot/assets/theme/colors.gd
class_name RegnumColors
extends Object

const MORAVIA_CRIMSON := Color("8B1E2D")
const BYZANTINE_GOLD := Color("C9A227")
const PARCHMENT := Color("E8DCC4")
const OAK_DARK := Color("2A1F14")
const OAK_MID := Color("3D2E1F")
const FOREST_CANOPY := Color("2F4A28")
const MEADOW := Color("5A7A3A")
const DANUBE := Color("3A6B7A")
const STONE_WALL := Color("6B6560")
const MAGYAR_STEPPE := Color("A67C52")
const IRON_GREY := Color("4A4E52")
const SKY_DUSK_TOP := Color("4A3A4A")
const SKY_DUSK_BOT := Color("2A2030")
const ROYAL_BLUE := Color("2C3E6B")
const BYZANTINE_CRIMSON := Color("9B1B30")
const IVORY := Color("F2E8D5")
const BG_DARKER := Color("0A0806")
const TEXT_MUTED := Color("7A6B55")
```

**Verify:** Godot načíta script bez parse error; farby match `ART_PROMPT_CANON.md` §1.

**Commit:** `feat(art): RegnumColors token constants`

---

### Task 2: Fonty do repo

**Objective:** Cormorant Garamond + Alegreya legálne v projekte.

**Files:**
- Create: `godot/assets/fonts/CormorantGaramond-*.ttf` (Regular, SemiBold, Bold)
- Create: `godot/assets/fonts/Alegreya-*.ttf` (Regular, Medium, Bold)
- Create: `godot/assets/fonts/OFL.txt` (alebo SIL license)

**Steps:**
1. Stiahnuť z Google Fonts / oficiálny OFL zip.
2. Len potrebné rezy (necommitnúť celý family dump).
3. Godot Import: DynamicFont, antialiasing on.

**Verify:** v editore font preview SK znakov (ľ, š, č, ť, ž, ô, ä).

**Commit:** `chore(art): add Cormorant Garamond + Alegreya OFL fonts`

---

### Task 3: `regnum_theme.tres` (vrstva C base)

**Objective:** Default Theme pre Button, Panel, Label, ProgressBar.

**Files:**
- Create: `godot/assets/theme/regnum_theme.tres` (editorom alebo `.gd` builder script)
- Optional Create: `godot/assets/theme/build_theme.gd` (ak tres ručne bolí)

**Štýl (z Block C):**
- Panel: `OAK_DARK` bg, gold hairline border (`BYZANTINE_GOLD` ~22% alpha)
- Button normal: `OAK_MID`; hover: lighter; pressed: `MORAVIA_CRIMSON`
- Button font: Alegreya 16; Title labels: Cormorant 28–36
- Text: `PARCHMENT`; secondary: muted
- Corner radius 12–16 px (StyleBoxFlat)
- Min touch ~44 px height na primary buttons

**Wire:**
- Modify: `godot/scenes/main/Main.tscn` — root `theme = regnum_theme`
- Modify: `godot/ui/ArmyUI.tscn` — inherit theme

**Verify:** spusti Main — UI nie je default grey.

**Commit:** `feat(ui): regnum Theme oak/parchment/gold`

---

### Task 4: Generovanie Visual Style Master (G1 gate)

**Objective:** Jeden schválený style sheet = ref pre všetko ostatné.

**Files:**
- Output: `godot/assets/events/regnum_visual_style_master_v1.webp` (alebo `.png`)
- Update: `docs/ASSET_MANIFEST.md` → Approved
- Keep raws (optional): `tools/art/raw/style_master/` (gitignore large if needed)

**Prompt:** `ART_PROMPT_CANON.md` §9.1  
**Model:** Flux Pro (primary_background)  
**Process:**
1. 3–6 kandidátov  
2. User vyberie 1  
3. Zapísať seed + provider + dátum do manifestu  
4. Status **Approved** — bez tohto **nebatchovať** portréty/lokality

**Verify:** vizuálne sedí Block A (linework, desaturácia, hex feel, nie anime/oil-photo).

**Commit:** `art: approve visual style master v1`

---

### Task 5: Master portréty (Mojmír II, Theodora, Árpád)

**Objective:** Identity lock pre characters UI / events.

**Files:**
- `godot/assets/portraits/mojmir_ii_master_portrait_v1.webp`
- `godot/assets/portraits/theodora_master_portrait_v1.webp`
- `godot/assets/portraits/arpad_master_portrait_v1.webp`
- Update manifest

**Prompts:** §9.6, §9.7, §9.8  
**Model:** Flux draft → identity multi-turn edit na finálne  
**Ref:** Style Master ako style reference  

**Pravidlá:**
- aspect 3:4  
- plain dark parchment BG  
- Árpád vizuálne oddelený (steppe block, žiadny royal blue dominance)  
- žiadne full plate / anime  

**Approve gate:** každý portrait zvlášť v manifeste.

**Commit:** `art: master portraits v1 mojmir theodora arpad`

---

### Task 6: Master lokality + dvor + emblém + battle

**Objective:** Hero views pre map click / chronicle / loading.

**Files:**
- `godot/assets/locations/nitra_master_hero_v1.webp`
- `godot/assets/locations/devin_master_fortress_v1.webp`
- `godot/assets/locations/bratislava_master_river_v1.webp`
- `godot/assets/locations/moravian_court_interior_v1.webp`
- `godot/assets/icons/factions/mojmir_dynasty_emblem_v1.png`
- `godot/assets/events/battle_danube_composition_v1.webp`

**Prompts:** §9.3–9.5, §9.9, §9.11  
**Aspect:** 16:9 lokality/event; 1:1 emblem  

**Kánon check battle:** nie víťazný moravský poster; Greek fire + steppe pressure.

**Commit:** `art: location heroes emblem battle master v1`

---

### Task 7: UI icon set (minimálne 12, cieľ 28)

**Objective:** Resource + akcie + symboly v jednom line weight.

**Minimum 12 (MVP):**
`gold, food, wood, stone, iron, prestige, eagle, cross_patriarchal, sword, shield, scroll, horse`

**Files:**
- `godot/assets/icons/ui/{name}_64.png` (+ optional `_256.png` masters mimo alebo v `tools/art/raw/icons/`)
- Optional atlas: `godot/assets/icons/ui/ui_icons_atlas.png` + `.tres`

**Prompt base:** Block C icon sub-block + §9.10  
**Export:** 256 master → downscale 64/128; padding 10–12%; transparent BG  
**Cleanup:** ručne zjednotiť stroke v Figma/Inkscape ak AI rozbije line weight  

**Commit:** `art: ui icon set v1 (12+)`

---

### Task 8: Restyle ArmyUI + shared components

**Objective:** Prvý herný panel podľa theme.

**Predpoklad:** Task 0b hotový (duplikát `scripts/ui/ArmyUI.*` zmazaný) — inak hrozí úprava nesprávnej kópie.

**Files:**
- Modify: `godot/ui/ArmyUI.gd`, `godot/ui/ArmyUI.tscn` (jediná platná verzia, wired na `/root/GameManager`)
- Create: `godot/ui/components/ResourceChip.tscn` + `.gd`
- Create: `godot/ui/components/OakPanel.tscn` (optional wrapper)

**Pozor:** táto scéna dnes nie je nikde inštancovaná (žiadny odkaz v `Main.tscn`) — reštyling sa v hre neprejaví, kým ju Task 9 nezapojí do `SidePanel`.

**Steps:**
1. Nahradiť raw Button list za theme-styled items  
2. Ikony pri resource/action ak dostupné  
3. SK labely, min height 44  
4. Emblem / faction color strip ak army má faction_id  

**Verify:** manuálne v editore — ArmyUI čitateľné, kontrast OK (parchment na oak).

**Commit:** `feat(ui): ArmyUI regnum theme + resource chips`

---

### Task 9: Main shell layout

**Objective:** Herný chrome: top status (rok, resources), center stage, bottom/side tabs.

**Files:**
- Modify: `godot/scenes/main/Main.tscn`, `Main.gd`
- Create: `godot/ui/StatusBar.tscn` + `.gd`
- Create: `godot/ui/MainChrome.tscn` (optional)

**Layout (1280×720 base, stretch expand):**
```
┌─────────────────────────────────────────┐
│ StatusBar: rok | resources icons | prestíž │
├──────────────────────────┬──────────────┤
│                          │ SidePanel    │
│   Stage (Map/Battle/     │ (Army/Dipl/  │
│    Event portrait)       │  Event)      │
│                          │              │
├──────────────────────────┴──────────────┤
│ TabBar: Mapa | Armáda | Kronika | …     │
└─────────────────────────────────────────┘
```

**Data:** čítať z `GameManager` / game_state (year, resources) — **nemeniť** tick logiku.

**Povinné pri prestavbe (z kritickej analýzy):**
- Inštancovať `godot/ui/ArmyUI.tscn` do `SidePanel` (dnes nie je nikde zapojená — bez tohto je Task 8 neviditeľný)
- Zachovať/premigrovať všetky existujúce funkčné háky z pôvodného plochého `Main.tscn`: `NextMonthButton`, `SkirmishButton`, `DevineButton`, `EventPanel` (+ `ChoiceA`/`ChoiceB`), `Chronicle` — a ich signálové väzby v `Main.gd`. `smoke_test.gd` je headless a toto nepokryje, takže rozbité prepojenie chytí len ručný test.
- Manuálny checklist po prestavbe: Ďalší mesiac funguje, Skirmish funguje, Devín tlačidlo funguje, Event modal + obe voľby fungujú, kronika sa dopĺňa.

**Verify:** spustenie Main ukáže SK chrome + reálne čísla ak state beží + vyššie uvedený checklist.

**Commit:** `feat(ui): main chrome status bar + tabs`

---

### Task 10: Map scéna (vrstva B — fáza A)

**Objective:** Čitateľná strategická mapa s token farbami (SVG/node-based, nie photoreal).

**Files:**
- Create: `godot/scenes/map/MapView.tscn` + `MapView.gd`
- Create: `godot/assets/map/` markers (settlement, fort) — SVG/PNG siluety
- Modify: Main stage hostí MapView

**Implementácia (MVP):**
1. Background: `FOREST_CANOPY` / `MEADOW` regions ako `Polygon2D` alebo TextureRect layers  
2. Rieky: `DANUBE` polylines  
3. Province nodes z existujúcich dát (`MapManager` / JSON) — pozície  
4. Settlement icon + loyalty ring farba (green/amber/crimson)  
5. Select glow; click → side panel  

**Neporiadok:** žiadny full AoE tilemap v tomto tasku.

**Verify:** všetky MVP provincie klikateľné; farby z `RegnumColors`.

**Commit:** `feat(map): MapView terrain tokens + settlements`

---

### Task 11: Battle presentation chrome (vrstva B)

**Objective:** Battle nie je text-only — backdrop + siluety + emblems.

**Files:**
- Create: `godot/scenes/battle/BattleView.tscn` + `BattleView.gd`
- Create: `godot/assets/battle/sil_infantry.png`, `sil_archer.png`, `sil_cavalry.png` (2 faction tints)
- Use: `battle_danube_composition_v1` ako optional full-bleed BG pre scenár 907

**UI:**
- Sky gradient `SKY_DUSK_TOP` → `SKY_DUSK_BOT`  
- Left Moravia / right opponent silhouettes podľa composition  
- Morale bars theme colors  
- **Nevymýšľať výsledky** — len vizualizovať výstup `BattleManager`

**Verify:** existujúci battle test / smoke stále pass; UI ukáže strany.

**Commit:** `feat(battle): BattleView silhouettes + dusk chrome`

---

### Task 12: Chronicle / Event plate wire-up (vrstva A)

**Objective:** Schválené narrative assety v hre.

**Files:**
- Create: `godot/scenes/chronicle/ChronicleView.tscn` + `.gd`
- Create: `godot/ui/EventModal.tscn` + `.gd`
- Create: `godot/assets/theme/portrait_rect_style` usage in modal

**Správanie:**
- Event s `art_id` → load z manifest path mapovania (`art_id` → `res://assets/...`)  
- Fallback: solid oak + title ak asset chýba  
- Devín 907 event použiť battle/location art podľa ID  

**Mapping file:**
- Create: `godot/data/art_map.json`  
```json
{
  "mojmir_ii_master_portrait": "res://assets/portraits/mojmir_ii_master_portrait_v1.webp",
  "battle_danube_composition": "res://assets/events/battle_danube_composition_v1.webp"
}
```

**Verify:** trigger event zobrazí obrázok; chýbajúci art nespadne.

**Commit:** `feat(ui): event/chronicle art_map wire-up`

---

### Task 13: Import presets + performance

**Objective:** Konzistentné texture flags.

**Godot import (pre UI icons):**
- Mipmaps on  
- Filter on  
- Compress: Lossless alebo VRAM compressed podľa platformy  
- 2D pixel art off (nie pixel game)

**Portraits/locations:**
- Large textures OK; zvážiť max 1920 na šírku v repo  

**Verify:** VRAM/size rozumné; žiadne rozmazané ikony pri 64px.

**Commit:** `chore(art): texture import defaults`

---

### Task 14: Web parity — **ARCHIVED, nerobiť**

**Zmena z kritickej analýzy:** `godot/docs/GODOT4_ARCHITECTURE_PROPOSAL.md` §11a už rozhodol — „React/TS prototyp sa archivuje... Nové featury sa do React vetvy nepridávajú.“ Overené aj priamo v `src/styles/global.css`: hex tokeny (`--moravia-crimson: #8b1e2d`, `--byzantine-gold: #c9a227`, `--parchment: #e8dcc4`, `--oak-dark/-mid`...) už presne sedia s kánonom — jediné čo by ostalo (fonty) by bola práca na archivovanej vetve.

**Akcia:** Tento task sa **neimplementuje**. Ak by sa React vetva predsa len znovu aktivovala, treba to najprv formálne zvrátiť v `GODOT4_ARCHITECTURE_PROPOSAL.md` §11a, nie potichu cez art task.

---

### Task 15: Dokumentácia pipeline

**Objective:** Ďalší agent vie generovať bez tohto chatu.

**Files:**
- Update: `godot/README.md` (sekcia Art)
- Update: `docs/VISUAL_DIRECTION.md` DoD checkboxes ak splnené
- Finalize: `docs/ASSET_MANIFEST.md` statuses

**Obsah README art:**
1. Čítaj `ART_PROMPT_CANON.md`  
2. Gen s ref = style master  
3. Approve v manifeste  
4. Path concencie + `art_map.json`  
5. Theme farby len cez `RegnumColors`

**Commit:** `docs(art): pipeline + manifest status`

---

## Odporúčané poradie commitov (batch groups)

Ak user povie „nakóď ako celok“, zoskup:

1. **Batch Infra:** Tasks 0, 0b, 1–3 (dirs, data integrity + dedup, colors, fonts, theme)  
2. **Batch Art Gen:** Tasks 4–7 (manuálny/AI gen + súbory do assets) — *vyžaduje user approve gates*  
3. **Batch UI:** Tasks 8–9  
4. **Batch Map/Battle:** Tasks 10–11  
5. **Batch Narrative + polish:** Tasks 12–13, 15  

---

## Test / validácia

| Čo | Ako |
|----|-----|
| Theme načítanie | Spustiť `Main.tscn` v editore |
| SK font glyphs | Label s „Župa Devín — ťaženie 907“ |
| Logika nerušená | `godot --headless -s res://tools/smoke_test.gd` (ak predtým prechádzal) |
| gdUnit | Manuálne v editore podľa user preferencie |
| Kontrast | Parchment text na oak — vizuálny check |
| Art kánon | Checklist v `tools/art/ASSET_CHECKLIST.md` (plate? anime? victory-poster 907?) |
| Missing art | EventModal fallback bez error spam |

---

## Riziká a tradeoffy

| Riziko | Mitigácia |
|--------|-----------|
| AI nekonzistentné tváre | Style Master + identity edit; 1 portrait = 1 Approved ref |
| Veľké binárne PNG v gite | WebP, max rozmery, `tools/art/raw/` gitignore |
| Font licensing | OFL commit + LICENSE |
| Scope creep 28 ikon + 24 BG | MVP: 12 ikon, 0 batch BG pred masters |
| Theme vs hardcoded modulate | Len `RegnumColors` + Theme |
| Battle art vs historický výsledok | Prompt + review checklist výslovne „not Moravian victory“ |
| React vs Godot dual work | Godot first; web parity **archived** (Task 14) — nerobiť, žiadne dual work |
| Devín province dáta nekonzistentné (religion type, neighbor asymetria) | Task 0b pred Task 10 |
| Duplicitná/mŕtva ArmyUI scéna zmätie budúceho agenta | Task 0b zmazanie pred Task 8 |
| `VERIFICATION.md` spec kóduje opačný historický výsledok Devína | Opravené priamo (viď P0-1) |

---

## Open questions (default ak user neodpovie)

| Otázka | Default |
|--------|---------|
| Gen provider? | OpenRouter Flux Pro / FAL podľa dostupného kľúča |
| Kde approve? | User v chate po priložení kandidátov; status do manifestu |
| Atlas vs loose icons? | Loose `*_64.png` MVP; atlas neskôr |
| Web parity teraz? | Nie |
| Koľko location masters pred MapView? | Min Devín + Nitra; Bratislava/dvor môžu ísť paralelne |

---

## Rýchly kickoff (prvé 3 príkazy po schválení plánu)

```bash
cd /Users/home/projects/regnum-moravicum-official
mkdir -p godot/assets/{fonts,theme,icons/ui,icons/factions,portraits,locations,events,map,battle} \
         godot/ui/components godot/scenes/{map,battle,chronicle} tools/art/raw
# potom Task 1 colors.gd + Task 0 manifest
```

---

## Referencie

- `docs/ART_PROMPT_CANON.md` — prompty §4–§9  
- `docs/VISUAL_DIRECTION.md` — herné vrstvy  
- `src/styles/global.css` — existujúce web tokeny (parity)  
- `godot/ui/ArmyUI.gd` — prvý UI target  
- `godot/scenes/main/Main.tscn` — shell  

---

## Changelog plánu

| Dátum | Poznámka |
|-------|----------|
| 2026-07-22 | v1 — generovanie + Godot implementácia, fázy G0–G6, tasks 0–15 |
| 2026-07-22 | v1.1 — kritická analýza po overení repozitára: opravený `VERIFICATION.md` (Devín 907 výsledok), nový Task 0b (devin.json religion/symetria, ArmyUI dedup), Task 8/9 doplnené o inštanciáciu + zachovanie existujúcich hookov, Task 14 preznačený na ARCHIVED, risk tabuľka rozšírená |

---

## Dodatok: M6 stav a grafika (2026-07-22)

> User update: M1–M5 logika kompletná; ďalšia vlna = **M6 UI/UX hrateľnosť**.

### AS-IS korekcie voči skoršiemu plánu
- Župy: **12** (s Devínom), nie 11
- `GameState.resources`: len **gold + prestige** — food/wood/stone/iron sú M6 kód + ikony
- G0 theme/fonts + Style Master Approved + G2 Review = hotové art foundation
- ArmyUI existuje, stále treba inštanciu v Main (M6 shell)
- React = ARCHIVED

### M6 art priorita (namiesto voľného G3–G5)
1. Approve/regen G2 masters
2. **UI icons MVP 12** (resources + religion + combat/scroll)
3. StatusBar chips + religion axis widget
4. MapView markers (B) pre 12 žúp
5. EventDialog art_map wire
6. Diplomacy/Army/Battle/End screens
7. Icons 13–28

Zdroj pravdy scope: `docs/M6_UI_ART_SCOPE.md`  
Visual DoD: `docs/VISUAL_DIRECTION.md` §10
| 2026-07-22 | v1.2 — M6 AS-IS dodatok; art priorita via M6_UI_ART_SCOPE |
