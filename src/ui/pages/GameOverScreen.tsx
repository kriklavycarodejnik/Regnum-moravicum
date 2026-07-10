// Regnum Moravicum v2.1 - Game Over Screen Page
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/GameOverScreen.module.css';

interface GameOverScreenProps {
  gameState: GameState;
  onBackToMenu: () => void;
}

export function GameOverScreen({ gameState, onBackToMenu }: GameOverScreenProps) {
  const victory = gameState.gameOverVictory === true;

  return (
    <div className={`${styles.container} ${victory ? styles.victory : styles.defeat}`}>
      <div className={styles.content}>
        <h1>{victory ? 'Víťazstvo' : 'Koniec hry'}</h1>
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
            <span className={styles.label}>Žúp pod vládou</span>
            <span className={styles.value}>
              {Object.values(gameState.zupy).filter((z) =>
                gameState.nobles.some((n) => n.id === z.owner && n.familyId === gameState.player.dynasty)
              ).length}
              {' / '}
              {Object.values(gameState.zupy).length}
            </span>
          </div>
        </div>

        <button className={styles.menuButton} onClick={onBackToMenu}>
          Späť do menu
        </button>
      </div>
    </div>
  );
}

export default GameOverScreen;
