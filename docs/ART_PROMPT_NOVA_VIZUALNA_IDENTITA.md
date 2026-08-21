# Nová vizuálna identita — prompt na zapracovanie (zdroj: Claude Design)

> **Zdroj:** `claude.ai/design/p/f6012712-9388-4d4d-b1cc-6966df696c6e`
> ("Game UI design system"), súbory `Vizualna sada.dc.html` + 2×
> `Navrhy obrazoviek*.dc.html` + `github.md`.
> Toto je **doplnok** k `ART_PROMPT_CANON.md` (Style Block C), nie nová
> paleta — pozri bod 0.

---

## 0. Kľúčové zistenie — paleta sedí, zdroj dát nesedí

**Dobrá správa:** hex hodnoty v novom návrhu (`#c9a227`, `#8b1e2d`,
`#e8dcc4`/`#f0e6d2`, `#0a0806`/`#14100c`, `#5a9c5a` success, `#c9902f`
warning) **presne zodpovedajú** existujúcim tokenom v
`godot/assets/theme/colors.gd` (`BYZANTINE_GOLD`, `MORAVIA_CRIMSON`,
`PARCHMENT`, `BG_DARKER`, `SUCCESS`, `WARNING`). Nová identita je teda
**kompatibilné rozšírenie** Style Block C, nie nový smer — netreba
prerábať paletu, len domaľovať chýbajúce assety v tom istom duchu.

**Problém:** `github.md` (metadáta Design projektu) hovorí, že mockupy sú
zakotvené v **archivovanej React vetve** (`src/ui/components/*.tsx`,
`src/styles/global.css`) — nie v aktívnom Godot kóde. Dôsledok: časť
návrhu odkazuje na UI koncepty, ktoré **v Godot verzii buď neexistujú,
alebo existujú inak**. Toto je rovnaký vzor, aký sme videli pri
eventoch (`historicalEvents.ts`) a battle engine (`engine.ts`) — obsah
je cenný, ale treba ho **prekladať** na aktuálny Godot dátový model,
nie kopírovať 1:1. Konkrétne nezrovnalosti sú v
`CHYBAJUCA_GRAFIKA_NOVA_IDENTITA.md` (bod 2) — **prečítaj ten dokument
pred generovaním** frakčných erbov, inak sa vygeneruje 6 erbov pre
frakcie, ktoré hra vôbec nemá.

---

## 1. Štýl — spoločný base prompt (anglicky, pre generátor)

```
Heraldic line-icon style, thin gold linework (#C9A227) on dark oak-brown
card background (#2C2118 to #231A12 gradient), consistent with existing
Regnum Moravicum Style Block C (parchment #E8DCC4, moravia-crimson
#8B1E2D accents). Medieval Slavic/Byzantine heraldry — no photorealism,
no modern iconography, no emoji-like flatness. Icons must read clearly
at 64px. Circular medallion frame optional per asset (see per-category
notes below). Single-color gold line art with selective crimson/color
accent fills, not full-color illustration.
```

Toto nahrádza doterajší (implicitný) prístup "žiadny jednotný ikon-set,
UI text/emoji zástupky" — je to prvý explicitný Style Block pre **line
icon** vrstvu, doplnok ku existujúcim A (narrative)/B (game world)/C
(UI chrome, doteraz len resource chips + battle silhouety).

---

## 2. Pripravené na generovanie (žiadna otvorená otázka)

### 2.1 Navigačné ikony (7×, 64/256px)

| Asset id (návrh) | Nahrádza | Popis |
|---|---|---|
| `icon_nav_map_64` | (žiadny súčasný icon, MapView tab nemá ikonu) | kompas + hviezda, kruhový rám |
| `icon_nav_events_64` | — | zvitok so zámkom |
| `icon_nav_diplomacy_64` | — | dve olivové ratolesti |
| `icon_nav_army_64` | — | prekrížený meč + štít |
| `icon_nav_battle_64` | — | prekrížené meče, hroty von |
| `icon_nav_chronicle_64` | — | otvorená kniha |
| `icon_nav_menu_64` | — | rovnoramenný kríž (dvojkríž) |

Pozn.: Godot dnes nemá sidebar-nav ekvivalent Reactu (žiadne prepínanie
celých obrazoviek cez ikony) — tieto sa dajú využiť na `TabContainer`
ikony pre `Armády`/`Diplomacia` taby (`Main.tscn:217-225`) a prípadne
na `devine_btn`/`skirmish_btn` v `ToolsRow`.

### 2.2 Chýbajúca 1 resource ikona

| Asset id | Popis |
|---|---|
| `icon_religion_64` | dvojitá krivka (Rím ↔ Konštantínopol) alebo zvon + váhy — pozri návrh v Vizuálnej sade, sekcia "Náboženstvo" |

Zvyšných 6 (zlato/jedlo/drevo/kameň/železo/prestíž) **už existuje** — pozri
gap-list, netreba generovať znova, len over kľúč `icon_gold_64` (známy
bug z tejto vetvy, viď `UPRAVY_PO_P0_IMPLEMENTACII.md`).

### 2.3 Sídelné budovy — 2 nové tiery

| Asset id | Popis |
|---|---|
| `marker_market_64` | stánky s vahami, otvorený trh |
| `marker_monastery_64` | kláštor s rozetovým oknom a krížom |

**Pozor:** toto sú v návrhu **typové** budovy (čo tam stojí), ale
súčasný `MapView.gd` má **prosperitné tiery** (small/medium/large podľa
čísla, nie podľa typu budovy) + samostatný fort indikátor. Pridanie
market/monastery ikon ako assetov je OK, ale ich **zapojenie** je
dizajnové rozhodnutie (viď gap-list bod 3) — negenerovať naslepo bez
rozhodnutia, ako sa určí, ktorá župa dostane trh vs. kláštor.

### 2.4 Dynastická pečať

| Asset id | Popis |
|---|---|
| `dynasty_seal_mojmir_v1` (256/1024px) | kruhová vosková pečať, dvojkríž na červenom poli, nápis "MOJMÍR II." — pre `EndScreen`/prípadnú Kroniku hlavičku |

---

## 3. Blokované na rozhodnutie (negenerovať, kým sa nepotvrdí)

### 3.1 Frakčné erby — 6× (Vizuálna sada)

Návrh má erby pre: **Župani, Cyrilometodskí kňazi, Byzantskí poslovia,
Nemeckí kolonisti, Maďarské zvyšky, Bogatovci**.

Toto je **iný zoznam frakcií**, než aké má `DiplomacyManager.gd`
(`moravia, franks, bavaria, hungary, poland, bohemia, byzantium`) —
6 emblémov pre tieto frakcie **už existuje** (`assets/icons/factions/
*_emblem_v1.png`). Pozri `CHYBAJUCA_GRAFIKA_NOVA_IDENTITA.md` bod 2 pre
presné mapovanie/rozpor a odporúčanie.

**Negenerovať**, kým nepadne rozhodnutie: nahradiť súčasných 6 emblémov
za tieto (herná zmena frakcií), alebo sú toto vnútro-moravské
frakcie/postavy (odkaz na eventovú dejovú líniu — Bogatovci, Cyrilometodskí
kňazi) **popri** existujúcich diplomatických frakciách — v tom prípade
treba 6 nových id, nie náhradu.

### 3.2 Unit siluety — 8× (2 frakcie × 4 typy)

Návrh: Moravania (zelená) a Maďari (hnedá) × Pešiak/Kopijník/Lukostrelec/
Jazda — farebne odlíšené podľa frakcie.

Súčasný stav: 6 assetov (`sil_infantry`, `sil_cavalry`, `sil_archer`,
`sil_commander`, `sil_magyar_horse`, `sil_shieldwall`) — **frakcie
nerozlišujú farbou**, sú univerzálne/dvojica špecifických (Devín).

**Otázka pred generovaním:** ideme na plnú 8-siluetovú maticu (viac
assetov, presnejšie battle view), alebo zostáva súčasný zjednodušený
6-asset set? Toto je aj herný rozsah (M8.3 fázová bitka teraz používa
`pick_ai_action`/kompozíciu, nie priamo frakčné siluety pre všetky 4
typy) — over súvis s `DALSI_KROK_M8.3_FAZOVA_BITKA.md` pred rozhodnutím.

---

## 4. Mimo rozsahu čistej grafiky (vyžaduje UI/dátovú prácu, nie len asset)

Tieto položky z mockupov **nie sú len chýbajúca grafika** — vyžadujú
zmenu v Godot scénach/dátach. Negenerovať ako "len obrázok", radšej
najprv rozhodnúť rozsah:

- **Loading Screen** — v Godote neexistuje samostatná scéna (React má
  `LoadingScreen.tsx`, Godot ide Menu → Briefing → Main priamo)
- **Kronika s farebnými medailónmi podľa typu udalosti** — dnešná
  `Chronicle` je plochý `RichTextLabel` (text log), nie štruktúrovaný
  zoznam s ikonami per-entry — treba dátovú zmenu (typ eventu → ikona)
- **Hlavné menu so 4 scenármi** (Prežitie/Konsolidácia/Zlatý vek/
  Mongolská skúška) — súčasný Godot MVP má **jednu** pevnú kampaň
  902-1000, žiadny výber scenára. Toto je stará Notion Game Design v2.1
  roadmapa (M1-M5 = len "Prežitie"), nie aktuálny rozsah.
- **Mapa s cestami, terénom a kompasom** — `MapView.gd` dnes kreslí
  polygóny žúp + rieku Dunaj (M8.4), ale žiadne cesty medzi župami ani
  kompas. Cesty/kompas sú pridateľné (podobný vzor ako river polygon),
  ale je to kódová úloha, nie len export obrázka.

---

## 5. Export špecifikácie (nezmenené, existujúci štandard)

Rovnaké ako doteraz — `_64`/`_256`/`_1024` PNG do
`godot/assets/icons/ui/` (ikony), `godot/assets/icons/factions/`
(emblémy), `godot/assets/battle/` (siluety, `_v1` suffix), registrovať
v `godot/data/art_map.json` **pod kľúčom zhodným s názvom súboru**
(vrátane `_64` suffixu — pozri známy `icon_gold`/`icon_gold_64` bug,
nerobiť tú istú chybu znova).
