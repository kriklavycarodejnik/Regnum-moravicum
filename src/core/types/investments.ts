// Regnum Moravicum v2.1 - Zupa Investment Types (Core Loop M1)
//
// Three parallel investment tracks per zupa (0-5 levels each), replacing the
// "building tree" concept from the Mistral feedback with a shallow-but-wide
// AoH2-style model. See src/core/engines/investmentEngine.ts.

export type InvestmentTrack = 'economy' | 'fortification' | 'church';
export type ReligiousRite = 'roman' | 'byzantine';

export interface ActiveInvestment {
  track: InvestmentTrack;
  startTick: number;
  completeTick: number;
  rite?: ReligiousRite; // only set when track === 'church'
}

export interface ZupaInvestmentState {
  economy: number; // 0-5
  fortification: number; // 0-5
  church: number; // 0-5
  active: ActiveInvestment | null;
}
