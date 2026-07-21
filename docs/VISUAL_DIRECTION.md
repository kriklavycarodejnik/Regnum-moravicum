# Regnum Moravicum — Visual Direction

> Cieľ: prémiová **iOS-like** historická stratégia s vizuálnym jazykom **Age of Empires 2 DE**,
> filtrovaná cez estetiku **Veľkej Moravy 10. storočia**.

---

## 1. Referencie

| Vrstva | Referencia | Čo berieme |
|--------|------------|------------|
| Mapa / svet | AoE2 DE campaign maps | Textúry terénu, rieky, lesy, soft height, cesty |
| Boj | AoE2 DE battle view | Siluety jednotiek, dym, zástavy, terrain backdrop |
| UI chrome | iOS strategy apps + medieval UI kits | Veľké touch targets, glass/wood panels, clear hierarchy |
| Flavor | Moravian/Slavic manuscripts, Devín, Nitra rotunda | Orlica, zlaté bordúry, cyrilika, drevo + kameň |

## 2. Farebná paleta (Veľká Morava × AoE2)

| Token | Hex | Použitie |
|-------|-----|----------|
| `moravia-crimson` | `#8B1E2D` | Hráč, orlica, dôležité CTA |
| `byzantine-gold` | `#C9A227` | Akcenty, rámy, prestíž |
| `parchment` | `#E8DCC4` | Text, panely light |
| `oak-dark` | `#2A1F14` | Pozadie panelov |
| `oak-mid` | `#3D2E1F` | Hover / secondary |
| `forest-canopy` | `#2F4A28` | Lesy na mape |
| `meadow` | `#5A7A3A` | Polia |
| `danube` | `#3A6B7A` | Rieky |
| `stone-wall` | `#6B6560` | Hradištia, pevnosti |
| `magyar-steppe` | `#A67C52` | Nepriateľ / maďari |
| `sky-dusk` | `#4A3A4A` → `#2A2030` | Bojové nebe |

## 3. Mapa (fáza A — SVG upgrade, fáza B — Phaser tilemap)

### Fáza A (teraz)
- Viacvrstvový SVG: sky/haze, mountains, forests blobs, Danube, roads, settlements
- Hradište ikony podľa prosperity (veža → citadela)
- Loyalty ring (zelená / jantár / červená)
- Soft glow na vybranú župu, pulse na frontu vojny
- Zoom/pan (CSS transform) na touch

### Fáza B (neskôr)
- Phaser 3 tilemap + parallax layers
- Animated smoke on occupied zupy, river shimmer
- Unit markers marching on roads

## 4. Boj (fáza A — rich SVG scene, fáza B — animated sprites)

### Fáza A (teraz)
- Vyššia scéna (~220px): sky gradient, sun/moon, terrain depth
- 2 rady siluet jednotiek (pešiaci, lukostrelci, jazda) podľa composition
- Animácie: banner flutter, dust puffs, sword clash flash, morale bars
- Side labels + commander coat of arms

### Fáza B
- Spine/frame sprites, particle blood/dust, camera shake on phase resolve

## 5. UI chrome (iOS premium)

- Safe-area padding, 44px min touch
- Rounded panels 12–16px, subtle inner highlight
- Resource chips s ikonami (nie len text)
- Bottom tab bar na mobile (namiesto bočného sidebaru)
- SF-like system feel + Georgia/Cinzel pre tituly

## 6. Tech path

1. **Teraz**: React + upgraded SVG/CSS (žiadny nový engine)
2. **Stredne**: Phaser 3 canvas vnorený do React (Map + Battle only)
3. **Neskôr (voliteľné)**: Godot 4 export iOS, ak chceš App Store nativne

## 7. Asset pipeline

- AI koncepty (Flux/SD) → ručný cleanup do SVG/PNG atlas
- Unit silhouette set: infantry, archer, cavalry, spear (Moravia + Magyar)
- Building set: rotunda, wooden wall, stone tower, market, monastery
- UI icons: gold, food, wood, stone, iron, prestige, eagle

## 8. Definition of Done (vizuálny milestone)

- [ ] Mapa čitateľná na iPhone a iPad, „wow“ first impression
- [ ] Bitka vizuálne rozlíši terén a strany bez čítania textu
- [ ] UI vyzerá ako prémiová app, nie webový prototyp
- [ ] 60fps na modernom mobile (SVG/CSS animácie ľahké)
- [ ] Konzistentná paleta a typografia naprieč obrazovkami
