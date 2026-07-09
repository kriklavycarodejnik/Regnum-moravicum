// Regnum Moravicum - Hungarian War Scenario

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
  // Oslobodená Maďarská župa
  liberatedHungarianZupa: {
    prestige: 5,
    gold: 1000,
    loyaltyBonus: 10,
  },
  // Oslobodená Nitrianska župa
  liberatedNitraZupa: {
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

// Zupa IDs
export const ZUPA_IDS = {
  hungarianZupa: 'hungarian_zupa',
  nitraZupa: 'nitra_zupa',
  nitrianskaZupa: 'nitrianska_zupa',
  moraviaBrno: 'moravia_brno',
};

// Terrain for battles
export const BATTLE_TERRAINS: Record<string, Terrain> = {
  [ZUPA_IDS.hungarianZupa]: 'field',
  [ZUPA_IDS.nitraZupa]: 'river',
  [ZUPA_IDS.nitrianskaZupa]: 'field',
  [ZUPA_IDS.moraviaBrno]: 'fortress',
};

// Commanders
export const COMMANDERS: Record<string, Commander> = {
  arpad: {
    id: 'commander_arpad',
    name: 'Árpád',
    skill: 8,
  },
  mojmir: {
    id: 'commander_mojmir',
    name: 'Mojmír II.',
    skill: 7,
  },
};

// Create initial armies for the scenario
export function createInitialArmies(): Army[] {
  return [
    // Hungarian army
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
      locationZupaId: ZUPA_IDS.hungarianZupa,
    },
    // Moravian army
    {
      id: 'army_moravian_main',
      factionId: FACTION_IDS.moravian,
      size: SCENARIO_CONSTANTS.moravianArmySize,
      morale: 90,
      commander: { ...COMMANDERS.mojmir },
      composition: {
        infantry: 0.55,
        cavalry: 0.20,
        archers: 0.25,
      },
      locationZupaId: ZUPA_IDS.nitrianskaZupa,
    },
  ];
}

// Create war objectives
export function createWarObjectives(): WarObjective[] {
  return [
    {
      zupaId: ZUPA_IDS.hungarianZupa,
      type: 'expel',
      completed: false,
    },
    {
      zupaId: ZUPA_IDS.nitrianskaZupa,
      type: 'expel',
      completed: false,
    },
  ];
}

// Create initial zupa war states
export function createInitialZupaWarStates(): ZupaWarState[] {
  return [
    {
      zupaId: ZUPA_IDS.hungarianZupa,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: FACTION_IDS.hungarian, // Occupied by Hungarians
    },
    {
      zupaId: ZUPA_IDS.nitrianskaZupa,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: null, // Initially not occupied
    },
    {
      zupaId: ZUPA_IDS.nitraZupa,
      controllerFactionId: FACTION_IDS.moravian,
      occupierFactionId: null,
    },
    {
      zupaId: ZUPA_IDS.moraviaBrno,
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
      description: 'Maďari vyšlú nájazdový oddiel 4 000 mužov do Nitrianskej župy',
      data: {
        armyId: 'army_hungarian_raid',
        size: SCENARIO_CONSTANTS.hungarianRaidSize,
        factionId: FACTION_IDS.hungarian,
        commander: { ...COMMANDERS.arpad }, // Same commander or different?
        composition: {
          infantry: 0.20,
          cavalry: 0.60,
          archers: 0.20,
        },
        targetZupaId: ZUPA_IDS.nitrianskaZupa,
      },
    },
    {
      tick: SCENARIO_CONSTANTS.reinforcementTick,
      type: 'reinforcement',
      description: 'Maďari dostanú posily +3 000 mužov, ak stále okupujú Maďarskú župu',
      data: {
        armyId: 'army_hungarian_main',
        reinforcementSize: SCENARIO_CONSTANTS.hungarianReinforcements,
        condition: {
          zupaId: ZUPA_IDS.hungarianZupa,
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

  // Check condition: Hungarians must still occupy Hungarian zupa
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
  return 'Maďarská vojna';
}

// Get scenario description
export function getScenarioDescription(): string {
  return `Maďarská vojna (902 - 907): Maďari pod velením kniežaťa Árpáda vpadli do Veľkej Moravy.
  Moravanom velí knieža Mojmír II., ktorý sa snaží obraniť svoju zem pred nájazdníkmi.
  Cieľom je vyhnať Maďarov z Moravy a oslobodiť okupované župy.`;
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
