// Regnum Moravicum - Hungarian War Scenario: Bitka pri Devíne (907)
//
// Kánon v1.1: 907 - Mojmír II. nastraží Árpádovým Maďarom pascu pri Devíne,
// s podporou byzantských lodí ovládajúcich grécky oheň a moravskej ťažkej
// pechoty ako "neprerušiteľnej steny". Víťazstvo zakladá mýtus "Morava ako
// štít". 908-910: ďalšie bitky a konečné odrazenie Maďarov, časť sa
// slavizuje, zvyšok ustupuje do Potisia. Veliteľom moravských vojsk v tejto
// vojne je župan Radomír, nie panovník osobne.

import type { War, WarObjective, ZupaWarState } from '../war/types';
import type { Terrain, Army, Commander, UnitType } from '../battle/types';

// Scenario constants
export const SCENARIO_CONSTANTS = {
  // Initial army sizes
  hungarianArmySize: 12000,
  moravianArmySize: 8000,

  // Reinforcements
  hungarianReinforcements: 3000,
  hungarianRaidSize: 4000,

  // Timing
  raidTick: 3,
  reinforcementTick: 12,
  timeoutTicks: 60,

  // Occupation effects
  loyaltyPenaltyPerTick: 1,
  goldPenaltyPerTick: 50,
};

// Scenario rewards (10.4)
export const SCENARIO_REWARDS = {
  // Oslobodený Devín (víťazstvo v bitke 907)
  liberatedDevin: {
    prestige: 5,
    gold: 1000,
    loyaltyBonus: 10,
  },
  // Oslobodená Nitra (konečné odrazenie, 910)
  liberatedNitra: {
    prestige: 7,
    gold: 1500,
    loyaltyBonus: 15,
  },
  // Prehra vojny
  warDefeat: {
    prestige: -5,
    gold: 0,
    loyaltyPenalty: -15,
  },
};

// Faction IDs
export const FACTION_IDS = {
  hungarian: 'hungarian',
  moravian: 'moravian',
};

// Zupa IDs - musia zodpovedať skutočným 11 župám generovaným v
// src/core/utils/generators.ts (id = `zupa_${name.toLowerCase().replace(/\s+/g, '_')}`)
export const ZUPA_IDS = {
  devin: 'zupa_devín',
  nitra: 'zupa_nitra',
  bratislava: 'zupa_bratislava',
  trnava: 'zupa_trnava',
};

// Terrain for battles - Devín leží na sútoku Dunaja a Moravy (rieka),
// Nitra je vnútrozemská (pole)
export const BATTLE_TERRAINS: Record<string, Terrain> = {
  [ZUPA_IDS.devin]: 'river',
  [ZUPA_IDS.nitra]: 'field',
  [ZUPA_IDS.bratislava]: 'field',
  [ZUPA_IDS.trnava]: 'field',
};

// Commanders
export const COMMANDERS: Record<string, Commander> = {
  arpad: {
    id: 'commander_arpad',
    name: 'Árpád',
    skill: 8,
  },
  // Radomír - kľúčový župan, veliteľ moravských vojsk v bitkách 907+ (kánon)
  radomir: {
    id: 'commander_radomir',
    name: 'Radomír',
    skill: 9,
  },
};

// Create initial armies for the scenario
export function createInitialArmies(): Army[] {
  return [
    // Hungarian army under Árpád
    {
      id: 'army_hungarian_main',
      factionId: FACTION_IDS.hungarian,
      size: SCENARIO_CONSTANTS.hungarianArmySize,
      morale: 85,
      commander: { ...COMMANDERS.arpad },
      composition: {
        infantry: 0.30,
        cavalry: 0.45,
        archers: 0.25,
      },
      locationZupaId: ZUPA_IDS.devin,
    },
    // Moravian army under Radomír - ťažká pechota ako "neprerušiteľná stena"
    {
      id: 'army_moravian_main',
      factionId: FACTION_IDS.moravian,
      size: SCENARIO_CONSTANTS.moravianArmySize,
      morale: 90,
      commander: { ...COMMANDERS.radomir },
      composition: {
        infantry: 0.55,
        cavalry: 0.20,
        archers: 0.25,
      },
      locationZupaId: ZUPA_IDS.nitra,
    },
  ];
}

// Create war objectives
export function createWarObjectives(): WarObjective[] {
  return [
    {
      zupaId: ZUPA_IDS.devin,
      type: 'expel',
      completed: false,
    },
    {
      zupaId: ZUPA_IDS.nitra,
      type: 'expel',
      completed: false,
    },
  ];
}

// Create initial zupa war states
export function createInitialZupaWarStates(): ZupaWarState[] {
  return [
    {
      zupaId: ZUPA_IDS.devin,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: FACTION_IDS.hungarian, // Occupied by Hungarians
    },
    {
      zupaId: ZUPA_IDS.nitra,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: null, // Initially not occupied
    },
    {
      zupaId: ZUPA_IDS.bratislava,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: null,
    },
    {
      zupaId: ZUPA_IDS.trnava,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: null,
    },
  ];
}

// Create the war
export function createHungarianWar(startTick: number): War {
  return {
    id: 'war_hungarian_invasion',
    attackerFactionId: FACTION_IDS.hungarian,
    defenderFactionId: FACTION_IDS.moravian,
    objectives: createWarObjectives(),
    startTick,
    timeoutTicks: SCENARIO_CONSTANTS.timeoutTicks,
    result: 'ongoing',
  };
}

// Scenario script events
export interface ScenarioEvent {
  tick: number;
  type: 'raid' | 'reinforcement' | 'battle';
  description: string;
  data: Record<string, unknown>;
}

// Get scenario events
export function getScenarioEvents(): ScenarioEvent[] {
  return [
    {
      tick: SCENARIO_CONSTANTS.raidTick,
      type: 'raid',
      description: 'Maďari vyšlú nájazdový oddiel 4 000 mužov smerom na Nitru',
      data: {
        armyId: 'army_hungarian_raid',
        size: SCENARIO_CONSTANTS.hungarianRaidSize,
        factionId: FACTION_IDS.hungarian,
        commander: { ...COMMANDERS.arpad },
        composition: {
          infantry: 0.20,
          cavalry: 0.60,
          archers: 0.20,
        },
        targetZupaId: ZUPA_IDS.nitra,
      },
    },
    {
      tick: SCENARIO_CONSTANTS.reinforcementTick,
      type: 'reinforcement',
      description: 'Maďari dostanú posily +3 000 mužov, ak stále okupujú Devín',
      data: {
        armyId: 'army_hungarian_main',
        reinforcementSize: SCENARIO_CONSTANTS.hungarianReinforcements,
        condition: {
          zupaId: ZUPA_IDS.devin,
          occupierFactionId: FACTION_IDS.hungarian,
        },
      },
    },
  ];
}

// Apply scenario event
export function applyScenarioEvent(
  event: ScenarioEvent,
  warEngine: import('../war/warEngine').WarEngine
): void {
  switch (event.type) {
    case 'raid':
      applyRaidEvent(event, warEngine);
      break;
    case 'reinforcement':
      applyReinforcementEvent(event, warEngine);
      break;
    case 'battle':
      // Battle events are handled by the war engine
      break;
  }
}

// Apply raid event
function applyRaidEvent(event: ScenarioEvent, warEngine: import('../war/warEngine').WarEngine): void {
  const data = event.data as {
    armyId: string;
    size: number;
    factionId: string;
    commander: Commander;
    composition: Record<UnitType, number>;
    targetZupaId: string;
  };

  // Create raid army
  const raidArmy: Army = {
    id: data.armyId,
    factionId: data.factionId,
    size: data.size,
    morale: 85, // Same as main Hungarian army
    commander: { ...data.commander },
    composition: { ...data.composition },
    locationZupaId: data.targetZupaId,
  };

  warEngine.addArmy(raidArmy);

  // Update zupa war state to show occupation
  const zupaState = warEngine.getZupaWarState(data.targetZupaId);
  if (zupaState) {
    warEngine.updateZupaWarState(data.targetZupaId, {
      occupierFactionId: data.factionId,
    });
  } else {
    warEngine.addZupaWarState({
      zupaId: data.targetZupaId,
      controllerFactionId: FACTION_IDS.moravian, // Assuming Moravia controls it
      occupierFactionId: data.factionId,
    });
  }
}

// Apply reinforcement event
function applyReinforcementEvent(event: ScenarioEvent, warEngine: import('../war/warEngine').WarEngine): void {
  const data = event.data as {
    armyId: string;
    reinforcementSize: number;
    condition: {
      zupaId: string;
      occupierFactionId: string;
    };
  };

  // Check condition: Hungarians must still occupy Devín
  const zupaState = warEngine.getZupaWarState(data.condition.zupaId);
  if (zupaState && zupaState.occupierFactionId === data.condition.occupierFactionId) {
    // Add reinforcement
    const army = warEngine.getArmy(data.armyId);
    if (army) {
      warEngine.updateArmy(data.armyId, {
        size: army.size + data.reinforcementSize,
      });
    }
  }
}

// Get scenario name
export function getScenarioName(): string {
  return 'Bitka pri Devíne';
}

// Get scenario description
export function getScenarioDescription(): string {
  return `Bitka pri Devíne (907 - 910): Maďari pod velením náčelníka Árpáda vpadli do Veľkej Moravy.
  Moravským vojskám velí župan Radomír, ktorý pri Devíne nastraží nepriateľovi pascu s podporou
  byzantských lodí ovládajúcich grécky oheň. Cieľom je vyhnať Maďarov z Devína a napokon aj z Nitry
  a odraziť maďarskú hrozbu natrvalo.`;
}

// Initialize the scenario
export function initializeHungarianWarScenario(startTick: number): {
  war: War;
  armies: Army[];
  zupyWarState: ZupaWarState[];
  events: ScenarioEvent[];
} {
  return {
    war: createHungarianWar(startTick),
    armies: createInitialArmies(),
    zupyWarState: createInitialZupaWarStates(),
    events: getScenarioEvents(),
  };
}
