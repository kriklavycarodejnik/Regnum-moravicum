#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# create-p2-cards.sh — P2 karty pre board "regnum".
#
# Stav overený 21. 8. 2026, 08:45 priamo z kanban.db, z vetvy
# fix/p1-kontrakt-clean a z docs/design/P1_DESIGN_GATE.md.
#
# ČO UŽ JE HOTOVÉ — nezakladaj to znova (overené v kóde, nie z dokumentov):
#   - Byzancia ako 7. frakcia: DiplomacyManager._ensure_default_factions() ju MÁ,
#     EventManager._resolve_faction_id() vracia "byzantium". DALSI_KROK_BYZANCIA.md
#     je zastaraný dokument, nie otvorená úloha.
#   - M8.3 fázová bitka: BattleManager.begin_phased_battle() + resolve_phase_round()
#     existujú, Main.gd:742 ich volá, BattleView má akčné tlačidlá. Chýba len
#     použitie MIMO cvičného skirmishu.
#   - M8.4 polygónová mapa: MapView.gd má POLY_SCALE, JITTER_RANGE,
#     _province_polygon(), draw_colored_polygon() pre všetkých 12 žúp.
#
# Priority sú zámerne pod 60, aby dobiehajúce P1 karty (95–60) mali prednosť
# pri max_in_progress: 3.
#
# Spustenie:  bash create-p2-cards.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="${REPO:-$HOME/projects/regnum-moravicum-official}"
HERMES="${HERMES:-hermes}"
BOARD="${BOARD:-regnum}"
K="$HERMES kanban --board $BOARD"

# Integračná karta z P1 — implementačné karty na ňu čakajú.
INTEG="${INTEG:-t_abcf645c}"

command -v "$HERMES" >/dev/null || { echo "CHYBA: 'hermes' nie je v PATH" >&2; exit 1; }
[ -d "$REPO/godot" ] || { echo "CHYBA: repo nenájdené: $REPO" >&2; exit 1; }

read -r -d '' PROTO <<PROTO_EOF || true

---
## Protokol

- Pracuj vo svojom worktree (\$HERMES_KANBAN_WORKSPACE). Repo: $REPO
- Základ je **main**. Over si to: ak git log main..fix/p1-kontrakt-clean nie je
  prázdny, integračná karta ešte nedobehla — vtedy stavaj na fix/p1-kontrakt-clean.
  Pred prácou: git fetch a rebase na tú vetvu, ktorá platí.
- Pred dokončením: cd godot && bash tools/check_all.sh — musí byť 7/7.
- Konči cez kanban_request_review(reviewer="rm-reviewer"). Nie cez kanban_complete.
- Merge robí výhradne rm-reviewer cez ~/.hermes/scripts/regnum-merge.sh <vetva>.
- Invarianty §4.1: Devín 907 vždy winner=="attacker", max 1× za run,
  dôsledky −30 prestíž / −20 lojalita Devína / +30 mood Maďarov,
  event RNG má vlastný seed. src/ je archív — zdroj dát, nie miesto na úpravy.
- **Review má strop 3 kolá.** Nález mimo scope karty = nová karta, nie blokér.
- Do metadata napíš, ako si overil, že to hráč reálne UVIDÍ. Headless test
  vizuál neoveruje — to je presne chyba, ktorá v P0 prešla ako 5/5 PASS
  na hre, ktorá sa nedala rozohrať.
PROTO_EOF

mk() {  # mk <assignee> <prio> <branch> <title> <body> [parent...]
  local assignee="$1" prio="$2" branch="$3" title="$4" body="$5"; shift 5
  local args=( create "$title" --assignee "$assignee" --priority "$prio"
               --body "$body$PROTO" --workspace "worktree:$REPO/.worktrees/$branch"
               --branch "$branch" --max-runtime 2h --max-retries 2
               --idempotency-key "regnum-$branch" --json )
  for p in "$@"; do args+=( --parent "$p" ); done
  $K "${args[@]}" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("task_id") or d.get("id") or (d.get("task") or {}).get("id",""))'
}

echo "=== P2 karty ==="

# ===========================================================================
# DIZAJN — tri spec karty. Nemajú závislosť na integrácii, lebo píšu len
# do docs/design/. Môžu bežať hneď, kým dobiehajú P1 karty.
# ===========================================================================

D1=$(mk rm-design 55 "design/p2-diplomacia" \
"Design spec: diplomacia s dôsledkami (P2)" \
"Spec do docs/design/P2_DIPLOMACIA.md.

STAV, ktorý si over (nededukuj z dokumentov, tie sú miestami zastarané):
  - DiplomacyManager má 7 frakcií vrátane byzantium, funkcie send_gift(),
    threaten(), set_treaty() a process_diplomacy().
  - DiplomacyPanel má 5 tlačidiel (dar, hrozba, pakt o neútočení, obchod,
    vojenský pakt) a zobrazuje všetky frakcie generickycky.
  - process_diplomacy() robí dnes JEDINÚ vec: náhodný drift nálady
    −2 až +2 za mesiac, zmluvy ho zjemnia. Nič viac.
  - Nálada NEVSTUPUJE do ničoho: events_catalog.json má v conditions len
    year / month / yearMin. Žiadny event, žiadna hrozba, žiadny side-goal
    sa nepýta na náladu frakcie.

Problém na vyriešenie: hráč má päť diplomatických tlačidiel, ktoré stoja
zlato, a jediný ich následok je posunuté číslo v paneli. To je odmena bez
ceny obrátene — cena bez odmeny. Tvoj vlastný gate to zakazuje.

Navrhni:
1) Čo nálada REÁLNE spôsobí. Minimálne tri kanály, každý viditeľný:
   - vstup do podmienok eventov (ktoré eventy sa odomknú/zamknú a pri akom prahu)
   - vstup do hrozieb (nálada Maďarov pod prahom = častejšie nájazdy, skorší
     alebo tvrdší dopad; kánon Devína 907 sa NEMENÍ)
   - vstup do side-goalov a beatov (diplomatický cieľ, ktorý sa dá splniť)
2) Ceny akcií tak, aby dar nebol vždy najlepšia voľba. Aspoň jedna akcia
   musí mať následok, ktorý hráč môže ľutovať.
3) Ako sa hráč dozvie, že to funguje — konkrétny UI prvok, nie „panel to ukáže\".

Prahy uveď číselne (napr. mood < 25 / 25–50 / > 75), aby ich rm-core vedel
zapísať bez ďalšieho kola otázok. Ku každej položke akceptačné kritérium,
ktoré overí rm-qa bez teba. Prejdi svojich päť testov. Scope nezväčšuj —
nové nápady sú triage karty pre P3.")
echo "  D1 spec diplomacia    -> $D1"

D2=$(mk rm-design 52 "design/p2-bitka" \
"Design spec: fázová bitka mimo cvičnej (P2)" \
"Spec do docs/design/P2_BITKA.md.

STAV, ktorý si over: fázová bitka NIE JE nová stavba, je hotová a zapojená
len na jednom mieste.
  - BattleManager.begin_phased_battle(), resolve_phase_round(), pick_ai_action()
    existujú a sú deterministické (test_battle_manager.gd overuje zhodu pri
    rovnakom seede).
  - BattleView má akčné tlačidlá (útok / streľba / obchvat) a vie vykresliť
    phase_logs.
  - Main.gd:737 _on_skirmish() je JEDINÝ volajúci. Dve kolá + rozhodnutie,
    pevná zostava 1000 vs 800, terén natvrdo field.

Problém: hráč sa k jedinému taktickému rozhodnutiu v hre dostane cez tlačidlo
Cvičná bitka, ktoré nemá následky. Skutočné strety (rand_border_raid,
bogata_uprising_917) sa odbavia textom a číslami.

Navrhni:
1) Ktoré existujúce strety idú cez fázovú bitku a ktoré zostanú textové.
   Devín 907 zostáva na HungarianWarScenario.resolve_devine_battle() —
   kánon je chránený, fázové voľby doňho nezasahujú. Toto NEOTVÁRAJ.
2) Odkiaľ sa berie zostava a terén: veľkosť a morálka z reálnych armád
   v GameState, terén z vlastností župy, nie konštanty.
3) Čo hráč pri prehre stratí a čo pri výhre získa — v mene, ktorú už hra má
   (vojaci, lojalita župy, prestíž, nálada frakcie). Žiadna nová mena.
4) Ako sa cvičná bitka odlíši od skutočnej, aby hráč vedel, kedy sa hrá o niečo.

Ku každej položke akceptačné kritérium overiteľné bez teba. Prejdi päť testov.
Ak z toho vyjde, že terén treba uložiť do province dát, napíš presné pole a
predvolenú hodnotu — nenechávaj to na implementátora.")
echo "  D2 spec bitka         -> $D2"

D3=$(mk rm-design 50 "design/p2-vizual" \
"Design spec: vizuálny dlh a obrazovky (P2)" \
"Spec do docs/design/P2_VIZUAL.md. Vychádzaj z docs/CHYBAJUCA_GRAFIKA_NOVA_IDENTITA.md,
ale over ho voči disku — časť tvrdení je staršia než dnešný stav.

Tri veci na rozhodnutie:

1) ERBY — dokument ponúka dve cesty a nerozhodol. Rozhodni ty a zdôvodni:
   (a) šesť nových vnútro-moravských subjektov (rada, cirkev, rody) POPRI
       existujúcich siedmich diplomatických emblémoch, alebo
   (b) zoznam je zastaraný a stačí prekresliť existujúcich 7 v novom
       heraldickom štýle.
   Rozhodnutie má dôsledok na DiplomacyManager, tak ho napíš aj tam.

2) ČO SA DÁ SPRAVIŤ BEZ NOVEJ GRAFIKY. Toto je hlavná časť spec-u.
   Boti nevedia kresliť PNG. Rozdeľ vizuálny dlh na:
   - položky, ktoré sú UI/dátová práca s existujúcimi assetmi
     (napr. kľúč icon_gold bez prípony _64 v art_map.json, kronika ako
     štruktúrovaný zoznam namiesto plochého logu, loading screen zo
     existujúcich hero obrázkov)
   - položky, ktoré naozaj potrebujú nový obrázok od Lukáša — k tým napíš
     presný prompt a cieľový kľúč v art_map.json, nič iné.
   Pre druhú skupinu navrhni graceful placeholder, aby chýbajúci súbor
   nerozbil scénu.

3) PORADIE. Čo z toho zmení dojem z hry najviac na jeden zásah, a čo je
   kozmetika. Zoraď, nepíš „všetko je dôležité\".

Audio do P2 nepatrí — vynechaj ho aj zo zoznamu.
Ku každej položke akceptačné kritérium overiteľné bez teba.")
echo "  D3 spec vizuál        -> $D3"

# ===========================================================================
# IMPLEMENTÁCIA — čakajú na integračnú kartu (fast-forward main),
# aby sa nestavalo na vetve, ktorá sa ide zlučovať.
# ===========================================================================

C1=$(mk rm-content 48 "fix/p2-naracia" \
"P2: NarrationManager — nekonzistentný economy text a vyčerpané varianty" \
"Dva nálezy z P1 design gate (docs/design/P1_DESIGN_GATE.md §6). Sú v jednom
súbore, preto sú v jednej karte — dve paralelné vetvy na NarrationManager.gd
by si vyrobili konflikt.

NÁLEZ 1 — logická nekonzistencia (NarrationManager.gd:146)
_generate_economy_text() vždy spomína župana z Gemera bez ohľadu na to, ktorú
župu vybral rng do locatívu. Keď rng vyberie Gemer, text znie: Sypárnice
v Gemeri sa plnia, no župan z Gemera poslal posla so žiadosťou o zrno.
Jedna župa má súčasne prebytok aj núdzu.
Náprava: druhú župu vyber z rovnakého poľa kľúčov tak, aby sa nerovnala prvej.
Fallback na generické pohraničie použi len vtedy, ak sú v hre menej než dve župy.

NÁLEZ 2 — anti-repetition vyčerpá economy varianty (NarrationManager.gd:116)
_apply_anti_repetition() drží 12 posledných šablón. Economy má ~12 variantov,
takže po 12 ťahoch vracia prázdny reťazec a Main.gd:1063 dosadí fallback
Mesiac uplynul v tichu dvorov a polí. V rokoch 908–914, keď nestrieľajú
random eventy (cooldown 15–24) ani rada županov (8 %), to podľa gate-u
zasiahne 30–40 % ťahov.
Náprava — obe časti:
  a) anti-repetition drž per kategória, nie globálne. Opakovanie ekonomickej
     vety po ôsmich mesiacoch nevadí; opakovanie vojnovej vety áno.
  b) dopíš economy varianty tak, aby ich bolo aspoň dvojnásobne viac než je
     okno pre túto kategóriu. Register drž moravský — mená, župy, plodiny,
     sypárnice, mýto, brod. Žiadna veta nesmie byť zameniteľná s inou
     stredovekou hrou.

Akceptácia:
  - simulácia 24 po sebe idúcich economy ťahov nevráti ani raz prázdny text
    (napíš na to test do tools/, nie ručné klikanie)
  - v žiadnej vygenerovanej vete nie je tá istá župa v prebytku aj v núdzi
  - fallback Mesiac uplynul v tichu ostáva v kóde ako posledná poistka,
    ale v teste sa nesmie objaviť
  - check_all.sh 7/7" \
"$INTEG")
echo "  C1 narácia            -> $C1"

C2=$(mk rm-content 45 "feat/p2-eventy-18" \
"P2: doport piatich zvyšných React eventov (katalóg 13 → 18)" \
"P1 kontrakt §1.1 zámerne vynechal päť eventov, ktoré v archíve src/ existujú
a sú hotové. P1 scope bol 14 položiek vrátane fallbacku rady županov; dnes je
v godot/data/events_catalog.json 13 eventov + council fallback. Tieto zostali:

  hist_hungarian_rumors_904   (src/data/historicalEvents.ts:42)
  hist_byzantine_envoy_904    (src/data/historicalEvents.ts:64)
  hist_german_ultimatum_910   (src/data/historicalEvents.ts:113)
  rand_traveling_merchant     (src/data/historicalEvents.ts:186)
  rand_court_intrigue         (src/data/historicalEvents.ts:286)

Prečo teraz: roky 904, 908–914 sú najtenšie miesto trasy — presne tam, kde
gate našiel fallback text. Tri z týchto piatich padnú do tejto diery.

Postup rovnaký ako pri porte 14 eventov:
  - dáta do events_catalog.json, snake_case kľúče (next_event, nie nextEvent)
  - moodChanges cieľ prelož cez EventManager._resolve_faction_id(); Byzancia
    už frakciou JE, takže byzantský vyslanec 904 má reálny dopad
  - art_id namapuj na existujúce mastery, nevymýšľaj nové kľúče
  - slovenčinu prepíš do moravského registra, nie doslovný preklad z angličtiny;
    každý event má 3–6 viet a aspoň dve voľby s rôznou cenou
  - váhy a cooldowny drž v duchu §1.3 a §1.7 P1 kontraktu

Akceptácia:
  - events_catalog.json má 18 eventov, žiadny duplicitný id
  - smoke test cez 24 mesiacov od 903 ukáže aspoň tri z nových eventov
  - žiadna voľba nie je bez ceny (aspoň jedna mena sa hýbe)
  - do docs/design/P1_KONTRAKT.md dopíš dodatok P2: zoznam 18, nie prepisuj
    pôvodnú tabuľku 14
  - check_all.sh 7/7" \
"$INTEG")
echo "  C2 eventy 18          -> $C2"

C3=$(mk rm-core 43 "feat/p2-condition-matcher" \
"P2: condition matcher — nálada, prestíž a lojalita ako podmienky eventov" \
"Otvorené z P1 kontraktu §1.2 (riadok 88): pokročilejší condition matcher bol
odložený ako triage pre P2. Teraz to blokuje diplomaciu.

Dnešný stav: conditions v events_catalog.json poznajú len year, month a
yearMin. Overiteľné: žiadny z 13 eventov nemá inú podmienku. Preto sa žiadny
event nevie spýtať, či sú Maďari nahnevaní alebo či je hráč v hanbe.

Implementuj podľa prahov z docs/design/P2_DIPLOMACIA.md (D1) — čísla neber
z hlavy, ber ich zo spec-u.

Rozšír matcher o:
  - faction_mood: { faction_id: byzantium, max: 30 } a min variant
  - prestige_min / prestige_max
  - province_loyalty: { province: nitra, max: 30 }
  - not_flag / flag pre stavy typu army_wizard_done, devine_resolved

Tvrdé požiadavky:
  - neznáma podmienka = event sa NEVYberie a zapíše sa varovanie, nikdy nie
    ticho prejde ako splnená
  - vyhodnotenie je čisté čítanie GameState, žiadny randf mimo seedovaného RNG
  - spätná kompatibilita: existujúcich 13 (resp. 18) eventov sa nesmie správať
    inak než dnes; deterministický seed test to musí dokázať pred aj po zmene

Akceptácia:
  - unit test pre každý nový typ podmienky, vrátane neznámej podmienky
  - deterministický 24-mesačný beh so seedom má rovnakú postupnosť ID ako pred
    zmenou, ak žiadny event nové podmienky nepoužíva
  - check_all.sh 7/7" \
"$D1" "$INTEG")
echo "  C3 condition matcher  -> $C3"

C4=$(mk rm-godot 40 "feat/p2-diplomacia-dosledky" \
"P2: diplomacia s dôsledkami — nálada, ktorá niečo robí" \
"Implementuj docs/design/P2_DIPLOMACIA.md (karta D1). Bez toho spec-u nezačínaj,
podmienky ti dodá condition matcher z karty C3.

Nedotýkaj sa toho, čo funguje: DiplomacyPanel zobrazuje frakcie generickycky
cez list_factions(), send_gift/threaten/set_treaty majú svoje guardy a
existujúce testy. Pridávaš následky, neprepisuješ vrstvu.

Minimálne tri kanály zo spec-u:
  - nálada vstupuje do podmienok eventov (cez C3, nie vlastnou vetvou)
  - nálada vstupuje do hrozieb — Devín 907 kánon sa NEMENÍ, mení sa okolie
  - aspoň jeden splniteľný diplomatický side-goal, ktorý sa napojí na
    existujúce beaty v ObjectivesPanel.compute_beats()

Akceptácia:
  - hráč vidí následok bez otvorenia panela: v TurnReporte, notifikácii alebo
    na mape. Priloženú snímku alebo runtime test uveď v metadata.
  - dar má cenu, ktorú hráč pocíti; aspoň jedna akcia môže vyjsť naopak
  - save/load zachová vzťahy aj rozpracovaný diplomatický cieľ
  - smoke test: nálada frakcie klesne pod prah a to sa PREUKÁZATEĽNE prejaví
    v hre, nielen v čísle
  - check_all.sh 7/7" \
"$D1" "$C3")
echo "  C4 diplomacia         -> $C4"

C5=$(mk rm-godot 38 "feat/p2-bitka-realna" \
"P2: fázová bitka v skutočných stretoch, nielen v cvičnej" \
"Implementuj docs/design/P2_BITKA.md (karta D2).

Východisko, ktoré NEROBÍŠ znova: begin_phased_battle(), resolve_phase_round(),
pick_ai_action() v BattleManager.gd sú hotové a deterministické. BattleView má
akčné tlačidlá aj vykresľovanie phase_logs. Main.gd:737 _on_skirmish() je vzor —
skopíruj tok, nie konštanty.

Devín 907 zostáva na HungarianWarScenario.resolve_devine_battle().
Ak sa pri práci ukáže, že kánon je ohrozený, zastav a založ kartu — nerieš to.

Akceptácia:
  - aspoň jeden skutočný stret zo spec-u prebehne fázovo a hráč v ňom vyberá
  - zostava a terén sa berú zo stavu hry, nie z konštánt v _on_skirmish
  - výsledok sa zapíše do GameState — straty, lojalita alebo nálada podľa spec-u
  - prehra má následok, ktorý hráč uvidí v ďalšom ťahu
  - deterministický test: rovnaký seed a rovnaké voľby = rovnaký výsledok
  - cvičná bitka funguje ako doteraz a je vizuálne odlíšená od skutočnej
  - check_all.sh 7/7" \
"$D2")
echo "  C5 bitka              -> $C5"

C6=$(mk rm-godot 35 "feat/p2-vizual-dlh" \
"P2: vizuálny dlh, ktorý sa dá spraviť bez novej grafiky" \
"Implementuj časť 2 z docs/design/P2_VIZUAL.md (karta D3) — výhradne položky,
ktoré spec označil ako UI/dátovú prácu s existujúcimi assetmi.
Nové PNG nevyrábaš a negeneruješ. Kde spec žiada obrázok od Lukáša, sprav
graceful placeholder, aby chýbajúci súbor nerozbil scénu, a napíš to do summary.

Isté položky (zvyšok podľa spec-u):
  - art_map.json: kľúč icon_gold nemá príponu _64 ako ostatných šesť
    resource ikon — zjednotiť a overiť, že sa ikona naozaj zobrazí
  - kronika je dnes plochý textový log; spec navrhuje štruktúrovaný zoznam

Akceptácia:
  - každá zmena je doložená snímkou alebo runtime testom, nie tvrdením
  - žiadny chýbajúci asset nespôsobí chybu pri štarte scény
  - existujúce vrstvenie panelov sa nerozbije (karta fix/ux-layering je hotová,
    neprešľapuj ju)
  - check_all.sh 7/7" \
"$D3")
echo "  C6 vizuálny dlh       -> $C6"

C7=$(mk rm-content 30 "docs/p2-aktualizacia" \
"P2: dokumentačný dlh — tri dokumenty klamú o stave" \
"Malá karta, ale drahá, ak sa neurobí: agent, ktorý si tieto súbory prečíta,
začne stavať niečo, čo už stojí.

ZOZNAM JE ZÁVÄZNÝ. Presne tieto tri súbory, žiadny iný:

  1. docs/DALSI_KROK_M8.3_FAZOVA_BITKA.md
  2. docs/DALSI_KROK_BYZANCIA.md
  3. docs/DALSI_KROK_KRITICKE_BUGY_CODEX.md

docs/DALSI_KROK_M8.4_POLYGON_MAPA.md sa NEDOTÝKAJ — MapView.gd sa práve mení
kartou na vizuálnu progresiu mapy a stavový blok by o deň klamal tiež.
Ostatné dokumenty v docs/ tiež nechaj — nie je to upratovacia karta.

Čo som overil 21. 8. 2026 v kóde. Ku každému bodu si to over sám a do stavového
bloku napíš súbor a riadok, na ktorom to vidíš. Kde sa nezhodneme, platí kód:

  M8.3 — dokument popisuje, čo treba postaviť. BattleManager.begin_phased_battle()
  a resolve_phase_round() existujú, Main.gd:742 ich volá, BattleView má akčné
  tlačidlá a vykresľuje phase_logs. Otvorené je LEN použitie mimo cvičnej bitky,
  a to rieši samostatná karta.

  BYZANCIA — dokument si pýta rozhodnutie, či pridať Byzanciu ako 7. frakciu.
  Byzancia už je v DiplomacyManager._ensure_default_factions() a
  EventManager._resolve_faction_id() vracia byzantium, nie prázdny reťazec.
  Rozhodnutie padlo, dokument o tom nevie. Otvorený zostáva bod 2.3 (tvar guardu
  v HungarianWarScenario) — ten v stavovom bloku nechaj ako stále platný.

  KRITICKE_BUGY_CODEX — tri nálezy z Codex review. Podľa môjho čítania sú
  všetky tri opravené: get_pending_event() v GameManager.gd má vetvu pre
  TYPE_ARRAY, _try_historical_event() v EventManager.gd preskakuje záznamy
  s req_year == 0, MainMenu._on_new() volá GameManager.reset(). TOTO OVER
  OBZVLÁŠŤ POZORNE — ak niektorý bug žije, nepíš stavový blok, ale založ
  kartu na opravu a v summary to povedz.

Úloha: na začiatok každého z troch súborov daj stavový blok — čo je hotové,
k akému commitu to bolo overené, čo z dokumentu ešte platí. Text pod blokom
nemaž, je to história rozhodnutí.

Akceptácia:
  - tri súbory, tri stavové bloky, každý s dátumom a commit hashom
  - každé tvrdenie v bloku má odkaz na súbor a riadok
  - žiadna zmena v godot/ ani v src/
  - ak si našiel živý bug, je z toho karta a nie stavový blok")
echo "  C7 dokumentačný dlh   -> $C7"

# ===========================================================================
# QA + GATE
# ===========================================================================

Q1=$(mk rm-qa 28 "qa/p2-regresia" \
"QA P2: regresia a vizuálna trasa po P2" \
"To isté, čo si robil pre P1, ale po P2. Trasa sa rozšírila o diplomaciu
a skutočnú bitku.

Spusti DISPLAY-BACKED, nie headless. Godot --headless nevie zachytiť viewport —
v P1 na tom spadli štyri pokusy. Ak sa display-backed beh nedá spustiť
z workera, NEskúšaj to štvrtýkrát: kanban_block(kind=capability) a napíš
presný príkaz pre Lukáša.

Trasa:
  1. plná regresia check_all.sh — 7/7
  2. 24 mesiacov od 903 bez jediného fallback textu Mesiac uplynul v tichu
  3. aspoň tri nové eventy z katalógu 18 sa objavia
  4. diplomatická akcia s viditeľným následkom — snímka pred a po
  5. skutočný fázový stret s voľbou hráča — snímka
  6. mapa v 902 a mapa v 915 vedľa seba — musia vyzerať inak
  7. Devín 907: winner=attacker, raz za run, dôsledky sedia

Akceptácia: ku každému bodu jedna veta, čo na snímke hráč vidí, a verdikt.
Bod, ktorý si neoveril na obrazovke, označ ako neoverený — nie ako PASS." \
"$C1" "$C2" "$C4" "$C5" "$C6")
echo "  Q1 QA regresia        -> $Q1"

G1=$(mk rm-design 25 "design/p2-gate" \
"P2 design gate — 10-minútová trasa po P2" \
"To isté, čo si robil pre P0 a P1. Výstup: docs/design/P2_DESIGN_GATE.md.

P1 gate vydal PASS 5/5. Jeho slabé miesto pomenuj a nezopakuj: hodnotil
side-goals ako implementované v čase, keď boli len v spec-e, a robil to
čítaním kódu bez GUI. Tentoraz máš snímky z karty Q1 — použi ich a k
verdiktu píš, ktorá snímka ho dokazuje.

Päť testov (prerozprávanie, cena, predvídateľnosť, špecifickosť, tempo) na
trase 902 → 907 → 915 → 920. Verdikt PASS alebo PREPRACOVAŤ s konkrétnymi
náhradami; kde test padne, napíš, ktorý špecialista to opraví.

Nález mimo P2 = triage karta pre P3, nie blokér." \
"$Q1")
echo "  G1 design gate        -> $G1"

# ===========================================================================
# Upratanie: stará triage karta na economy naráciu je teraz duplicitná s C1.
# Priorita 0 v triage = dispatcher ju aj tak nikdy nezoberie, ale nech
# nestraší v boarde.
# ===========================================================================
if [ -n "${C1:-}" ]; then
  $K comment t_2e9f4251 --body "Nahradené kartou $C1 (P2: NarrationManager — oba nálezy v jednej vetve). Archivujem, aby sa práca nerobila dvakrát." >/dev/null 2>&1 || true
  if $K archive t_2e9f4251 >/dev/null 2>&1; then
    echo "  t_2e9f4251 archivovaná (duplicita s C1)"
  else
    echo "  POZOR: t_2e9f4251 sa nepodarilo archivovať — zavri ju ručne v dashboarde"
  fi
fi

echo
echo "=== Hotovo. 11 kariet. ==="
echo "Hneď spustiteľné (bez závislosti): D1 $D1, D2 $D2, D3 $D3"
echo "Čaká na integračnú kartu $INTEG: C1 $C1, C2 $C2, C3 $C3"
echo
echo "Pri max_in_progress_per_profile: 1 sa D1–D3 zoradia za sebou (všetky tri"
echo "sú rm-design), takže zaberú jeden slot, nie tri. Bez tej voľby zoberú"
echo "všetky tri sloty naraz."
