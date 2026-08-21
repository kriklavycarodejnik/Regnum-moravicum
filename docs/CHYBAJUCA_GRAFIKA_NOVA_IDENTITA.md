# Zoznam chýbajúcej grafiky — nová vizuálna identita

> Porovnanie: `claude.ai/design/p/f6012712-9388-4d4d-b1cc-6966df696c6e`
> (Vizuálna sada + 2× Návrhy obrazoviek) vs. overený aktuálny stav
> `godot/data/art_map.json` a súborov na disku (commit `2a17c0a`).
> Súvisiaci prompt: `ART_PROMPT_NOVA_VIZUALNA_IDENTITA.md`.

---

## 1. Navigačné ikony — 7× chýba úplne

| Ikona | Stav |
|---|---|
| Mapa, Udalosti, Diplomacia, Armády, Bitky, Kronika, Menu/Crest | ❌ **chýba všetkých 7** — Godot nemá sidebar-nav ekvivalent, ale dajú sa využiť na `TabContainer` taby a nástrojové tlačidlá |

## 2. Ikony zdrojov — 6/7 existuje, 1 chýba

| Ikona | Stav |
|---|---|
| Zlato | ⚠️ existuje súbor, ale kľúč v `art_map.json` je `icon_gold` bez `_64` — známy bug, pozri `UPRAVY_PO_P0_IMPLEMENTACII.md` |
| Jedlo, Drevo, Kameň, Železo, Prestíž | ✅ existujú (`icon_food_64`, `icon_wood_64`, `icon_stone_64`, `icon_iron_64`, `icon_prestige_64`) |
| Náboženstvo | ❌ **chýba** — najbližšie existujúce sú `icon_cross_latin_64`/`icon_cross_patriarchal_64` (iný účel — používa ich `ReligionAxis`, nie resource chip) |

## 3. Frakčné erby — 🔴 nesúlad, nie len chýbajúca grafika

**Návrh (6):** Župani, Cyrilometodskí kňazi, Byzantskí poslovia,
Nemeckí kolonisti, Maďarské zvyšky, Bogatovci

**Skutočné frakcie v `DiplomacyManager.gd`:** `moravia, franks, bavaria,
hungary, poland, bohemia, byzantium`

**Existujúce emblémy na disku** (`assets/icons/factions/`):
`bavaria_emblem_v1.png`, `bohemia_emblem_v1.png`, `byzantium_emblem_v1.png`,
`franks_emblem_v1.png`, `hungary_emblem_v1.png`, `poland_emblem_v1.png`,
`mojmir_dynasty_emblem_v1.png` — **7 emblémov, všetky pre existujúce
frakcie, kompletné.**

| Návrh | Zodpovedá dnešnej frakcii? |
|---|---|
| Byzantskí poslovia | ≈ `byzantium` (existuje emblém) |
| Maďarské zvyšky | ≈ `hungary` (existuje emblém) |
| Nemeckí kolonisti | žiadna priama zhoda (`franks`/`bavaria` sú najbližšie, ale nie identické) |
| Župani | žiadna zhoda — `moravia` je hráč sám, nie diplomatická frakcia |
| Cyrilometodskí kňazi | **neexistuje** ako frakcia v `DiplomacyManager` vôbec |
| Bogatovci | **neexistuje** ako frakcia — je to postava/dejová línia z portovaných eventov (`bogata_trial_916`, `bogata_uprising_917`), nie diplomatický subjekt |

**Prečo tento nesúlad vznikol:** presne tie isté 4 nezhodné mená
(Cyrilometodskí Kňazi, Bogatovci, Nemeckí Kolonisti, Župani) sú
`moodChanges` ciele z **archivovaného** `historicalEvents.ts` — narazili
sme na presne tento problém pri portovaní eventov (`_resolve_faction_id`
alias-mapovanie, oprava v `178e8e4`). Vizuálny návrh bol zjavne
zakotvený v tom istom staršom obsahovom modeli, nie v aktuálnom
`DiplomacyManager` zozname.

**Odporúčanie:** negenerovať 6 nových erbov naslepo. Namiesto toho
rozhodnúť:
- (a) toto sú **vnútro-moravské** postavy/frakcie (rada, cirkev,
  rody) — potrebujú nové id **popri** existujúcich 7 diplomatických
  emblémoch, nie namiesto nich, alebo
- (b) toto je zastaraný zoznam z inej fázy vývoja a stačí prekresliť
  existujúcich 7 emblémov v novom heraldickom štýle (zachovať frakcie,
  zmeniť len vizuál)

## 4. Sídelné budovy — 3/5 existuje, 2 chýbajú + koncepčný rozdiel

| Ikona | Stav |
|---|---|
| Osada (small), Hradisko (medium), Citadela (large) | ✅ existujú ako `marker_settlement_small/medium/large` |
| Trhovisko | ❌ chýba |
| Kláštor | ❌ chýba |

**Koncepčný rozdiel:** existujúci systém viaže marker na **prosperitu**
(číslo → small/medium/large), návrh viaže marker na **typ budovy**
(trh vs. kláštor vs. pevnosť — kvalitatívna vlastnosť župy). Toto nie
je len chýbajúca grafika — vyžaduje rozhodnutie, či/ako sa "typ budovy"
vôbec ukladá v `province` dátach (dnes tam nie je).

## 5. Siluety jednotiek — 6 existuje (univerzálne), 8 by znamenalo frakčnú maticu

| Existuje dnes | Návrh chce navyše |
|---|---|
| `sil_infantry`, `sil_cavalry`, `sil_archer`, `sil_commander`, `sil_magyar_horse`, `sil_shieldwall` (6, univerzálne/Devín-špecifické) | Moravania+Maďari × Pešiak/Kopijník/Lukostrelec/Jazda = 8, farebne odlíšené podľa frakcie |

Toto **nie je čisté doplnenie** — čiastočne prekrýva (`sil_infantry`
≈ univerzálny "Pešiak"), čiastočne rozširuje (frakčné farebné varianty
zatiaľ neexistujú). Rozsah závisí od M8.3/budúcich battle-view iterácií.

## 6. Dynastická pečať — chýba úplne

| Asset | Stav |
|---|---|
| Kruhová vosková pečať Mojmíra II. | ❌ chýba — najbližšie je `mojmir_dynasty_emblem_v1.png` (iný štýl, portrétový erb, nie pečať) |

## 7. Screen-level assety mimo čisto grafického rozsahu

Tieto položky z `Návrhy obrazoviek*.dc.html` vyžadujú UI/dátovú prácu
navyše k assetom — podrobnosti v `ART_PROMPT_NOVA_VIZUALNA_IDENTITA.md`
bod 4:

| Screen | Chýba |
|---|---|
| Loading Screen | celá scéna neexistuje v Godote |
| Kronika s farebnými medailónmi | `Chronicle` je plochý text log, nie štruktúrovaný zoznam |
| Hlavné menu so 4 scenármi | Godot MVP má len 1 pevnú kampaň (902-1000) |
| Mapa s cestami + kompasom | `MapView.gd` nemá cesty medzi župami ani kompas ikonu |

---

## Zhrnutie — čo je bezpečné generovať hneď

✅ **Áno, rovno:** 7 nav ikon, 1 religion resource ikona, 2 building
ikony (market/monastery — asset áno, zapojenie neskôr), 1 dynastická
pečať = **11 nových assetov bez otvorenej otázky**.

🔴 **Nie, kým sa nerozhodne:** 6 frakčných erbov (bod 3), 8-siluetová
matica (bod 5), všetky screen-level položky (bod 7).
