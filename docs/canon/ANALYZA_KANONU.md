# Analýza a audit kánonu Regnum Moravicum

Dátum: 23. august 2026  
Autor: Kronikár a architekt kánonu (`rm-canon`)  
Rozsah auditu: Kánonické pravidlá, dátové štruktúry (`godot/data/`), kódové mechaniky a manažéri (`godot/scripts/`), testovacie suity (`godot/test/`), projektová dokumentácia (`docs/`, `godot/docs/`) a naratívne texty.

---

## 1. Prehľad stavu kánonických pilierov

| Pilier kánonu | Pravidlo / Očakávanie | Stav v projekte | Verdikt |
|---|---|---|---|
| **Devín 907** | Maďarské víťazstvo (`winner == "attacker"`), prestíž −30, lojalita Devína −20, nálada Maďarov +30 | `HungarianWarScenario.gd` pevne vynucuje `outcome["winner"] = "attacker"`, test `test_devine_907.gd` overuje. V `test_hungarian_war_scenario.gd` však pretrvávajú zastarané testy simulujúce výhru obrancu a obsadenie „Bratislavy“ frakciou „madari“. | **Čiastočne nekonzistentné v testoch** (pozri Chyba č. 1) |
| **Následníctvo** | Seniorát / primogenitúra (žiadna voľba, žiadne hybridy) | V `SuccessionManager.gd` chýba metóda `set_succession_type()` a fallbackuje na metódu `_elect_new_ruler()` (voľba podľa prestíže), čo odporuje kánonu. Testy v `test_succession_manager.gd` testujú voľbu (`election`). | **Nekonzistentné** (pozri Chyba č. 2) |
| **Náboženstvo** | `religion` je výhradne `int`/`float` 0–100 (latin vs orthodox vs pohanstvo), nikdy reťazec | Všetkých 12 JSON súborov v `godot/data/provinces/*.json` používa korektné celé čísla. `ReligionManager.gd` a `MapManager.gd` obsahujú legacy fallbacky na reťazce (`"pagan"`, `"christian"`), no číselná os 0–100 je plne funkčná. | **V poriadku v dátach** (kód nesie legacy fallbacky) |
| **Frakcie** | `moravia`, `hungary`, `franks`, `bavaria`, `poland`, `bohemia` (+ `byzantium`) | Všetkých 7 frakcií je zjednotených v `DiplomacyManager.gd`, `BattleViewTranslations.gd` aj v emblémoch assetov. | **V súlade s kánonom** |
| **Provincie** | 12 historických komitátov, `devin` je samostatná provincia, symetrický graf susedností | Všetkých 12 žúp je definovaných, graf susedností je overený a plne symetrický. | **V súlade s kánonom** |
| **Obdobie & reálie** | Raný 10. storočie (902–1000), kniežatstvo (nie kráľovstvo) | Nájdené ojedinelé anachronické pojmy v eventoch („kráľovské vojsko“, „kráľovské sklady“ namiesto kniežacích). | **Drobné textové chyby** (pozri Chyba č. 3) |

---

## 2. Nájdené chyby a nekonzistencie (SEKCIA A)

### Chyba č. 1: Zastarané testy odporujúce kánonu Devín 907 a názvosloviu frakcií
* **Zdroj:** `godot/test/scenarios/test_hungarian_war_scenario.gd:43-75`
* **Popis problému:**
  1. Test `test_devine_battle_rewards()` (riadky 43–55) predpokladá moravské víťazstvo (`winner == "defender"`) a udeľovanie odmien za obranu Devína, čo je v priamom rozpore s nemenným pravidlom kánonu (Devín 907 vždy vyhrávajú Maďari ako útočníci).
  2. Test `test_devine_battle_occupation()` (riadok 75) overuje nastavenie okupanta `occupier_faction` na string `"madari"` (namiesto kánonického ID frakcie `"hungary"`) a predpokladá okupáciu provincie `"bratislava"` namiesto provincie `"devin"`.
* **Dôsledok:** Tento testovací súbor zlyháva voči skutočnej implementácii v `HungarianWarScenario.gd` a šíri nekánonické predstavy o možnom moravskom víťazstve v roku 907.
* **Návrh nápravy:** Aktualizovať `test_hungarian_war_scenario.gd` tak, aby odrážal kánonický deterministický prielom maďarských vojsk a mechanické postihy (prestíž −30, lojalita Devína −20, nálada Maďarov +30).

---

### Chyba č. 2: Nekánonická voľba panovníka (election) v logike a testoch následníctva
* **Zdroj:** `godot/scripts/managers/SuccessionManager.gd:25, 68–88` a `godot/test/m4/test_succession_manager.gd:46–69`
* **Popis problému:**
  1. Podľa kánonu je jedinou povolenou formou následníctva **seniorát** (prípadne primogenitúra v neskoršom vývoji dynastie). Voľby a hybridné systémy sú zakázané.
  2. V `SuccessionManager.gd` metóda `_elect_new_ruler()` volí panovníka podľa najvyššej prestíže spomedzi všetkých žijúcich veľmožov bez ohľadu na dynastickú príslušnosť (`dynasty_id`).
  3. V `SuccessionManager.gd` úplne chýba implementácia `set_succession_type()` a prepínanie medzi seniorátom a primogenitúrou, hoci testovacia suita `test_succession_manager.gd` tieto metódy volá a testuje voľbu (`election`).
* **Dôsledok:** Pri úmrtí panovníka bez priameho dediča v dátach môže trón pripadnúť cudziemu veľmožovi na základe nekánonickej voľby.
* **Návrh nápravy:** Upraviť `SuccessionManager.gd` tak, aby striktne uplatňoval seniorát v rámci mojmírovskej dynastie (najstarší žijúci mužský príbuzný) a pri vymretí línie nastala dynastická kríza / regentstvo, nie voľba.

---

### Chyba č. 3: Anachronické použitie pojmu „kráľovský“ namiesto „kniežací“
* **Zdroj:** `godot/data/events_catalog.json:327, 364` a `docs/design/P0_EVENTY.md:145, 165`
* **Popis problému:**
  1. V evente `bogata_uprising_917` (voľba `crush`, riadok 327) text znie: *„Poslať kráľovské vojsko potlačiť vzburu“*.
  2. V evente `rand_bad_harvest` (voľba `open`, riadok 364) text znie: *„Otvoriť kráľovské sklady pre Zemplín“*.
  3. Podľa kánonu pre obdobie 902–1000 je Veľká Morava kniežatstvom a Mojmír II. je kniežaťom. Tituly a inštitúcie majú niesť označenie *„kniežacie vojsko“*, *„kniežacie sypárne / sklady“*, *„kniežací dvor“*.
* **Dôsledok:** Narušenie historickej autenticity a terminologickej čistoty kánonu.
* **Návrh nápravy:** Pripraviť návrh pre `rm-content` na úpravu textov na *„Poslať kniežacie vojsko...“* a *„Otvoriť kniežacie sypárne...“*.

---

### Chyba č. 4: Obmedzená zásoba variantov v NarrationManager
* **Zdroj:** `godot/scripts/managers/NarrationManager.gd:138–272`
* **Popis problému:**
  1. Generátory textov pre ekonomiku, diplomaciu, armády a náboženstvo obsahujú iba 1 až 3 statické šablóny.
  2. Anti-repetičný buffer (`recent_templates`, veľkosť 12) pri dlhšej hre spôsobuje, že generátor vracia prázdny reťazec `""`, pretože varianty sa rýchlo vyčerpajú.
  3. Pre niektoré župy chýba špecifický lokálny kolorit (napr. Tekov, Hont, Novohrad, Užhorod v ekonomických a vojenských textoch).
* **Dôsledok:** Zápisy v hernej kronike sa po 20–30 ťahoch stávajú monotónnymi alebo prázdnymi.
* **Návrh nápravy:** Rozšíriť sadu naratívnych šablón a hookov (pozri Sekciu B).

---

## 3. Návrhy na doplnenie kánonu (SEKCIA B)

### 3.1 Dynastické línie a sukcesné scenáre

#### A. Mojmírovská dynastia (rok 902)
1. **Mojmír II.** (knieža, nar. cca 870 / vek 32 v roku 902)
   - *Historický profil:* Schopný, diplomaticky rozhľadený panovník, ktorý obnovil moravskú cirkevnú hierarchiu (pápežskí legáti 899/900) a usiloval sa o konsolidáciu ríše po nájazdoch a občianskych vojnách.
   - *Kánonický osud:* Po roku 907 (Devín) vládne oslabenej ríši z nitrianskeho a moravského jadra, čelí tlaku maďarských kmeňov a nemeckých markgrófov.
2. **Svätopluk II.** (mladší brat, údelné knieža, nar. cca 874)
   - *Historický profil:* V 90. rokoch 9. storočia viedol odboj proti Mojmírovi II. s podporou Bavorska (Arnulf).
   - *Kánonická línia:* V roku 902 po zmieri drží údel v Nitriansku alebo na pohraničí. Predstavuje permanentné riziko separatizmu a bavorského vplyvu.
   - *Sukcesný scenár (Seniorát):* Ak Mojmír II. skoná bez starších príbuzných, trón pripadá Svätoplukovi II. Ak Svätopluk predtým zradil alebo prijal bavorskú ochranu, hrozí rozpad ríše na nitrianske a moravské údelné kniežatstvo.
3. **Predslav** (tretí brat / syn Svätopluka I., nar. cca 865)
   - *Historický profil:* Záhadná postava z prameňov (Cividalský evanjeliár — *Predslaus*). Podľa tradície pán Bratislavy (*Braslavespurch / Preslawaspurch*).
   - *Kánonická línia:* Správca západnej pohraničnej marky a dunajských pevností (Bratislava, Devín). Vojensky orientovaný, skeptický k byzantským sľubom, opora dunajskej obrany.
4. **Mladšia generácia (potomstvo Mojmíra II. a Theodory)**
   - **Rastislav (syn Mojmíra II., nar. 908):** Narodený po devínskej katastrofe, symbol nádeje a obnovy.
   - **Gorazd (druhorodený syn, nar. 911):** Predurčený pre cirkevnú dráhu na upevnenie staroslovienskeho arcibiskupstva.

#### B. Sukcesné krízy a scenáre medzivládia
1. **Scenár „Krvavý snem v Nitre“ (Dynastický spor bratov):**
   - *Spúšťač:* Pokles lojality Nitry pod 40 a nízka autorita (prestíž < 20). Svätopluk II. spochybňuje bratovu vládu po vojenskom neúspechu.
   - *Možnosti riešenia:*
     - A: Udeliť Svätoplukovi polovicu pokladnice a samostatný údel v Trenčíne a Nitre (rozdelenie armády, strata príjmov, dočasný mier).
     - B: Uvrhnúť brata do žalára na Devíne (pokles lojality u jeho priaznivcov, hrozba bavorského zásahu).
     - C: Predvolať županov na všeobecný súd a potvrdiť seniorát prísahou na kríž.
2. **Scenár „Vymretie po meči a Byzantské regentstvo“:**
   - *Spúšťač:* Skon panovníka, kým je následník maloletý (< 16 rokov) a vdova Theodora žije na dvore.
   - *Dôsledok:* Theodora preberá regentstvo s radou starších županov. Frakcia *bavaria* a *franks* to označujú za „grécku tyraniu“, vzrastá tlak na latinizáciu liturgie.

---

### 3.2 Frakčné oblúky a historický vývoj (902–930)

```
                       ┌─────────────────────────┐
                       │   902: Obnova Moravy    │
                       │ Mojmír II. upevňuje moc │
                       └────────────┬────────────┘
                                    │
                                    ▼
                       ┌─────────────────────────┐
                       │ 903–906: Voľba spojenectva│
             ┌─────────┤   Byzancia vs Rím       ├─────────┐
             │         └─────────────────────────┘         │
             ▼                                             ▼
   ┌───────────────────┐                         ┌───────────────────┐
   │ Latinská orientácia│                         │ Byzantský zväzok  │
   │ Zmier s Bavorskom │                         │ Sobáš s Theodorou │
   └─────────┬─────────┘                         └─────────┬─────────┘
             │                                             │
             └──────────────────────┬──────────────────────┘
                                    │
                                    ▼
                       ┌─────────────────────────┐
                       │ 907: Katastrofa na Devíne│
                       │   Maďarský prielom      │
                       └────────────┬────────────┘
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        ▼                                                       ▼
┌───────────────────────────────┐               ┌───────────────────────────────┐
│ 908–915: Stepný pakt          │               │ 908–915: Pevnostná reduta     │
│ Odvody Maďarom, spoločné      │               │ Ústup do Karpát, stavba valov │
│ nájazdy na Bavorsko a Sasko   │               │ a obnova dunajskej stráže     │
└───────────────┬───────────────┘               └───────────────┬───────────────┘
                │                                               │
                └───────────────────────┬───────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ 915–925: Povstanie Bogatovcov │
                        │  a konsolidácia Karpatskej ríše│
                        └───────────────────────────────┘
```

1. **Oblúk Maďari (`hungary`): Od nájazdov k susedskému spolužitiu**
   - *Fáza I (902–907):* Narastajúci tlak, sondovanie hraníc na Zemplíne a Užhorode.
   - *Fáza II (907):* Devínsky zlom — deštrukcia podunajského pásu.
   - *Fáza III (908–920):* Možnosť voľby: tributárny mier (platenie v striebre/daniach výmenou za to, že maďarské ťahy smerujú na západ do Bavorska a Itálie) ALEBO permanentná partizánska vojna v lesoch a priesmykoch.
2. **Oblúk Byzancia (`byzantium`): Vzdialený ochranca a kultúrny maják**
   - Príchod gréckych staviteľov, pisárov a ikonopiscov.
   - Zavedenie byzantského práva (*Zakon sudnyj ljudem*) a posilnenie cisárskeho kultu kniežaťa.
   - Riziko: Odcudzenie západných žúp (Morava, Trenčín), ktoré obchodujú s Pasovom a Regensburgom.
3. **Oblúk Bavorsko a Franská ríša (`bavaria`, `franks`): Rivalita na Dunaji**
   - Po porážke bavorských vojsk pri Bratislave/Devíne v roku 907 sú Bavori sami v defenzíve.
   - Príležitosť pre Moravu: Vystupovať ako sprostredkovateľ alebo spojenec proti stepnému nebezpečenstvu, no za cenu ústupkov pasovskému biskupovi.
4. **Oblúk Čechy a Poľsko (`bohemia`, `poland`): Slovanské pohraničie**
   - Přemyslovci v Čechách (Spytihněv I., Vratislav I.) balansujú medzi Moravou a Saskom/Bavorskom.
   - Možnosť dynastických sobášov a vytvorenia severného obranného valu proti nájazdom.

---

### 3.3 Návrh nových naratívnych textov a variantov pre NarrationManager

Na vyriešenie vyčerpania šablón a obohatenie kroniky navrhujeme nasledovné varianty s historickým registrom:

#### A. Ekonomika a úroda (`_generate_economy_text`)
1. *„V tekovských a hontianskych baniach vytavili olovo a striebro; dvorce na Hrone posielajú kniežaťu plné vozy rudy.“*
2. *„Dunajské mlyny pri Bratislave melú obilie z úrodných polí, no zemplínsky ľud hlási prázdne sýpky po nočných mrazoch.“*
3. *„Kupci z bavorského Pasova vykupujú na nitrianskom trhu kože a med, no platia znehodnoteným striebrom.“*
4. *„Lesní včelári v Gemeri a na Spiši odviedli bohatý desiatok vosku pre kniežacie chrámy.“*

#### B. Diplomacia a zahraničie (`_generate_diplomacy_text`)
1. *„Z Prahy dorazil posol přemyslovského kniežaťa — ponúka spojenectvo proti Sasom, no žiada voľný prechod cez moravské priesmyky.“*
2. *„Krakovskí Vislania posielajú dary a žiadajú kniežacích kňazov, aby pokrstili ich predákov na brehu Visly.“*
3. *„Bavorský posol na koni s penou na slabinách priniesol z Regensburgu listinu: žiada moravské obilie a sľubuje neútočenie.“*
4. *„Z Byzancie priplávala po Dunaji loď s purpurovým hodvábom a tajným posolstvom cisára o pohybe Pečenehov.“*

#### C. Vojna a pohraničie (`_generate_war_text`)
1. *„Dymové signály na hradiskách Zemplína a Užhorodu varujú pred rýchlymi stepnými jazdcami; dobytok sťahujú za dubové palisády.“*
2. *„Pohraničná stráž pri Trenčíne zadržala franckých zvedov s mapami považských brodov a opevnení.“*
3. *„Na devínskom brale hliadky dňom i nocou sledujú južný breh Dunaja — vietor prináša pach spálenísk z Panónie.“*
4. *„Kniežacia jazda rozprášila lúpežnú rotu v nitrianskych lesoch; koruhvy porazených visia na bráne hradiska.“*

#### D. Náboženstvo a kultúra (`_generate_religion_text`)
1. *„V nitrianskej bazilike znejú staroslovienske spevy z hlaholských kníh; kňazi vyučujú novú družinu pisárov.“*
2. *„Bavorskí klerici na Morave odmietajú prijímať sviatosti od slovanských kňazov a hrozia pápežskou kliatbou.“*
3. *„V hlbokých lesoch Novohradu vztýčili staroverci dreveného Perúna; župan žiada kniežací zásah a misionárov s krížom.“*
4. *„Z Konštantínopola dorazili relikvie svätých mučeníkov; v uliciach podhradia kľačia zástupy v tichej modlitbe.“*

---

## 4. Rozhodnutia vyžadujúce schválenie od RM-DESIGN (SEKCIA C)

Pre ďalší vývoj a implementáciu je potrebné rozhodnutie vedúceho dizajnu (`rm-design`) v nasledujúcich bodoch:

1. **Formalizácia pravidiel následníctva v kóde (`SuccessionManager`):**
   - *Otázka:* Máme v `SuccessionManager.gd` úplne odstrániť voľbu (`election`) a ponechať výhradne **seniorát** (s možnosťou reformy na primogenitúru cez neskorší event/rozhodnutie), pričom pri absencii mužského dediča sa aktivuje stav „Dynastická kríza / Regentstvo“?
   - *Odporúčanie rm-canon:* **ÁNO.** Seniorát je jadrom moravského kánonu.

2. **Vyčistenie nekánonických testov v `test_hungarian_war_scenario.gd`:**
   - *Otázka:* Môže sa testovacia suita upraviť tak, aby testovala výhradne scenár maďarského víťazstva v roku 907 a odstránili sa zastarané očakávania moravskej výhry a reťazca `"madari"`?
   - *Odporúčanie rm-canon:* **ÁNO.** Testy musia presne odrážať nemenné pravidlá kánonu.

3. **Korekcia terminológie v katalógu eventov (`events_catalog.json`):**
   - *Otázka:* Schvaľuje `rm-design` postúpenie zmeny textov v `events_catalog.json` na profil `rm-content`, kde sa nahradia slová *„kráľovské vojsko“* a *„kráľovské sklady“* historicky presnými pojmami *„kniežacie vojsko“* a *„kniežacie sypárne“*?
   - *Odporúčanie rm-canon:* **ÁNO.**

4. **Integrácia rozšírenej sady naratívnych textov do `NarrationManager.gd`:**
   - *Otázka:* Má profil `rm-canon` / `rm-content` pripraviť komplexný pull request s 20+ novými šablónami pre `NarrationManager.gd` vrátane dynamického vkladania žúp a frakcií?
   - *Odporúčanie rm-canon:* **ÁNO.** Zabráni sa tým zlyhávaniu anti-repetičného filtra v neskorších fázach hry.

---

*Správu vypracoval:* `rm-canon`  
*Archivované v:* `docs/canon/ANALYZA_KANONU.md`
