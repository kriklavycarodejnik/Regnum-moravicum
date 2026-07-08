// Regnum Moravicum v2.1 - Unit Data
// Útok, Obrana, Rýchlosť, Dosah, Náklady (zlato), Údržba (zlato/mes)

export const UNITS = {
  lightInfantry: { attack: 4, defense: 3, speed: 6, range: 1, cost: 20, upkeep: 1 },
  heavyInfantry: { attack: 6, defense: 7, speed: 4, range: 1, cost: 40, upkeep: 2 },
  archers:       { attack: 8, defense: 2, speed: 5, range: 3, cost: 35, upkeep: 2 },
  lightCavalry:  { attack: 7, defense: 4, speed: 9, range: 1, cost: 60, upkeep: 3 },
  heavyCavalry:  { attack: 9, defense: 8, speed: 7, range: 1, cost: 120, upkeep: 4 },
} as const;

export type UnitType = keyof typeof UNITS;

export interface UnitStats {
  attack: number;
  defense: number;
  speed: number;
  range: number;
  cost: number;
  upkeep: number;
}

export default UNITS;
