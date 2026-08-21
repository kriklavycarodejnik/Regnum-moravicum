# Ďalší krok — M8.4: Polygon mapa (AoE2-štýl)

> **Toto je inštrukcia pre implementáciu, nie hotový kód.**

---

## 0. Kontext — toto je už dávnejšie naplánované, nie nový nápad

`docs/VISUAL_DIRECTION.md` §6 delí mapu na:
- **Fáza A (M6)** — hotová: kruhové markery, loyalty ring, settlement
  marker, army dots
- **Fáza B (post-M6)** — *"Tilemap, river shimmer, marching markers"* —
  toto je presne M8.4, len sa naň doteraz nedostalo

`MapView.gd` navyše **už dnes kreslí jednu polygónovú vec** — rieku
Dunaj (riadky 143-156):
```gdscript
var river := PackedVector2Array([...])
draw_colored_polygon(river, river_col)
```
Mechanizmus (`draw_colored_polygon` s `PackedVector2Array`) je teda
overený a funguje. Netreba nový rendering systém.

---

## 1. Kľúčové rozhodnutie — procedurálne polygóny, nie ručne kreslené hranice

Pôvodná úvaha („treba nakresliť 12 skutočných hraníc žúp") by vyžadovala
nové dáta a niekoľko kôl vizuálneho ladenia (kto to nakreslí, ako sedia
susedné hranice na seba). **Namiesto toho:** vygenerovať nepravidelný
mnohouholník **procedurálne** z existujúcich dát (`x`, `y`, `r` v
`map_layout.json`, ktoré už máme pre všetkých 12 žúp) — deterministicky
podľa `pid`, aby tvar bol pri každom prekreslení rovnaký (nie blikajúci
šum).

**Prečo je to lepšie riešenie pre údržbu:** žiadne nové dátové súbory,
žiadna ručná autorská práca na 12 tvaroch, žiadne riziko, že susedné
polygóny budú vyzerať rozbité. AoE2-štýl teritórium aj tak nie je
geograficky presné — je to štylizovaná „rozmazaná" hranica vplyvu, nie
kartografia.

**Súbor:** `godot/scenes/map/MapView.gd`

Pridať helper funkciu:
```gdscript
func _province_polygon(pid: String, cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 10
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pid)
	for i in range(n):
		var angle: float = (float(i) / float(n)) * TAU
		var jitter: float = 1.0 + rng.randf_range(-0.18, 0.18)
		var rr: float = r * 1.35 * jitter
		pts.append(Vector2(cx + cos(angle) * rr, cy + sin(angle) * rr))
	return pts
```
`RandomNumberGenerator` s pevným `seed` (z `hash(pid)`) zaručuje, že
tvar župy je pri každom `_draw()` volaní identický — nemení sa medzi
prekresleniami.

---

## 2. Kde presne prepojiť (nahradiť fill kruhu, nie odstrániť overlaye)

**Súbor:** `godot/scenes/map/MapView.gd`, `_draw()`, sekcia okolo
riadkov 198-232 (marker/settlement blok — presné čísla sa mohli od
poslednej verifikácie mierne posunúť, over pred úpravou).

Aktuálne dve vetvy kreslia kruh ako fill:
```gdscript
if has_art:
    ...
    draw_circle(center, r + 1.0, C.OAK_DARK)      # ← toto nahradiť
    draw_texture_rect(tex, dest, ...)
    ...
else:
    ...
    draw_circle(center, r, fill)                    # ← a toto nahradiť
    ...
```

Nahradiť oba `draw_circle(center, ...)` fill-volania za:
```gdscript
var poly := _province_polygon(pid, cx, cy, r)
draw_colored_polygon(poly, <rovnaká farba, čo mala predtým draw_circle>)
```

**Čo NECHAŤ bezo zmeny (zámerné obmedzenie rozsahu pre v1):**
- Všetky overlaye — `draw_arc()` pre loyalty ring, threat ring
  (`< 30 loyalty` z P1.5), selection/hover ring — zostávajú kruhové,
  centrované na `(cx, cy)` s polomerom `r`. Vizuálne to funguje ako
  „glow okolo teritória", netreba ich meniť na polygónový obrys.
- Settlement ikona, fort indikátor, army dot, label — bezo zmeny.
- **Hit-testing** (`_hit_test()`, riadky 291-306) — zostáva kruhový
  (`d <= r + 6.0`). Klikacia oblasť sa nebude presne zhodovať s
  nepravidelným okrajom polygónu na okrajoch — to je akceptovateľné
  zjednodušenie pre v1 (bežné aj v komerčných strategických hrách),
  presný point-in-polygon hit-test nechať ako prípadné v2 vylepšenie.

---

## 3. Akceptačné kritériá

- [ ] Každá zo 12 žúp má nepravidelný, „ručne pôsobiaci" tvar namiesto
      dokonalého kruhu
- [ ] Tvar je **stabilný** medzi prekresleniami (queue_redraw() viackrát
      za sebou → rovnaký polygón, nie flikajúci šum) — over vizuálne
      alebo tým, že `_province_polygon()` je čistá funkcia bez
      globálneho RNG stavu
- [ ] Loyalty ring, threat ring, selection ring, settlement/fort/army
      markery a label vyzerajú rovnako ako predtým (len fill pod nimi
      sa zmenil)
- [ ] Klikanie na provinciu funguje rovnako ako predtým (kruhový
      hit-test nezmenený)
- [ ] Rieka Dunaj (existujúci `draw_colored_polygon` blok) zostáva
      bezo zmeny

## 4. Ako overiť

```bash
cd godot
bash tools/check_all.sh
```
Toto je čisto vizuálna zmena v `_draw()` — smoke testy/TS ju nevedia
zmysluplne overiť. **Nutné manuálne vizuálne overenie** (spustiť hru,
pozrieť mapu) — ideálne priložiť screenshot pred/po.

## 5. Odhad

Vzhľadom na bod 1 (procedurálne, žiadne nové dáta) — jedna funkcia +
2 nahradené volania v `_draw()`. Realisticky hodina-dve, nie 2-3 dni z
pôvodného hrubého odhadu. Ak sa neskôr ukáže, že procedurálny tvar
vyzerá zle pri konkrétnych župách (napr. prekrýva susedné mesto), dá sa
doladiť úpravou `n`/`jitter`/`1.35` multiplikátora — stále bez nových dát.
