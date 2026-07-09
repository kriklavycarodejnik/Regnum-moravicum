// Regnum Moravicum v2.1 - Battle View Component
import type { GameState } from '../../core/types/gameState';
import type { BattleAction } from '../../battle/types';
import {
  canStartHungarianWar,
  getAvailableBattleFronts,
  shouldAutoResolve,
  type BattleFront,
} from '../../core/engines/warCampaign';
import { getScenarioDescription } from '../../scenarios/hungarianWar';
import { CoatOfArms } from './CoatOfArms';
import styles from '../../styles/BattleView.module.css';

interface BattleViewProps {
  gameState: GameState;
  onStartWar: () => void;
  onStartBattle: (front: BattleFront) => void;
  onPlayBattlePhase: (action: BattleAction) => void;
  onAutoResolveBattle: (front: BattleFront) => void;
}

const PHASE_LABEL: Record<string, string> = {
  attack: 'Fáza 1: Útok',
  counterattack: 'Fáza 2: Protiútok',
  decision: 'Fáza 3: Rozhodnutie',
  finished: 'Bitka skončila',
};

const ACTION_LABEL: Record<BattleAction, string> = {
  melee: 'Priamy útok',
  ranged: 'Streľba',
  flank: 'Obchvat',
  retreat: 'Ústup',
};

export function BattleView({ gameState, onStartWar, onStartBattle, onPlayBattlePhase, onAutoResolveBattle }: BattleViewProps) {
  const zupaName = (id: string): string => gameState.zupy[id]?.name || id;
  const wc = gameState.warCampaign;

  if (!wc) {
    return (
      <div className={styles.container}>
        <div className={styles.header}>
          <h2>Vojny</h2>
        </div>
        <div className={styles.content}>
          {canStartHungarianWar(gameState) ? (
            <div className={styles.emptyState}>
              <div className={styles.icon}>⚔️</div>
              <h3>Maďari vtrhli do Moravy!</h3>
              <p>{getScenarioDescription()}</p>
              <div className={styles.actionButtons}>
                <button className={`${styles.actionButton} ${styles.primary}`} onClick={onStartWar}>
                  Zvolať vojsko a čeliť Maďarom
                </button>
              </div>
            </div>
          ) : (
            <div className={styles.emptyState}>
              <div className={styles.icon}>🕊️</div>
              <h3>Zatiaľ mier</h3>
              <p>Morava zatiaľ nečelí žiadnej vojne.</p>
            </div>
          )}
        </div>
      </div>
    );
  }

  const activeBattle = wc.activeBattle;

  if (activeBattle) {
    const { battle, attackerArmy, defenderArmy } = activeBattle;
    const isFinished = battle.currentPhase === 'finished';

    return (
      <div className={styles.container}>
        <div className={styles.header}>
          <h2>{PHASE_LABEL[battle.currentPhase] ?? battle.currentPhase}</h2>
          <span className={`${styles.battleStatus} ${isFinished ? styles.completed : styles.ongoing}`}>
            {zupaName(battle.zupaId)} · {battle.terrain}
          </span>
        </div>
        <div className={styles.content}>
          <div className={styles.battleInfo}>
            <div className={`${styles.battleSide} ${styles.sideAttacker}`}>
              <div className={styles.sideHeader}>
                <CoatOfArms nobleId={attackerArmy.commander.id} size={32} />
                <h3 className={styles.sideName}>Maďari ({attackerArmy.commander.name})</h3>
              </div>
              <div className={styles.unitRow}>
                <span className={styles.unitStat}>Počet mužov:</span>
                <span className={`${styles.unitStat} ${styles.value}`}>{Math.round(attackerArmy.size).toLocaleString('sk-SK')}</span>
              </div>
              <div className={styles.unitRow}>
                <span className={styles.unitStat}>Morálka:</span>
                <span className={`${styles.unitStat} ${styles.value}`}>{Math.round(attackerArmy.morale)}</span>
              </div>
            </div>
            <div className={`${styles.battleSide} ${styles.sideDefender}`}>
              <div className={styles.sideHeader}>
                <CoatOfArms nobleId={defenderArmy.commander.id} size={32} />
                <h3 className={styles.sideName}>Moravania ({defenderArmy.commander.name})</h3>
              </div>
              <div className={styles.unitRow}>
                <span className={styles.unitStat}>Počet mužov:</span>
                <span className={`${styles.unitStat} ${styles.value}`}>{Math.round(defenderArmy.size).toLocaleString('sk-SK')}</span>
              </div>
              <div className={styles.unitRow}>
                <span className={styles.unitStat}>Morálka:</span>
                <span className={`${styles.unitStat} ${styles.value}`}>{Math.round(defenderArmy.morale)}</span>
              </div>
            </div>
          </div>

          <div className={styles.battleLog}>
            <p className={styles.logTitle}>Kronika bitky</p>
            <div className={styles.logEntries}>
              {activeBattle.narrationLog.length === 0 ? (
                <div className={`${styles.logEntry} ${styles.neutral}`}>Vojská sa zoraďujú do boja...</div>
              ) : (
                activeBattle.narrationLog.map((line, i) => (
                  <div key={i} className={`${styles.logEntry} ${styles.neutral}`}>{line}</div>
                ))
              )}
            </div>
          </div>

          {!isFinished && (
            <div className={styles.actionButtons}>
              {(['melee', 'ranged', 'flank', 'retreat'] as BattleAction[]).map((action) => (
                <button
                  key={action}
                  className={`${styles.actionButton} ${action === 'retreat' ? styles.danger : ''}`}
                  onClick={() => onPlayBattlePhase(action)}
                >
                  {ACTION_LABEL[action]}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  const fronts = getAvailableBattleFronts(gameState);
  const warConcluded = wc.war.result !== 'ongoing';

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2>Bitka pri Devíne</h2>
        <span className={`${styles.battleStatus} ${warConcluded ? styles.completed : styles.ongoing}`}>
          {wc.war.result === 'victory' ? 'Víťazstvo' : wc.war.result === 'defeat' ? 'Prehra' : 'Prebieha'}
        </span>
      </div>
      <div className={styles.content}>
        <div className={styles.victoryConditions}>
          <p className={styles.conditionsTitle}>Ciele vojny</p>
          <div className={styles.conditionsList}>
            {wc.war.objectives.map((o) => (
              <div key={o.zupaId} className={styles.conditionItem}>
                <span className={styles.conditionIcon}>{o.completed ? '✅' : '⏳'}</span>
                <p className={styles.conditionText}>Vyhnať Maďarov zo župy {zupaName(o.zupaId)}</p>
              </div>
            ))}
          </div>
        </div>

        {!warConcluded && fronts.length > 0 && (
          <div className={styles.battleResults}>
            <p className={styles.resultsHeader}>Dostupné bitky</p>
            {fronts.map((front) => {
              const enemy = wc.armies.find((a) => a.id === front.enemyArmyId);
              const moravian = wc.armies.find((a) => a.id === 'army_moravian_main');
              const autoAvailable = enemy && moravian && shouldAutoResolve(enemy, moravian, front.terrain);
              return (
                <div key={front.zupaId} className={styles.unitRow} style={{ justifyContent: 'space-between' }}>
                  <span>
                    {zupaName(front.zupaId)} ({front.terrain}) — nepriateľ: {Math.round(enemy?.size ?? 0).toLocaleString('sk-SK')} mužov
                  </span>
                  <div className={styles.actionButtons} style={{ marginTop: 0 }}>
                    <button className={`${styles.actionButton} ${styles.primary}`} onClick={() => onStartBattle(front)}>
                      Zaútočiť
                    </button>
                    {autoAvailable && (
                      <button className={styles.actionButton} onClick={() => onAutoResolveBattle(front)}>
                        Auto-vyriešiť
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <div className={styles.battleLog}>
          <p className={styles.logTitle}>Priebeh vojny</p>
          <div className={styles.logEntries}>
            {wc.log.slice(-15).map((line, i) => (
              <div key={i} className={`${styles.logEntry} ${styles.neutral}`}>{line}</div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default BattleView;
