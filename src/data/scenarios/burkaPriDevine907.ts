// Regnum Moravicum v2.1 - Start Scenario: 907 - Búrka pri Devíne (Core Loop M3)
import type { StartScenarioConfig } from '../../core/types/scenario';

export const BURKA_PRI_DEVINE_907: StartScenarioConfig = {
  id: 'burka-pri-devine-907',
  name: '907 — Búrka pri Devíne',
  description:
    'Päť rokov drobných vojen vyčerpalo pokladnicu a maďarské jazdectvo sa zhromažďuje za Dunajom. Devín, brána ríše, je nepokojný a nedostatočne zásobený.',
  startYear: 907,
  startTick: 60, // 5 years * 12 months since the 902 baseline
  victoryScenario: 'prežitie',
  initialResourceOverrides: { gold: 400, food: 60 },
  zupaLoyaltyOverrides: { Devín: 35 },
  religionAxisStart: 0,
  activeThreats: [
    'Maďarské jazdectvo sa zhromažďuje za Dunajom a ohrozuje Devín.',
    'Roky drobných vojen vyprázdnili pokladnicu.',
  ],
};

export default BURKA_PRI_DEVINE_907;
