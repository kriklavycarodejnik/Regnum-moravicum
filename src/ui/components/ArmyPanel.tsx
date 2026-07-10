// Regnum Moravicum v2.1 - Army Panel Component
import type { GameState } from '../../core/types/gameState';
import type { Noble } from '../../core/types/entities';
import { CoatOfArms } from './CoatOfArms';
import styles from '../../styles/ArmyPanel.module.css';

interface ArmyPanelProps {
  gameState: GameState;
}

const UNIT_LABEL: Record<string, string> = {
  lightInfantry: 'Ľahká pechota',
  heavyInfantry: 'Ťažká pechota',
  archers: 'Lukostrelci',
  lightCavalry: 'Ľahká jazda',
  heavyCavalry: 'Ťažká jazda',
};

const STANCE_LABEL: Record<string, string> = {
  idle: 'V pokoji',
  marching: 'Na pochode',
  besieging: 'Obliehanie',
  defending: 'Obrana',
};

const STANCE_CLASS: Record<string, string> = {
  idle: 'statusActive',
  marching: 'statusMarching',
  besieging: 'statusBesieging',
  defending: 'statusResting',
};

export function ArmyPanel({ gameState }: ArmyPanelProps) {
  const getNoble = (id: string): Noble | undefined => gameState.nobles.find((n) => n.id === id);
  const getZupaName = (id: string): string => gameState.zupy[id]?.name ?? 'Neznáma';

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2>Armády</h2>
      </div>
      <div className={styles.content}>
        {gameState.armies.length === 0 ? (
          <div className={styles.emptyState}>
            <div className={styles.icon}>🛡️</div>
            <p>Kráľovstvo zatiaľ nemá vlastné vojsko.</p>
          </div>
        ) : (
          <div className={styles.armyList}>
            {gameState.armies.map((army) => {
              const commander = getNoble(army.commanderId);
              const totalUnits = Object.values(army.units).reduce((sum, n) => sum + n, 0);
              const stanceClass = styles[STANCE_CLASS[army.stance] ?? 'statusActive'];

              return (
                <div key={army.id} className={styles.armyCard}>
                  <div className={styles.armyIcon}>
                    {commander ? (
                      <CoatOfArms nobleId={commander.id} familyId={commander.familyId} title={commander.title} size={40} />
                    ) : (
                      '🛡️'
                    )}
                  </div>
                  <div className={styles.armyInfo}>
                    <h3 className={styles.armyName}>Veliteľ: {commander?.name ?? 'Neznámy'}</h3>
                    <p className={styles.armyLocation}>📍 {getZupaName(army.location)}</p>
                    <div className={styles.armyStats}>
                      <span className={`${styles.statusBadge} ${stanceClass}`}>{STANCE_LABEL[army.stance] ?? army.stance}</span>
                      <span className={styles.armyStat}>Morálka: {army.morale}%</span>
                      <span className={styles.armyStat}>Mužov: {totalUnits}</span>
                      <span className={styles.armyStat}>Údržba: {army.upkeep} zlato/mesiac</span>
                    </div>
                    <div className={styles.unitComposition}>
                      <div className={styles.unitList}>
                        {(Object.entries(army.units) as [string, number][])
                          .filter(([, count]) => count > 0)
                          .map(([unitType, count]) => (
                            <span key={unitType} className={styles.unitBadge}>
                              <span className={styles.count}>{count}×</span>
                              <span className={styles.name}>{UNIT_LABEL[unitType] ?? unitType}</span>
                            </span>
                          ))}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

export default ArmyPanel;
