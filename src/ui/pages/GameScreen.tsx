// Regnum Moravicum v2.1 - Game Screen Page
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
import styles from '../../styles/GameScreen.module.css';

type ActivePanel = 'map' | 'events' | 'diplomacy' | 'army' | 'battle';

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

  const renderPanel = () => {
    switch (activePanel) {
      case 'map':
        return <MapView gameState={gameState} />;
      case 'events':
        return <EventPanel gameState={gameState} onResolveEvent={onResolveEvent} />;
      case 'diplomacy':
        return <DiplomacyPanel gameState={gameState} onPerformDiplomaticAction={onPerformDiplomaticAction} />;
      case 'army':
        return <ArmyPanel gameState={gameState} />;
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
        <nav className={styles.sidebar}>
          <button
            className={`${styles.navButton} ${activePanel === 'map' ? styles.active : ''}`}
            onClick={() => setActivePanel('map')}
          >
            Mapa
          </button>
          <button
            className={`${styles.navButton} ${activePanel === 'events' ? styles.active : ''}`}
            onClick={() => setActivePanel('events')}
          >
            Udalosti
          </button>
          <button
            className={`${styles.navButton} ${activePanel === 'diplomacy' ? styles.active : ''}`}
            onClick={() => setActivePanel('diplomacy')}
          >
            Diplomacia
          </button>
          <button
            className={`${styles.navButton} ${activePanel === 'army' ? styles.active : ''}`}
            onClick={() => setActivePanel('army')}
          >
            Armády
          </button>
          <button
            className={`${styles.navButton} ${activePanel === 'battle' ? styles.active : ''}`}
            onClick={() => setActivePanel('battle')}
          >
            Bitky
          </button>
        </nav>
        
        <div className={styles.content}>
          {renderPanel()}
        </div>
      </div>

      <button 
        className={styles.backButton}
        onClick={onBackToMenu}
      >
        Späť do menu
      </button>
    </div>
  );
}

export default GameScreen;
