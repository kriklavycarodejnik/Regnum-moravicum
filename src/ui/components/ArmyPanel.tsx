// Regnum Moravicum v2.1 - Army Panel Component (Placeholder)
import type { GameState } from '../../core/types/gameState';
import styles from '../../styles/ArmyPanel.module.css';

interface ArmyPanelProps {
  gameState: GameState;
}

export function ArmyPanel({ gameState }: ArmyPanelProps) {
  // Get noble name by ID
  const getNobleName = (id: string): string => {
    const noble = gameState.nobles.find(n => n.id === id);
    return noble ? noble.name : 'Neznámy';
  };

  // Get zupa name by ID
  const getZupaName = (id: string): string => {
    return gameState.zupy[id]?.name || 'Neznáma';
  };

  return (
    <div className={styles.container}>
      <h2>Armády</h2>
      <p className={styles.placeholder}>
        Armády budú plne implementované v Fáze 2
      </p>
      {gameState.armies.length > 0 ? (
        <div className={styles.armyList}>
          {gameState.armies.map(army => (
            <div key={army.id} className={styles.army}>
              <h3>Armáda {army.id}</h3>
              <p>Veliteľ: {getNobleName(army.commanderId)}</p>
              <p>Poloha: {getZupaName(army.location)}</p>
              <p>Morálka: {army.morale}%</p>
              <p>Stav: {army.stance}</p>
              <p>Údržba: {army.upkeep} zlato/mesiac</p>
              <div className={styles.units}>
                <span>Ľahká pechota: {army.units.lightInfantry}</span>
                <span>Ťažká pechota: {army.units.heavyInfantry}</span>
                <span>Lukostrelci: {army.units.archers}</span>
                <span>Ľahká jazda: {army.units.lightCavalry}</span>
                <span>Ťažká jazda: {army.units.heavyCavalry}</span>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className={styles.noArmies}>Žiadne armády</p>
      )}
    </div>
  );
}

export default ArmyPanel;
