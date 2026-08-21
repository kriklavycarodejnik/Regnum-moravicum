# Screenshot Trace Tool

Nástroj na vizuálnu QA hry Regnum Moravicum. Spustí hru v okennom režime
(display-backed), odohrá celú trasu a po každom kroku uloží PNG screenshot.

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

## Čo testuje (7 krokov — integračný gate)

| # | Súbor | Stav hry | Čo kontrolovať |
|---|-------|----------|----------------|
| 1 | `01_MENU.png` | Hlavné menu | Pozadie, erb, tlačidlá „Nová hra“, „Načítať“, „Koniec“ |
| 2 | `02_BRIEFING.png` | Poslanie po „Nová hra“ | Portrét Mojmíra II., text poslania, tlačidlo „Rozumiem — vstúpiť do ríše“ |
| 3 | `03_KLIK_NA_NITRO.png` | Klik na Nitru (panel výberu vyplnený) | HeroArt, názvy žúp, vyplnený panel so zdrojmi a ilustráciou |
| 4 | `04_TURNREPORT.png` | Mesačná správa po „Ďalší mesiac“ | Karta mesačnej správy (zmeny zdrojov, narácia), threat clock |
| 5 | `05_EVENT_903.png` | Event 903/01 Pápežské posolstvo | Titul, telo eventu, **všetky 3 voľby (A/B/C) plne viditeľné**, event art |
| 6 | `06_MAPA_906.png` | Mapa v roku 906 s threat markermi | Threat markery na župách, threat clock, clean map view |
| 7 | `07_DEVIN_MODAL.png` | Devín prepare modal 907/01 | Devín špeciálny modal, text varovania, tlačidlo „Pripraviť obranu“ |

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
   Každý PNG musí byť 1280×720 (výnimka: 05_EVENT_903 môže byť 1280×960 —
   bol zachytený pri dočasne zväčšenom okne, aby sa voľby zmestili).
   „Rozumná“ veľkosť — čisto čierny frame má pár KB, plný render stovky KB.
   Ak sú všetky súbory ~1–5 KB, capture bežal bez framebufferu
   (pravdepodobne `--headless`).

## Ako to funguje

Skript `extends SceneTree` (nahrádza default MainLoop):

1. Načíta `MainMenu.tscn` → screenshot `01_MENU`.
2. Načíta `Briefing.tscn` → `02_BRIEFING`.
3. Načíta `Main.tscn`, vyberie Nitru → `03_KLIK_NA_NITRO`.
4. Klikne „Ďalší mesiac“ → TurnReport → `04_TURNREPORT`.
5. Posunie rok na 903/01, dočasne zväčší okno na 1280×960, skryje
   ChroniclePanel a NotificationFeed, vyvolá event → `05_EVENT_903`.
6. Vyrieši event, posunie rok na 906/01 → `06_MAPA_906`.
7. Posunie rok na 907/01, otvorí Devín modal → `07_DEVIN_MODAL`.

Architektúra: `_capture_step()` → `root.get_texture().get_image().save_png()`.

## Dôležité upozornenia

- **Nepoužívať `--headless`** — pozri Požiadavky.
- Skript používa `quit(0)` pri úspechu, `quit(1)` pri chybe (exit kód sa
  propaguje cez `capture.sh`).
- Ak sa capture nedá spustiť z agenta (napr. SSH bez displeja), spustite
  `bash tools/capture.sh` ručne na stroji s displejom — je to jediný príkaz,
  ktorý človek potrebuje.
- Krok 5 dočasne zväčšuje okno na 1280×960 (približne o 240px viac na výšku).
  Po capture sa okno vráti na 1280×720. Výsledný PNG bude mať 1280×960 —
  to je zámer, aby boli eventové voľby plne viditeľné. Pre ostatné kroky
  je výstup 1280×720.

## QA pravidlo (povinné pre P1 karty)

P1 karta sa neuzavrie bez sady screenshotov z tohto nástroja. Po každej P1
zmene spusti `bash tools/capture.sh` a pripoj/over 7 PNG pokrývajúcich
celú trasu menu → nová hra → coach → ďalší mesiac → event → mapa → Devín.