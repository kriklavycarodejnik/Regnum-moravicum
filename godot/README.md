# Regnum Moravicum — Godot 4

Ťahová historická stratégia (Veľká Morava, Mojmír II.).

## Stav

- **M1 Jadro:** GameState, TickManager, SaveManager (seeded RNG), MapManager, 11 žúp
- **M2 Simulácia + narácia:** EconomyManager, NobilityManager, NarrationManager (TickReport)
- **MVP horizont:** 902–1000
- React/TS prototyp zostáva v root-e ako archív / referencia (Phase 2 battle spec = zdroj pravdy)

## Spustenie

1. Otvor priečinok `godot/` v Godot 4.3+
2. Spusti projekt (hlavná scéna: `scenes/main/Main.tscn`)
3. Tlačidlo **Ďalší mesiac** spúšťa tick

## Štruktúra

```
godot/
├── autoloads/GameManager.gd
├── data/provinces/          # 11 žúp (JSON)
├── scripts/core/            # GameState, TickManager, SaveManager
├── scripts/managers/        # Economy, Nobility, Narration, Map
├── scripts/resources/
├── scenes/main/
└── project.godot
```

## Architektúra

Pozri `docs/GODOT4_ARCHITECTURE_PROPOSAL.md` (v1.3).

## Ďalšie vlny

- **M3:** BattleManager (port Phase 2), WarManager, DiplomacyManager
- **M4:** SuccessionManager, ReligionManager, VictoryManager, Hungarian War
