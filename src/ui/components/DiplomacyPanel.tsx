// Regnum Moravicum v2.1 - Diplomacy Panel Component (Placeholder)
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/DiplomacyPanel.module.css';

interface DiplomacyPanelProps {
  gameState: GameState;
}

export function DiplomacyPanel({ gameState }: DiplomacyPanelProps) {
  return (
    <div className={styles.container}>
      <h2>Diplomacia</h2>
      <p className={styles.placeholder}>
        Diplomacia bude implementovaná v Fáze 3
      </p>
      <div className={styles.factionList}>
        {gameState.factions.map(faction => (
          <div key={faction.id} className={styles.faction}>
            <h3>{faction.name}</h3>
            <p>Nálada: {faction.personality}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default DiplomacyPanel;
