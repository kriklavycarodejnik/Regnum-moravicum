// Regnum Moravicum v2.1 - Event Panel Component
import { useState } from 'react';
import type { GameState } from '../../core/types/gameState';
import type { EventChoice, GameEvent } from '../../core/types/events';
import styles from '../../styles/EventPanel.module.css';

interface EventPanelProps {
  gameState: GameState;
  onResolveEvent: (eventId: string, choiceIndex: number) => void;
}

const TYPE_LABEL: Record<GameEvent['type'], string> = {
  historical: 'Historická udalosť',
  random: 'Náhodná udalosť',
  diplomatic: 'Diplomacia',
  military: 'Vojna',
  religious: 'Náboženstvo',
};

function typeClass(type: GameEvent['type']): string {
  // .eventType/.eventItem CSS only styles military/diplomatic/religious/random;
  // historical events reuse the neutral "random" look.
  const key = type === 'historical' ? 'random' : type;
  return styles[key] ?? '';
}

function tickToDate(tick: number): string {
  const year = 902 + Math.floor(tick / 12);
  const month = (tick % 12) + 1;
  return `Rok ${year}, mesiac ${month}`;
}

interface EffectBadge {
  text: string;
  sign: 'positive' | 'negative' | 'neutral';
}

function describeEffects(choice: EventChoice): EffectBadge[] {
  const badges: EffectBadge[] = [];

  if (choice.prestigeChange) {
    badges.push({
      text: `Prestíž ${choice.prestigeChange > 0 ? '+' : ''}${choice.prestigeChange}`,
      sign: choice.prestigeChange > 0 ? 'positive' : 'negative',
    });
  }
  if (choice.religionChange) {
    badges.push({
      text: `Náboženstvo ${choice.religionChange > 0 ? '+' : ''}${choice.religionChange}`,
      sign: 'neutral',
    });
  }
  if (choice.resourceChanges) {
    for (const [key, value] of Object.entries(choice.resourceChanges)) {
      if (!value) continue;
      badges.push({ text: `${key} ${value > 0 ? '+' : ''}${value}`, sign: value > 0 ? 'positive' : 'negative' });
    }
  }
  if (choice.moodChanges) {
    for (const [faction, delta] of Object.entries(choice.moodChanges)) {
      for (const [mood, value] of Object.entries(delta)) {
        if (!value) continue;
        badges.push({
          text: `${faction}: ${mood} ${value > 0 ? '+' : ''}${value}`,
          sign: value > 0 ? 'positive' : 'negative',
        });
      }
    }
  }

  return badges;
}

export function EventPanel({ gameState, onResolveEvent }: EventPanelProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);

  const activeEvent = gameState.events.find((e) => !e.triggered) ?? null;
  const history = gameState.events
    .filter((e) => e.triggered)
    .slice()
    .sort((a, b) => (b.triggeredTick ?? 0) - (a.triggeredTick ?? 0));

  const handleConfirm = () => {
    if (!activeEvent || selectedIndex === null) return;
    onResolveEvent(activeEvent.id, selectedIndex);
    setSelectedIndex(null);
  };

  const handleCancelSelection = () => {
    setSelectedIndex(null);
  };

  if (!activeEvent) {
    return (
      <div className={styles.container}>
        <div className={styles.header}>
          <h2>Udalosti</h2>
        </div>
        <div className={styles.content}>
          <div className={styles.emptyState}>
            <div className={styles.icon}>📜</div>
            <p>Momentálne žiadne udalosti nečakajú na rozhodnutie.</p>
          </div>

          {history.length > 0 && (
            <div className={styles.eventList}>
              {history.slice(0, 20).map((event) => (
                <div key={event.id} className={`${styles.eventItem} ${typeClass(event.type)}`}>
                  <div className={styles.eventItemHeader}>
                    <h4 className={styles.eventItemTitle}>{event.title}</h4>
                    <span className={styles.eventItemDate}>{tickToDate(event.triggeredTick ?? 0)}</span>
                  </div>
                  <p className={styles.eventItemSummary}>{event.description}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2>{activeEvent.title}</h2>
        <span className={`${styles.eventType} ${typeClass(activeEvent.type)}`}>{TYPE_LABEL[activeEvent.type]}</span>
      </div>
      <div className={styles.content}>
        <div className={styles.eventDescription}>
          <p>{activeEvent.description}</p>
        </div>

        <div className={styles.choices}>
          {activeEvent.choices.map((choice, index) => {
            const effects = describeEffects(choice);
            return (
              <div
                key={index}
                className={`${styles.choice} ${selectedIndex === index ? styles.selected : ''}`}
                onClick={() => setSelectedIndex(index)}
              >
                <span className={styles.radio} />
                <div className={styles.choiceContent}>
                  <p className={styles.choiceTitle}>{choice.text}</p>
                  {effects.length > 0 && (
                    <div className={styles.choiceEffects}>
                      {effects.map((effect, i) => (
                        <span key={i} className={`${styles.effect} ${styles[effect.sign]}`}>
                          {effect.text}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        <div className={styles.choiceButtons}>
          <button className={styles.cancelButton} onClick={handleCancelSelection} disabled={selectedIndex === null}>
            Zrušiť výber
          </button>
          <button className={styles.confirmButton} onClick={handleConfirm} disabled={selectedIndex === null}>
            Potvrdiť rozhodnutie
          </button>
        </div>
      </div>
    </div>
  );
}

export default EventPanel;
