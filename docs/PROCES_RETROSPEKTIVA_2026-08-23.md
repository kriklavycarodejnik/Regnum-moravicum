# Regnum Moravicum — retrospektíva agentického procesu a návrh cost-efektívnej optimalizácie

Stav zisťovaný 23. 8. 2026 priamo z: `git` (lokálny repo + worktrees), `gh` (GitHub),
`~/.hermes/kanban/boards/regnum/` (kanban.db, board.json), profilov ôsmich botov
v `~/.hermes/profiles/rm-*` (config.yaml, errors.log, `hermes insights`) a doc-histórie
v `docs/P2_STAV_A_KARTY.md`. Cieľom dokumentu je zodpovedať zadanie: aktuálny stav →
spätné chyby → optimalizácia smerom k maximálnej cost efektivite cez lepší proces.

Súvisiace memory: [[github-regnum-moravicum]], [[hermes-agent-server]],
[[feedback-verifier-not-implementer]].

---

## 1. Zhrnutie

- **Board práve teraz stojí.** 65 kariet done, 7 blocked, 2 todo, **0 running**, žiadny
  dispatcher proces nebeží. Príčina väčšiny dnešných blokov: **OpenRouter kredity sú
  vyčerpané** (HTTP 402) — 271 takýchto chýb naprieč piatimi z ôsmich botov len dnes ráno.
- **Cena za posledné ~3 dni aktivity (20.–23. 8.): ~61 USD odhadovaných**, ~1,05 miliardy
  tokenov, naprieč ôsmimi bot-profilmi. Časť tejto sumy sú neúspešné requesty, ktoré
  narazili na 402 a nič nepriniesli.
- **Recenzný krok (rm-reviewer) je najdrahší aj najčastejší** — 217 sessions za 5 dní
  oproti 47 dokončeným review, t.j. ~4,6 session na jeden review. Časť je pravdepodobne
  umelo nafúknutá retry-mi na 402, ale aj bez toho je to najťažší uzol pipeline.
- **Dva strukturálne zablokované tasky** (`rm-orchestrator`, `rm-canon`) dostali
  `workspace_kind: scratch` — bez prístupu k súborovému systému — na úlohu, ktorá vyžaduje
  čítať `docs/canon/*.md`. Boli odsúdené na blok už pri vzniku karty, a napriek tomu si
  vypýtali reálne API volania (viď session dumpy z dnešného rána).
- **Bezpečnostná poistka `hard_stop_enabled` bola identifikovaná ako chýbajúca 21. 8.**
  vo `P2_STAV_A_KARTY.md` a **k 23. 8. je stále `false` vo všetkých ôsmich profiloch** —
  dvojdňová neopravená medzera, počas ktorej mal napr. `rm-core` priemernú dĺžku session
  ~4h 40m bez tvrdého stropu.
- **GitHub nie je systém záznamu.** Lokálny `main` je ~123 commitov pred tým, čo je
  reálne pushnuté; jediný otvorený PR (#6, veľký M5–M7 scope) visí nezlúčený od
  29. 7. do 23. 8.; issue tracker má za celý beh projektu iba 2 issues (obe closed) —
  desiatky reálnych nálezov namiesto toho žijú len v `kanban.db` a v `docs/DALSI_KROK_*.md`.

---

## 2. Aktuálny stav — repozitár a lokálna práca

**Repo:** `https://github.com/kriklavycarodejnik/Regnum-moravicum.git` (súkromný,
`kriklavycarodejnik`). Lokálny working copy: `~/projects/regnum-moravicum-official`,
aktuálne na `fix/p1-devin-modal-chronicle`, s neuloženými zmenami v šiestich súboroch
(P0 eventy, GameState, EventManager, NarrationManager, test scenár).

**Rozsah paralelnej práce:** 44 lokálnych vetiev, z toho **32 aktívnych git worktrees**
pod `.worktrees/` — každá karta z kanban boardu dostáva vlastný worktree, aby mohli boti
bežať súbežne bez konfliktov. `P2_STAV_A_KARTY.md` (21. 8.) už predtým upozornil na
„20+ mŕtvych worktree" určených na `prunable` upratanie ako súčasť integračnej karty
`t_abcf645c` — k 23. 8. `.worktrees/` stále obsahuje branch-e, ktoré `git branch -a`
neeviduje ako aktívne (napr. `t_08e6afce`, `t_51f6f022`, `t_a201a874`, `t_c355cbb8`),
čiže upratovanie sa ešte neudialo.

**Verifikačná brána (`godot/tools/check_all.sh`):** 5 headless kontrol (Smoke M5, Smoke
M6, TurnReport runtime, UI slovak labels, Army wizard runtime). Hlavičkový komentár
skriptu tvrdí „4 kontroly", `create-p2-cards.sh` protokol vyžaduje „7/7" — ani jedno
číslo nesedí so skutočnými piatimi checkmi. Malý, ale symptomatický príklad širšieho vzoru
z časti 5: dokumenty o procese sa rozchádzajú so skutočným procesom.

---

## 3. Aktuálny stav — GitHub

| Čo | Stav |
|---|---|
| `main` push | 21. 8. 2026, 11:29 UTC |
| Otvorené PR | #6 „Godot M5-M7: gameplay loop, event content port, Byzancia, P1 hĺbka" — vytvorené 29. 7., **stále open**, 3,5 týždňa bez zlúčenia |
| Ostatné PR | #3 open (M1 investment engine, 15. 7.), #1 a #2 merged (Phase 0, 8. 7.) |
| Issues | iba 2 za celú existenciu repa, oba **closed** (29. 7.) — `Main.tscn` parse chyba a chýbajúci `icon_gold_64` |

Kontrast oproti kanban boardu: ten má za posledné 3 dni **65 dokončených kariet**, z toho
desiatky reálnych bugfixov a review nálezov — nič z toho sa nepremietlo do GitHub Issues.
GitHub v tomto projekte momentálne slúži len ako pôvodné úložisko `main`, nie ako priebežný
záznam práce. To nie je nutne chyba (kanban.db je rýchlejší a lacnejší na iteráciu), ale
znamená to, že **GitHub je zavádzajúci zdroj pravdy** pre kohokoľvek, kto by si stav
projektu overoval len cez `gh pr list` / `gh issue list`.

---

## 4. Aktuálny stav — Hermes agent (kanban swarm)

Toto je **tretia, samostatná inštalácia Hermes Agent** vedľa VPS Telegram bota a bežného
desktop hermes serve z [[hermes-agent-server]] — lokálny multi-bot kanban swarm špecificky
pre tento projekt.

**Architektúra:** board `regnum` (`~/.hermes/kanban/boards/regnum/`), 8 pomenovaných
bot-rolí, každá s vlastným plnohodnotným Hermes profilom (`~/.hermes/profiles/rm-*`,
vlastný `config.yaml`, `state.db`, `auth.json`, samostatný cron ticker):

| Bot | Rola | Model | Provider |
|---|---|---|---|
| rm-orchestrator | rozklad analýz na karty | `upstage/solar-pro4` | openrouter |
| rm-design | design spec dokumenty | `qwen/qwen3.8-max` | openrouter |
| rm-core | herná logika/kontrakty | `z-ai/glm-5.2` | nvidia |
| rm-godot | Godot implementácia | `qwen/qwen3-coder` | openrouter |
| rm-content | texty, eventy, narácia | `google/gemma-4-31b-it` | openrouter |
| rm-canon | kánon/lore dokumenty | `mistral-large-latest` | mistral |
| rm-qa | vizuálna QA, regresia | `google/gemma-4-31b-it` | openrouter |
| rm-reviewer | review + merge brána | `upstage/solar-pro4` | openrouter |

**Protokol (z `create-p2-cards.sh`):** každá karta beží vo vlastnom worktree, základ je
`main` (alebo aktívna integračná vetva), pred dokončením musí prejsť `check_all.sh`,
dokončenie ide výhradne cez `kanban_request_review(reviewer="rm-reviewer")` — nie priamy
`kanban_complete` — a merge robí výhradne `rm-reviewer` cez `~/.hermes/scripts/regnum-merge.sh`.
Review má strop 3 kolá; nález mimo scope karty sa nemá riešiť ako blokér, ale ako nová karta.

---

## 5. Živý stav boardu (zistené priamo teraz)

```
by_status: blocked=7, done=65, todo=2   (running=0)
```

**Žiadny dispatcher proces nebeží** (`ps aux` — okrem desktop appky a gateway nič, čo by
naberalo karty z frontu). Board je fakticky zamrznutý.

### 5.1 Prečo je 7 kariet blocked

Dve odlišné príčiny, obe si vyžiadali reálne (platené) API volania predtým, než zablokovali:

1. **Štrukturálny nesúlad workspace/úloha** — `t_38947f19`, `t_f42bcd4d`
   (rm-orchestrator), `t_37cd2250`, `t_09f264b6` (rm-content), `t_a835c59d`
   (rm-canon) majú `workspace_kind: scratch`, teda **bez pripojenia repa**. Ich zadanie
   pritom explicitne vyžaduje čítať `docs/canon/*.md` alebo písať do `PRIBEH.md`.
   Vlastný self-report jedného z nich (`t_38947f19`): *„Nemám prístup k systému súborov
   — nemôžem prečítať docs/canon/*.md ani výsledky analýzy... Potrebujem, aby mi bola
   ponúknutá možnosť prečítať súbory zo workspace."* Karta bola odsúdená na neúspech
   v momente vytvorenia — nešlo o zlyhanie modelu, ale o zlú konfiguráciu karty.
2. **`t_b7983d19`** (rm-godot, P2 diplomacia) — normálny worktree, zablokovaný pravdepodobne
   kaskádou z bodu 5.2 (kredity), nie štrukturálnym problémom.

### 5.2 OpenRouter kredity vyčerpané

V `errors.log` naprieč profilmi, len za dnešok:

| Bot | Počet HTTP 402 chýb |
|---|---|
| rm-reviewer | 135 |
| rm-godot | 78 |
| rm-orchestrator | 36 |
| rm-design | 21 |
| rm-qa | 1 |
| rm-core | 0 (iný provider — nvidia) |

Príklad hlásenia: *„This request requires more credits... You requested up to 65536
tokens, but can only afford 3275."* Toto vysvetľuje, prečo je board momentálne bez
bežiacich kariet a prečo časť dnešných sessions (rm-canon, rm-content) skončila
neúspešne napriek tomu, že spotrebovala tokeny/čas — **platili sa neúspešné pokusy**,
kým rozpočet nedošiel úplne.

---

## 6. Cost dáta (posledných 5 dní, `hermes insights` per profil)

| Bot | Sessions | Tokeny spolu | Odhad ceny | Pozn. |
|---|---:|---:|---:|---|
| rm-reviewer | 217 | 351,1 M | **$17,90** | 47 done → 4,6 session/review |
| rm-design | 22 | 55,4 M | $12,72 | najvyššia cena/session |
| rm-godot | 95 | 353,3 M | $12,25 | |
| rm-core | 14 | 70,3 M | $10,71 | priemerná session ~4h 40m |
| rm-content | 30 | 68,9 M | $5,75 | dnes zastavené na 402 |
| rm-qa | 18 | 89,9 M | $1,43 | |
| rm-canon | 11 | 5,3 M | $0,45 | všetkých 11 sessions dnes, 0 done |
| rm-orchestrator | 9 | 1,6 M | $0,08 | |
| **Spolu** | **416** | **~995 M** | **~$61,29** | |

Poznámky k číslam:
- Modely sú prevažne lacné/voľné vrstvy (`deepseek-v4-flash` dominuje u rm-godot aj
  rm-reviewer), preto je cena za takmer miliardu tokenov relatívne nízka — **problém
  teda nie je cena za token, ale objem sessions a opakovaní**.
- `rm-reviewer` je najdrahší nie preto, že by robil zložitú prácu na kartu, ale preto,
  že prechádza review najčastejšie (217 sessions) — to je miesto s najväčším pákovým
  efektom pre optimalizáciu (časť 8.2).
- `rm-core` má priemernú dĺžku session ~4h 40m, čo je rádovo nad ostatnými (rádovo
  desiatky minút) — priamy dôsledok chýbajúceho `hard_stop_enabled`.

---

## 7. Retrospektíva chýb

### 7.1 Už zdokumentované 21. 8., stále neopravené 23. 8.

| # | Chyba | Zdroj | Stav k 23. 8. |
|---|---|---|---|
| 1 | `tool_loop_guardrails.hard_stop_enabled` chýba/false, žiadny `max_in_progress_per_profile` | `P2_STAV_A_KARTY.md` §1 | **stále false vo všetkých 8 profiloch** |
| 2 | 20+ mŕtvych worktree, upratanie súčasťou integračnej karty | `P2_STAV_A_KARTY.md` §2 | worktrees pre neexistujúce branch-e stále v `.worktrees/` |
| 3 | Plánovacie dokumenty (`DALSI_KROK_*.md`) boli untracked, v bot worktree by neexistovali | `P2_STAV_A_KARTY.md` §2 | commit odvtedy prebehol (viditeľné v `docs/`) — **táto oprava sa udržala** |

### 7.2 Systémové vzory chýb (opakujú sa naprieč viacerými incidentmi)

**A. Headless verifikácia ≠ reálna hráčska pravda.** Dvakrát zdokumentovaný ten istý
koreňový problém, s odstupom: P0 gate vydal 5/5 PASS na hre, ktorá sa nedala reálne
rozohrať; P1 design gate vydal PASS 5/5 pre side-goals a vizuálnu progresiu, ktoré boli
v tom čase stále v `todo` — gate sám priznal, že nemal GUI a čítal len kód. Protokolový
text v `create-p2-cards.sh` už obsahuje varovanie („Headless test vizuál neoveruje"),
ale je to textová pripomienka v prompte, nie mechanická kontrola — spolieha sa na to,
že si ju model prečíta a poslúchne, namiesto vynúteného artefaktu.

**B. Dokumenty klamú o stave, agent im verí namiesto kódu.** Tri `DALSI_KROK_*.md`
dokumenty tvrdili, že fázová bitka/Byzancia/kritické bugy ešte čakajú, hoci všetko bolo
už hotové v kóde. `P2_STAV_A_KARTY.md` to sám pomenúva ako *„najlacnejšia možná chyba
a najdrahší možný následok"* — agent si prečíta zastaraný dokument a začne stavať niečo,
čo už existuje. Rovnaký vzor teraz vidno aj v `check_all.sh` (časť 2) — komentár tvrdí
iné číslo kontrol než skutočne beží.

**C. Artefakty dôkazov miznú pred tým, než ich niekto uvidí.** Screenshoty pre vizuálnu
QA padali do `res://tools/screenshots/` — cesty relatívnej k worktree kópii repa, ktorá
sa po zlúčení pruneuje, a naviac bola v `.gitignore`. Reviewer nemal ako uvidieť dôkaz,
ktorý karta žiadala. Opravené na absolútnu cestu (`REGNUM_SHOTS_DIR`), ale iba pre
vizuálnu QA vetvu — nie ako všeobecné pravidlo pre každý artefakt, ktorý karta produkuje.

**D. Karty sa zakladajú bez overenia, že bot má na úlohu fyzický prístup.** Nová, dnes
zistená inštancia rovnakého vzoru ako B/C: `workspace_kind: scratch` sa priradilo úlohám,
ktoré potrebujú čítať/písať súbory v repe. Náklad sa minul skôr, než karta stihla urobiť
čokoľvek užitočné.

**E. Rozpočtové zlyhanie sa rieši reaktívne, nie preventívne.** Nič v pipeline
nekontrolovalo zostatok OpenRouter kreditu vopred. Systém namiesto toho poslal stovky
requestov, ktoré zlyhali na 402, kým sa front sám nezasekol. Toto je jediné zistenie
v tomto dokumente, ktoré priamo a merateľne stoji peniaze bez akéhokoľvek výstupu.

---

## 8. Návrh optimalizácie — cesta k cost-efektívnemu procesu

Zoradené podľa pomeru náklad opravy : ušetrený efekt, nie podľa dôležitosti pre hru.

### 8.1 Okamžité, takmer nulová cena opravy

1. **Preflight kontrola OpenRouter zostatku** pred dispatchom karty (alebo aspoň pred
   spustením dispatchera na začiatku dňa) — ak zostatok nepokryje odhadovaný `max_tokens`
   × počet paralelných botov, dispatcher sa nemá spúšťať a má poslať notifikáciu namiesto
   toho, aby nechal 271 requestov padnúť na 402. Toto jediné opatrenie by dnes ušetrilo
   reálne peniaze aj čas.
2. **Zapnúť `hard_stop_enabled: true` a nastaviť `max_in_progress_per_profile`** vo
   všetkých 8 profiloch teraz — medzera je zdokumentovaná už 2 dni. `rm-core` s
   priemernou session 4h 40m je presne scenár, pred ktorým táto poistka chráni.
3. **Zakázať `workspace_kind: scratch` pre karty, ktorých telo obsahuje cestu k súboru
   v repe** (jednoduchá regex kontrola pri `mk()`/vytváraní karty stačí) — orchestrátor
   a canon karty potrebujú aspoň read-only mount repa, nikdy nie scratch.
4. **Dokončiť upratanie `.worktrees/`** — príkaz `git worktree prune` plus zmazanie
   branch-í bez zodpovedajúcej karty. Znižuje šum, ktorý agent číta pri orientácii
   v repe (menej tokenov na kontext), a odstraňuje riziko, že nový bot omylom nastúpi
   na mŕtvu vetvu.

### 8.2 Zníženie nákladu review slučky (najväčší jednotlivý nákladový uzol)

5. Po oprave bodu 8.1.1 **prepočítať pomer sessions/done pre rm-reviewer** — súčasných
   4,6 session/review je čiastočne umelo nafúknutých retry-mi na 402. Ak aj po odstránení
   týchto zlyhaní ostane pomer vysoký, treba zmenšiť priemernú veľkosť diffu na kartu
   (menšie karty → kratšie review), nie pridávať ďalšie kolo review.
6. **`check_all.sh` má byť tvrdá brána pred review, nie súčasť review promptu.** Ak
   dispatcher/worker skript vie strojovo overiť 5/5 pred tým, než sa karta vôbec pošle
   `rm-reviewer`-ovi, ušetrí sa celý reviewer-run na kartách, ktoré by aj tak zlyhali na
   mechanickej kontrole.

### 8.3 Zavrieť medzeru medzi „testy prešli" a „hráč to reálne vidí"

7. **Mechanická kontrola prítomnosti vizuálneho artefaktu**, nie iba textová pripomienka
   v prompte: karta označená ako UI/vizuálna nesmie prejsť do `done`, kým nemá pripojený
   screenshot/vizuálny diff na ceste mimo `.gitignore` a mimo worktree, ktorá sa pruneuje
   (rovnaký fix, aký P2 vizuálna QA už má cez `REGNUM_SHOTS_DIR` — treba ho urobiť
   predvoleným pre všetky vizuálne karty, nie len jednu vetvu).
8. **Plánovacie/status dokumenty commitovať v tom istom PR/merge, ktorý mení kód, ktorý
   popisujú** — nie dodatočne. Zabráni to opakovaniu vzoru B (dokument klame, lebo nikdy
   nebol pushnutý spolu so zmenou).

### 8.4 GitHub ako vedomá voľba, nie náhodný vedľajší efekt

9. Rozhodnúť explicitne: buď (a) GitHub ostáva len pre míľnikové integrácie — `main` sa
   pushne a PR sa otvorí len pri dokončení integračnej karty typu `t_abcf645c`, a
   issue tracker sa prestane považovať za zdroj pravdy — alebo (b) `regnum-merge.sh`
   automaticky otvára/aktualizuje GitHub PR pri každom merge, aby GitHub reálne
   zrkadlil `kanban.db`. Súčasný stav (ani jedno dôsledne) je najhorší z oboch — vytvára
   dojem sledovateľnosti, ktorý neexistuje. Vzhľadom na objem práce (65 kariet/3 dni)
   odporúčam (a) — GitHub pre míľniky, kanban.db ostáva pracovný systém záznamu.

### 8.5 Viditeľnosť nákladov, aby sa dnešný výpadok neopakoval nepovšimnuto

10. Existuje `hermes insights --days N` per profil, ale nikto ho pravidelne nekontroluje.
    Odporúčam denný súhrn (cez existujúci cron ticker, ktorý každý profil už má) —
    súčet $ spolu, počet blocked kariet, stav kreditov — zapísaný do denníka podľa
    [[hermes-notion-diary-convention]]. Lacná zmena (jeden script, beží raz denne),
    ktorá by dnešný výpadok odhalila v momente vzniku, nie pri externej kontrole.

---

## 9. Odporúčané ďalšie kroky

V súlade s [[feedback-verifier-not-implementer]] toto ostáva inštrukčný dokument, nie
implementácia — zmeny v bodoch 8.1–8.5 majú ísť do samostatných kariet/promptov pre
príslušných botov (najmä 8.1.1–8.1.3 sú infra zmeny mimo scope `rm-*` botov, robí ich
človek alebo `rm-orchestrator` s opraveným workspace).

Poradie podľa dopadu na cost efektivitu:
1. Preflight kredity + hard stop (8.1.1, 8.1.2) — zastavuje aktívne krvácanie.
2. Oprava `workspace_kind` pre orchestrator/canon/content karty (8.1.3) — prestane
   platiť za karty odsúdené na neúspech.
3. Prepočet review nákladu po bode 1 a prípadné zmenšenie kariet (8.2).
4. Vizuálny artefakt ako tvrdá brána (8.3) — zabraňuje najdrahšej triede chyby
   (false PASS, ktorý sa zistí až neskôr a musí sa opravovať znova).
5. GitHub rozhodnutie a denný cost súhrn (8.4, 8.5) — udržateľnosť do budúcna.
