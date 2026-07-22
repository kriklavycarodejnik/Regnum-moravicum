# Regnum Moravicum — Canonical Art Prompt

> **Zdroj pravdy pre AI generovanie assetov** (narrative art, portréty, lokality, erby, event scény).  
> UI chrome a herná mapa majú vlastné pravidlá nižšie (vrstvy B/C), ale zdieľajú **tú istú paletu a material culture**.  
>  
> Textový kánon (succession, religion, Devín 907, frakcie) je nadradený.  
> Machine-facing prompty = **anglicky**. Poznámky = slovensky.

**Súvisiace dokumenty**
- `docs/VISUAL_DIRECTION.md` — herný vizuál (mapa, boj, UI)
- `docs/M6_UI_ART_SCOPE.md` — M6 panely, resources, religion axis, icon ID
- `docs/ASSET_MANIFEST.md` — status assetov
- Notion: *🎨 Vizuálna biblia* → *Farebnosť a výtvarný štýl*, *Pravidlá konzistencie*
- Master assety: Planned → In Progress → Approved

**Workflow**
```
canon text → visual canon (tento súbor) → style/hero master asset → scene generation
```

---

## 0. Tri vrstvy, jedna rodina

| Vrstva | Účel | Médium | Prompt set |
|--------|------|--------|------------|
| **A — Narrative** | event art, portréty, hero views, battle covers, kronika | historical comic / illustrated chronicle | Master Style Block A |
| **B — Game world** | mapa, jednotky, budovy, siluety | AoE2-like terrain + readable silhouettes, rovnaká paleta | Style Block B |
| **C — UI chrome** | panely, resource chips, 28-icon set, typografia | iOS premium + parchment/wood | Style Block C (+ export specs) |

**Pravidlo:** jeden Visual Style Master drží paletu, line weight a material culture.  
**Nie** jeden prompt na všetky tri vrstvy.

---

## 1. Kanonická farebná paleta (hex kotvy)

> Jedna tabuľka. Ak sa líši starší `ART-DIRECTION.md`, **platí táto**.

| Token | Hex | Použitie |
|-------|-----|----------|
| `moravia-crimson` | `#8B1E2D` | hráč, orlica, CTA, kráľovské akcenty |
| `byzantine-gold` | `#C9A227` | prestíž, rámy, výšivky |
| `parchment` | `#E8DCC4` | text na dark, light panely, fill ikon |
| `oak-dark` | `#2A1F14` | pozadie panelov, drevo |
| `oak-mid` | `#3D2E1F` | hover / secondary wood |
| `forest-canopy` | `#2F4A28` | lesy, krajina |
| `meadow` | `#5A7A3A` | polia |
| `danube` | `#3A6B7A` | rieky, hmlové diaľky |
| `stone-wall` | `#6B6560` | hradištia, kameň |
| `magyar-steppe` | `#A67C52` | maďarský/stepný blok |
| `iron-grey` | `#4A4E52` | železo, linework ikon |
| `sky-dusk-top` | `#4A3A4A` | bojové nebo (vrch) |
| `sky-dusk-bot` | `#2A2030` | bojové nebo (spodok) |
| `royal-blue` | `#2C3E6B` | moravský dvor (plášte, zástavy) |
| `byzantine-crimson` | `#9B1B30` | byzantský dvor |
| `ivory` | `#F2E8D5` | byzantský / sakrálny accent |

### Faction palette blocks (do promptu podľa scény)

**Moravian court**
```
muted earth tones, royal blue #2C3E6B, aged gold #C9A227, deep crimson #8B1E2D,
weathered timber brown #2A1F14, cold stone gray #6B6560, parchment ivory #E8DCC4
```

**Byzantine influence**
```
imperial gold #C9A227, deep crimson #9B1B30, ivory #F2E8D5, muted purple,
ceremonial glow, restrained jewel accents (no neon)
```

**Steppe / Magyar opponent**
```
leather and dust browns #A67C52, iron grey #4A4E52, cold stone, muted red accents,
weathered nomadic materials, no royal blue dominance
```

---

## 2. Typografia (len UI — nie do image promptov)

| Rola | Font | Poznámka |
|------|------|----------|
| Tituly / display | **Cormorant Garamond** | serif, kronikársky charakter |
| Body / UI | **Alegreya** | čitateľné dlhé texty |
| Fallback systém | SF Pro / system sans | len technické labely, ak treba |

> Cinzel / Playfair / Inter zo starších draftov = **deprecated** pre nový UI.  
> **Nikdy** nepíš názvy fontov do image promptu (artefakty textu).

---

## 3. Obdobie a material culture (MVP 902–1000)

**Positive anchors**
```
Great Moravia / early 10th-century Central Europe material culture:
wooden palisades, early stone churches and rotundas, thatched longhouses,
mail and lamellar armor, round shields, spears, seax knives, horse archery on the steppe side,
Byzantine silk and gold embroidery only on high nobility, riverside oak forests, Morava/Danube valleys
```

**Hard bans (obdobie)**
```
full gothic plate armor, late gothic fairy-tale towers, baroque or renaissance interiors,
gunpowder, firearms, modern clothing, oversized fantasy crowns
```

**Kánon bitiek:** Devín / Dunaj 907 — **Maďari víťazia**; vizuál nie je moravský triumfálny plakát.

---

## 4. Master Style Block A — Narrative (vlož do KAŽDÉHO narrative promptu)

```
Historical comic illustrated chronicle of early medieval Central Europe,
refined ink linework with soft painted shading, parchment texture,
muted earthy royal palette (anchors: #8B1E2D crimson, #C9A227 gold,
#E8DCC4 parchment, #2A1F14 oak, #2F4A28 forest, #3A6B7A danube,
#6B6560 stone), dramatic single-source natural light (dawn, dusk, or torch),
Great Moravia / early 10th-century Slavic material culture
(wooden palisades, early stone rotunda churches, mail and lamellar,
round shields, spears, seax), weathered lived-in textures,
strong silhouettes, restrained composition with negative space,
subtle desaturation, cinematic but non-photoreal, no oversaturated fantasy,
no cel-shading, no modern UI, no anachronistic armor or architecture
```

### Negative / Avoid List A

```
low-poly, cartoon proportions, flat vector clipart, anime, neon colors,
generic high fantasy (dragons, elves, glowing magic), full plate armor,
late gothic towers, baroque interiors, photorealism, plastic glossy render,
oversaturated colors, modern clothing, modern fonts or UI overlays,
watermark, text artifacts, blurry, stock-photo look, cel-shading
```

---

## 5. Style Block B — Game world (mapa / jednotky)

```
Top-down / slight-iso strategy map language inspired by classic historical RTS terrain readability
(not a screenshot clone): soft height, readable biomes, clear settlement silhouettes,
same Regnum Moravicum palette anchors, early 10th-century Slavic fortifications,
unit markers as strong silhouettes (infantry, archer, cavalry), no photoreal clutter,
no modern UI chrome in the plate, subtle atmosphere haze
```

### Negative B

```
photoreal satellite map, cluttered UI, neon fog of war, fantasy creatures,
anachronistic castles, low-poly mobile placeholder look, illegible unit blobs
```

---

## 6. Style Block C — UI chrome & icons

```
Premium mobile strategy UI chrome: dark oak panels #2A1F14, parchment text #E8DCC4,
byzantine-gold #C9A227 hairline borders, moravia-crimson #8B1E2D CTA,
12–16px rounded corners, large touch targets, subtle inner highlight,
resource chips with clean icons, no clutter
```

### Icon sub-block (28-icon sprite / heraldic marks)

```
Single heraldic or UI icon, fine manuscript linework, clean silhouette,
even diffused light, no strong drop shadow, reads clearly at 24px,
iron-grey #4A4E52 linework, parchment #E8DCC4 fill, optional oxblood/gold accent,
centered, generous padding, flat background
```

### Icon export specs

| Parameter | Value |
|-----------|--------|
| Master size | 256×256 px |
| Safe padding | 10–12 % |
| Atlas cell (game) | 64×64 / 128×128 |
| Variants | outline + filled |
| Background | transparent **or** flat parchment (jedno per set) |
| No | gradients, heavy drop shadow, micro-detail that dies at 24px |

---

## 7. Šablóna promptu (Narrative A)

```
[SUBJECT / SCENE — concrete, period-accurate]
+
[MASTER STYLE BLOCK A]
+
[COMPOSITION — e.g. wide establishing shot / 3/4 bust portrait]
+
[LIGHT — dawn mist / torchlit interior / Greek fire river light]
+
[PALETTE — faction block + hex anchors]
+
[TECH — aspect ratio, no text, clean margins]
+
[NEGATIVE LIST A]
+
[REF — style master / character master path or description]
```

### Tech defaults

| Asset type | Aspect | Notes |
|------------|--------|--------|
| Hero location / event BG | 16:9 | leave sky/edge crop room |
| Portrait bust | 3:4 | plain dark parchment-toned BG |
| Emblem / icon | 1:1 | flat BG or transparent intent |
| Battle cover | 21:9 or 16:9 | wide cinematic |

Po schválení hero referencie: **lock seed** (ak provider podporuje) + **image reference** pre celý batch.

---

## 8. Odporúčané modely (OpenRouter / FAL — podľa dostupnosti)

| Účel | Model (preferencia) | Poznámka |
|------|---------------------|----------|
| Hero BG, atmosféra, style master | **Flux.2 Pro** (alebo aktuálny Flux Pro na OR/FAL) | style/ref lock naprieč batchom |
| Portréty / identity edit | **Gemini image (multi-turn)** / ekvivalent „Nano Banana“ | same face, new pose/emotion |
| Moodboard only | Grok Imagine / rýchly Flux Schnell | **nie** production kanon |
| Legacy local script | `projects/regnum-moravicum/image_gen.py` (FAL Flux) | default štýl = chronicle; ostatné len explorácia |

V Notion drž skôr **účel** (`primary_background`, `identity_edit`) než marketingový názov modelu.

**Production default štýl:** illustrated chronicle (Block A).  
Komiks-vibrant / čistá byzantská mozaika / full realist oil = **iba moodboard**, nie Approved kanon.

---

## 9. Ready-to-paste prompty

### 9.1 Visual Style Master (priorita 1)

```
Visual style reference sheet for an alternate early medieval Slavic empire (Great Moravia, c. 902–1000):
six small panels on one parchment-toned page showing (1) fortified hilltop dvorec at dawn,
(2) three-quarter noble bust, (3) river fortress cliff, (4) steppe horse archer opponent,
(5) torchlit timber-and-stone throne hall with subtle Byzantine textiles,
(6) simple heraldic emblem study — unified historical comic / illustrated chronicle look,
refined ink linework, soft painted shading, muted earthy royal palette anchors
#8B1E2D #C9A227 #E8DCC4 #2A1F14 #2F4A28 #3A6B7A #6B6560, dramatic natural light,
strong silhouettes, subtle desaturation, cinematic non-photoreal
+ [NEGATIVE LIST A]
+ aspect 3:2, no text labels, no modern UI, clean margins
```

### 9.2 Župný dvorec — dawn establishing (BG)

```
A fortified wooden and stone knieža's dvorec on a hilltop overlooking a Moravian river valley at dawn,
smoke rising from a longhouse, palisade walls, early autumn mist in the lowlands, early 10th century
+ [MASTER STYLE BLOCK A]
+ wide establishing shot, slightly elevated three-quarter aerial angle
+ soft golden dawn light breaking through mist, long shadows
+ palette: Moravian court block + anchors #C9A227 #2F4A28 #E8DCC4 #2A1F14
+ aspect 16:9, no text, no UI, clean edges for crop
+ [NEGATIVE LIST A]
```

### 9.3 Nitra — Master Hero View

```
Early medieval Nitra as capital of a powerful Slavic kingdom, fortified hilltop center,
wooden and stone fortifications in transition, early church/rotunda and royal structures,
strong skyline, Morava basin landscape, cinematic panoramic city view
+ [MASTER STYLE BLOCK A]
+ wide panoramic hero shot, elevated viewpoint
+ clear late-day side light, atmospheric depth haze
+ palette: Moravian court + #3A6B7A distant water, #6B6560 stone
+ aspect 16:9
+ [NEGATIVE LIST A] + late gothic mega-castle, renaissance streets, modern city
```

### 9.4 Devín — Master Fortress View

```
Dramatic early medieval fortress on a rocky cliff above the Danube, defensive stronghold
of a Slavic kingdom, rugged terrain, timber-stone military architecture, strategic river position,
stormy heroic but grim atmosphere (frontier defense, not triumphal parade)
+ [MASTER STYLE BLOCK A]
+ fortress panorama, low storm light, iron and river tones
+ palette: stone #6B6560, danube #3A6B7A, oak-dark, muted crimson banners only as accents
+ aspect 16:9
+ [NEGATIVE LIST A] + fairy-tale towers, late gothic fantasy castle
```

### 9.5 Bitka pri Dunaji / Devín 907 — Battle Composition Master

```
Epic early 10th-century battle on the Danube frontier: Slavic infantry shield wall and fortifications
under pressure from steppe horse archers and cavalry; burning ships; Greek fire orange on the river;
dramatic smoke; disciplined vs mobile contrast; wide cinematic composition; outcome reads as
steppe breakthrough / fortress crisis (not a Moravian victory poster)
+ [MASTER STYLE BLOCK A]
+ ultra-wide battle cover, layered depth (river / ships / walls / sky)
+ light: Greek fire orange + smoke grey + iron steel, dusk sky #4A3A4A to #2A2030
+ palette: magyar-steppe #A67C52 vs moravia-crimson accents, danube, iron-grey
+ aspect 21:9 or 16:9
+ [NEGATIVE LIST A] + fantasy monsters, firearms, full gothic plate armies, photoreal war photography
```

### 9.6 Mojmír II. — Master Portrait

```
Three-quarter bust portrait of an early medieval Slavic king around age 30,
dark shoulder-length hair, short trimmed beard, solemn intelligent face,
dark blue royal cloak #2C3E6B with subtle gold #C9A227 embroidery, Byzantine influence restrained,
noble but disciplined presence, mail or rich textile visible at collar — not full plate
+ [MASTER STYLE BLOCK A]
+ close-up bust, 3/4 angle, plain dark parchment-toned background
+ single-source side light, Rembrandt-style shadow on far cheek
+ palette: royal-blue, byzantine-gold, parchment, oak-dark
+ aspect 3:4, no text, no crown overload
+ [NEGATIVE LIST A] + anime, neon, oversized fantasy crown, photorealism
```

### 9.7 Theodora — Master Portrait

```
Byzantine princess, elegant noblewoman, composed expression, dark hair with imperial styling,
rich but restrained Byzantine dress, gold #C9A227 and deep crimson #9B1B30 accents,
refined jewelry, clearly distinct from Moravian court dress
+ [MASTER STYLE BLOCK A]
+ 3/4 bust portrait, plain dark background
+ soft regal side light
+ palette: Byzantine influence block
+ aspect 3:4
+ [NEGATIVE LIST A] + fantasy sorceress, anime princess, modern makeup, glitter
```

### 9.8 Árpád — Master Portrait

```
Steppe war leader, stern weathered face, braided or wind-worn dark hair,
nomadic military clothing, leather and fur layers, horse-archer culture cues,
fierce but historically grounded presence — visual contrast to Mojmír II
+ [MASTER STYLE BLOCK A]
+ 3/4 bust portrait, plain darker dusty background
+ hard frontier side light
+ palette: Steppe / Magyar block #A67C52 #4A4E52
+ aspect 3:4
+ [NEGATIVE LIST A] + horned viking helmet, fantasy barbarian, gothic armor
```

### 9.9 Kráľovský znak Mojmírovcov — Master Emblem

```
Early medieval Slavic royal emblem, clean heraldic design, strong recognizable central symbol
suitable for shield, banner and seal, regal but historically grounded, historical heraldry illustration
+ [MASTER STYLE BLOCK A] adapted for emblem clarity
+ centered emblem sheet, flat or parchment ground, no scenic background
+ even diffused light, high silhouette readability
+ palette: #8B1E2D #C9A227 #E8DCC4 #2A1F14
+ aspect 1:1
+ [NEGATIVE LIST A] + modern logo, neon, overcomplicated fantasy crest, glossy vector branding
```

### 9.10 UI icon example (raven / sword mark)

```
A single heraldic icon of a raven perched on a sword, fine manuscript linework,
suitable for a UI icon set, clean silhouette
+ [Icon sub-block C]
+ centered, no background scene
+ even diffused light
+ iron-grey linework, parchment fill, oxblood accent #8B1E2D
+ [NEGATIVE LIST A] + no gradients, no drop shadow, no micro-noise
```

### 9.11 Moravský kráľovský dvor — Interior Master

```
Interior of an early medieval Slavic royal court, throne hall with subtle Byzantine influence,
banners, carved timber, stone structure, royal textiles, solemn ceremonial atmosphere
+ [MASTER STYLE BLOCK A]
+ medium-wide interior establishing shot, readable throne axis
+ candlelight amber + soft ceremonial glow
+ palette: Moravian court + gold embroidery accents
+ aspect 16:9
+ [NEGATIVE LIST A] + baroque palace, gigantic high-fantasy throne room, gothic cathedral clone
```

---

## 10. Pravidlá konzistencie (operačné)

1. **Jazyk:** SK poznámky / EN prompty. Bez miešania v jednom prompt poli.
2. **Postavy:** Master Portrait + (ideálne) Full Body Reference pred batch scénami.  
   Meniť smieš: póza, emócia, svetlo, prostredie, poškodenie výstroja.  
   Nemení sa bez nového masteru: tvár, vlasy, dominantná paleta, kľúčový symbol.
3. **Lokality:** po Approved Master View negenerovať Nitra/Devín/Bratislava „od nuly“.
4. **Erby:** najprv master emblem → shield / banner / seal.
5. **Stavy assetu:** `Planned → In Progress → Approved`.
6. **Naming:** `mojmir_ii_master_portrait_v1`, `devin_master_fortress_view_v2`.
7. **Ref chain:** Style Master → Location/Portrait masters → scene variants.
8. **Devín 907:** vizuálny tón krízy / stepného prielomu, nie moravské víťazstvo.

---

## 11. Definition of Done (vizuálny kanon)

- [ ] Visual Style Master schválený (Approved)
- [ ] Hex paleta zafixovaná v Godot theme + web CSS tokens
- [ ] Mojmír II / Theodora / Árpád master portraits Approved
- [ ] Nitra / Devín / Bratislava / dvor master views Approved
- [ ] Mojmírovci emblem + 1 banner variant
- [ ] Battle composition master (Dunaj/Devín) Approved
- [ ] 28-icon set v jednom line weight
- [ ] Žiadny production asset mimo Block A (narrative) bez ref na master
- [ ] M6: UI icons MVP 12 + StatusBar resource chips + religion axis art
- [ ] M6: G2 masters Approved a napojené cez art_map (Event/End/Battle)

---


---

## 12. M6 alignment (UI hrateľnosť)

> Logika M1–M5 je hotová. Grafika M6 **obsluhuje** simuláciu, nemeniu tick/battle math.

### Resources (StatusBar chips)

| key | icon id | Stav v GameState (AS-IS) |
|-----|---------|---------------------------|
| gold | `icon_gold` | existuje |
| prestige | `icon_prestige` | existuje |
| food | `icon_food` | **M6 doplniť** |
| wood | `icon_wood` | **M6 doplniť** |
| stone | `icon_stone` | **M6 doplniť** |
| iron | `icon_iron` | **M6 doplniť** |

Kým kód nedoplní kľúče, UI môže zobrazovať `0` — ikony pripraviť vopred (G3).

### Religion axis

- UI: track −100…+100 (alebo mapovanie podľa `ReligionManager`)
- Ikony: `icon_cross_latin` (Rím), `icon_cross_patriarchal` (Konštantínopol)
- Farby: Rome = cooler stone/blue-grey; Constantinople = gold + byzantine-crimson

### Povinné UI ikony MVP (12) — G3

`icon_gold`, `icon_food`, `icon_wood`, `icon_stone`, `icon_iron`, `icon_prestige`,
`icon_eagle`, `icon_cross_latin`, `icon_cross_patriarchal`, `icon_sword`, `icon_shield`, `icon_scroll`

Extended 13–28 (diplomacia, army actions, save): pozri `M6_UI_ART_SCOPE.md` §4.

### G2 narrative → M6 wire

| Asset | M6 použitie |
|-------|-------------|
| portréty | EventDialog, succession, dynasty UI |
| nitra/devin/bratislava/court | province focus, loading, chronicle header |
| emblem | MainMenu, StatusBar player mark, diplomacy Morava |
| battle_danube | BattlePanel / 907 scenario / GameOver crisis BG |

Wire výhradne cez `godot/data/art_map.json`.

### Touch

Min **48×48** px hit target; žiadny hover-only feedback.


## 13. Changelog

| Dátum | Zmena |
|-------|--------|
| 2026-07-22 | v1 — kanonický art prompt: vrstvy A/B/C, hex kotvy, ready-to-paste masters |
| 2026-07-22 | v1.1 — M6 alignment: resources/religion/icons/wire; odkaz M6_UI_ART_SCOPE |

*Posledná aktualizácia: 22. júl 2026*
