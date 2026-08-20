# Screenshot Trace Tool

Nástroj na vizuálnu QA hry Regnum Moravicum. Spustí hru v okennom režime
(display-backed), odohrá celú 10-minútovú trasu a po každom kroku uloží PNG
screenshot.

## Rýchle spustenie (jeden príkaz)

```bash
cd godot && bash tools/capture.sh
```

PNG súbory sa uložia do `godot/tools/screenshots/`. Každý beh prepíše
predchádzajúcu sadu (názvy sú stabilné, bez časovej pečiatky).

## Požiadavky

- **Godot 4.x** s grafickým výstupom (Metal/Vulkan/GL). **Nefunguje s
  `--headless`** — headless Godot nevytvára framebuffer, `get_image()` vracia
  `null` a capture zlyhá.
- Prepínač `--disable-vsync` (voliteľný, urýchli beh).
- Okno je automaticky minimalizované (`WINDOW_MODE_MINIMIZED`), aplikácia sa
  nedostáva do popredia.

## Čo testuje (7 krokov — celá trasa)

| # | Súbor | Stav hry | Čo kontrolovať |
|---|-------|----------|----------------|
| 1 | `01_MENU.png` | Hlavné menu | Pozadie, erb, tlačidlá „Nová hra“, „Načítať“, „Koniec“ |
| 2 | `02_BRIEFING.png` | Poslanie po „Nová hra“ | Portrét Mojmíra II., text poslania, tlačidlo „Rozumiem — vstúpiť do ríše“ |
| 3 | `03_COACH_1_3.png` | Coach 1/3 | Overlay „Klikni na Nitru“, mapa so šípkou na Nitru |
| 4 | `04_COACH_2_3.png` | Coach 2/3 | Overlay „Tvoje poslanie…“, tlačidlo „Rozumiem“ |
| 5 | `05_COACH_3_3.png` | Coach 3/3 | Overlay „Stlač Ďalší mesiac“, šípka na tlačidlo dole |
| 6 | `06_TURNREPORT.png` | Po „Ďalší mesiac“ | Karta mesačnej správy (zmeny zdrojov, narácia), tlačidlo „Pokračovať“ |
| 7 | `07_MAPA_PO_TAHU.png` | Mapa po zatvorení správy a udalosti | Mapa, župy, story line, bočný panel (HeroArt, armády, diplomacia) — žiadne popupy |

## Ako rýchlo prejsť screenshoty

1. Otvor adresár v prieskumníku (macOS):
   ```bash
   open godot/tools/screenshots/
   ```
   Súbory sú pomenované číselne (`01_` … `07_`), takže sa zoradia presne
   v poradí trasy — stačí ich prejsť zľava doprava / v poradí 1→7.

2. Pri každom kroku over dve veci:
   - **Obsah sedí so stavom** (viď tabuľka vyššie) — žiadna čierna/šedá
     obrazovka namiesto mapy, žiadny chýbajúci text.
   - **Žiadne vizuálne artefakty** — rozbité fonty, prekryté tlačidlá,
     chýbajúce ikony, orezaný text (najmä dlhé slovenské diakritiky).

3. Rýchly sanity check rozmerov/obsahu:
   ```bash
   ls -la godot/tools/screenshots/
   ```
   Každý PNG musí byť 1280×720 a „rozumná“ veľkosť — čisto čierny frame má
   pár KB, plný render stovky KB. Ak sú všetky súbory ~1–5 KB, capture bežal
   bez framebufferu (pravdepodobne `--headless`).

## Ako to funguje

Skript `extends SceneTree` (nahrádza default MainLoop):

1. Načíta `MainMenu.tscn` → screenshot `01_MENU`.
2. Zavolá `GameManager.reset()`, načíta `Briefing.tscn` → `02_BRIEFING`.
3. Načíta `Main.tscn` (coach krok 1/3) → `03_COACH_1_3`.
4. Vyberie Nitru + posunie coach na 2/3 → `04_COACH_2_3`.
5. Posunie coach na 3/3 → `05_COACH_3_3`.
6. Klikne „Ďalší mesiac“ → TurnReport (+ udalosť Korunovácia) → `06_TURNREPORT`.
7. Dismissne TurnReport, vyrieši udalosť (voľba A) → mapa → `07_MAPA_PO_TAHU`.

Architektúra: `_capture_step()` → `root.get_texture().get_image().save_png()`.

## Dôležité upozornenia

- **Nepoužívať `--headless`** — pozri Požiadavky.
- Skript používa `quit(0)` pri úspechu, `quit(1)` pri chybe (exit kód sa
  propaguje cez `capture.sh`).
- Ak sa capture nedá spustiť z agenta (napr. SSH bez displeja), spustite
  `bash tools/capture.sh` ručne na stroji s displejom — je to jediný príkaz,
  ktorý človek potrebuje.

## QA pravidlo (povinné pre P1 karty)

P1 karta sa neuzavrie bez sady screenshotov z tohto nástroja. Po každej P1
zmene spusti `bash tools/capture.sh` a pripoj/over 7 PNG (aspoň 6) pokrývajúcich
celú trasu menu → nová hra → coach → ďalší mesiac → TurnReport.
