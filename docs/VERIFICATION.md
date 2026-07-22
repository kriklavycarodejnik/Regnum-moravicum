# Regnum Moravicum — Verifikačný manuál (M5)

## 1. Úvod
Tento dokument popisuje **ako overiť funkčnosť M5** (armády, campaign AI) v Godot 4.
Zahrňuje:
- **Automatizované testy** (smoke testy, gdUnit4).
- **Manuálnu verifikáciu** (GUI, logy).
- **Blokéry a riešenia** z `KRITICKA_ANALYZA_GODOT_PORT_v3.md`.

---

## 2. Testovacie prostredie
### Požiadavky
| Nástroj          | Verzia  | Poznámka                                  |
|------------------|---------|-------------------------------------------|
| Godot Engine     | 4.7.1   | [Stiahnuť tu](https://godotengine.org)    |
| gdUnit4          | 4.2.1   | [GitHub](https://github.com/MikeSchulze/gdUnit4) |
| Python           | 3.11+   | Pre `gdlint` a skripty                   |

### Inštalácia závislostí
```bash
# Inštalácia gdlint (GDScript linter)
pip install gdtoolkit

# Inštalácia gdUnit4 v Godot projekte
# 1. Stiahnuť gdUnit4 z GitHubu
# 2. Skopírovať addons/gdUnit4 do godot/addons/
# 3. Aktivovať v Godot: Project > Project Settings > Plugins
```

---

## 3. Automatizované testy
### 3.1 Smoke testy (M5)
**Cieľ**: Rýchla verifikácia armád, campaign AI a determinizmu.
**Súbor**: `tools/smoke_test.gd`
**Spustenie**:
```bash
cd /Users/home/Projects/regnum-moravicum-official/godot
godot --headless --path . -s res://tools/smoke_test.gd
```

**Očakávaný výstup** (`SMOKE_PASS`):
```
=== Regnum Moravicum smoke test v8 (M5) ===
Devín 907 battle: winner=defender result=victory_decision
Devín 907 defender win OK
Rewards: +5 prestige, +1000 gold, +10 loyalty
Occupation cleared OK
Succession: ruler=Mojmír II., heir=Svätopluk II., type=seniority
Succession data OK
Religion: dominant=pagan, changes=0
Religion dominant OK
Victory: NO, type=none
Armies: 3 total
Initial armies OK
Army movement OK
Army upkeep: 0 events
ES Devín: magyar 7495.6 | moravia 10988.2
Hungarian river morale OK: 65.0
Tick determinism OK
SMOKE_PASS
```

**Blokéry**:
- `SMOKE_FAIL`: Chyby v inicializácii armád alebo campaign AI.
- **Riešenie**: Overiť `CampaignManager.gd` a `ArmyManager.gd`.

---

### 3.2 gdUnit4 testy (M5)
**Cieľ**: Unit testy pre armády a campaign AI.
**Súbory**:
- `test/m5/test_army_manager.gd`
- `test/m5/test_campaign_manager.gd` *(nový)*

**Spustenie**:
1. **V Godot Editore**:
   - Otvoriť projekt: `godot --path .`
   - V menu: `Project > Tools > GdUnit4`
   - Vybrať testové súbory a kliknúť na **Run Tests**.

2. **Manuálne v konzole** (nie je podporované v gdUnit4 v4.2.1):
   ```bash
   # NEPODPOROVANÉ (iba pre referenciu)
   godot --headless --path . -s res://test/m5/test_runner.gd
   ```

**Očakávaný výstup**:
- ✅ **Zelené testy**: Všetky testy prešli.
- ❌ **Červené testy**: Chyby v logike (napr. `CampaignManager`, `ArmyManager`).

---

## 4. Manuálna verifikácia (M5)
### 4.1 GUI verifikácia
**Postup**:
1. Spustiť hru v Godot Editore: `F5`.
2. Overiť:
   - **Armády (M5)**: Vytvorenie, pohyb, bitky, obliehania.
   - **Campaign AI**: Ťahy nepriateľských frakcií (Maďari, Frankovia).
   - **Devín 907**: Historická presnosť (grécky oheň, river morale).
   - **Tick engine**: Postup času (M1-M5).

**Očakávané správanie**:
- Armády sa zobrazujú na mape s ikonami.
- Bitky sú deterministické (rovnaký seed = rovnaký výsledok).
- Campaign AI vykonáva ťahy podľa stratégie (expanzia/obrana).

---

### 4.2 Logovanie
**Súbor**: `user://logs/game.log` (vytvorený automaticky).
**Aktivácia**:
```gdscript
# V GameManager.gd
func _ready():
    var log_file = FileAccess.open("user://logs/game.log", FileAccess.WRITE)
    log_file.store_string("Game started at %s" % Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()))
    log_file.close()
```

**Overenie**:
```bash
cat ~/.local/share/godot/app_userdata/Regnum\\ Moravicum/logs/game.log
```

---

## 5. Opravené body z `KRITICKA_ANALYZA_GODOT_PORT_v3.md`
| Bod | Súbor | Oprava | Stav |
|-----|-------|--------|------|
| `GameState.gd` poškodený | `scripts/core/GameState.gd` | Obnovená trieda `GameState` s priamym prístupom (`state.year`). | ✅ Hotovo |
| Grécky oheň bonus | `HungarianWarScenario.gd` | Aplikovaný na efektívnu silu (ES) namiesto morálky (`+15%`). | ✅ Hotovo |
| Devín vs. Bratislava | `data/provinces/devin.json` | Pridaná samostatná provincia `devin`. | ✅ Hotovo |
| Prehra v `VictoryManager` | `VictoryManager.gd` | Pridaná podmienka `owned_provinces == 0`. | ✅ Hotovo |
| `.get(x) or default` | `HungarianWarScenario.gd` | Nahradené `.get(x, default)` pre falsy hodnoty (`0`, `false`, `""`). | ✅ Hotovo |
| Reflection vzory | `scripts/managers/*.gd` | Prechod na priamy prístup (`game_state.year`). | ✅ Hotovo |

---

## 6. Ďalšie kroky (M5)
### 6.1 Implementácia `CampaignManager.gd`
**Cieľ**: Vojenská AI pre ťahy, obliehania, expanziu.
**Požiadavky**:
- Determinizmus cez `SaveManager.rng`.
- Integracia s `WarManager.gd` a `DiplomacyManager.gd`.
- Historická presnosť (9. storočie).

### 6.2 UI pre armády
**Cieľ**: Vytvoriť UI pre zobrazenie a ovládanie armád.
**Požiadavky**:
- Mapa s jednotkami (ikony armád).
- Tlačidlá pre pohyb/bitky/obliehania.
- Informácie o armáde (veľkosť, morálka, zásoby).

### 6.3 Integračné testy
**Cieľ**: Overiť interakciu medzi manažérmi.
**Testy**:
- Determinizmus campaign AI.
- Historická presnosť (Devín 907, expanzia Maďarov).
- Výkon pre 100+ armád.

---

## 7. Kontakt
- **GitHub Issues**: [kriklavycarodejnik/Regnum-moravicum/issues](https://github.com/kriklavycarodejnik/Regnum-moravicum/issues)
- **Discord**: [Hermes Agents](https://discord.gg/hermes-agents)

---
**Posledná aktualizácia**: 22. júla 2026
**Autor**: Hermes Agent (Mistral Large 3)