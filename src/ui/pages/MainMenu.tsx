// Regnum Moravicum v3.0 - Main Menu (AoE2 × Veľká Morava splash)
import { useState } from 'react';
import type { ScenarioType } from '../../core/types/gameState';
import styles from '../../styles/MainMenu.module.css';

const SCENARIOS: { id: ScenarioType; name: string; description: string; year: string; icon: string }[] = [
  {
    id: 'prežitie',
    name: 'Prežitie',
    description: 'Zachráňte Veľkú Moravu pred zánikom. Rok 902, Mojmír II. na tróne.',
    year: '902–1000',
    icon: '🛡',
  },
  {
    id: 'konsolidácia',
    name: 'Konsolidácia',
    description: 'Zjednoťte roztrúsené slovanské kmene pod jednu vládu.',
    year: 'Kmeňe',
    icon: '⚜',
  },
  {
    id: 'zlatý_vek',
    name: 'Zlatý vek',
    description: 'Dovedzte Veľkú Moravu k najväčšej sláve a prestíži.',
    year: 'Sláva',
    icon: '✦',
  },
  {
    id: 'mongolská_skúška',
    name: 'Mongolská skúška',
    description: 'Obranite sa proti mongolskej invázii z východu.',
    year: 'Skúška',
    icon: '⚔',
  },
];

interface MainMenuProps {
  onStartGame: (scenario: ScenarioType, seed?: string) => void;
  onLoadGame: () => void;
  hasSavedGame: boolean;
}

function SplashArt() {
  return (
    <svg className={styles.splashArt} viewBox="0 0 900 420" preserveAspectRatio="xMidYMid slice" aria-hidden>
      <defs>
        <linearGradient id="menuSky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#3a2a3a" />
          <stop offset="55%" stopColor="#1e1824" />
          <stop offset="100%" stopColor="#0a0806" />
        </linearGradient>
        <radialGradient id="menuSun" cx="72%" cy="28%" r="30%">
          <stop offset="0%" stopColor="#e8c84a" stopOpacity="0.35" />
          <stop offset="100%" stopColor="#e8c84a" stopOpacity="0" />
        </radialGradient>
        <linearGradient id="menuRiver" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#2a5565" />
          <stop offset="50%" stopColor="#4a8a9a" />
          <stop offset="100%" stopColor="#2a5565" />
        </linearGradient>
      </defs>
      <rect width="900" height="420" fill="url(#menuSky)" />
      <rect width="900" height="420" fill="url(#menuSun)" />
      <path d="M 0,160 C 120,120 220,180 340,130 C 460,85 560,150 700,110 C 800,85 860,120 900,100 L 900,0 L 0,0 Z" fill="#2a2430" opacity="0.7" />
      <path d="M 0,210 C 140,170 260,220 400,175 C 540,135 680,200 900,160 L 900,0 L 0,0 Z" fill="#1a1520" opacity="0.5" />
      <ellipse cx="200" cy="240" rx="90" ry="40" fill="#243a20" opacity="0.45" />
      <ellipse cx="520" cy="220" rx="110" ry="50" fill="#243a20" opacity="0.4" />
      <ellipse cx="760" cy="250" rx="80" ry="35" fill="#243a20" opacity="0.35" />
      <path d="M 0,340 C 80,320 160,350 240,330 C 340,305 420,345 520,325 C 640,300 760,340 900,320 L 900,420 L 0,420 Z" fill="#2a3a22" />
      <path d="M 20,360 C 100,345 180,370 280,350 C 380,332 480,365 600,348 C 720,332 820,360 880,350" fill="none" stroke="url(#menuRiver)" strokeWidth="10" strokeLinecap="round" opacity="0.7" />
      {/* Hradište silhouette */}
      <g transform="translate(450, 250)">
        <ellipse cx="0" cy="70" rx="70" ry="14" fill="#0a0806" opacity="0.45" />
        <rect x="-60" y="40" width="120" height="28" fill="#4a4238" stroke="#1a140c" />
        {Array.from({ length: 8 }, (_, i) => (
          <rect key={i} x={-60 + i * 15} y="28" width="10" height="14" fill="#4a4238" stroke="#1a140c" />
        ))}
        <rect x="-18" y="0" width="36" height="55" fill="#5a5348" stroke="#1a140c" />
        <path d="M -18,0 L 0,-22 L 18,0" fill="#8b1e2d" stroke="#1a140c" />
        <circle cx="0" cy="-28" r="8" fill="#d8c8a8" stroke="#1a140c" />
        <path d="M -8,-28 L 0,-40 L 8,-28" fill="#c9a227" />
        <line x1="0" y1="-40" x2="0" y2="-55" stroke="#c8b898" strokeWidth="2" />
        <path d="M 0,-55 L 14,-48 L 0,-42 Z" fill="#8b1e2d" />
      </g>
      {/* Tiny unit silhouettes */}
      <g fill="#6b8f5a" opacity="0.75">
        {[300, 330, 360, 390].map((x, i) => (
          <g key={i} transform={`translate(${x}, 330)`}>
            <rect x="-3" y="0" width="6" height="12" rx="1" />
            <circle cx="0" cy="-4" r="3" />
          </g>
        ))}
      </g>
      <g fill="#a67c52" opacity="0.7">
        {[560, 590, 620].map((x, i) => (
          <g key={i} transform={`translate(${x}, 328)`}>
            <ellipse cx="2" cy="8" rx="9" ry="4" />
            <rect x="-2" y="-2" width="5" height="8" rx="1" />
            <circle cx="0" cy="-5" r="2.5" />
          </g>
        ))}
      </g>
    </svg>
  );
}

export function MainMenu({ onStartGame, onLoadGame, hasSavedGame }: MainMenuProps) {
  const [selectedScenario, setSelectedScenario] = useState<ScenarioType>('prežitie');
  const [seed, setSeed] = useState<string>('');
  const [showSeedInput, setShowSeedInput] = useState<boolean>(false);

  const handleStart = () => {
    onStartGame(selectedScenario, showSeedInput && seed ? seed : undefined);
  };

  return (
    <div className={styles.container}>
      <div className={styles.hero}>
        <SplashArt />
        <div className={styles.heroOverlay}>
          <div className={styles.crest}>✠</div>
          <h1>Regnum Moravicum</h1>
          <p className={styles.tagline}>Alternatívna história Veľkej Moravy · 902–1000</p>
          <p className={styles.subtitle}>Vládni ako Mojmír II. · župy · frakcie · bitky · kronika</p>
        </div>
      </div>

      <main className={styles.main}>
        <section className={styles.scenarios}>
          <div className={styles.sectionHead}>
            <h2>Vyberte scenár</h2>
            <span className={styles.sectionHint}>kampaň / režim hry</span>
          </div>
          <div className={styles.scenarioList}>
            {SCENARIOS.map((scenario) => (
              <button
                key={scenario.id}
                type="button"
                className={`${styles.scenarioButton} ${selectedScenario === scenario.id ? styles.selected : ''}`}
                onClick={() => setSelectedScenario(scenario.id)}
              >
                <div className={styles.scenarioTop}>
                  <span className={styles.scenarioIcon} aria-hidden>
                    {scenario.icon}
                  </span>
                  <span className={styles.scenarioYear}>{scenario.year}</span>
                </div>
                <h3>{scenario.name}</h3>
                <p>{scenario.description}</p>
              </button>
            ))}
          </div>
        </section>

        <section className={styles.options}>
          <label className={styles.checkRow}>
            <input
              type="checkbox"
              checked={showSeedInput}
              onChange={(e) => setShowSeedInput(e.target.checked)}
            />
            <span>Vlastné semeno (seed) pre deterministickú hru</span>
          </label>
          {showSeedInput && (
            <input
              type="text"
              value={seed}
              onChange={(e) => setSeed(e.target.value)}
              placeholder="napr. morava_902"
              className={styles.seedInput}
            />
          )}
        </section>

        <div className={styles.buttons}>
          <button type="button" className={styles.primaryButton} onClick={handleStart}>
            Začať novú hru
          </button>
          {hasSavedGame && (
            <button type="button" className={styles.secondaryButton} onClick={onLoadGame}>
              Pokračovať v uloženej hre
            </button>
          )}
        </div>
      </main>

      <footer className={styles.footer}>
        <p>Veľká Morava · AoE2 inšpirácia · ťahová stratégia v prehliadači</p>
      </footer>
    </div>
  );
}

export default MainMenu;
