## 8. Integračné testy (M5)

### 8.1 Testovacie súbory
| Súbor | Overuje | Očakávaný výsledok |
|-------|---------|---------------------|
| `test_campaign_determinism.gd` | Determinizmus `CampaignManager.gd`. | Rovnaký seed = rovnaké ťahy AI. |
| `test_historical_accuracy.gd` | Historická presnosť (Devín 907, expanzia Maďarov). | Maďari expandujú, Morava vyhráva Devín 907. |
| `test_performance.gd` | Výkon pre 100+ armád. | Max 500 ms na spracovanie. |

### 8.2 Spustenie testov
1. **Aktivovať gdUnit4 plugin**:
   - `Project > Project Settings > Plugins` → Zaškrtnúť `gdUnit4`.
2. **Spustiť testy**:
   - Otvoriť `test/integration/test_runner.gd`.
   - Kliknúť na ▶️ **Run** (alebo `F5`).
3. **Overiť výsledky**:
   - Všetky testy by mali byť ✅ **zelené**.

### 8.3 Blokéry
- **gdUnit4 v4.2.1 nemá CLI runner**: Testy je možné spustiť iba v Godot editore.
- **Výkonové testy**: Vyžadujú manuálne meranie času.