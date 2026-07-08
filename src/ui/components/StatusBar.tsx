// Regnum Moravicum v2.1 - Status Bar Component
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/StatusBar.module.css';

interface StatusBarProps {
  gameState: GameState;
  onTick: () => void;
}

export function StatusBar({ gameState, onTick }: StatusBarProps) {
  const religionLabel = gameState.religion.value >= 0 ? 'Konštantínopol' : 'Rím';
  const religionPercent = Math.abs(gameState.religion.value);

  return (
    <div className={styles.container}>
      <div className={styles.leftSection}>
        <div className={styles.yearTick}>
          <span className={styles.label}>Rok:</span>
          <span className={styles.value}>{gameState.year}</span>
        </div>
        <div className={styles.yearTick}>
          <span className={styles.label}>Mesiac:</span>
          <span className={styles.value}>{gameState.tick + 1}/12</span>
        </div>
      </div>

      <div className={styles.centerSection}>
        <div className={styles.resources}>
          <div className={styles.resource}>
            <span className={styles.label}>Zlato:</span>
            <span className={styles.value}>{gameState.resources.gold}</span>
          </div>
          <div className={styles.resource}>
            <span className={styles.label}>Potrava:</span>
            <span className={styles.value}>{gameState.resources.food}</span>
          </div>
          <div className={styles.resource}>
            <span className={styles.label}>Drevo:</span>
            <span className={styles.value}>{gameState.resources.wood}</span>
          </div>
          <div className={styles.resource}>
            <span className={styles.label}>Kameň:</span>
            <span className={styles.value}>{gameState.resources.stone}</span>
          </div>
          <div className={styles.resource}>
            <span className={styles.label}>Železo:</span>
            <span className={styles.value}>{gameState.resources.iron}</span>
          </div>
        </div>
      </div>

      <div className={styles.rightSection}>
        <div className={styles.prestige}>
          <span className={styles.label}>Prestíž:</span>
          <span className={styles.value}>{gameState.player.prestige}</span>
        </div>
        <div className={styles.religion}>
          <span className={styles.label}>Náboženstvo:</span>
          <span className={styles.value}>
            {religionLabel} ({religionPercent}%)
          </span>
        </div>
        <button 
          className={styles.tickButton}
          onClick={onTick}
        >
          Ďalší mesiac
        </button>
      </div>
    </div>
  );
}

export default StatusBar;
