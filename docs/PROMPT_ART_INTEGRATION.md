# Prompt: Zapracovanie grafiky Regnum Moravicum do Godot kódu

> Skopíruj celý blok „PROMPT PRE AGENTA“ nižšie do novej konverzácie / Claude Code / iného agenta.  
> Repo: `regnum-moravicum-official` · Godot root: `godot/`  
> Jazyk odpovedí a kódu: **slovenčina**. Workflow: **celý batch naraz**, nepytaj sa po každom súbore.

---

## PROMPT PRE AGENTA

```
Si implementačný agent pre historicko-strategickú hru Regnum Moravicum (Godot 4.x, GDScript).

## Cieľ
Zapracuj a doladi existujúcu grafiku (AI assety + theme) do herného kódu tak, aby UI konzistentne používalo:
1) kanonické farby/fonty (theme),
2) art_map.json pre narrative assety,
3) UI ikony v StatusBar/Religion/akciách,
4) master portréty/lokality/battle pri eventoch, výbere župy, bitkách a EndScreen,
5) nič nerozbilo M1–M5 logiku ani determinizmus.

NIE JE cieľ generovať novú AI grafiku (pokiaľ niečo nechýba na disku).  
NIE JE cieľ React. React vetva je ARCHIVED.

## Repozitár a cesty
- Project root: regnum-moravicum-official/
- Godot project: godot/  (project.godot tu; res:// = godot/)
- Art assets: godot/assets/
- Mapovanie: godot/data/art_map.json
- Layout mapy: godot/data/map_layout.json
- Kanon: docs/ART_PROMPT_CANON.md, docs/VISUAL_DIRECTION.md, docs/M6_UI_ART_SCOPE.md, docs/ASSET_MANIFEST.md
- Konvencie: slovenčina v UI/komentároch; game_state.field priamy prístup (NIE game_state.get("year")); seeded RNG cez SaveManager; Devín 907 = Maďari víťazia (winner=attacker).

## Čo UŽ EXISTUJE (NEPREPISUJ od nuly — rozširuj)
### Art na disku (Approved)
godot/assets/
  events/regnum_visual_style_master_v1.png
  events/battle_danube_composition_v1.png
  portraits/mojmir_ii_master_portrait_v1.png
  portraits/theodora_master_portrait_v1.png
  portraits/arpad_master_portrait_v1.png
  locations/nitra_master_hero_v1.png
  locations/devin_master_fortress_v1.png
  locations/bratislava_master_river_v1.png
  locations/moravian_court_interior_v1.png
  icons/factions/mojmir_dynasty_emblem_v1.png
  icons/ui/icon_{gold,food,wood,stone,iron,prestige,eagle,cross_latin,cross_patriarchal,sword,shield,scroll}_{64,256,1024}.png
  fonts/CormorantGaramond-*.ttf, Alegreya-*.ttf
  theme/colors.gd, theme/regnum_theme_factory.gd

### UI shell už zapojený v Main
- MainMenu (run/main_scene)
- StatusBar (resource chips + ikony)
- ReligionAxis
- MapView (12 žúp)
- SideTabs: Armády + Diplomacia
- EventPanel + EventArt
- BattleView, NotificationFeed
- EndScreen
- art_map lookup v Main.gd (_resolve_art_path, _set_event_art)

### Logika
- GameState.resources: gold, food, wood, stone, iron, prestige
- Economy/Diplomacy/Victory manažéri existujú
- smoke_test.gd + smoke_test.m6.gd majú prechádzať

## Čo TREBA ZAPRACOVAŤ / DOLADIŤ (tvoja úloha)

### 0. PRED art wiringom over/oprav — existujúci bug v event shape (objavené pri kontrole, NIE spôsobené týmto promptom, ale priamo blokuje bod B1)

`EventManager._build_council_event()` (scripts/managers/EventManager.gd) vracia `{"text": ..., "choices": {"gifts": {"text":..., "effect":...}, "fortify": {...}}}` — teda `choices` je **Dictionary** a event nemá `title`/`body`/`art_id`.
`Main.gd._show_event(ev)` ale číta `ev.get("title", ...)`, `ev.get("body", ...)`, `ev.get("art_id", ...)` a robí `var choices: Array = ev.get("choices", [])` s indexovaním `choices[0]`, `choices[1]` — čo pri Dictionary hodnote spadne (typový nesúlad Array/Dictionary) hneď ako nastane council event (8 % šanca / tick v `process_events()`).
Žiadny existujúci test to nechytá — `smoke_test.gd` aj `smoke_test.m6.gd` nikdy neprejdú cez `_show_event` s reálnym pending_event.

**Over najprv, či bug skutočne existuje** (spustiť Main, klikať „Ďalší mesiac“ kým nepadne council event, alebo dočasne vynútiť `rng.randf_range < 0.08` vetvu). Ak áno, oprav **najmenej invazívne**:
- Preferované: pridaj tenký normalizačný krok v `GameManager.get_pending_event()` (nie v EventManager, aby si nemenil RNG/determinizmus), ktorý raw `{text, choices: Dictionary}` premapuje na `{title, body, art_id, choices: Array[{id, label, effect}]}` očakávané v `Main.gd`.
- Alternatíva: uprav `EventManager._build_council_event()` priamo na cieľový tvar (ak to nezmení poradie RNG volaní/determinizmus — over `test/m5` testy).
- Pridaj krátky manuálny/automatizovaný check, že vynútený council event zobrazí sa a obe voľby fungujú bez script error — toto nekryje žiadny existujúci smoke test.

Toto over/oprav **pred** rozširovaním EventArt/art_id logiky v bode B1, inak sa nová art_id vetva stavia na rozbitom základe.

### A. ArtCatalog (povinné)
Vytvor `godot/scripts/ui/ArtCatalog.gd` (autoload ALEBO statický helper preloadovaný z UI):
- load `res://data/art_map.json` raz
- `func path(art_id: String) -> String`
- `func texture(art_id: String) -> Texture2D` (null ak chýba; NIKDY nekrachuj)
- `func has(art_id: String) -> bool`
- preferuj `_64` pre UI ikony, full path z art_map pre narrative
- nahradť duplicitné _resolve_art_path v Main.gd / EndScreen.gd / BattleView volaním ArtCatalog

Odporúčané: pridať autoload:
  ArtCatalog="*res://scripts/ui/ArtCatalog.gd"
do project.godot [autoload] vedľa GameManager.

### B. Dôsledné napojenie art_id všade
1) **EventManager / eventy**  
   - Každý pending_event dictionary môže mať `"art_id": "..."`.  
   - Ak chýba, Main fallback:
     - ruler/dynasty → mojmir_ii_master_portrait
     - province nitra/devin/bratislava → príslušný location master
     - battle/war → battle_danube_composition
   - EventArt TextureRect: expand/cover, min height ~140–180, hide ak null.

2) **Výber župy (MapView → Main)**  
   - už mapuje nitra/devin/bratislava; rozšír:
     - morava → moravian_court_interior (alebo nitra)
     - default → mojmir_dynasty_emblem alebo style master (tlmene)
   - zobraz art v bočnom náhľade ALEBO EventArt/Selection preview (jednoduchý TextureRect `ProvinceArt` v MainColumn ak treba).

3) **Bitky**  
   - Skirmish/Devín už volá BattleView.show_outcome.  
   - Zabezpeč art_path cez ArtCatalog.  
   - Devín 907 VŽDY battle_danube_composition + vizuál crisis (nie víťazný moravský poster).  
   - Kronika + NotificationFeed dostanú stručný výsledok.

4) **EndScreen**  
   - win → moravian_court_interior alebo mojmir portrait  
   - lose → battle_danube_composition alebo devin_master_fortress  
   - emblem mojmir_dynasty_emblem v rohu (ak chýba, skip)

5) **MainMenu**  
   - emblem už; dopln background TextureRect (style master alebo court) s modulate dark (0.35–0.5), aby UI ostalo čitateľné.

6) **DiplomacyPanel**  
   - pri frakcii hungary zobraz arpad_master_portrait ako malý náhľad (64–96px) ak existuje  
   - moravia nikdy v listi nepriateľov (už)  
   - voliteľne icon_sword/shield pri mood hostile/friendly

7) **StatusBar / ReligionAxis**  
   - over že ikony loadujú `res://assets/icons/ui/icon_*_64.png`  
   - ak ResourceLoader.exists zlyhá, chip ostane text-only (no crash)

### C. Theme konzistencia
- VŠETKY UI scripty: `const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")`  
  a `theme = _ThemeFactory.build()` — NIE class_name RegnumThemeFactory (Godot cold start bez .godot cache padá).
- Farby: `const C = preload("res://assets/theme/colors.gd")` a `C.MORAVIA_CRIMSON` atď.
- Touch target min 48px na buttonoch.
- Typed GDScript: žiadne `var x := dict.get(...)` bez typu (project má warnings-as-errors).  
  Správne: `var x: String = str(dict.get("k", ""))`.

### D. Import / texture flags (ak chýbajú .import)
Po pridaní/úprave PNG spusti raz Godot headless load scény aby vznikli .import.  
UI ikony: filter + mipmaps OK. Žiadny pixel-art disable filter.

### E. Nemenné invarianty (NEPORUŠ)
- Devín 907: Maďari vyhrávajú (attacker). Nemeniť battle math aby „vyzerala lepšie“.
- 12 provincií vrátane devin; susedia symetrickí.
- resources kľúče nesmú zmiznúť.
- game_state.year/month/provinces priamy prístup.
- smoke_test.gd a smoke_test.m6.gd musia prejsť.
- Main.tscn a MainMenu.tscn headless load bez SCRIPT ERROR.

## Implementačný postup (batch)
0. Over/oprav event shape bug (bod 0 vyššie) — pred čímkoľvek ďalším
1. ArtCatalog + autoload
2. Refactor Main/EndScreen/BattleView na ArtCatalog
3. Doplniť art fallbacky (event/province/menu/diplomacy)
4. Theme preload audit vo všetkých ui/*.gd a scenes/**/*.gd
5. Spustiť testy (nižšie) a opraviť pády
6. Krátky SUMMARY čo sa zmenilo + zoznam súborov

## Testy (povinné pred hotovo)
```bash
cd godot
godot --headless --path . -s res://tools/smoke_test.gd --quit-after 30
# expect: SMOKE_PASS, Devin winner=attacker, Provinces: 12

godot --headless --path . -s res://tools/smoke_test.m6.gd --quit-after 30
# expect: SMOKE_M6_PASS

godot --headless --path . --scene res://scenes/main/Main.tscn --quit-after 6
godot --headless --path . --scene res://scenes/menu/MainMenu.tscn --quit-after 4
godot --headless --path . --scene res://scenes/end/EndScreen.tscn --quit-after 4
# expect: žiadny SCRIPT ERROR / Parse Error / null instance na @onready
```
Headless resource leaks pri exite = NEBLOKUJÚCE.

## Definition of Done
- [ ] Event shape (`title`/`body`/`art_id`/`choices` ako Array) zjednotený medzi EventManager výstupom a Main.gd/EventDialog spotrebou — over ručne vynúteným council eventom (žiadny existujúci smoke test toto nekryje)
- [ ] ArtCatalog je jediný resolver ciest k art_id
- [ ] Event/Bitka/Župa/Menu/End používajú Approved assety z assets/ cez art_map
- [ ] Chýbajúci art = hide/fallback, nie crash
- [ ] Theme cez preload factory všade
- [ ] SMOKE_PASS + SMOKE_M6_PASS + MAIN/MENU/END load OK
- [ ] Žiadna zmena battle výsledkov Devín 907
- [ ] Kód a UI texty po slovensky
- [ ] Celý batch naraz, bez pýtania po každom súbore

## Out of scope
- Generovanie nových Flux obrázkov
- React/web
- Notion
- 28-icon extended set (iba ak ostane čas PO DoD)
- Tilemap/spine animácie jednotiek
```

---

## Rýchle použitie

1. Otvor novú session s agentom v `regnum-moravicum-official`.  
2. Vlož celý blok **PROMPT PRE AGENTA**.  
3. Po dobehu over:
   - `godot --headless --path godot -s res://tools/smoke_test.gd`
   - `godot --headless --path godot -s res://tools/smoke_test.m6.gd`

## Poznámka k stavu
Veľa UI už grafiku používa (StatusBar ikony, EventArt, BattleView, emblem v menu). Tento prompt cieľom **zjednotiť a dokončiť wire** cez ArtCatalog + doplniť chýbajúce miesta (diplomacia portrait, menu BG, fallbacky), nie stavať shell od nuly.

## Overené pri kontrole plánu (2026-07-22) — 2 drobné korekcie
- Tvrdenie „project má warnings-as-errors“ (sekcia C) nemá oporu v `project.godot` (žiadna `[debug]` sekcia s takým nastavením) — typovanie je aj tak dobrá prax, ale neber to ako vynútené projektové pravidlo pri debugovaní.
- `docs/ASSET_MANIFEST.md` má UI ikony v stave **Review**, nie Approved (na rozdiel od 9 narrative masters, ktoré Approved sú) — na wiring to nevadí (súbory existujú), ale formálne schválenie ikon ešte chýba.
- Kritický nález (event shape mismatch) je zapracovaný vyššie ako bod „0.“ a v Definition of Done — over/oprav ho pred rozširovaním EventArt logiky.
