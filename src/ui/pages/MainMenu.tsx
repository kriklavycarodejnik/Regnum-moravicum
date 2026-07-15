// Regnum Moravicum v2.1 - Main Menu Page
import { useState } from 'react';
import type { ScenarioType } from '../../core/types/gameState';
import { SCENARIOS as START_SCENARIOS, DEFAULT_SCENARIO_ID } from '../../data/scenarios';
import styles from '../../styles/MainMenu.module.css';

const SCENARIOS: { id: ScenarioType; name: string; description: string }[] = [
  {
    id: 'prežitie',
    name: 'Prežitie',
    description: 'Zachraňte Veľkú Moravu pred zánikom. Rok 902, Mojmír II. na tróne.'
  },
  {
    id: 'konsolidácia',
    name: 'Konsolidácia',
    description: 'Zjednotite roztrúsené slovanské kmene pod jednu vládu.'
  },
  {
    id: 'zlatý_vek',
    name: 'Zlatý vek',
    description: 'Doviedite Veľkú Moravu k najväčšej sláve.'
  },
  {
    id: 'mongolská_skúška',
    name: 'Mongolská skúška',
    description: 'Obranite sa proti mongolskej invázii.'
  }
];

interface MainMenuProps {
  onStartGame: (scenario: ScenarioType, seed?: string, startScenarioId?: string) => void;
  onLoadGame: () => void;
  hasSavedGame: boolean;
}

export function MainMenu({ onStartGame, onLoadGame, hasSavedGame }: MainMenuProps) {
  const [selectedScenario, setSelectedScenario] = useState<ScenarioType>('prežitie');
  const [selectedStartScenario, setSelectedStartScenario] = useState<string>(DEFAULT_SCENARIO_ID);
  const [seed, setSeed] = useState<string>('');
  const [showSeedInput, setShowSeedInput] = useState<boolean>(false);

  const handleStart = () => {
    onStartGame(selectedScenario, showSeedInput && seed ? seed : undefined, selectedStartScenario);
  };

  const handleLoad = () => {
    onLoadGame();
  };

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <h1>Regnum Moravicum v2.1</h1>
        <p>Alternatívna história Veľkej Moravy</p>
      </header>

      <main className={styles.main}>
        <section className={styles.scenarios}>
          <h2>Vyberte scenár</h2>
          <div className={styles.scenarioList}>
            {SCENARIOS.map(scenario => (
              <button
                key={scenario.id}
                className={`${styles.scenarioButton} ${selectedScenario === scenario.id ? styles.selected : ''}`}
                onClick={() => setSelectedScenario(scenario.id)}
              >
                <h3>{scenario.name}</h3>
                <p>{scenario.description}</p>
              </button>
            ))}
          </div>
        </section>

        <section className={styles.scenarios}>
          <h2>Vyberte začiatočnú situáciu</h2>
          <div className={styles.scenarioList}>
            {Object.values(START_SCENARIOS).map((startScenario) => (
              <button
                key={startScenario.id}
                className={`${styles.scenarioButton} ${selectedStartScenario === startScenario.id ? styles.selected : ''}`}
                onClick={() => setSelectedStartScenario(startScenario.id)}
              >
                <h3>{startScenario.name}</h3>
                <p>{startScenario.description}</p>
              </button>
            ))}
          </div>
        </section>

        <section className={styles.options}>
          <div className={styles.optionGroup}>
            <label>
              <input
                type="checkbox"
                checked={showSeedInput}
                onChange={(e) => setShowSeedInput(e.target.checked)}
              />
              Použiť vlastné semeno (seed)
            </label>
            {showSeedInput && (
              <input
                type="text"
                value={seed}
                onChange={(e) => setSeed(e.target.value)}
                placeholder="Zadajte semeno..."
                className={styles.seedInput}
              />
            )}
          </div>
        </section>

        <div className={styles.buttons}>
          <button 
            className={styles.primaryButton}
            onClick={handleStart}
          >
            Začať novú hru
          </button>
          
          {hasSavedGame && (
            <button 
              className={styles.secondaryButton}
              onClick={handleLoad}
            >
              Načítať uloženú hru
            </button>
          )}
        </div>
      </main>

      <footer className={styles.footer}>
        <p>Inšpirované Stronghold Crusader, Crusader Kings a Civilization</p>
      </footer>
    </div>
  );
}

export default MainMenu;
