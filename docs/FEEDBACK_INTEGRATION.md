# Regnum Moravicum — Feedback Integration (M5)

## 1. Úvod
Tento dokument sleduje **stav opráv z `KRITICKA_ANALYZA_GODOT_PORT_v3.md`**.
Zahrňuje:
- **Kritické chyby** a ich opravy.
- **Blokéry** a riešenia.
- **Ďalšie kroky** pre M5.

---

## 2. Stav opráv z analýzy
| Bod | Popis | Súbor | Oprava | Stav |
|-----|-------|-------|--------|------|

### 🔴 KRITICKÉ
| 1 | `GameState.gd` obsahoval kód `SaveManager.gd` | `scripts/core/GameState.gd` | Obnovená trieda `GameState` s priamym prístupom (`state.year`). | ✅ Hotovo |
| 2 | `SaveManager.gd` bol prepísaný obsahom `GameState.gd` | `scripts/core/SaveManager.gd` | Obnovená pôvodná logika `SaveManager`. | ✅ Hotovo |

### 🟠 VYSOKÁ PRIORITA
| 3 | Grécky oheň bonus aplikovaný na morálku namiesto ES | `HungarianWarScenario.gd` | Aplikovaný na efektívnu silu (ES) (`+15%`). | ✅ Hotovo |
| 4 | Devín natvrdo stotožnený s Bratislavou | `data/provinces/devin.json` | Pridaná samostatná provincia `devin`. | ✅ Hotovo |
| 5 | Chýbajúce podmienky prehry v `VictoryManager` | `VictoryManager.gd` | Pridaná podmienka `owned_provinces == 0`. | ✅ Hotovo |

### 🟡 STREDNÁ PRIORITA
| 6 | `.get(x) or default` nahradzuje falsy hodnoty (`0`, `false`, `""`) | `HungarianWarScenario.gd` | Nahradené `.get(x, default)`. | ✅ Hotovo |
| 7 | Reflection vzory (`game_state.get("year")`) | `scripts/managers/*.gd` | Prechod na priamy prístup (`game_state.year`). | ✅ Hotovo |
| 8 | `ReligionManager` logoval novú hodnotu namiesto starej | `ReligionManager.gd` | Opravené poradie mutácie a logovania. | ✅ Hotovo |

### 🟢 NÍZKA PRIORITA
| 9 | `ArmyManager` nemal inicializáciu armád | `ArmyManager.gd` | Pridaná metóda `_init_armies()`. | ✅ Hotovo |
| 10 | `MapManager` nenahrával `neighbors` z JSON | `MapManager.gd` | Opravené načítanie `neighbors`. | ✅ Hotovo |

---

## 3. Blokéry pre ďalší vývoj (M5)
| Blokér | Popis | Riešenie | Stav |
|--------|-------|----------|------|
| `CampaignManager.gd` chýba | Vojenská AI pre ťahy, obliehania, expanziu. | Implementovať podľa šablóny. | ⏳ Čaká na implementáciu |
| UI pre armády chýba | Chýbajúce tlačidlá pre pohyb/bitky. | Vytvoriť UI v Godot 4. | ⏳ Čaká na implementáciu |
| Integračné testy chýbajú | Chýbajú testy pre `CampaignManager`. | Vytvoriť `test_campaign_manager.gd`. | ⏳ Čaká na implementáciu |

---

## 4. Ďalšie kroky (M5)
### 4.1 Implementácia `CampaignManager.gd`
**Cieľ**: Vojenská AI pre ťahy, obliehania, expanziu.
**Požiadavky**:
- Determinizmus cez `SaveManager.rng`.
- Integracia s `WarManager.gd` a `DiplomacyManager.gd`.
- Historická presnosť (9. storočie).

**Šablóna**:
```gdscript
class_name CampaignManager
extends RefCounted

var game_state: GameState
var war_manager: WarManager
var diplomacy_manager: DiplomacyManager
var rng: RandomNumberGenerator

func _init(state: GameState, war_mgr: WarManager, dip_mgr: DiplomacyManager, rng_ref: RandomNumberGenerator) -> void:
    game_state = state
    war_manager = war_mgr
    diplomacy_manager = dip_mgr
    rng = rng_ref

func process_campaign() -> Dictionary:
    var report := {"type": "campaign", "events": []}
    # Logika pre ťahy, obliehania, expanziu
    return report
```

### 4.2 UI pre armády
**Cieľ**: Vytvoriť UI pre zobrazenie a ovládanie armád.
**Požiadavky**:
- Mapa s jednotkami (ikony armád).
- Tlačidlá pre pohyb/bitky/obliehania.
- Informácie o armáde (veľkosť, morálka, zásoby).

**Šablóna**:
```gdscript
extends Control

var army_manager: ArmyManager
var map_manager: MapManager

func _ready() -> void:
    army_manager = get_node("/root/GameManager").army_manager
    map_manager = get_node("/root/GameManager").map_manager
    _update_army_list()

func _update_army_list() -> void:
    var armies = army_manager.list_armies()
    # Zobrazenie armád v UI
```

### 4.3 Integračné testy
**Cieľ**: Overiť interakciu medzi manažérmi.
**Testy**:
- Determinizmus campaign AI.
- Historická presnosť (Devín 907, expanzia Maďarov).
- Výkon pre 100+ armád.

**Príklad testu**:
```gdscript
extends "res://test/test_base.gd"

func test_campaign_determinism():
    var w1 = _make_world(42)
    var w2 = _make_world(42)
    var c1 = w1.campaign.process_campaign()
    var c2 = w2.campaign.process_campaign()
    assert_eq(c1, c2, "Campaign AI nie je deterministická!")
```

---

## 5. Kontakt
- **GitHub Issues**: [kriklavycarodejnik/Regnum-moravicum/issues](https://github.com/kriklavycarodejnik/Regnum-moravicum/issues)
- **Discord**: [Hermes Agents](https://discord.gg/hermes-agents)

---
**Posledná aktualizácia**: 22. júla 2026
**Autor**: Hermes Agent (Mistral Large 3)