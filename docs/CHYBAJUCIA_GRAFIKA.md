# Chýbajúca grafika, ikony a UI — audit (po wired assetoch)

> Stav: všetky A/B/C assety sú **vygenerované** (117 PNG) a **v `art_map.json`** (112 entries).
> Zostáva ich **zapojiť do kódu** — UI komponenty ich ešte nepoužívajú.

---

## ✅ Vygenerované + v art_map (hotovo)

| Vrstva | Počet | Príklady |
|--------|-------|----------|
| Portréty A | 3 | mojmir_ii, theodora, arpad |
| Lokality A | 4 | nitra, devin, bratislava, court |
| Event plates A | 6 | papal_legation, byzantine_marriage, bogata_conspiracy, border_raid, harvest_tithe, council |
| Battle cover A | 2 | danube_composition, style_master |
| UI ikony C | 28×3 veľkosti | všetky MVP + extended (gift, threat, trade, nap, pact, save, load, next_month, victory, defeat, bell, move, split, merge, upgrade) |
| Frakčné emblémy C | 6 | hungary, franks, bavaria, poland, bohemia, byzantium |
| Battle siluety B | 6 | infantry, archer, cavalry, commander, magyar_horse, shieldwall |
| Map markery B | 5 | settlement_small/medium/large, fort, army_dot |

---

## 🔧 Treba zapojiť do kódu

| Komponent | Asset | Čo treba spraviť |
|-----------|-------|------------------|
| **DiplomacyPanel** | frakčné emblémy | ✅ Už zapojené cez `FACTION_ART` |
| **BattleView** | battle siluety | V `show_outcome()` renderovať siluety podľa frakcií |
| **MapView** | map markery | Nahradiť kruhy za settlement/fort/army ikony |
| **ArmyUI** | icon_move, icon_split, icon_merge | Pridať ikony k tlačidlám |
| **StatusBar** | resource ikony | ✅ Už zapojené |
| **ReligionAxis** | cross ikony | ✅ Už zapojené |
| **MainMenu** | icon_save, icon_load | Pridať ikony k tlačidlám |
| **EndScreen** | icon_victory, icon_defeat | Zobraziť podľa výsledku |
| **NotificationFeed** | icon_bell | Pridať ikonu zvončeka |

---

## 🔍 Čaká na schválenie (Review → Approved)

12 MVP UI ikon je v adresári `godot/assets/icons/ui/` a v `art_map.json`, ale v `ASSET_MANIFEST.md` majú status **Review**. Treba ich vizuálne schváliť alebo pregenerovať.

---

## ✅ Nič nechýba — všetko je vygenerované

Oproti pôvodnému auditu (`CHYBAJUCIA_GRAFIKA.md` pred aktualizáciou):
- ~~Battle siluety (6 ks)~~ — ✅ existujú
- ~~Event-specific A-plates (6 ks)~~ — ✅ existujú
- ~~Frakčné emblémy (6 ks)~~ — ✅ existujú + zapojené
- ~~Extended ikony 13–28~~ — ✅ existujú
- ~~Map markery (5 ks)~~ — ✅ existujú
