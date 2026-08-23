# Regnum Moravicum — stav boardu a karty pre P3

Stav k 23. 8. 2026, ~10:00. Čítané priamo z `hermes kanban --board regnum` (live), z
`git log`/`git diff` v hlavnom checkoute a z `docs/canon/ANALYZA_KANONU.md`
(auditná správa `rm-canon`, 23. 8. 2026, zatiaľ **untracked** v gite).

Nadväzuje na `docs/P2_STAV_A_KARTY.md`. Rovnaký formát: over stav v kóde, nie len
v dokumentoch — presne to isté zlyhanie sa už dvakrát zopakovalo (P0 gate, P1 gate),
pozri `docs/PROCES_RETROSPEKTIVA_2026-08-23.md` §7.2.

---

## 1. Kde reálne stojí P2 (over si to, nededukuj z tabuľky nižšie)

| Karta | Stav podľa `kanban stats` | Overenie v kóde |
|---|---|---|
| D1 diplomacia spec | done (`t_f21ed40a`) | **Dokument reálne chýba v gite** — nová karta `t_f07fe912` (running) ho práve prepisuje a commituje. Rovnaký vzor ako C7 v P2: karta označená done, artefakt neexistuje. |
| D2 bitka spec | done (`t_b8ae6e4f`) | `docs/design/P2_BITKA.md` existuje (51 KB) — OK |
| D3 vizuál spec | done (`t_414e86ab`) | `docs/design/P2_VIZUAL.md` existuje (19 KB) — OK |
| C1 narácia (P1 gate nálezy) | done (`t_cdf8b5e9`) | — |
| C2 port 5 eventov | done (`t_f57b76d8`) | — |
| C3 condition matcher | done (`t_d394b9aa`) | `EventManager.gd:53-106` má `moodMin/moodMax`, `prestige_min/max`, `province_loyalty` — potvrdené v kóde |
| C4 diplomacia s dôsledkami | **blocked** (`t_b7983d19`) | `DiplomacyManager.process_diplomacy()` (riadky 57-77) robí stále len náhodný drift nálady — C4 reálne nedobehla |
| C5 bitka v skutočných stretoch | done (`t_067f7b1b`) | — |
| C6 vizuálny dlh | done (`t_444e6df8`) | — |
| C7 dokumentačný dlh | done (`t_873822c8`) | — |
| Q1 QA P2 | **todo** (`t_62206909`) | čaká na C4 |
| G1 P2 design gate | **todo** (`t_7a929c3b`) | čaká na Q1 |

**Záver: P2 nie je zavretá.** Chýba C4 (blokovaná na chýbajúcom D1 dokumente, ktorý sa
práve dopisuje), za ňou Q1 a G1. Karty P3 nižšie preto delím na tie, čo môžu bežať
hneď (dizajn, bez dopadu na existujúci kód), a tie, čo musia počkať na `t_7a929c3b`
(P2 gate) presne tak, ako P2 implementačné karty čakali na integráciu.

## 2. Čo je navyše hotové mimo P2 scope — kánonický audit

`rm-canon` dokončil (`t_a13a2c44`, done) kompletný audit kánonu:
`docs/canon/ANALYZA_KANONU.md` (213 riadkov) + `docs/canon/PRIBEH.md` (64 riadkov).
**Oba súbory sú untracked** — rovnaké riziko ako pri `DALSI_KROK_*.md` v P1: ak sa
worktree upratú, práca zmizne. Odporúčam commit pred spustením P3 kariet.

Audit našiel a väčšinu už aj opravil:

| Nález (ANALYZA_KANONU) | Stav |
|---|---|
| Chyba č.1 — zastarané testy Devín 907 (`test_hungarian_war_scenario.gd`) | **Opravené, ale uncommitted** v hlavnom checkoute (`git diff` ukazuje presne túto zmenu) |
| Chyba č.2 — voľba namiesto seniorátu (`SuccessionManager.gd`) | **Committed** (`2e79ac7`) — `set_succession_type()` existuje, `_succession_type` default `"seniority"`, komentár cituje audit priamo v kóde |
| Chyba č.3 — anachronizmus „kráľovský"/„kniežací" | **Beží práve teraz** (`t_69509096`, running) |
| Chyba č.4 — vyčerpané varianty `NarrationManager` | Čiastočne — C1 (P2) opravil anti-repetition mechaniku; samotné rozšírenie o nové texty (SEKCIA C, bod 4 auditu) ešte nie je karta. Sekcia 3.3 auditu má **16 hotových textov na priame použitie**. |

Sekcie 3.1–3.2 auditu (dynastická kríza, sukcesné scenáre, frakčné oblúky 907–930)
sú navrhnutý, no neimplementovaný obsah — presne materiál na P3.

## 3. Karty pre P3 — 7 kusov

| # | Karta | Bot | Prio | Čaká na |
|---|---|---|---|---|
| D1 | Design spec: dynastická kríza a sukcesné scenáre | rm-design | 55 | — |
| D2 | Design spec: frakčné oblúky 907–930 ako event reťazce | rm-design | 50 | C4 (`t_b7983d19`) |
| C1 | 16 naratívnych textov z auditu do NarrationManager | rm-content | 45 | — |
| C2 | Implementácia sukcesnej krízy | rm-godot | 40 | D1, P2 gate (`t_7a929c3b`) |
| C3 | Implementácia frakčných oblúkov | rm-godot | 35 | D2, C4, P2 gate |
| Q1 | QA P3: regresia a vizuálna trasa | rm-qa | 25 | C1, C2, C3 |
| G1 | P3 design gate | rm-design | 20 | Q1 |

Rovnaký princíp ako v P2: dizajnové karty (D1) bez dopadu na existujúci kód môžu bežať
hneď paralelne s dobiehajúcim P2 chvostom. Implementačné karty (C2, C3) explicitne
čakajú na `t_7a929c3b` (P2 gate) — nestavať P3 obsah na vetve, ktorá sa ešte len bude
zlučovať, presne z dôvodu, prečo mala P2 integračnú kartu `t_abcf645c`.

D2 a C3 naviac závisia na C4 (diplomacia s dôsledkami), pretože frakčné oblúky z
auditu (tributárny mier vs. partizánska vojna pre Maďarov, byzantský vs. latinský
zväzok) sú prakticky to isté ako "nálada, ktorá niečo robí" — bez C4 nemá `mood`
žiadny mechanický dopad, na ktorom by sa dali stavať ďalšie eventové reťazce.

C1 nemá kanban závislosť, ale **skontroluj `git log` pred štartom** — v hlavnom
checkoute prebieha uncommitted práca na `NarrationManager.gd` (Chyba č.3/č.4), C1
na ňu nadväzuje a pri súbehu si vyrobí merge konflikt v tom istom súbore.

Skript `tools/hermes-bots/create-p3-cards.sh` vytvorí presne týchto 7 kariet.
**Nespúšťaj ho, kým nepotvrdíš:**
1. OpenRouter kredit má nenulový zostatok (23. 8. ráno bol 271× HTTP 402 naprieč
   piatimi botmi — pozri `docs/PROCES_RETROSPEKTIVA_2026-08-23.md` §5.2),
2. `docs/canon/ANALYZA_KANONU.md` a `PRIBEH.md` sú commitnuté (inak D1/D2 nemajú
   z čoho vychádzať v bot worktree),
3. duplicitné blocked karty (`t_38947f19`/`t_08c4de58`, `t_f42bcd4d`/`t_f76947f9`,
   `t_a835c59d`/`t_8de6a3f6` — všetky `workspace_kind: scratch`, rovnaký štrukturálny
   nesúlad ako v retrospektíve §5.1) sú buď opravené na worktree, alebo archivované,
   aby dispatcher nepokračoval v platení za karty, ktoré nemôžu uspieť.
