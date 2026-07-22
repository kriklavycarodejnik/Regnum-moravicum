# Chýbajúca grafika, ikony a UI — audit ku commitu `178e8e4+`

> Stav: všetky 3.x stavebné práce hotové (Coach, Devín modal, TurnReport).
> Tento dokument je inventúra všetkého, čo v hre ešte **chýba vizuálne**.

---

## A — Narrative art (vrstva A)

| ID | Typ | Stav | Poznámka |
|----|-----|------|-----------|
| `regnum_visual_style_master` | style_master | ✅ Approved | |
| `mojmir_ii_master_portrait` | portrait | ✅ Approved | |
| `theodora_master_portrait` | portrait | ✅ Approved | |
| `arpad_master_portrait` | portrait | ✅ Approved | |
| `nitra_master_hero` | location | ✅ Approved | |
| `devin_master_fortress` | location | ✅ Approved | |
| `bratislava_master_river` | location | ✅ Approved | |
| `moravian_court_interior` | location | ✅ Approved | používané ako fallback pre väčšinu eventov |
| `mojmir_dynasty_emblem` | emblem | ✅ Approved | |
| `battle_danube_composition` | battle | ✅ Approved | |

**Chýba (A):**
- [ ] **Event-specific plates** — pre kľúčové historické eventy (byzantská svadba, pápežské posolstvo, sprisahanie Bogata, súd, povstanie). Dnes všetky používajú `moravian_court_interior` ako fallback.
- [ ] **Frakčné portréty** — franský vyslanec, bavorský vojvoda, poľský knieža, český knieža. DiplomacyPanel používa len `mojmir_dynasty_emblem` pre všetky frakcie.
- [ ] **Loading screen / main menu background** — dnes `moravian_court_interior` dimmed.

---

## C — UI ikony (vrstva C)

### MVP 12 (Review — čaká na schválenie)

| ID | Súbor | Použitie | Status |
|----|-------|----------|--------|
| `icon_gold` | `icon_gold_64.png` | StatusBar | 🔍 Review |
| `icon_food` | `icon_food_64.png` | StatusBar | 🔍 Review |
| `icon_wood` | `icon_wood_64.png` | StatusBar | 🔍 Review |
| `icon_stone` | `icon_stone_64.png` | StatusBar | 🔍 Review |
| `icon_iron` | `icon_iron_64.png` | StatusBar | 🔍 Review |
| `icon_prestige` | `icon_prestige_64.png` | StatusBar | 🔍 Review |
| `icon_eagle` | `icon_eagle_64.png` | — (rezerva) | 🔍 Review |
| `icon_cross_latin` | `icon_cross_latin_64.png` | ReligionAxis | 🔍 Review |
| `icon_cross_patriarchal` | `icon_cross_patriarchal_64.png` | ReligionAxis | 🔍 Review |
| `icon_sword` | `icon_sword_64.png` | — (rezerva) | 🔍 Review |
| `icon_shield` | `icon_shield_64.png` | — (rezerva) | 🔍 Review |
| `icon_scroll` | `icon_scroll_64.png` | — (rezerva) | 🔍 Review |

### Extended 13–28 (nevygenerované)

| # | ID | Použitie |
|---|----|----------|
| 13 | `icon_gift` | DiplomacyPanel — tlačidlo Dar |
| 14 | `icon_threat` | DiplomacyPanel — tlačidlo Hrozba |
| 15 | `icon_treaty` | DiplomacyPanel — zmluvy |
| 16 | `icon_trade` | DiplomacyPanel — Obchod |
| 17 | `icon_nap` | DiplomacyPanel — Neútočná zmluva |
| 18 | `icon_military_pact` | DiplomacyPanel — Vojenský pakt |
| 19 | `icon_army_move` | ArmyUI — Presun |
| 20 | `icon_army_split` | ArmyUI — Rozdeliť |
| 21 | `icon_army_merge` | ArmyUI — Zlúčiť |
| 22 | `icon_siege` | ArmyUI — Obliehanie |
| 23 | `icon_save` | Hlavné menu / Save |
| 24 | `icon_load` | Hlavné menu / Load |
| 25 | `icon_next_month` | Hlavné tlačidlo ťahu |
| 26 | `icon_notification` | NotificationFeed |
| 27 | `icon_victory_laurel` | EndScreen |
| 28 | `icon_defeat_broken_sword` | EndScreen |

---

## B — Mapa a boj (vrstva B)

**Chýba úplne všetko:**

| ID | Typ | Veľkosť | Použitie |
|----|-----|---------|----------|
| `marker_settlement_1` | settlement tier | 32×32 | MapView — nízka prosperita |
| `marker_settlement_2` | settlement tier | 32×32 | MapView — stredná prosperita |
| `marker_settlement_3` | settlement tier | 32×32 | MapView — vysoká prosperita |
| `marker_fort` | fort | 32×32 | MapView — opevnenie |
| `marker_army_dot` | army dot | 16×16 | MapView — armáda na mape |
| `sil_infantry_moravia` | silhouette | 64×128 | BattleView — moravská pechota |
| `sil_archer_moravia` | silhouette | 64×128 | BattleView — moravskí lukostrelci |
| `sil_cavalry_moravia` | silhouette | 64×128 | BattleView — moravská jazda |
| `sil_infantry_magyar` | silhouette | 64×128 | BattleView — maďarská pechota |
| `sil_archer_magyar` | silhouette | 64×128 | BattleView — maďarskí lukostrelci |
| `sil_cavalry_magyar` | silhouette | 64×128 | BattleView — maďarská jazda |
| `pip_friendly` | relation | 12×12 | DiplomacyPanel |
| `pip_neutral` | relation | 12×12 | DiplomacyPanel |
| `pip_hostile` | relation | 12×12 | DiplomacyPanel |

---

## UI prvky bez vlastných assetov

| Prvok | Súbor | Čo chýba |
|-------|-------|----------|
| **TurnReport card** | `Main.gd:_show_turn_report` | Resource ikony v carde (dnes len text). Ideálne: ikona + hodnota vedľa seba. |
| **Coach overlay** | `Main.gd:_show_coach_overlay` | Žiadna šípka/ukazovateľ. Čisto textový overlay. |
| **Devín modal** | `Main.gd:_show_devin_modal` | Žiadne art pozadie. Iba text + tlačidlo. |
| **NotificationFeed** | `ui/NotificationFeed.gd` | Toast notifikácie bez ikony. |
| **ObjectivesPanel** | `ui/ObjectivesPanel` | Iba text, bez progress indikátora / ikon. |
| **ArmyUI** | `ui/ArmyUI.gd` | Tlačidlá bez ikon (Presun/Bitka/Obliehanie). |
| **DiplomacyPanel** | `ui/DiplomacyPanel.gd` | Akčné tlačidlá bez ikon. Frakčné emblémy — všetky frakcie zdieľajú `mojmir_dynasty_emblem`. Chýbajú: franský, bavorský, uhorský, poľský, český, byzantský emblém. |
| **StatusBar** | `ui/StatusBar.gd` | Chipy majú ikony ✅, ale hodnoty sú len čísla bez vizuálneho oddelenia. |
| **ReligionAxis** | `ui/ReligionAxis.gd` | Ikony ✅, chýba dekoratívny track (ornament medzi ikonami). |
| **MainMenu** | `scenes/menu/MainMenu.gd` | Emblem ✅, background art dimmed ✅. Chýba: tlačidlá s ikonami (New/Load/Quit). |
| **EndScreen** | `scenes/end/EndScreen.gd` | Art ✅, chýbajú: ikony na tlačidlách (Menu/Restart). |
| **BattleView** | `scenes/battle/BattleView.gd` | Art plate ✅. Chýbajú: siluety jednotiek, morale bary s frakčnými farbami. |
| **MapView** | `scenes/map/MapView.gd` | Kruhové markery ✅. Chýbajú: settlement tier ikony, army dot, fort marker, faction tint na provinciách. |

---

## Priorita (odporúčanie)

| Priorita | Čo | Dôvod |
|----------|-----|--------|
| **P0** | Schváliť 12 UI ikon (Review → Approved) | Blokuje akýkoľvek vizuálny posun — ikony sú už vygenerované, len čakajú |
| **P1** | Frakčné emblémy (6 ks) | DiplomacyPanel vyzerá rovnako pre všetky frakcie |
| **P2** | Akčné ikony pre DiplomacyPanel (6 ks) | Tlačidlá bez ikon sú nečitateľné |
| **P3** | Map markery (settlement ×3, fort, army dot) | MapView bez markerov je holý |
| **P4** | Battle siluety (6 ks) | BattleView je len text + art plate |
| **P5** | Event-specific A-plates (4–6 ks) | Všetky eventy majú rovnaký fallback art |
| **P6** | Extended ikony 19–28 | ArmyUI, Save/Load, notifikácie |
