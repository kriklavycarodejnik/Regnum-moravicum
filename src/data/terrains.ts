// Regnum Moravicum v2.1 - Terrain Data
// Percentuálne bonusy pre Pechotu, Jazdu, Lukostrelcov

export const TERRAINS = {
  plain:     { infantry: 0,   cavalry: +20, archers: 0 },
  forest:    { infantry: +20, cavalry: -20, archers: +10 },
  mountains: { infantry: +10, cavalry: -30, archers: +20 },
  river:     { infantry: -10, cavalry: -10, archers: 0 },
} as const;

export type TerrainType = keyof typeof TERRAINS;

export interface TerrainBonuses {
  infantry: number;
  cavalry: number;
  archers: number;
}

export const TAX_LEVELS = {
  low:    { coefficient: 0.3, description: 'Nízka' },
  medium: { coefficient: 0.5, description: 'Stredná' },
  high:   { coefficient: 0.8, description: 'Vysoká' },
} as const;

export type TaxLevel = keyof typeof TAX_LEVELS;

export interface TaxConfig {
  coefficient: number;
  description: string;
}

export default TERRAINS;
