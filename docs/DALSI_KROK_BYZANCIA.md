# Ďalší krok — Byzancia ako frakcia + drobný cleanup guardu

> **Stav implementácie (overené k 21. 8. 2026, commit `9898b1c`):**
> - `DiplomacyManager.gd:30`: Byzancia je zavedená ako 7. frakcia (`"byzantium": {"name": "Byzantská ríša", "mood": 50.0, "relations": {}}`).
> - `EventManager.gd:468-470`: `_resolve_faction_id()` správne mapuje aliasy `byzantium`, `byzantskí`, `konštantínopol` na `"byzantium"`.
> - **Čo z dokumentu ešte platí / zostáva otvorené:** Rozhodnutie o Byzancii (bod 2) už prebehlo a je implementované (`DiplomacyManager.gd:23-35`, `EventManager.gd:463-470`). Ako platné a otvorené (s nízkou prioritou) zostáva odporúčanie z bodu 3 (čistenie / zjednotenie tvaru guardu v `HungarianWarScenario.gd:85` vs `WarManager.gd:60`). Text nižšie slúži ako archív rozhodnutia.

---

## 1. Overený stav (commit `564adfa`, nezávisle overené)

| Kontrola | Výsledok |
|---|---|
| `Main.tscn` headless boot | Čisté, bez chyby (predtým padalo na chýbajúcom `ChoiceC`) |
| Duplicita `choices.size() >= 3` v `Main.gd` | Vyčistené, 1 výskyt |
| Smoke M5 (`tools/smoke_test.gd`) | `SMOKE_PASS`, `Devin 907: winner=attacker` (kánon drží) |
| Smoke M6 (`tools/smoke_test.m6.gd`) | `SMOKE_M6_PASS` |
| TS testy (`npm run test`) | 305/305 |
| 1.1 `nextEvent`→`next_event` | ✅ 0 camelCase, 4 snake_case v `events_catalog.json` |
| 1.3 `zupaLoyalty` | ✅ aplikuje sa v `resolve_choice()` |
| 2.1 `PROVINCE_DEVIN := "devin"` | ✅ vrátane obojsmernej susednosti `devin.json` ↔ `nitra.json` |
| 2.2A/B (vekový gate, story line) | ✅ |

**Jediné dva otvorené body:** 1.2 Byzancia (rozhodnutie) a 2.3 tvar guardu (cleanup, nízka priorita).

---

## 2. Otvorené rozhodnutie — Byzancia (1.2)

### Zistenie
`_resolve_faction_id()` v `godot/scripts/managers/EventManager.gd` mapuje
`"byzantium"`/`"byzantskí"`/`"konštantínopol"` na `""` → efekt sa ticho
zahodí, lebo `DiplomacyManager._ensure_default_factions()` nemá
Byzanciu medzi svojimi 6 frakciami (`moravia/franks/bavaria/hungary/poland/bohemia`).

Toto je **najväčšia jednotlivá skupina** v portovaných `moodChanges` —
10 z 25 výskytov (aliancia s Levom VI., byzantská ponuka sobáša, celá
svadobná dejová línia 906–907). Bez frakcie zostáva táto línia mechanicky
bez dôsledkov — hráč dostane text, ale žiadny vzťahový efekt.

### Odporúčanie: **Možnosť A — pridať Byzanciu ako 7. frakciu**

Dôvody:
- Malý, izolovaný zásah (jeden nový záznam v jednom dictionary).
- `DiplomacyPanel.gd` (riadok 92) volá `diplomacy_manager.list_factions()`
  generickycky — nová frakcia sa v UI zobrazí **automaticky**, žiadna
  ďalšia zmena v paneli nie je potrebná.
- Odomkne 40 % → ~100 % funkčnosti portovaných `moodChanges` bez zásahu
  do dát (JSON sa nemení, len alias v kóde).
- Alternatíva B (zdokumentovať ako no-op) by defacto vyradila polovicu
  zmyslu už hotovej content-portovacej práce (1.2/1.3/1.4).

### Presná zmena (až po schválení)

**Súbor:** `godot/scripts/managers/DiplomacyManager.gd`,
funkcia `_ensure_default_factions()`

Doplniť do `default_factions` dictionary (odporúčaná počiatočná nálada
50.0 — neutrálno-priateľská, konzistentná s ostatnými frakciami mimo
Maďarov):

```gdscript
"byzantium": {"name": "Byzantská ríša", "mood": 50.0, "relations": {}},
```

**Súbor:** `godot/scripts/managers/EventManager.gd`,
funkcia `_resolve_faction_id()`

Zmeniť vetvu, ktorá dnes vracia `""`:

```gdscript
# pred:
if lower in ["byzantium", "byzantskí", "konštantínopol"]:
    return ""
# po:
if lower in ["byzantium", "byzantskí", "konštantínopol"]:
    return "byzantium"
```

### Akceptačné kritériá
- [ ] `list_factions()` vracia 6 frakcií (bez zmeny — `moravia` sa
      v paneli beztak nezobrazuje), `DiplomacyPanel` teraz zobrazuje aj
      Byzanciu (7. karta)
- [ ] Event `byz_bride_proposal_906` (voľba „Prijať ponuku sobáša“) po
      vyriešení preukázateľne zdvihne `factions["byzantium"].mood`
      (over cez `GameManager.diplomacy_manager.get_mood("byzantium")`
      pred/po `resolve_event_choice`)
- [ ] Smoke M5 + M6 stále `PASS` (Byzancia nemá vplyv na Devín ani
      ekonomiku, zmena je izolovaná)
- [ ] TS testy nedotknuté (zmena je len v `godot/`)

---

## 3. Voliteľný cleanup — 2.3 tvar guardu (nízka priorita)

`HungarianWarScenario.resolve_devine_battle()` pri opakovanom volaní
vracia `{"result": "already_resolved"}`, zatiaľ čo `WarManager` vrstva
vyššie vracia `{"ok": false, "error": "already_resolved", "chronicle": "..."}`.
Dnes neškodné — `WarManager` guard vždy zachytí opakovanie skôr, než sa
k vnútornému guardu dostane volanie. Zjednotiť tvar len ak sa v budúcnosti
pridá nový volajúci, ktorý ide priamo cez `HungarianWarScenario` (obchádza
`WarManager`).

**Netreba riešiť teraz** — len poznámka pre budúcu reláciu, aby sa
nezabudlo, ak niekto bude refaktorovať vrstvu vojny.

---

## 4. Ďalší krok

Odpoveď stačí v tvare:

1. **`implementuj A`** — pridám Byzanciu ako frakciu + opravím alias,
   overím smoke + TS, nahlásim výsledok
2. **`B — zdokumentuj no-op`** — nechám kód ako je, len sem doplním
   poznámku, že Byzancia je vedomo bez efektu (zmením odporúčanie v
   tomto súbore, žiadny kód sa nemení)
3. **`aj 2.3`** — spolu s A/B zjednotiť aj tvar guardu (malý extra zásah)
4. iný pokyn

Bez tvojho go nezačínam kód.
