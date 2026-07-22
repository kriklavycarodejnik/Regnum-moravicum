# Kánon žúp — Godot (rozhodnutie 21. 7. 2026)

## Rozhodnutie

**Godot vetva používa historické veľkomoravské/uhorské komitáty**, nie moderné mestá z React prototype.

| ID | Názov | Poznámka |
|----|-------|----------|
| morava | Morava | jadro |
| nitra | Nitra | sídlo |
| bratislava | Bratislava | západ / riečne centrum |
| devin | Devín | pevnosť pri Dunaji (samostatná župa; Devín 907) |
| trencin | Trenčín | severozápad |
| tekov | Tekov | stred |
| hont | Hont | juh |
| novohrad | Novohrad | juhovýchod |
| gemer | Gemer | stredovýchod |
| spis | Spiš | severovýchod |
| zemplin | Zemplín | východ |
| uzhorod | Užhorod | juhovýchodná hranica |

## Prečo nie React zoznam

React (`MORAVIAN_ZUPY`): Nitra, Devín, Bratislava, Trnava, Zvolen, Banská Bystrica, Košice, Prešov, Žilina, Poprad, Bardejov.

Problém: viaceré názvy sú moderné / anachronické pre rok 902 (napr. Banská Bystrica ~13. stor.). Godot sada je historicky vernejšia.

## Susednosť

Každý `data/provinces/*.json` má pole `neighbors: string[]` (neorientovaný graf, overená symetria).  
Zdroj pravdy pre `WarManager` / mapu v M3 — **nie** ad-hoc kruh z React generators.

## React

React prototype zostáva archív / referencia. Pri prípadnom ďalšom React worke treba buď:
- migrovať na túto sadu, alebo
- explicitne označiť React zoznam ako legacy prototype-only.

## Otvorené

- Bratislava a Devín sú **samostatné** župy (symetrický neighbors graf).
- Export z Notion DB nahradí ručné JSON, keď budú Relations TODO hotové.
