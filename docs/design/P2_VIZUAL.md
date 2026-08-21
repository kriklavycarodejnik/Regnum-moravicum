# P2 design spec: vizuálny dlh a obrazovky

> **Zodpovedný:** rm-design  
> **Vstupné dokumenty overené voči aktuálnemu kódu:**
> - `docs/CHYBAJUCA_GRAFIKA_NOVA_IDENTITA.md` — porovnané s `godot/data/art_map.json`, `scripts/managers/DiplomacyManager.gd`, disk assetmi
> - `docs/VISUAL_DIRECTION.md` — platí, nie je v rozpore
> - `docs/M6_UI_ART_SCOPE.md` — platí
> - `docs/ART_PROMPT_NOVA_VIZUALNA_IDENTITA.md` — prompt reference (vrstva C)
> - `docs/NAVRH_HERNY_ZAZITOK.md` §4.1 — invarianty
>
> **Všetky rozhodnutia overené voči disku, nie dokumentom z minulej fázy.**

---

## 1. Rozhodnutie: erby

### Verdikt: (b) — prekresliť existujúcich 7 emblémov v jednotnom heraldickom štýle

Zamietnuté: (a) — 6 nových vnútro-moravských subjektov.

### Zdôvodnenie

**Čo je na disku dnes:**
| Frakcia | art_map key | Súbor | Stav |
|---------|------------|-------|------|
| moravia | `emblem_moravia` | `mojmir_dynasty_emblem_v1.png` | ✅ |
| franks | `emblem_franks` | `franks_emblem_v1.png` | ✅ |
| bavaria | `emblem_bavaria` | `bavaria_emblem_v1.png` | ✅ |
| hungary | `emblem_hungary` | `hungary_emblem_v1.png` | ✅ |
| poland | `emblem_poland` | `poland_emblem_v1.png` | ✅ |
| bohemia | `emblem_bohemia` | `bohemia_emblem_v1.png` | ✅ |
| byzantium | `emblem_byzantium` | `byzantium_emblem_v1.png` | ✅ |

Všetkých 7 emblémov je na disku, registrovaných v `art_map.json`, a frakčné ID presne zodpovedajú `DiplomacyManager._ensure_default_factions()`.

**Čo navrhoval zdrojový dokument (a prečo to nie je správne):**

| Návrh (6) | Zodpovedá dnešnej frakcii? | Problém |
|-----------|---------------------------|---------|
| Byzantskí poslovia | ≈ byzantium (existuje emblém) | Už je pokryté existujúcim emblémom |
| Maďarské zvyšky | ≈ hungary (existuje emblém) | Už je pokryté existujúcim emblémom |
| Nemeckí kolonisti | franks/bavaria najbližšie, ale nie identické | Neexistuje samostatná frakcia — je to eventová línia |
| Župani | **žiadna zhoda** — moravia je hráč | Nie diplomatická frakcia, je to vnútorná správa |
| Cyrilometodskí kňazi | **neexistuje** ako DiplomacyManager frakcia | Náboženská línia, nie diplomatický subjekt |
| Bogatovci | **neexistuje** ako DiplomacyManager frakcia | Postava/dejová línia z eventov (bogata_trial_916, bogata_uprising_917) |

Päť zo šiestich položiek **nemá** zodpovedajúcu diplomatickú frakciu. Pridať ich by znamenalo:
1. Vynájsť nový subsystém "vnútorné frakcie/reálne entity" — dnes neexistuje
2. Zmeniť `DiplomacyManager` API, `GameState` save formát, eventy, UI panely
3. Rozšíriť scope P2 nad rámec vizuálneho dlhu do herného dizajnu

Pravidlo: *Nezväčšuješ scope P0.* Toto je presne taká zmena.

### Dôsledok na DiplomacyManager

**Žiadna zmena.** Frakčné ID zostávajú:
`moravia`, `franks`, `bavaria`, `hungary`, `poland`, `bohemia`, `byzantium`
art_map kľúče `emblem_*` s týmito 7 zostávajú. Jediná zmena je vizuálna: nový súbor pod rovnakým kľúčom.

#### Súvisiaci čistý-up: duplicitné kľúče v art_map.json

art_map.json dnes obsahuje duplicitné aliasy:
```
"emblem_bavaria": "path",          ← canonical
"bavaria_emblem": "same_path"      ← duplicitný alias (6×, chýba moravia)
```

Tieto vznikli počas P1 migrácie z React názvov `bavaria_emblem` na Godot konvenciu `emblem_bavaria`. Ak ich rm-godot opravuje, stačí:
- Ponechať canonical kľúče `emblem_*` (7)
- Odstrániť aliasy `*_emblem` (6)
- Overiť, že žiadny Godot kód nevolá `ArtCatalog.texture("bavaria_emblem")` — search cez grep

**Akceptačné kritérium:** `art_map.json` má práve 7 `emblem_*` kľúčov (žiadne `*_emblem`), `DiplomacyManager.list_factions()` vracia 6 nevlastných frakcií. Smoke M6 PASS.

---

## 2. Rozdelenie vizuálneho dlhu

### 2.1 UI/dátová práca (bez nových PNG) — možná hneď

Tieto položky vyžadujú len Godot kód a existujúce assety. Nemôžu sa oneskoriť o Lukášov batch.

#### 2.1.1 Chronicle ako štruktúrovaný zoznam

**Problém:** Dnes `Main.tscn:141-146` — `RichTextLabel` s plochým text logom. Hráč nevidí typ udalosti, ikonu, ani vizuálne odlíšenie dôležitých ťahov. Porušuje test 1 (prerozprávanie) — po 15 minútach hry je kronika nečitateľná zhluk textu.

**Riešenie:** Nahradiť `RichTextLabel` za `VBoxContainer` s per-entry `HBoxContainer`:
- Ikonka podľa typu eventu (existujúce `icon_sword`, `icon_scroll`, `icon_cross_latin`, `icon_shield`, `icon_eagle`)
- Rok/mesiac
- Text
- Scroll + max viditeľných položiek (napr. 20, tlačidlo "staršie")

**Zapojenie:** `NarrationManager.generate_chronicle()` už produkuje štruktúrované riadky — refaktor `Main.gd._update_chronicle()` aby vypĺňal detaily per-entry, nie append text.

**Akceptačné kritérium:** Po 5 ťahoch má kronika aspoň 5 riadkov, každý s ikonkou a dátumom. Hráč vie povedať "v marci 903 prišli pápežskí legáti" — nie "v kronike je text".

**Priradenie:** `rm-godot`
**Súbory:** `Main.gd` (_update_chronicle, _on_notification), `Main.tscn` (ChroniclePanel)

#### 2.1.2 Loading screen z existujúcich hero assetov

**Problém:** Dnes žiadny loading screen. `MainMenu` → `Briefing` → `Main.tscn` (resp. `MainMenu` → `Main.tscn` pri load) — čierna obrazovka počas načítania, trvá ~2–8 sekúnd.

**Riešenie:** Nová scéna `Loading.tscn`:
- `TextureRect` s náhodným hero assetom z poolu: `nitra_master_hero`, `devin_master_fortress`, `bratislava_master_river`, `moravian_court_interior`, `mojmir_ii_master_portrait`, `regnum_visual_style_master`
- Modulácia 0.25 (temné)
- Uprostred text "Načítavam Kroniku Moravy..." (Alegreya italic)
- ProgressBar nie je nutný — scéna sa prepne hneď, ako je Main.tscn ready

**Zapojenie:** `MainMenu._on_new()` a `MainMenu._on_load()` → `Loading.tscn` → v `_ready` začne deferred change do `Briefing`/`Main`.

**Akceptačné kritérium:** Pri štarte hry (nová hra aj load) je viditeľná loading scéna ~0.5–8 sekúnd s hero obrázkom. Žiadna čierna obrazovka.

**Priradenie:** `rm-godot`
**Nový súbor:** `scenes/loading/Loading.tscn`, `Loading.gd`

#### 2.1.3 Background art na hlavnej obrazovke

**Problém:** `Main.tscn:35-45` — `BackgroundArt` (TextureRect) dnes používa prvé dostupné `TextureRect` s moduláciou 0.18. Ak nie je nastavené, čierna. Žiadna zmena medzi ťahmi.

**Riešenie:** Rotovať background art podľa kontextu:
- Keď je vybratá župa: `ArtCatalog.province_art_id(province)` — už existuje
- Keď nie je vybratá: cyklus cez hero assety (`nitra_master_hero`, `devin_master_fortress`, `moravian_court_interior`) po 10 ťahoch
- Vždy modulácia 0.18–0.25

**Zapojenie:** `Main.gd._on_province_selected()` + časovač/možno v `_process(delta)` s throttlom.

**Akceptačné kritérium:** Po kliknutí na župu sa pozadie zmení na jej hero art (alebo aspoň default). Po 10 ťahoch bez kliku sa pozadie zmení.

**Priradenie:** `rm-godot`

#### 2.1.4 icon_gold — fix kľúča v art_map.json

**Problém (známy):** `art_map.json:12` má `"icon_gold"` (bez `_64`) ako hlavný kľúč, ale súbor je `icon_gold_64.png`. Všetky ostatné resource ikony (`icon_food`, `icon_wood`...) majú kľúč bez `_64`, ale kód aj ArtCatalog používa konvenciu `_64`. Riadok 114 už má dupkát `"icon_gold_64"` — oprava existuje, len treba odstrániť starý kľúč.

**Riešenie:** `art_map.json`:
- Odstrániť riadok 12: `"icon_gold": "res://..."` (bez _64)
- Ponechať riadok 114: `"icon_gold_64": "res://..."`

**Akceptačné kritérium:** `ArtCatalog.texture("icon_gold_64")` vracia platnú textúru. `ArtCatalog.texture("icon_gold")` vracia `null`. Smoke M6 PASS.

**Priradenie:** `rm-godot`

#### 2.1.5 Graceful placeholder pre chýbajúci art_id

**Problém:** Dnes `ArtCatalog.texture(id)` vracia `null` ak kľúč chýba — volajúci musí riešiť fallback. Niektoré scény (napr. `BattleView`, `EventDialog`) vracajú `null` ako prázdny TextureRect.

**Riešenie:** Pridať fallback vrstvu v `ArtCatalog.gd`:
```gdscript
func safe_texture(art_id: String, fallback_id: String = "") -> Texture2D:
    var tex := texture(art_id)
    if tex != null:
        return tex
    if fallback_id != "":
        return texture(fallback_id)
    # implicitný fallback — oak ColorRect generovať nejde, vráti null a volajúci zobrazí label
    return null
```

A v každej TextureRect používajúcej art_map: ak `texture()` vráti null, nastaviť `modulate.a = 0` (neviditeľný) namiesto prázdneho bieleho obdĺžnika. Event panel: oak background + label "Ilustrácia sa pripravuje" (SK).

**Akceptačné kritérium:** Ak chýba akýkoľvek art_map kľúč (napr. `event_xyz`), scéna nikdy nezobrazí biely/čierny štvorec — buď oak panel, alebo transparent.

**Priradenie:** `rm-godot`

#### 2.1.6 Cesty medzi župami + kompas

**Problém:** `MapView.gd` kreslí polygóny 12 žúp + rieku Dunaj. Cesty medzi župami (historické obchodné trasy) a kompas neexistujú. Mapa pôsobí plocho.

**Riešenie:**
- Pridať `Line2D` cesty medzi susednými župami (definícia v JSON alebo v MapView konštante: nitra↔trenčín, nitra↔devín, devín↔bratislava, bratislava↔morava...)
- Kompas: `TextureRect` v pravom hornom rohu, ikona z existujúcich (najbližšie `icon_eagle` alebo nový asset cez P2 batch)
- Mriežka alebo modulácia nie je nutná — jednoduché line cesty

**Zapojenie:** `MapView.gd` — nová funkcia `_draw_roads()`, `_draw_compass()`.

**Akceptačné kritérium:** Na mape sú viditeľné čiary spájajúce susedné župy. V pravom hornom rohu je kompas.

**Priradenie:** `rm-godot`

---

### 2.2 Nové assety od Lukáša (PNG)

Tieto položky vyžadujú nový obrázok. Prompt a špecifikácia sú v `docs/ART_PROMPT_NOVA_VIZUALNA_IDENTITA.md` §2 (štýl Block C — heraldic line-icon, gold linework na oak). Tu uvádzam len kľúč a graceful placeholder pre chýbajúci súbor.

#### 2.2.1 Navigačné ikony (7×)

| art_map key | Veľkosť | Popis | Prompt ref |
|------------|---------|-------|------------|
| `icon_nav_map_64` | 64/256px | kompas + hviezda, kruhový rám | ART_PROMPT_NOVA §2.1 |
| `icon_nav_events_64` | 64/256px | zvitok so zámkom | ART_PROMPT_NOVA §2.1 |
| `icon_nav_diplomacy_64` | 64/256px | dve olivové ratolesti | ART_PROMPT_NOVA §2.1 |
| `icon_nav_army_64` | 64/256px | prekrížený meč + štít | ART_PROMPT_NOVA §2.1 |
| `icon_nav_battle_64` | 64/256px | prekrížené meče, hroty von | ART_PROMPT_NOVA §2.1 |
| `icon_nav_chronicle_64` | 64/256px | otvorená kniha | ART_PROMPT_NOVA §2.1 |
| `icon_nav_menu_64` | 64/256px | rovnoramenný kríž (dvojkríž) | ART_PROMPT_NOVA §2.1 |

**Umiestnenie:** `godot/assets/icons/ui/`
**Registrácia:** `art_map.json` pod kľúčom zhodným s názvom (vrátane `_64`).
**Graceful placeholder:** TabContainer taby — ak ikona chýba, zobraziť len text label (už dnes funguje). Prázdna Textúra = nevkladať TextureRect vôbec.

#### 2.2.2 Resource ikona — náboženstvo (1×)

| art_map key | Veľkosť | Popis | Prompt ref |
|------------|---------|-------|------------|
| `icon_religion_64` | 64/256px | dvojitá krivka (Rím ↔ Konštantínopol) alebo zvon + váhy — pozri návrh, sekcia "Náboženstvo" | ART_PROMPT_NOVA §2.2 |

**Graceful placeholder:** Ak chýba, resource chip pre náboženstvo používa existujúcu `icon_cross_patriarchal_64` (byzantský kríž — najbližší význam).

#### 2.2.3 Sídelné budovy — market a monastery (2×)

| art_map key | Veľkosť | Popis | Prompt ref |
|------------|---------|-------|------------|
| `marker_market_64` | 64/256px | stánky s vahami, otvorený trh | ART_PROMPT_NOVA §2.3 |
| `marker_monastery_64` | 64/256px | kláštor s rozetovým oknom a krížom | ART_PROMPT_NOVA §2.3 |

**Upozornenie:** Tieto assety je bezpečné generovať, ale **ich herné zapojenie nie je v scope P2** — dnes `MapView.gd` používa prosperity tiery (small/medium/large), nie typ budovy. Kým sa nerozhodne dátový model (uchováva sa "typ budovy" v `province.json`?), assety čakajú v `art_map.json` ako "nepoužité, pripravené".

**Graceful placeholder:** Na mape sa nezobrazujú, kým ich niekto nezapojí. Ak sú v art_map ale nikto ich nevolá = žiaden problém.

#### 2.2.4 Dynastická pečať (1×)

| art_map key | Veľkosť | Popis | Prompt ref |
|------------|---------|-------|------------|
| `dynasty_seal_mojmir_v1` | 256/1024px | kruhová vosková pečať, dvojkríž na červenom poli, nápis "MOJMÍR II." | ART_PROMPT_NOVA §2.4 |

**Umiestnenie:** `godot/assets/icons/factions/`
**Graceful placeholder:** EndScreen už dnes používa `mojmir_dynasty_emblem` ako fallback. Ak `dynasty_seal_mojmir_v1` chýba, zobraziť emblém. Nespadne.

#### 2.2.5 Frakčné emblémy — heraldický restyle (7×, len nový vizuál)

| art_map key | Existujúci súbor | Nový súbor (cieľ) |
|------------|------------------|--------------------|
| `emblem_moravia` | `mojmir_dynasty_emblem_v1.png` | `mojmir_dynasty_emblem_v2.png` |
| `emblem_franks` | `franks_emblem_v1.png` | `franks_emblem_v2.png` |
| `emblem_bavaria` | `bavaria_emblem_v1.png` | `bavaria_emblem_v2.png` |
| `emblem_hungary` | `hungary_emblem_v1.png` | `hungary_emblem_v2.png` |
| `emblem_poland` | `poland_emblem_v1.png` | `poland_emblem_v2.png` |
| `emblem_bohemia` | `bohemia_emblem_v1.png` | `bohemia_emblem_v2.png` |
| `emblem_byzantium` | `byzantium_emblem_v1.png` | `byzantium_emblem_v2.png` |

**Štýl:** Jednotný heraldický štýl — heraldic line-icon, gold linework na oak (viď ART_PROMPT_NOVA §1 base prompt). Každý emblém má:
- Kruhový medailónový rám (gold)
- Heraldické znamenie (morava = dvojkríž/orlica, franks = ľalia, bavaria = modro-biely šach, hungary = dvojkríž/tatranské vrchy, poland = orlica, bohemia = lev, byzantium = dvojhlavý orol)
- Názov frakcie v slovanskej cyrilike alebo latinke (voliteľné)

**Graceful placeholder:** `art_map.json` ukazuje na `_v1` súbor, kým `_v2` nie je na disku. Všetky _v1 existujú a fungujú — žiaden breaking change.

---

### 2.3 Mimo P2 (odložené)

#### 2.3.1 Unit siluety — 8× frakčná matica

Problém: Dnes 6 univerzálnych siluet. Návrh chce Moravania+Maďari × 4 typy = 8 farebne odlíšených.

**Odložené** — závisí od M8.3 battle-view iterácie a rozhodnutia, či frakčné siluety vôbec ideme robiť. P2 sa venuje len statickým UI assetom, nie battle.

#### 2.3.2 Hlavné menu so 4 scenármi

Godot MVP má len 1 kampaň (902–1000). Menu so 4 scenármi (Prežitie/Konsolidácia/Zlatý vek/Mongolská skúška) je starý dizajn z React vetvy. **Nepatrí do P2.**

---

## 3. Poradie implementácie

Zoradené podľa dopadu na "hráč si po prvých minútach rozpráva príbeh svojej vlády". Číslo = poradie, nie priorita (všetky sú P2).

### P0 — Chronicle ako štruktúrovaný zoznam

**Prečo prvé:** Priamo ovplyvňuje test 1 (prerozprávanie). Bez neho hráč po 10 minútach nevie povedať, čo sa stalo v prvom ťahu — kronika je stena textu. UI práca, žiadna závislosť na Lukášovi.

**Kto:** rm-godot. **Blokuje:** nič.

### P1 — Loading screen

**Prečo druhé:** Loading screen je prvý kontakt s hrou (pri novom štarte aj load). Čierna obrazovka hneď po kliknutí na "Nová hra" je "lacný" dojem. Dá sa spraviť z existujúcich assetov.

**Kto:** rm-godot. **Blokuje:** nič.

### P2 — Navigačné ikony (7×)

**Prečo tretie:** TabContainer (Armády/Diplomacia/Kronika) dnes len text — ikony zlepšujú orientáciu o 100 % na prvý pohľad. Potrebujú nový PNG od Lukáša.

**Kto:** rm-content (generovanie promptov a batch), rm-godot (zapojenie do tabov).

### P3 — icon_gold fix + duplicitné kľúče

**Prečo:** Jeden riadok v JSON, triviálne, ale resource chip zlato dnes funguje na duplicitnom kľúči — fix je rýchly a elegantný.

**Kto:** rm-godot. **Blokuje:** nič.

### P4 — Cesty + kompas na mape

**Prečo:** Zlepšuje dojem z mapy, ale je to kozmetika — bez ciest je mapa funkčná. Kódová práca, závisí na MapView.gd.

**Kto:** rm-godot. **Blokuje:** nič.

### P5 — Frakčné emblémy restyle (7×)

**Prečo:** Jednotný heraldický štýl je viditeľný v DiplomacyPanel a EndScreen. Dnešné emblémy sú funkčné, ale štýlovo nekonzistentné. Restyle potrebuje Lukáša.

**Kto:** rm-content (batch), rm-godot (art_map update).

### P6 — Background art rotácia

**Prečo:** Kozmetika — main screen pozadie. Zlepšuje prémiový dojem, ale hráč si to neuvedomí, kým neklikne na župu (vtedy už funguje province art).

**Kto:** rm-godot.

### P7 — Graceful placeholder systém

**Prečo:** Poistka, nie feature. Dôležité až po pridaní nových assetov (P2, P5), keď reálne hrozí chýbajúci súbor.

**Kto:** rm-godot.

### P8 — Religion resource ikona + building markery

**Prečo:** Funkčne sa nezobrazia, kým religion nie je resource v StatusBar a building typ nie je v province dátach. Assety sú pripravené v art_map, zapojenie je samostatná karta neskôr.

**Kto:** rm-content (generovať asset), rm-godot (len art_map register).

### P9 — Dynastická pečať

**Prečo:** EndScreen už používa emblém. Pečať je vylepšenie — prémiová kosmetika, nie nutná pre funkčnosť.

**Kto:** rm-content (generovať), rm-godot (zapojenie do EndScreen + Loading).

---

## 4. Zhrnutie — čo sa posúva ďalej

| Skupina | Počet assetov | Závislosť na Lukášovi | Kto robí |
|---------|---------------|----------------------|----------|
| UI/dátová práca (6 položiek) | 0 | Nie | rm-godot |
| Nové PNG (11) | 7 nav ikon + 1 religion + 2 markery + 1 seal = 11 | Áno | rm-content → rm-godot |
| Restyle (7) | 7 emblémov v2 | Áno | rm-content → rm-godot |
| Mimo P2 | siluety 8, 4 scenáre menu | — | Samostatné karty |

---

## 5. Overenie

Tento spec je overený voči aktuálnemu disku:
- `art_map.json` — 125 riadkov, všetky kľúče prečítané
- `DiplomacyManager.gd` — 7 frakcií, `_ensure_default_factions()` volanie overené
- `assets/icons/factions/` — 7 PNG, všetky existujú
- `Main.tscn` — Chronicle je RichTextLabel (riadok 141), BackgroundArt je TextureRect (riadok 35)
- `MainMenu.gd` — loading chýba, priamo change_scene_to_file
- `ArtCatalog.gd` — `texture()` vracia null pri chýbajúcom kľúči, nemá safe_texture

Headless test vizuál neoveruje. Overenie týchto zmien vyžaduje:
1. **Screenshot trace:** spustiť hru, urobiť screenshot v krokoch: menu → loading → main screen → po kliknutí na župu → diplomacia tab → po 5 ťahoch kronika
2. **Akceptačné kritériá** vyššie sú overiteľné screenshotom alebo kontrolou JSON/GD súborov