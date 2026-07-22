# M6 — UI/UX + Art scope (napojenie na grafiku)

> **Stav logiky:** M1–M5 + M6 UI shell — hrateľné. `SMOKE_PASS` + `SMOKE_M6_PASS`. Devín 907 = Maďari.  
> **Art A:** Style Master + G2 masters **Approved**.  
> **Art C:** Theme/fonty + UI icons 12 **Approved**.  
> **M6 UI:** MainMenu, StatusBar, ReligionAxis, MapView, Army/Diplomacy tabs, Event+art, BattleView, NotificationFeed, EndScreen, full resources.

**Súvisiace:**  
`docs/ART_PROMPT_CANON.md` · `docs/VISUAL_DIRECTION.md` · `docs/ASSET_MANIFEST.md` ·  
`.hermes/plans/2026-07-22_121322-grafika-generovanie-implementacia.md`

---

## 1. Overený AS-IS (kód, nie wish-list)

| Vrstva | Fakt v repo |
|--------|-------------|
| Župy | **12** JSON (`godot/data/provinces/`), vrátane **devin** (nie 11) |
| `GameState.resources` | **gold, food, wood, stone, iron, prestige** |
| Main UI | flat VBox: Title, StatusBar (rok + resources text), Chronicle, EventPanel 2 voľby, Devín/Skirmish/NextMonth |
| ArmyUI | Inštancovaná v Main SideTabs spolu s DiplomacyPanel |
| Art | Style Master + G2 Approved; art_map; 12 UI icons |
| Theme | `RegnumColors` + `RegnumThemeFactory` na Main |
| React | **ARCHIVED** — žiadna web parity práca |

M6 teda **dopĺňa UI + chýbajúce resource polia + panely**, a **spotrebúva** už hotové A-mastery cez `art_map.json`.

---

## 2. M6 systémy → art / UI mapovanie

### 2.1 Kompletný model zdrojov

| Resource key | UI label (SK) | Icon id | Farba / poznámka |
|--------------|---------------|---------|------------------|
| `gold` | Zlato | `icon_gold` | byzantine-gold `#C9A227` |
| `food` | Jedlo | `icon_food` | meadow / grain |
| `wood` | Drevo | `icon_wood` | oak / forest |
| `stone` | Kameň | `icon_stone` | stone-wall `#6B6560` |
| `iron` | Železo | `icon_iron` | iron-grey `#4A4E52` |
| `prestige` | Prestíž | `icon_prestige` | orlica / dvojkríž gold |

**Art úloha:** UI icon set (vrstva C) — linework manuscript, 256→64, čitateľné na 24px.  
**Kód úloha (mimo čistej grafiky):** rozšíriť `GameState.resources` + EconomyManager; StatusBar chipy.

### 2.2 Religion axis (Rím ↔ Konštantínopol)

| UI prvok | Špec |
|----------|------|
| Slider / bar | rozsah **-100 … +100** (alebo 0–100 ak kód mapuje inak — zosúladiť s `ReligionManager`) |
| Ľavý pól | Rím — ikona `icon_cross_latin` / papal, chladnejšia šedomodrá |
| Pravý pól | Konštantínopol — ikona `icon_cross_patriarchal` / byzantine gold+crimson |
| Stred | neutrál / misijná zóna — parchment |

**Art:** 2–3 religion ikony + prípadne tenký ornament na track.  
**Narrative A (neskôr):** event plates pre Cyrila a Metoda, papal bull (až budú event ID).

### 2.3 Event system

| Prvok | Art / UI |
|-------|----------|
| `EventDialog` | Oak `PanelContainer` (theme), TitleLabel, body Alegreya, 2–4 Button voľby min h 48 |
| Optional art | `TextureRect` z `art_map[event.art_id]` — fallback solid oak |
| Kronika | RichTextLabel; riadky bez AI art |

**Existujúce A assety na wire:** portréty (dynastia/AI), lokality (province events), `battle_danube_composition` (907).

### 2.4 Diplomacia

| Prvok | Art |
|-------|------|
| Faction row icon | emblém / farba frakcie (Morava = mojmir emblem; Maďari = steppe tint; Franky/Bavorsko/Poľsko/Čechy = farebné pečate — Planned) |
| Relation pip | friendly / neutral / hostile (zelená / jantár / crimson kruh) |
| Action icons | `icon_gift`, `icon_threat`, `icon_treaty`, `icon_trade`, `icon_nap`, `icon_military_pact` |

### 2.5 Victory / Game Over

| Screen | Art |
|--------|-----|
| Victory | muted gold + parchment; optional court interior BG dimmed |
| Defeat / Devín crisis | dusk sky + battle plate dimmed; **nie** moravský triumf pri 907 prehre |
| CTA | Restart / Menu — theme buttons |

### 2.6 Hlavné UI panely (M6 shell)

```
┌─ StatusBar (resources chips + religion mini-axis + Next month) ─┐
├─ MapView (B) ──────────────┬─ SideStack ───────────────────────┤
│  province colors           │  Tabs: Armáda | Diplomacia |      │
│  loyalty rings             │  Event (modal over) | Kronika     │
│  army markers              │                                   │
├─ NotificationFeed ─────────┴───────────────────────────────────┤
└─ optional BattlePanel when war active ─────────────────────────┘
```

| Panel | Scéna (cieľ) | Art závislosť |
|-------|--------------|---------------|
| MainMenu | `scenes/menu/MainMenu.tscn` | emblem, parchment BG |
| StatusBar | `ui/StatusBar.tscn` | 6 resource icons + religion |
| MapView | `scenes/map/MapView.tscn` | biome colors, settlement markers, faction tints |
| EventDialog | `ui/EventDialog.tscn` | theme + optional A plate |
| DiplomacyPanel | `ui/DiplomacyPanel.tscn` | faction icons |
| ArmyPanel | exist. `ui/ArmyUI.tscn` → rename/extend | unit silhouettes later |
| BattlePanel | `ui/BattlePanel.tscn` / `scenes/battle/BattleView.tscn` | dusk + silhouettes + battle plate |
| Chronicle | part of Main or `ChronicleView` | text only MVP |
| NotificationFeed | `ui/NotificationFeed.tscn` | tiny icons optional |
| Victory/GameOver | `scenes/end/Victory.tscn`, `GameOver.tscn` | BG plates |
| Save/Load | menu + toast | žiadny AI art |

**Touch:** min **48×48** px hit target (M6 iOS); theme buttons už majú ~44 — bump na 48 v M6 theme pass.

---

## 3. Priorita art produkcie pre M6 (poradie)

| Prio | Batch | Obsah | Blokuje |
|------|-------|--------|---------|
| **P0** | G2 approve | User schváli/regen 9 masters | narrative wire |
| **P1** | **UI icons MVP (12)** | gold, food, wood, stone, iron, prestige, eagle, cross_latin, cross_patriarchal, sword, shield, scroll | StatusBar, Diplomacy basic |
| **P2** | Faction pips + relation | 6 frakcií farba + 3 relation dots | DiplomacyPanel |
| **P3** | Map markers B | settlement 3 tier, army dot, fort | MapView |
| **P4** | Battle silhouettes B | infantry/archer/cavalry ×2 tints | BattlePanel |
| **P5** | Icons extended | gift, threat, treaty, trade, nap, pact, save, next_month… → smerom k 28 | full chrome |
| **P6** | Event narrative | historické event plates podľa EventManager ID | flavor |

G2 mastery **neslúžia** ako map tiles — len event/loading/end screens.

---

## 4. UI icon set — záväzný zoznam M6

### MVP 12 (generovať v G3)

1. `icon_gold`  
2. `icon_food`  
3. `icon_wood`  
4. `icon_stone`  
5. `icon_iron`  
6. `icon_prestige`  
7. `icon_eagle` (Morava / player)  
8. `icon_cross_latin` (Rím)  
9. `icon_cross_patriarchal` (Konštantínopol)  
10. `icon_sword`  
11. `icon_shield`  
12. `icon_scroll` (event/kronika)

### Extended 13–28 (po MVP shell)

13–18: gift, threat, treaty, trade, nap, military_pact  
19–22: army_move, army_split, army_merge, siege  
23–25: save, load, next_month  
26–28: notification, victory_laurel, defeat_broken_sword  

**Štýl:** Block C — iron-grey linework, parchment fill, 1 accent (gold/crimson), no drop shadow, 256 master → 64 atlas.

---

## 5. Farebné sémantiky M6 (UI, nie len mapa)

| Význam | Farba |
|--------|--------|
| Player / CTA | moravia-crimson |
| Prestige / wealth accent | byzantine-gold |
| Positive / loyalty high | meadow / success green |
| Warning | `#C9902F` (už vo web tokens) |
| Hostile / low loyalty | moravia-crimson |
| Religion Rome lean | cooler grey-blue |
| Religion Constantinople lean | byzantine-gold + crimson |
| Magyar / enemy | magyar-steppe |
| Disabled | text-muted on oak |

`RegnumColors` doplniť pri M6: `SUCCESS`, `WARNING`, `RELIGION_ROME`, `RELIGION_BYZ` ak chýbajú.

---

## 6. Wire pravidlá (art → Godot)

1. **Žiadny hardcode cesty v paneloch** — len `art_map.json` / budúci `ArtCatalog.gd`.  
2. Missing texture → oak ColorRect + SK label (nespadnúť).  
3. Event s `art_id` → portrait/location/battle.  
4. Devín 907 UI/battle: použiť `battle_danube_composition` / `devin_master_fortress` v **crisis** tónovaní; výsledok z BattleManager nemenit.  
5. Resource chip: ikona + číslo; ak key chýba v `resources`, zobraz `0` (kým Economy nedoplní).

---

## 7. Čo grafika M6 *nerobí* (YAGNI)

- React/TS panely  
- 24 event BG pred Event ID zoznamom  
- Spine unit animácie  
- Notion sync  
- Zmena tick poradia / battle math  

---

## 8. Definition of Done — M6 vizuál (hrateľná)

- [x] StatusBar: 6 resource chips + religion axis + Next/Save/Menu (48px)  
- [x] MapView: 12 žúp, loyalty tint, select, tooltip  
- [x] EventDialog: 2 choices + optional art plate  
- [x] ArmyPanel inštancovaný v shelli  
- [x] DiplomacyPanel zoznam frakcií + základné akcie  
- [x] BattleView chrome  
- [x] Victory + GameOver (EndScreen)  
- [x] MainMenu New/Load/Quit + Save v hre  
- [x] 12 UI icons Approved + v StatusBar  
- [x] G2 masters Approved alebo explicitne rejectnuté s regen  
- [x] smoke_test + smoke_test.m6 PASS  
- [ ] Touch targets ≥ 48  

---

## 9. Odporúčané vetvenie / batch po grafike

1. User: **approve g2** (alebo regen)  
2. **G3** — UI icons 12 + StatusBar scéna (aj keď resources ešte gold/prestige — chipy food/wood/stone/iron ukazujú 0)  
3. Paralelne kód: rozšírenie `GameState.resources`  
4. MapView + EventDialog wire art_map  
5. Diplomacy / Army / End screens  
6. Icons 13–28 + polish  

---

## 10. Changelog

| dátum | zmena |
|-------|--------|
| 2026-07-22 | v1 — M6 scope zohľadnený voči AS-IS kódu (12 žúp, gold+prestige only, G2 Review, theme done) |
| 2026-07-22 | MapView + ReligionAxis + MainMenu wired into Godot shell |
| 2026-07-22 | M6 shell complete: NotificationFeed + BattleView + smoke_test.m6 |
