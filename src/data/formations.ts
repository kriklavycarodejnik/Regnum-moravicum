// Regnum Moravicum v2.1 - Formation Data
// Percentuálne bonusy

export const FORMATIONS = {
  klin:        { attack: +20, defense: -10 },
  shieldWall:  { attack: -10, defense: +30 },
  archerLine:  { attack: +20, defense: -10 },
  mixed:       { attack: +10, defense: +10 },
} as const;

export type FormationType = keyof typeof FORMATIONS;

export interface FormationBonuses {
  attack: number;
  defense: number;
}

export default FORMATIONS;
