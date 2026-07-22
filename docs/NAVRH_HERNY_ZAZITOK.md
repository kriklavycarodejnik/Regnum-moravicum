# Návrh vylepšení — herný zážitok Regnum Moravicum (v1.3)

> **Toto je návrh + rozhodnutia, nie implementácia.**  
> Kód sa **nezačína** bez explicitného go (`schvaľujem P-1.1 + P0` alebo rez).  
> História: v1.1 (UX/feedback) → v1.2/v1.3 (obsah + bug Devín + port eventov).

**Súvisiace:** `GAMEPLAY_LOOP.md` · Godot `EventManager.gd` · (archived) React `historicalEvents.ts` / `eventEngine.ts`  
**Kánon bitky:** Devín 907 — **Maďari (útočník) vždy vyhrajú**, `winner == "attacker"`. Notion tabuľka Game Design v2.1 k tomuto = **zastaraná**.

---

## 1. Diagnóza — prečo sa gameplay cíti zle

### 1.1 Čo v1.1 trafilo správne (prezentácia ťahu)
| Problém | Stav |
|---------|------|
| Žiadna spätná väzba po ťahu | TurnReport chýba |
| Žiadny threat clock k 907 | chýba |
| Žiadny coach na mape | briefing ≠ učenie v scéne |
| Devín 907 ako „debug“ tlačidlo | tools-row, nie kapitola |

Pôvodný P0.1–P0.6 na toto dobre odpovedá.

### 1.2 Hlbší problém (v1.3 — z kódu + Notion)
**Obsahová vrstva je takmer prázdna.**

- `EventManager.gd` má **jeden** hardcoded event: „Rada županov“, ~8 %/mesiac, vždy ten istý text.
- Aj s dokonalým TurnReportom by hráč po pár mesiacoch videl **stále to isté**.
- Skutočná príčina „nehrám stratégiu s príbehom“ = **chýbajúci obsah pod UI**, nie len chýbajúca prezentácia.

### 1.3 Vedľajšie korekcie oproti v1.1
| Predpoklad v1.1 | Realita |
|-----------------|---------|
| Briefing = veľká stena textu | Je kratší než sa zdalo → **nízka priorita** ďalšieho skracovania |
| Objectives treba stavať od nuly | `ObjectivesPanel.gd` už má fázy + „Teraz urob“ → P1 len **vytiahnuť do popredia** |
| Diplomacia mŕtva | Mechanika **funguje** (frakcie, mood, dar/hrozba/zmluvy) — chýba **odkaz z cieľov** |

---

## 2. P-1.1 — bug pred všetkým ostatným (BLOKER)

### Problém
`resolve_devine_battle()` (alebo ekvivalent cez `GameManager.run_devine_battle` / WarManager):
- ide spustiť **manuálne kedykoľvek** (aj 902),
- a znova **automaticky** pri tiku ~907/07,
- bez poistky → exploit: opakovaná odmena (zlato/prestíž/lojalita podľa implementácie).

### Fix (cca 30 min)
1. Flag v `GameState`: `devine_resolved: bool = false` (do `to_dict` / `from_dict`).
2. `run_devine_battle` / scenario: ak `devine_resolved` → no-op + hláška „už odohrané“.
3. Auto-trigger v tiku 907: len ak `not devine_resolved`.
4. Po úspešnom resolve: `devine_resolved = true`.
5. **Kánon výsledku nemeniť:** `winner == "attacker"` (Maďari).

**Bez P-1.1 nestavať P0.4 (Devín kapitola).**

---

## 3. Revidovaný backlog (poradie realizácie)

| Krok | Čo | Prečo | Effort |
|------|-----|--------|--------|
| **P-1.1** | `devine_resolved` — Devín max 1× | Bug / blokuje P0.4 | ~30 min |
| **P0.1–P0.6** | Coach, TurnReport, threat clock, Devín modal, CTA sync, (briefing len light touch) | Viditeľnosť spätnej väzby | ~1 deň |
| **P0.7** | **Port 14 eventov** z React `historicalEvents.ts` (+ logika z `eventEngine.ts` podľa potreby) do Godot `EventManager` | Bez obsahu je TurnReport prázdny ~90 % mesiacov | ~0,5 dňa |
| **P1** | Fázové beaty do popredia, dipl side-goals, army wizard pred 907, map threat markers | Hĺbka | 1,5–3 dni |
| **P2** | Nová grafika, plný battle UI, audio | Neblokuje pocit hry | týždne |

### P0.1–P0.6 (detail, overené voči kódu)
| ID | Feature |
|----|---------|
| P0.1 | Coach 3 kroky na mape (`tutorial_step` / `tutorial_done` v save) |
| P0.2 | TurnReport po každom `process_next_month` (Δ resources + 1 veta; ak event → CTA riešiť) |
| P0.3 | Threat clock: mesiace do 907; po 907 → roky do 1000 |
| P0.4 | Devín ako kapitola (modal 906–907) — **až po P-1.1** |
| P0.5 | Briefing — len light touch (nie priorita) |
| P0.6 | Primary CTA text sync s „Teraz urob“ |

### P0.7 — port eventov (namiesto písania od nuly)
Zdroj (archived React, overené v Notion / testoch historicky):
- `src/data/historicalEvents.ts`
- `src/core/engines/eventEngine.ts` (podmienky, váhy)

Cieľ Godot:
- Dáta: napr. `godot/data/events/*.json` alebo jeden `events_catalog.json`
- `EventManager`: load katalogu, weighted pick, conditions, `pending_event` shape kompatibilný s Main (`title/body/art_id/choices[]` cez existujúcu normalizáciu)
- Zachovať **seeded RNG** (žiadny `randf` mimo SaveManager RNG)
- Mapovať `art_id` na existujúce mastery kde dáva zmysel (dvor, portréty, Devín, …)

Príklady obsahu na port (zo zhrnutia feedbacku):
- papežské posolstvo
- byzantská ponuka sobáša → vetvy
- sprisahanie Bogata → súd / povstanie
- (+ zvyšok z 14)

---

## 4. Ideálnych ~8 minút (nezmenené v princípe)

```
Menu → krátky briefing → MAPA + coach 1–2–3
→ Ďalší mesiac → TurnReport (Δ + veta / event)
→ clock „Do Maďarov: N mes.“
→ 906/907 kapitola Devín (1×, Maďari vyhrávú)
→ ďalej ťahy s pestrými eventmi (P0.7) smerom k 1000
```

---

## 5. Invarianty

| | |
|--|--|
| Devín 907 | `winner == "attacker"` (Maďari) **vždy** |
| Devín frekvencia | **max 1×** za run (`devine_resolved`) |
| RNG | seeded cez SaveManager |
| Smoke | `SMOKE_PASS` + `SMOKE_M6_PASS` po každom balíku |
| React | ARCHIVED pre nové featury — len **zdroj na port dát/logiky eventov** |
| Notion GD v2.1 battle table | zastaraná voči Godot kánonu Devín |

---

## 6. DoD balíka „P-1.1 + P0 (+ P0.7)“

- [ ] Devín nejde 2×; manuál pred 907 buď blocked alebo bez odmeny-exploit
- [ ] Auto 907 rešpektuje flag
- [ ] Coach 3 kroky raz za run (skip)
- [ ] Každý ťah má TurnReport s Δ
- [ ] Threat clock viditeľný pred 907
- [ ] Devín modal/kapitola 1×
- [ ] ≥ niekoľko rôznych eventov z portu (cieľ: katalóg 14, MVP subset OK ak je v PR plný port)
- [ ] SMOKE_PASS, SMOKE_M6_PASS, Devín attacker

---

## 7. Go-workflow (ďalší krok)

Odpoveď stačí:

| Príkaz | Význam |
|--------|--------|
| **`schvaľujem P-1.1 + P0`** | Celý balík vrátane P0.7 portu eventov |
| **`schvaľujem P-1.1 + P0 bez P0.7`** | Najprv UX/bug; eventy samostatne |
| **`len P-1.1`** | Iba Devín flag |
| **`P0 s úpravou: …`** | Rez / zmena scope |

**Kód nezačínam** bez jedného z týchto potvrdení.

---

## 8. Zhrnutie verzií

| Verzia | Prínos |
|--------|--------|
| v1.1 | UX: coach, TurnReport, clock, Devín kapitola |
| v1.3 | + prázdny obsah ako koreň; + P-1.1 bug; + P0.7 port 14 eventov; + korekcie Objectives/dipl/briefing; + Devín kánon v bode 15.6 nižšie |

---

## 15.6 Rozhodnutie — Devín 907 (ZÁVÄZNÉ)

**Godot kánon platí:**

- Bitka pri Devíne (907): **víťaz = útočník = Maďari**
- V kóde / scenári: `winner == "attacker"` (prípadne ekvivalent `result` konzistentný s smoke)
- **Nemeniť** battle math ani „morálny“ flip pre hráča
- UI / kronika / kapitola musia hovoriť pravdu: kríza, prehra Moravy pri Devíne, dôsledky
- Tabuľky / texty v Notion Game Design v2.1, ktoré hovoria inak = **zastarané**, nepoužívať ako source of truth

Smoke invariant: `Devin 907: winner=attacker`.
