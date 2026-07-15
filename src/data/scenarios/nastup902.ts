// Regnum Moravicum v2.1 - Start Scenario: 902 - Nástup Mojmíra II. (Core Loop M3)
import type { StartScenarioConfig } from '../../core/types/scenario';

export const NASTUP_902: StartScenarioConfig = {
  id: 'nastup-902',
  name: '902 — Nástup Mojmíra II.',
  description:
    'Mojmír II. preberá vládu nad Veľkou Moravou v jej najsilnejšom období. Pokladnica je plná, žpy verné, no ríša čelí tichým vnútorným pnutiam medzi rímskym a byzantským vplyvom.',
  startYear: 902,
  startTick: 0,
  victoryScenario: 'prežitie',
  initialResourceOverrides: {},
  zupaLoyaltyOverrides: {},
  religionAxisStart: 0,
  activeThreats: [],
};

export default NASTUP_902;
