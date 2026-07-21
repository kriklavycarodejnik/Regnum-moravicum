// Regnum Moravicum v3.0 - Status Bar (iOS premium resource chips)
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/StatusBar.module.css';

interface StatusBarProps {
  gameState: GameState;
  onTick: () => void;
}

const RESOURCES: { key: keyof GameState['resources']; label: string; icon: string }[] = [
  { key: 'gold', label: 'Zlato', icon: '◆' },
  { key: 'food', label: 'Potrava', icon: '❀' },
  { key: 'wood', label: 'Drevo', icon: '♣' },
  { key: 'stone', label: 'Kameň', icon: '▲' },
  { key: 'iron', label: 'Železo', icon: '⚒' },
];

export function StatusBar({ gameState, onTick }: StatusBarProps) {
  const religionLabel = gameState.religion.value >= 0 ? 'Konštantínopol' : 'Rím';
  const religionPercent = Math.abs(gameState.religion.value);
  const month = (gameState.tick % 12) + 1;

  return (
    <header className={styles.container}>
      <div className={styles.leftSection}>
        <div className={styles.brand}>
          <span className={styles.eagle} aria-hidden>
            ✠
          </span>
          <div className={styles.brandText}>
            <span className={styles.brandTitle}>Regnum Moravicum</span>
            <span className={styles.dateLine}>
              Rok {gameState.year} · mesiac {month}
            </span>
          </div>
        </div>
      </div>

      <div className={styles.centerSection}>
        <div className={styles.resources}>
          {RESOURCES.map((r) => (
            <div key={r.key} className={styles.resourceChip} title={r.label}>
              <span className={styles.chipIcon} aria-hidden>
                {r.icon}
              </span>
              <span className={styles.chipValue}>{gameState.resources[r.key]}</span>
              <span className={styles.chipLabel}>{r.label}</span>
            </div>
          ))}
        </div>
      </div>

      <div className={styles.rightSection}>
        <div className={styles.metaChip}>
          <span className={styles.metaLabel}>Prestíž</span>
          <span className={styles.metaValue}>{gameState.player.prestige}</span>
        </div>
        <div className={styles.metaChip}>
          <span className={styles.metaLabel}>Náboženstvo</span>
          <span className={styles.metaValue}>
            {religionLabel} {religionPercent}%
          </span>
        </div>
        <button
          type="button"
          className={styles.tickButton}
          onClick={onTick}
          disabled={gameState.gameOver}
        >
          Ďalší mesiac →
        </button>
      </div>
    </header>
  );
}

export default StatusBar;
