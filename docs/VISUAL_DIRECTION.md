# Regnum Moravicum — Visual Direction

> Cieľ: prémiová **iOS-like** historická stratégia s mapovým jazykom inšpirovaným **Age of Empires 2 DE**,
> filtrovaná cez estetiku **Veľkej Moravy 10. storočia (902–1000)**.
>
> **AI generovanie / narrative art:** [`ART_PROMPT_CANON.md`](./ART_PROMPT_CANON.md)  
> **M6 UI/UX art scope:** [`M6_UI_ART_SCOPE.md`](./M6_UI_ART_SCOPE.md)  
> **Manifest:** [`ASSET_MANIFEST.md`](./ASSET_MANIFEST.md)

---

## 0. Stav projektu (AS-IS → M6)

| Vrstva | Stav |
|--------|------|
| **Simulácia M1–M5** | Kompletná (tick, battle, war, diplomacy base, succession, religion drift, victory, campaign/armies). `SMOKE_PASS`. |
| **Župy** | **12** (vrátane samostatného Devína) |
| **Resources v kóde** | dnes `gold` + `prestige` → M6 doplní `food`, `wood`, `stone`, `iron` |
| **Devín 907** | Maďari víťazia (`winner=attacker`) — vizuál crisis, nie moravský triumf |
| **Narrative art A** | Style Master **Approved**; G2 masters **Approved** |
| **UI theme C** | `RegnumColors` + `RegnumThemeFactory` + Cormorant/Alegreya **Implemented** |
| **UI panely** | Main flat shell; ArmyUI existuje ale nie je v Main; M6 = plný chrome |
| **React** | **ARCHIVED** |

---

## 1. Tri vrstvy, jedna rodina

| Vrstva | Účel | Médium |
|--------|------|--------|
| **A — Narrative** | event art, portréty, hero views, battle covers, end screens | historical comic / illustrated chronicle |
| **B — Game world** | mapa, jednotky, budovy, markery | AoE2-like čitateľný terén + siluety |
| **C — UI chrome** | StatusBar, panely, 12–28 ikon, religion axis, touch 48px | iOS premium + parchment/wood |

---

## 2. Referencie

| Vrstva | Referencia | Čo berieme |
|--------|------------|------------|
| Mapa / svet | AoE2 DE campaign maps | Textúry terénu, rieky, lesy, soft height, cesty |
| Boj | AoE2 DE battle view | Siluety jednotiek, dym, zástavy, terrain backdrop |
| UI chrome | iOS strategy apps + medieval UI kits | Veľké touch targets (48px), wood panels, clear hierarchy |
| Flavor / narrative | Moravian/Slavic manuscripts, Devín, Nitra rotunda | Orlica, zlaté bordúry, drevo + kameň |
| Tone | Illustrated chronicle | Soft painted shading, muted royal earth |

---

## 3. Farebná paleta (kanonické hex)

| Token | Hex | Použitie |
|-------|-----|----------|
| `moravia-crimson` | `#8B1E2D` | Hráč, orlica, CTA, hostile |
| `byzantine-gold` | `#C9A227` | Akcenty, rámy, prestíž, Konštantínopol lean |
| `parchment` | `#E8DCC4` | Text, light fill |
| `oak-dark` | `#2A1F14` | Pozadie panelov |
| `oak-mid` | `#3D2E1F` | Secondary / hover |
| `forest-canopy` | `#2F4A28` | Lesy |
| `meadow` | `#5A7A3A` | Polia, high loyalty |
| `danube` | `#3A6B7A` | Rieky |
| `stone-wall` | `#6B6560` | Hradištia, icon stone |
| `magyar-steppe` | `#A67C52` | Maďari |
| `iron-grey` | `#4A4E52` | Železo, icon linework |
| `sky-dusk-top` | `#4A3A4A` | Bojové nebo |
| `sky-dusk-bot` | `#2A2030` | Bojové nebo |
| `royal-blue` | `#2C3E6B` | Moravský dvor |
| `byzantine-crimson` | `#9B1B30` | Byzantský dvor |
| `ivory` | `#F2E8D5` | Sakrálny accent |
| `warning` | `#C9902F` | Warning / medium loyalty |
| `success` | `#5A9C5A` | Positive feedback |

### Faction / religion

- **Morava:** earth + royal blue + gold + crimson  
- **Byzantium / Konštantínopol pólo:** gold + deep crimson + ivory  
- **Rím pólo:** cooler stone + muted blue-grey  
- **Steppe/Magyar:** dust brown + iron grey  

---

## 4. Typografia (UI)

| Rola | Font |
|------|------|
| Tituly | **Cormorant Garamond** |
| Body | **Alegreya** |
| Fallback | system sans |

Touch: **min 48×48** px (M6 iOS). Žiadny hover-only stav.

---

## 5. M6 UI shell (cieľová kompozícia)

```
MainMenu → New / Load / Settings / Quit
In-game:
  StatusBar: year·month | gold food wood stone iron prestige | religion axis | Next month | Save
  MapView (center) | Side tabs: Army | Diplomacy | Chronicle
  EventDialog (modal)
  BattlePanel (when war)
  NotificationFeed
  VictoryScreen / GameOverScreen
```

Detaily panelov a icon ID: **`M6_UI_ART_SCOPE.md`**.

---

## 6. Mapa (B)

### Fáza A (M6)
- Control/Polygon alebo Texture regióny — 12 žúp  
- Loyalty ring (success / warning / crimson)  
- Settlement marker podľa prosperity  
- Army dots; select glow; touch tooltip  
- Farby z `RegnumColors`  

### Fáza B (post-M6)
- Tilemap, river shimmer, marching markers  

---

## 7. Boj (B + A plate)

- Sky dusk gradient; siluety pešiak/luk/jazda × frakcia  
- Optional full-bleed: `battle_danube_composition` pre 907  
- Morale bars theme  
- **Výsledok vždy z BattleManager** — art nelže o Devíne 907  

---

## 8. UI chrome (C)

- Oak panels, gold hairline, crimson CTA  
- Resource **chips s ikonami** (6 keys po doplnení GameState)  
- Religion axis widget Rím ↔ Konštantínopol  
- Icon set: MVP **12**, extended → **28** (zoznam v M6_UI_ART_SCOPE)  
- Export: 256 → 64/128, transparent  

---

## 9. Asset pipeline (aktuálny)

| Krok | Status |
|------|--------|
| 1. Visual Style Master | **Approved** |
| 2–5. G2 locations/portraits/emblem/battle | **Approved** |
| 6. UI icons 12 | **Review** (G3) |
| 7. Map markers + battle silhouettes | Planned (M6 P3–P4) |
| 8. Wire `art_map.json` → Event/End/Loading | Planned |
| 9. Extended icons 13–28 | After shell |

Stavy: `Planned → Generating → Review → Approved → Implemented`.

---

## 10. Definition of Done

### Art foundation (teraz)
- [x] Style Master Approved  
- [x] Theme + fonts in Godot  
- [x] G2 masters Approved  
- [ ] UI icons MVP 12  

### M6 hrateľný vizuál
- [ ] StatusBar 6 resources + religion + Next  
- [ ] MapView 12 žúp  
- [ ] EventDialog + art fallback  
- [ ] ArmyPanel v shelli  
- [ ] DiplomacyPanel  
- [ ] Battle chrome  
- [ ] Victory / GameOver  
- [ ] MainMenu + Save/Load  
- [ ] Touch ≥ 48px  
- [ ] Smoke (+ neskôr m6 smoke) PASS  

---

## 11. Changelog

| Dátum | Zmena |
|-------|--------|
| 2026-07-22 | M6 AS-IS: 12 žúp, resources gold+prestige, G2 Review, odkaz `M6_UI_ART_SCOPE.md`, touch 48px, religion axis |
| 2026-07-22 | Zjednotenie s `ART_PROMPT_CANON.md` |
| staršie | AoE2 × iOS × Veľká Morava baseline |

*Posledná aktualizácia: 22. júl 2026*
