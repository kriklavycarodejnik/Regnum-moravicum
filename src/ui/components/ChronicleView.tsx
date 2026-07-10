// Regnum Moravicum v2.1 - Chronicle View Component
import type { GameState } from '../../core/types/gameState';
import type { GameEvent } from '../../core/types/events';
import styles from '../../styles/ChronicleView.module.css';

interface ChronicleViewProps {
  gameState: GameState;
}

const TYPE_ICON: Record<GameEvent['type'], string> = {
  historical: '📜',
  random: '🎲',
  diplomatic: '🕊️',
  military: '⚔️',
  religious: '☦️',
};

function tickToDate(tick: number): { year: number; month: number } {
  return { year: 902 + Math.floor(tick / 12), month: (tick % 12) + 1 };
}

export function ChronicleView({ gameState }: ChronicleViewProps) {
  const entries = gameState.events
    .filter((e) => e.triggered)
    .slice()
    .sort((a, b) => (a.triggeredTick ?? 0) - (b.triggeredTick ?? 0));

  const warLog = gameState.warCampaign?.log ?? [];

  const hasContent = entries.length > 0 || warLog.length > 0;

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2>Kronika Regnum Moravicum</h2>
        <p className={styles.subtitle}>Chronica Regni Moravici — zápisky o vláde dynastie Mojmírovcov</p>
      </div>

      <div className={styles.content}>
        {!hasContent && (
          <div className={styles.emptyState}>
            <div className={styles.icon}>🕊️</div>
            <p>Kronika je zatiaľ prázdna. Dejiny sa ešte len začínajú písať.</p>
          </div>
        )}

        {entries.length > 0 && (
          <div className={styles.timeline}>
            {entries.map((event) => {
              const { year, month } = tickToDate(event.triggeredTick ?? 0);
              const choice = event.resolvedChoiceIndex !== undefined ? event.choices[event.resolvedChoiceIndex] : undefined;
              return (
                <div key={event.id} className={styles.entry}>
                  <div className={styles.entryMarker}>
                    <span className={styles.entryIcon}>{TYPE_ICON[event.type]}</span>
                  </div>
                  <div className={styles.entryCard}>
                    <div className={styles.entryDate}>
                      Rok {year}<span className={styles.entryMonth}>, mesiac {month}</span>
                    </div>
                    <h3 className={styles.entryTitle}>{event.title}</h3>
                    <p className={styles.entryDescription}>{event.description}</p>
                    {choice && (
                      <p className={styles.entryDecision}>
                        <span className={styles.entryDecisionLabel}>Rozhodnutie dvora:</span> {choice.text}
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {warLog.length > 0 && (
          <div className={styles.warSection}>
            <h3 className={styles.warHeading}>Vojnová kronika — Vojna s Maďarmi</h3>
            <div className={styles.warLog}>
              {warLog.map((line, i) => (
                <p key={i} className={styles.warLogLine}>
                  <span className={styles.warLogMarker}>§{i + 1}</span> {line}
                </p>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default ChronicleView;
