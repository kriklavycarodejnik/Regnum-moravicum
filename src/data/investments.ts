// Regnum Moravicum v2.1 - Investment Track Metadata (Core Loop M1)
import type { InvestmentTrack } from '../core/types/investments';

export interface InvestmentTrackInfo {
  track: InvestmentTrack;
  name: string;
  description: string;
}

export const INVESTMENT_TRACKS: Record<InvestmentTrack, InvestmentTrackInfo> = {
  economy: {
    track: 'economy',
    name: 'Hospodárstvo',
    description: 'Trhy, remeslá a poľnohospodárstvo — zvyšuje mesačný príjem zlata.',
  },
  fortification: {
    track: 'fortification',
    name: 'Opevnenie',
    description: 'Hradby a strážne veže — posilňuje obranu župy pri obliehaní.',
  },
  church: {
    track: 'church',
    name: 'Cirkev',
    description: 'Kostoly a kláštory — zvyšuje lojalitu ľudu a posúva náboženskú os.',
  },
};

export default INVESTMENT_TRACKS;
