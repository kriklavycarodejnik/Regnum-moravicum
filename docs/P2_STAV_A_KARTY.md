# Regnum Moravicum — stav boardu a karty pre P2

Stav k 21. 8. 2026, 08:45. Čítané priamo z `~/.hermes/kanban/boards/regnum/kanban.db`,
z vetvy `fix/p1-kontrakt-clean` a z `docs/design/P1_DESIGN_GATE.md`.

---

## 1. Board práve teraz

Gateway beží od 20. 8. 17:17, ESTOP je zhodený, dispatcher berie karty.
Config sedí s odporúčaniami z validačnej baseline: `max_in_progress: 3`,
`free_only: true` + `openrouter_model: nvidia/nemotron-3-ultra-550b-a55b:free`,
decomposer aj triage_specifier sú preč z Luny na deepseek.

**Zostáva neopravené jedno:** `tool_loop_guardrails.hard_stop_enabled` je stále
`false` a `max_in_progress_per_profile` v configu nie je. Guard proti scramble
teda stále nedrží.

| Stav | Počet | Karty |
|---|---|---|
| done | 42 | celé P0, P1 kontrakt, UX vlna, slovenské názvy |
| running | 2 | vizuálna QA (t_ff5bbdd1), design spec progresie (t_c147405a) |
| todo | 3 | side-goals, vizuálna progresia mapy, integrácia main |
| triage | 1 | economy narácia (t_2e9f4251) |
| archived | 2 | — |

Práce na boarde je teda na pár hodín, potom botom dôjde fronta. To je dôvod
pre P2 karty.

## 2. Čo stojí za pozornosť

**Vizuálna QA sa dnes ráno zablokovala a zase rozbehla.** t_ff5bbdd1 spadla
o 08:31 na `kanban_block(capability)` — worker nevedel odvodiť presný herný stav
pre 7 požadovaných snímok. O 08:37 dostala komentár a beží znova. V
`godot/tools/screenshots/` je 7 PNG z 20. 8. 21:23, ale zachytávajú starú trasu
(menu, briefing, tri kroky coacha, TurnReport, mapa) — nie tú, ktorú karta žiada
(panel výberu župy, event 903, mapa 906 s markermi, Devín modal). Vetva
`qa/p1-vizualna-trasa` má opravený `screenshot_trace.gd`, snímky z nej ešte nie sú.

Toto je jediná karta, ktorá drží integráciu: main je 123 commitov pozadu a
`t_abcf645c` sa nesmie pohnúť skôr než budú snímky zelené.

**Design spec na progresiu raz spadol na protokol.** t_c147405a má za sebou
crashnutý beh s hláškou, že worker skončil `rc=0` bez terminálneho kanban volania.
Práca pritom hotová je — vetva `design/p1-progresia-a-ciele` má commit `aba14a3`
so spec-om. Beží druhé kolo; ak sa to zopakuje, spec stačí zobrať z vetvy ručne.

**P1 design gate vydal PASS 5/5, ale hodnotil aj to, čo ešte nie je.**
Gate píše, že side-goals sú „implementované a prepojené na existujúci GameState".
V skutočnosti sú `t_ba3d04ce` (side-goals) aj `t_cc9a8c3d` (vizuálna progresia)
stále v `todo` a spec, podľa ktorého sa majú robiť, nie je ani zlúčený. Gate
zároveň sám priznáva, že nemal GUI a čítal len kód. Verdikt teda platí pre eventy,
ceny volieb a tempo — pre side-goals a vizuálnu progresiu je nekrytý. Preto má
karta P2 gate v zadaní explicitne pracovať so snímkami, nie s kódom.

**Tri dokumenty klamú o stave.** Overené v kóde:

| Dokument | Čo tvrdí | Skutočnosť |
|---|---|---|
| `DALSI_KROK_M8.3_FAZOVA_BITKA.md` | fázovú bitku treba postaviť | `begin_phased_battle()` + `resolve_phase_round()` existujú, `Main.gd:742` ich volá, BattleView má akčné tlačidlá |
| `DALSI_KROK_BYZANCIA.md` | čaká sa na rozhodnutie, či pridať Byzanciu | Byzancia je v `DiplomacyManager._ensure_default_factions()` aj v `EventManager._resolve_faction_id()` — hotové. Otvorený zostáva len bod 2.3 (tvar guardu) |
| `DALSI_KROK_KRITICKE_BUGY_CODEX.md` | tri kritické bugy z Codex review | všetky tri sú opravené: `get_pending_event()` má vetvu pre `TYPE_ARRAY`, `_try_historical_event()` preskakuje `req_year == 0`, `MainMenu._on_new()` volá `GameManager.reset()` |

`DALSI_KROK_M8.4_POLYGON_MAPA.md` je z karty C7 vynechaný zámerne — polygóny
v `MapView.gd` síce hotové sú, ale súbor sa práve mení kartou na vizuálnu
progresiu mapy a stavový blok by o deň klamal tiež.

Toto je najlacnejšia možná chyba a najdrahší možný následok: agent si súbor
prečíta a začne stavať niečo, čo už stojí. Preto je to karta C7.

**Plánovacie dokumenty nie sú v gite.** `docs/DALSI_KROK_*.md`,
`CHYBAJUCA_GRAFIKA_NOVA_IDENTITA.md`, `ART_PROMPT_NOVA_VIZUALNA_IDENTITA.md`
aj `docs/design/P0_DESIGN_GATE.md` boli untracked — existovali len na tvojom
disku. V worktree bota by neexistovali vôbec, takže karta C7 by nemala čo
opraviť. Sú **nastagované** na `fix/p1-kontrakt-clean` (spolu s
`P1_DESIGN_GATE.md`, ktorý je obsahovo zhodný s verziou na `design/p1-gate`,
takže ten merge prejde bez konfliktu) — commit musíš spustiť ty, dôvod je
v poslednej sekcii.

**Snímky padali do worktree a do gitignore.** `screenshot_trace.gd` mal
`OUTPUT_DIR := "res://tools/screenshots/"`. V kanban worktree je `res://` kópia
repa, takže snímky skončili v adresári, ktorý sa po zlúčení pruneuje — a
`godot/tools/screenshots/` je navyše v `.gitignore`, takže sa ani necommitli.
Reviewer teda nemal ako uvidieť dôkaz, ktorý karta žiada. Zmenené na absolútnu
cestu do hlavného repa s prepínačom `REGNUM_SHOTS_DIR`.

**20+ mŕtvych worktree.** `git worktree list` ukazuje 24 záznamov, z toho 23
`prunable`. Upratanie je súčasťou integračnej karty `t_abcf645c`.

## 3. Kde je hra tenká — z toho vychádza P2

| Miesto | Zistenie |
|---|---|
| Narácia | economy text si protirečí, keď rng vyberie Gemer; anti-repetition (okno 12) vyčerpá ~12 economy variantov a v 908–914 padá 30–40 % ťahov na fallback |
| Obsah | katalóg má 13 eventov + council; päť hotových eventov z archívu `src/` sa neportovalo, tri z nich padajú presne do tenkých rokov 904 a 908–914 |
| Diplomacia | 7 frakcií, 5 tlačidiel, `process_diplomacy()` robí len náhodný drift −2…+2. Žiadny event, hrozba ani cieľ sa nálady nepýta — `conditions` poznajú iba `year`, `month`, `yearMin` |
| Bitka | fázový systém je hotový a zapojený **len** na tlačidle Cvičná bitka s natvrdo danou zostavou 1000 vs 800. Skutočné strety sa odbavia textom |
| Vizuál | 11 assetov sa dá podľa dokumentu generovať hneď, 6 erbov a siluetová matica čakajú na rozhodnutie; `icon_gold` má v `art_map.json` kľúč bez `_64` |

Audio je z P2 vynechané podľa zadania.

## 4. Karty pre P2 — 11 kusov

Priority sú zámerne pod 60, aby dobiehajúce P1 karty (95–60) mali pri
`max_in_progress: 3` prednosť.

| # | Karta | Bot | Prio | Čaká na |
|---|---|---|---|---|
| D1 | Design spec: diplomacia s dôsledkami | rm-design | 55 | — |
| D2 | Design spec: fázová bitka mimo cvičnej | rm-design | 52 | — |
| D3 | Design spec: vizuálny dlh a obrazovky | rm-design | 50 | — |
| C1 | NarrationManager — nekonzistencia + vyčerpané varianty | rm-content | 48 | integrácia |
| C2 | Doport 5 eventov (13 → 18) | rm-content | 45 | integrácia |
| C3 | Condition matcher — nálada, prestíž, lojalita | rm-core | 43 | D1, integrácia |
| C4 | Diplomacia s dôsledkami | rm-godot | 40 | D1, C3 |
| C5 | Fázová bitka v skutočných stretoch | rm-godot | 38 | D2 |
| C6 | Vizuálny dlh bez novej grafiky | rm-godot | 35 | D3 |
| C7 | Stavové bloky do troch DALSI_KROK dokumentov | rm-content | 30 | — |
| Q1 | QA P2: regresia a vizuálna trasa | rm-qa | 28 | C1, C2, C4, C5, C6 |
| G1 | P2 design gate | rm-design | 25 | Q1 |

Tri dizajnové karty nemajú závislosť — píšu len do `docs/design/`, takže sa
môžu rozbehnúť hneď a paralelne s dobiehajúcim P1. Implementačné karty visia na
integračnej karte `t_abcf645c`, aby sa nestavalo na vetve, ktorá sa ide zlučovať.

Dve veci v kartách stoja za zdôraznenie, lebo idú proti zvyku botov:

- **C6 nevyrába grafiku.** Boti nekreslia PNG. Karta robí len UI a dáta nad
  existujúcimi assetmi a pre chýbajúce robí graceful placeholder; prompty pre
  nové obrázky vypíše D3 a vyrobíš ich ty.
- **Devín 907 je vo všetkých kartách chránený.** C5 má v zadaní zastaviť a založiť
  kartu, ak by sa kánon dostal do hry.

## 5. Ako to spustiť

Najprv commit — zmeny sú nastagované, ale commit z mojej strany neprejde.
Most na tvoj disk nemá právo mazať súbory, takže git nedokáže odstrániť
`.git/index.lock` a každý zápisový príkaz skončí na „Another git process seems
to be running". Stagovanie prežilo, lock som odpratal do `_to_delete/git-locks/`.

```bash
cd ~/projects/regnum-moravicum-official
git status                     # over, čo je nastagované
git commit -m "chore(P2): snímky mimo worktree + plánovacie dokumenty do gitu"
```

Potom karty:

```bash
cd tools/hermes-bots
bash create-p2-cards.sh
```

Skript je idempotentný — `--idempotency-key regnum-<vetva>` zabráni duplikátom
pri opakovanom spustení.

Triage kartu `t_2e9f4251` zavrie skript sám — pridá do nej komentár s ID novej
karty a zarchivuje ju. Ak by archivácia zlyhala, vypíše to a zavrieš ju
v dashboarde. (Aj tak by sa nikdy nedispatchla — má prioritu 0.)

Zostáva jedna vec ručne: zapnúť `tool_loop_guardrails.hard_stop_enabled: true`
a dopísať `kanban.max_in_progress_per_profile: 1`. Sú to jediné dve položky
z validačnej baseline, ktoré ešte nesedia.

Dve poznámky k tomu druhému prepínaču, lebo mení, ako sa board správa:

- **D1–D3 sa ním samy zoradia.** Všetky tri sú `rm-design`, takže pri
  `per_profile: 1` zaberú jeden slot, nie tri, a P1 dobiehanie má voľné dva.
  Bez tej voľby si vezmú všetky tri sloty naraz — čo dnes až tak nevadí, lebo
  `t_abcf645c` aj tak visí na vizuálnej QA, ale je to zbytočné riziko.
- **`rm-reviewer` je pri `per_profile: 1` úzke hrdlo.** Každá karta končí
  `request_review` na tento jediný profil a `review_dispatch: true` z toho robí
  ďalšiu dispatchovanú úlohu. Review sa teda budú radiť za sebou. Pri troch
  slotoch to je prijateľné; keby si `max_in_progress` dvíhal, `rm-reviewer`
  je prvé miesto, kde to prestane platiť.
