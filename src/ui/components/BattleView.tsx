// Regnum Moravicum v2.1 - Battle View Component (Placeholder)
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/BattleView.module.css';

interface BattleViewProps {
  gameState: GameState;
}

export function BattleView({ gameState }: BattleViewProps) {
  return (
    <div className={styles.container}>
      <h2>Bitky</h2>
      <p className={styles.placeholder}>
        Bitky budú implementované v Fáze 2
      </p>
      {gameState.wars.length > 0 ? (
        <div className={styles.warList}>
          {gameState.wars.map(war => (
            <div key={war.id} className={styles.war}>
              <h3>Vojna: {war.attacker} vs {war.defender}</h3>
              <p>Ciel: {war.goal}</p>
              <p>Stav: {war.status}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className={styles.noWars}>Žiadne vojny</p>
      )}
    </div>
  );
}

export default BattleView;
