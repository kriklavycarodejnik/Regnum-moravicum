// Regnum Moravicum v3.0 - Game Screen (iOS tab chrome)
import { useState } from 'react';
import type { GameState } from '../../core/types/gameState';
import type { BattleAction } from '../../battle/types';
import type { BattleFront } from '../../core/engines/warCampaign';
import type { DiplomaticActionType } from '../../core/engines/diplomacyEngine';
import { StatusBar } from '../components/StatusBar';
import { MapView } from '../components/MapView';
import { EventPanel } from '../components/EventPanel';
import { DiplomacyPanel } from '../components/DiplomacyPanel';
import { ArmyPanel } from '../components/ArmyPanel';
import { BattleView } from '../components/BattleView';
import { ChronicleView } from '../components/ChronicleView';
import styles from '../../styles/GameScreen.module.css';

type ActivePanel = 'map' | 'events' | 'diplomacy' | 'army' | 'battle' | 'chronicle';

interface GameScreenProps {
  gameState: GameState;
  onTick: () => void;
  onBackToMenu: () => void;
  onStartWar: () => void;
  onStartBattle: (front: BattleFront) => void;
  onPlayBattlePhase: (action: BattleAction) => void;
  onAutoResolveBattle: (front: BattleFront) => void;
  onResolveEvent: (eventId: string, choiceIndex: number) => void;
  onPerformDiplomaticAction: (factionId: string, action: DiplomaticActionType) => void;
}

const NAV: { id: ActivePanel; label: string; icon: string }[] = [
  { id: 'map', label: 'Mapa', icon: '🗺' },
  { id: 'events', label: 'Udalosti', icon: '📜' },
  { id: 'diplomacy', label: 'Diplomacia', icon: '🕊' },
  { id: 'army', label: 'Armády', icon: '🛡' },
  { id: 'battle', label: 'Bitky', icon: '⚔' },
  { id: 'chronicle', label: 'Kronika', icon: '📖' },
];

export function GameScreen({
  gameState,
  onTick,
  onBackToMenu,
  onStartWar,
  onStartBattle,
  onPlayBattlePhase,
  onAutoResolveBattle,
  onResolveEvent,
  onPerformDiplomaticAction,
}: GameScreenProps) {
  const [activePanel, setActivePanel] = useState<ActivePanel>('map');

  const pendingEvents = gameState.events.filter((e) => !e.triggered).length;
  const warActive = Boolean(gameState.warCampaign && gameState.warCampaign.war.result === 'ongoing');

  const renderPanel = () => {
    switch (activePanel) {
      case 'map':
        return <MapView gameState={gameState} />;
      case 'events':
        return <EventPanel gameState={gameState} onResolveEvent={onResolveEvent} />;
      case 'diplomacy':
        return (
          <DiplomacyPanel
            gameState={gameState}
            onPerformDiplomaticAction={onPerformDiplomaticAction}
          />
        );
      case 'army':
        return <ArmyPanel gameState={gameState} />;
      case 'chronicle':
        return <ChronicleView gameState={gameState} />;
      case 'battle':
        return (
          <BattleView
            gameState={gameState}
            onStartWar={onStartWar}
            onStartBattle={onStartBattle}
            onPlayBattlePhase={onPlayBattlePhase}
            onAutoResolveBattle={onAutoResolveBattle}
          />
        );
      default:
        return <MapView gameState={gameState} />;
    }
  };

  return (
    <div className={styles.container}>
      <StatusBar gameState={gameState} onTick={onTick} />

      <div className={styles.mainContent}>
        <nav className={styles.sidebar} aria-label="Hlavná navigácia">
          {NAV.map((item) => {
            const badge =
              item.id === 'events' && pendingEvents > 0
                ? pendingEvents
                : item.id === 'battle' && warActive
                  ? '!'
                  : null;
            return (
              <button
                key={item.id}
                type="button"
                className={`${styles.navButton} ${activePanel === item.id ? styles.active : ''}`}
                onClick={() => setActivePanel(item.id)}
              >
                <span className={styles.navIcon} aria-hidden>
                  {item.icon}
                </span>
                <span className={styles.navLabel}>{item.label}</span>
                {badge !== null && <span className={styles.navBadge}>{badge}</span>}
              </button>
            );
          })}
          <button type="button" className={styles.menuLink} onClick={onBackToMenu}>
            ← Menu
          </button>
        </nav>

        <div className={styles.content}>{renderPanel()}</div>
      </div>
    </div>
  );
}

export default GameScreen;
