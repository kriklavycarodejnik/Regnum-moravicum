// Regnum Moravicum v3.0 — Game Over
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/GameOverScreen.module.css';

interface GameOverScreenProps {
  gameState: GameState;
  onBackToMenu: () => void;
}

export function GameOverScreen({ gameState, onBackToMenu }: GameOverScreenProps) {
  const victory = gameState.gameOverVictory === true;
  const zupaCount = Object.values(gameState.zupy).filter((z) =>
    gameState.nobles.some((n) => n.id === z.owner && n.familyId === gameState.player.dynasty)
  ).length;
  const totalZupy = Object.values(gameState.zupy).length;

  return (
    <div className={`${styles.container} ${victory ? styles.victory : styles.defeat}`}>
      <div className={styles.content}>
        <h1>{victory ? 'Víťazstvo dynastie' : 'Koniec vlády'}</h1>
        <p className={styles.reason}>{gameState.gameOverReason}</p>

        <div className={styles.stats}>
          <div className={styles.stat}>
            <span className={styles.label}>Posledný rok</span>
            <span className={styles.value}>{gameState.year}</span>
          </div>
          <div className={styles.stat}>
            <span className={styles.label}>Prestíž</span>
            <span className={styles.value}>{gameState.player.prestige}</span>
          </div>
          <div className={styles.stat}>
            <span className={styles.label}>Župy</span>
            <span className={styles.value}>
              {zupaCount}/{totalZupy}
            </span>
          </div>
        </div>

        <button type="button" className={styles.menuButton} onClick={onBackToMenu}>
          Späť do menu
        </button>
      </div>
    </div>
  );
}

export default GameOverScreen;
