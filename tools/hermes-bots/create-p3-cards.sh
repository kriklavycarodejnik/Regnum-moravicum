#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# create-p3-cards.sh — P3 karty pre board "regnum".
#
# Stav overený 23. 8. 2026, ~10:00 z kanban.db (stats/list), z git log/diff
# v hlavnom checkoute a z docs/canon/ANALYZA_KANONU.md. Plný rozbor:
# docs/P3_STAV_A_KARTY.md.
#
# PODMIENKY PRED SPUSTENÍM (over ich, skript ich sám nekontroluje):
#   1. OpenRouter kredit má nenulový zostatok — 23.8. ráno bolo 271x HTTP 402
#      naprieč 5 botmi, board z toho stál so 0 running.
#   2. docs/canon/ANALYZA_KANONU.md a PRIBEH.md sú commitnuté (D1/D2 z nich
#      vychádzajú, v bot worktree by inak neexistovali — rovnaká chyba ako
#      untracked DALSI_KROK_*.md v P1).
#   3. Duplicitné blocked karty na workspace_kind:scratch (t_38947f19/t_08c4de58,
#      t_f42bcd4d/t_f76947f9, t_a835c59d/t_8de6a3f6) sú opravené alebo archivované.
#
# ČO UŽ JE HOTOVÉ z auditu — nezakladaj to znova:
#   - SuccessionManager.gd: seniorát/primogenitúra namiesto voľby (commit 2e79ac7,
#     set_succession_type() existuje, _succession_type default "seniority").
#   - EventManager.gd:53-106: condition matcher má moodMin/moodMax, prestige_min/max,
#     province_loyalty — C3 z P2 je hotová.
#   - test_hungarian_war_scenario.gd: oprava Chyby č.1 je v hlavnom checkoute
#     uncommitted — over `git status`, možno ju stačí len commitnúť.
#
# Spustenie:  bash create-p3-cards.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="${REPO:-$HOME/projects/regnum-moravicum-official}"
HERMES="${HERMES:-hermes}"
BOARD="${BOARD:-regnum}"
K="$HERMES kanban --board $BOARD"

# Existujúce karty z P2, na ktoré sa P3 karty viažu ako na parent.
C4_P2="${C4_P2:-t_b7983d19}"   # P2: diplomacia s dôsledkami (blocked)
G1_P2="${G1_P2:-t_7a929c3b}"   # P2 design gate (todo)

command -v "$HERMES" >/dev/null || { echo "CHYBA: 'hermes' nie je v PATH" >&2; exit 1; }
[ -d "$REPO/godot" ] || { echo "CHYBA: repo nenájdené: $REPO" >&2; exit 1; }

read -r -d '' PROTO <<PROTO_EOF || true

---
## Protokol

- Pracuj vo svojom worktree (\$HERMES_KANBAN_WORKSPACE). Repo: $REPO
- Základ je vetva platná po zlúčení P2 gate ($G1_P2) — over si to cez git log,
  ak P2 gate ešte nedobehol, stavaj na najnovšej integračnej vetve.
- Pred dokončením: cd godot && bash tools/check_all.sh — musí byť 5/5.
- Konči cez kanban_request_review(reviewer="rm-reviewer"). Nie cez kanban_complete.
- Merge robí výhradne rm-reviewer cez ~/.hermes/scripts/regnum-merge.sh <vetva>.
- Invarianty §4.1: Devín 907 vždy winner=="attacker", max 1× za run,
  dôsledky −30 prestíž / −20 lojalita Devína / +30 mood Maďarov,
  event RNG má vlastný seed. src/ je archív — zdroj dát, nie miesto na úpravy.
- Kánon je docs/canon/ANALYZA_KANONU.md a docs/canon/PRIBEH.md. Kde si nie si
  istý menom/dátumom/vzťahom, over si ho tam skôr než si ho vymyslíš.
- **Review má strop 3 kolá.** Nález mimo scope karty = nová karta, nie blokér.
- Do metadata napíš, ako si overil, že to hráč reálne UVIDÍ. Headless test
  vizuál neoveruje.
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

echo "=== P3 karty ==="

# ===========================================================================
# DIZAJN — D1 nemá závislosť, D2 potrebuje C4 (nálada musí niečo robiť skôr,
# než na nej stavia frakčné oblúky).
# ===========================================================================

D1=$(mk rm-design 55 "design/p3-dynastia" \
"Design spec: dynastická kríza a sukcesné scenáre (P3)" \
"Spec do docs/design/P3_DYNASTIA.md. Vychádza z docs/canon/ANALYZA_KANONU.md
§3.1 (Mojmírovská dynastia, sukcesné krízy) — over si obsah v aktuálnom súbore,
môže sa medzičasom zmeniť.

STAV, ktorý si over v kóde, nie v dokumente:
  - SuccessionManager.gd má set_succession_type() a _succession_type default
    \"seniority\" (commit 2e79ac7). Voľba (election) je odstránená.
  - get_heir() vyberá mužského dediča v rámci dynastie podľa seniority/primogeniture
    (SuccessionManager.gd:90-131). Poznámka v kóde priznáva, že primogenitúra
    v skutočnosti ešte nemá genealogické väzby — over, či to pre tvoj spec stačí.

Audit navrhuje dva konkrétne scenáre — over ich a rozhodni, ktorý ide do P3:
  1. \"Krvavý snem v Nitre\" — Svätopluk II. spochybní vládu pri lojalite Nitry
     < 40 a prestíži < 20. Tri možnosti riešenia (údel, žalár, prísaha).
  2. \"Vymretie po meči a byzantské regentstvo\" — panovník zomrie s maloletým
     dedičom (< 16), Theodora preberá regentstvo, franská/bavorská frakcia
     to označí za \"gréckou tyraniou\".

Navrhni:
  1. Presné spúšťacie podmienky v jazyku existujúceho condition matchera
     (EventManager.gd:53-106: moodMin/moodMax, prestige_min/max, province_loyalty,
     flag/not_flag) — nevymýšľaj nové polia, ak sa dá vyjadriť existujúcimi.
  2. Ako sa scenár napojí na get_heir()/process_succession() — nová vetva,
     alebo eventy, ktoré menia vstupy do existujúcej logiky?
  3. Dôsledky v mene, ktorú hra už má (prestíž, lojalita, mood, gold) — žiadna
     nová mena.
  4. Ako sa hráč dozvie, že kríza prebieha, skôr než dopadne (varovanie
     v TurnReporte alebo ObjectivesPanel, nie prekvapenie).

Ku každej položke akceptačné kritérium overiteľné bez teba. Scope nezväčšuj —
Predslav a mladšia generácia (Rastislav, Gorazd) z §3.1 nechaj ako budúci
obsah, spomeň ich len ako mená pre budúce eventy, neimplementuj ich teraz.")
echo "  D1 spec dynastia      -> $D1"

D2=$(mk rm-design 50 "design/p3-frakcie" \
"Design spec: frakčné oblúky 907-930 ako event reťazce (P3)" \
"Spec do docs/design/P3_FRAKCIE.md. Vychádza z docs/canon/ANALYZA_KANONU.md §3.2.

NEZAČÍNAJ, kým C4 (nálada s dôsledkami, $C4_P2) nie je zlúčená — bez nej mood
nemá mechanický dopad, na ktorom by tieto oblúky dávali zmysel. Over si to cez
kanban_show $C4_P2 pred štartom.

STAV, ktorý si over:
  - DiplomacyManager má 7 frakcií (moravia, franks, bavaria, hungary, poland,
    bohemia, byzantium), každá s mood 0-100 (DiplomacyManager.gd:24-30).
  - process_diplomacy() (riadky 57-77) po C4 už nálade priradí mechanický
    dôsledok — zisti ktorý, aby si naň nadviazal, nie ho duplikoval.

Audit navrhuje štyri oblúky — vyber a rozpracuj aspoň Maďarov (najbližšie
k jadru hry cez Devín 907):
  1. Maďari: tributárny mier (striebro/dane výmenou za nájazdy smerom na
     západ) VS. permanentná partizánska vojna. Toto sa NESMIE dotknúť
     kánonu Devína 907 — ten zostáva fixný, oblúk je o období PO 907.
  2. Byzancia: kultúrny vplyv (grécki stavitelia, Zakon sudnyj ljudem) proti
     riziku odcudzenia západných žúp (Morava, Trenčín).
  3. Bavorsko/Franská ríša: Moravy ako sprostredkovateľ po ich porážke pri
     Devíne, za cenu ústupkov pasovskému biskupovi.
  4. Čechy/Poľsko: dynastické sobáše, severný obranný val.

Pre vybraný oblúk (aspoň jeden, ideálne dva) navrhni:
  1. Konkrétne prahy mood/prestige/loyalty, pri ktorých sa oblúk posúva
     (číselne, nie \"keď je nálada nízka\").
  2. Eventy alebo side-goals, cez ktoré sa rozhodnutie prejaví — napoj na
     existujúci ObjectivesPanel.compute_beats(), nevytváraj paralelný systém.
  3. Nezvratné vetvy vs. vratné — ktoré rozhodnutie hráč nemôže vziať späť.

Ku každej položke akceptačné kritérium overiteľné bez teba." \
"$C4_P2")
echo "  D2 spec frakcie       -> $D2"

# ===========================================================================
# CONTENT — nezávislé od integrácie, ale koordinuj s prebiehajúcou prácou
# na NarrationManager.gd v hlavnom checkoute (over git log pred štartom).
# ===========================================================================

C1=$(mk rm-content 45 "content/p3-naracia-rozsirenie" \
"P3: 16 naratívnych textov z kánonického auditu do NarrationManager" \
"docs/canon/ANALYZA_KANONU.md §3.3 má 16 hotových textov (4 kategórie po 4)
s moravským registrom — economy, diplomacia, vojna, náboženstvo. Over si
najprv git log na NarrationManager.gd — v hlavnom checkoute prebiehala
súbežná uncommitted práca na tomto súbore (Chyba č.3/č.4 z auditu), aby si
si nevyrobil merge konflikt s prácou, ktorá už existuje.

Postup:
  - skopíruj 16 textov zo spec-u do príslušných _generate_*_text() metód
  - dosaď dynamické mená žúp/frakcií tam, kde to text umožňuje (nenechávaj
    ich ako statický reťazec, ak môžu byť parametrizované ako existujúce)
  - drž sa per-kategória anti-repetition oknom, ktoré zaviedla P2 karta C1
    (nekopíruj globálne okno 12, ktoré viedlo k vyčerpaniu variantov)

Akceptácia:
  - simulácia 24 po sebe idúcich ťahov nevráti fallback \"Mesiac uplynul v tichu\"
    ani raz v žiadnej zo štyroch kategórií
  - všetkých 16 nových textov sa aspoň raz objaví v 48-ťahovej simulácii
  - check_all.sh 5/5")
echo "  C1 naracia rozsirenie -> $C1"

# ===========================================================================
# IMPLEMENTÁCIA — čaká na zlúčenie P2 design gate (G1_P2), aby sa nestavalo
# na vetve, ktorá sa ešte len ide zlučovať.
# ===========================================================================

C2=$(mk rm-godot 40 "feat/p3-dynasticka-kriza" \
"P3: implementácia dynastickej krízy (podľa D1 spec)" \
"Implementuj docs/design/P3_DYNASTIA.md (karta D1). Bez spec-u nezačínaj.

Nedotýkaj sa toho, čo funguje: SuccessionManager.get_heir()/process_succession()
majú existujúce testy pre bežné dedenie — pridávaš krízovú vetvu, neprepisuješ
základ.

Akceptácia:
  - kríza sa spustí presne za podmienok zo spec-u, nie skôr/neskôr
  - hráč dostane varovanie pred dopadom, nie až po ňom
  - save/load zachová rozpracovanú krízu
  - deterministický test: rovnaký seed a rovnaké voľby = rovnaký výsledok
  - Devín 907 kánon sa touto kartou nemení — ak sa pri práci ukáže, že by
    musel, zastav a založ kartu, nerieš to tu
  - check_all.sh 5/5" \
"$D1" "$G1_P2")
echo "  C2 dynasticka kriza   -> $C2"

C3=$(mk rm-godot 35 "feat/p3-frakcne-obluky" \
"P3: implementácia frakčných oblúkov (podľa D2 spec)" \
"Implementuj docs/design/P3_FRAKCIE.md (karta D2). Bez spec-u nezačínaj.

Akceptácia:
  - aspoň jeden frakčný oblúk zo spec-u má viditeľný, hráčom voliteľný uzol
  - dôsledok voľby je viditeľný bez otvorenia panela (TurnReport/notifikácia/mapa)
  - Devín 907 kánon sa nemení
  - check_all.sh 5/5" \
"$D2" "$G1_P2")
echo "  C3 frakcne obluky     -> $C3"

# ===========================================================================
# QA + GATE
# ===========================================================================

Q1=$(mk rm-qa 25 "qa/p3-regresia" \
"QA P3: regresia a vizuálna trasa po P3" \
"To isté ako pre P2, rozšírené o dynastickú krízu a frakčné oblúky.

Spusti DISPLAY-BACKED, nie headless — v P1 na headless spadli štyri pokusy.
Ak sa display-backed beh nedá spustiť z workera, NEskúšaj to štvrtýkrát:
kanban_block(kind=capability) a napíš presný príkaz pre Lukáša.

Trasa:
  1. plná regresia check_all.sh — 5/5
  2. 24 mesiacov od 903 bez jediného fallback textu Mesiac uplynul v tichu
  3. aspoň jedna dynastická kríza sa spustí a hráč urobí voľbu — snímka
  4. aspoň jeden frakčný oblúk sa posunie a hráč to vidí — snímka pred/po
  5. Devín 907: winner=attacker, raz za run, dôsledky sedia (nezmenené P3-kou)

Akceptácia: ku každému bodu jedna veta, čo na snímke hráč vidí, a verdikt.
Bod, ktorý si neoveril na obrazovke, označ ako neoverený — nie ako PASS." \
"$C1" "$C2" "$C3")
echo "  Q1 QA regresia        -> $Q1"

G1=$(mk rm-design 20 "design/p3-gate" \
"P3 design gate — 10-minútová trasa po P3" \
"To isté, čo pre P0/P1/P2. Výstup: docs/design/P3_DESIGN_GATE.md.

P1 gate vydal PASS 5/5 pre veci, ktoré boli len v spec-e — nezopakuj to.
Hodnoť len to, čo vidíš na snímkach z Q1, nie čo tvrdí kód alebo spec.
Kde snímka chýba, výrok je neoverený, nie PASS.

Päť testov (prerozprávanie, cena, predvídateľnosť, špecifickosť, tempo) na
trase 902 → 907 → 915 → 930. Verdikt PASS alebo PREPRACOVAŤ s konkrétnymi
náhradami.

Nález mimo P3 = triage karta pre P4, nie blokér." \
"$Q1")
echo "  G1 design gate        -> $G1"

echo
echo "=== Hotovo. 7 kariet. ==="
echo "Hneď spustiteľné (bez blokujúcej závislosti v P3): D1 $D1, C1 $C1"
echo "Čaká na C4 ($C4_P2): D2 $D2"
echo "Čaká na P2 gate ($G1_P2): C2 $C2, C3 $C3"
