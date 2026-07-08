// Regnum Moravicum v2.1 - Event Panel Component (Placeholder)
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/EventPanel.module.css';

interface EventPanelProps {
  gameState: GameState;
}

export function EventPanel({ gameState }: EventPanelProps) {
  return (
    <div className={styles.container}>
      <h2>Udalosti</h2>
      <p className={styles.placeholder}>
        Panel udalostí bude implementovaný v Fáze 3
      </p>
      {gameState.events.length > 0 ? (
        <div className={styles.eventList}>
          {gameState.events.map(event => (
            <div key={event.id} className={styles.event}>
              <h3>{event.title}</h3>
              <p>{event.description}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className={styles.noEvents}>Žiadne udalosti</p>
      )}
    </div>
  );
}

export default EventPanel;
