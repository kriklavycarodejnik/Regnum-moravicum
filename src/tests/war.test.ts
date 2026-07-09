// Regnum Moravicum - War Tests

import { describe, it, expect, beforeEach } from 'vitest';
import { WarEngine } from '../war/warEngine';
import { ZUPA_ADJACENCY } from '../war/adjacency';
import { createHungarianWar, createInitialArmies, createInitialZupaWarStates, initializeHungarianWarScenario, SCENARIO_CONSTANTS, FACTION_IDS, ZUPA_IDS } from '../scenarios/hungarianWar';
import type { War, ZupaWarState } from '../war/types';
import type { Army, Battle } from '../battle/types';

describe('War Engine', () => {
  let engine: WarEngine;
  let war: War;
  let armies: Army[];
  let zupyWarState: ZupaWarState[];

  beforeEach(() => {
    engine = new WarEngine();
    war = createHungarianWar(0);
    armies = createInitialArmies();
    zupyWarState = createInitialZupaWarStates();

    engine.initialize([war], armies, zupyWarState, [], 0);
  });

  describe('Initialization', () => {
    it('should initialize with wars', () => {
      expect(engine.getAllWars().length).toBe(1);
      expect(engine.getWar('war_hungarian_invasion')).not.toBeNull();
    });

    it('should initialize with armies', () => {
      expect(engine.getAllArmies().length).toBe(2);
      expect(engine.getArmy('army_hungarian_main')).not.toBeNull();
      expect(engine.getArmy('army_moravian_main')).not.toBeNull();
    });

    it('should initialize with zupa war states', () => {
      expect(engine.getAllZupaWarStates().length).toBe(4);
    });

    it('should initialize with current tick', () => {
      expect(engine.getCurrentTick()).toBe(0);
    });
  });

  describe('War Management', () => {
    it('should add new war', () => {
      const newWar: War = {
        id: 'war2',
        attackerFactionId: 'faction1',
        defenderFactionId: 'faction2',
        objectives: [],
        startTick: 0,
        timeoutTicks: 60,
        result: 'ongoing',
      };

      engine.addWar(newWar);
      expect(engine.getWar('war2')).not.toBeNull();
    });

    it('should update war', () => {
      engine.updateWar('war_hungarian_invasion', { result: 'victory' });
      const updatedWar = engine.getWar('war_hungarian_invasion');
      expect(updatedWar?.result).toBe('victory');
    });

    it('should get all wars', () => {
      const allWars = engine.getAllWars();
      expect(allWars.length).toBe(1);
      expect(allWars[0].id).toBe('war_hungarian_invasion');
    });
  });

  describe('Army Management', () => {
    it('should add new army', () => {
      const newArmy: Army = {
        id: 'army_new',
        factionId: 'moravian',
        size: 500,
        morale: 80,
        commander: { id: 'cmd_new', name: 'New', skill: 5 },
        composition: { infantry: 1.0, cavalry: 0, archers: 0 },
        locationZupaId: ZUPA_IDS.bratislava,
      };

      engine.addArmy(newArmy);
      expect(engine.getArmy('army_new')).not.toBeNull();
    });

    it('should update army', () => {
      engine.updateArmy('army_hungarian_main', { size: 15000 });
      const updatedArmy = engine.getArmy('army_hungarian_main');
      expect(updatedArmy?.size).toBe(15000);
    });

    it('should remove army', () => {
      engine.removeArmy('army_hungarian_main');
      expect(engine.getArmy('army_hungarian_main')).toBeNull();
    });

    it('should get all armies', () => {
      const allArmies = engine.getAllArmies();
      expect(allArmies.length).toBe(2);
    });
  });

  describe('Zupa War State Management', () => {
    it('should add zupa war state', () => {
      const newState: ZupaWarState = {
        zupaId: 'new_zupa',
        controllerFactionId: 'moravian',
        occupierFactionId: null,
      };

      engine.addZupaWarState(newState);
      expect(engine.getZupaWarState('new_zupa')).not.toBeNull();
    });

    it('should update zupa war state', () => {
      engine.updateZupaWarState(ZUPA_IDS.devin, { occupierFactionId: null });
      const updatedState = engine.getZupaWarState(ZUPA_IDS.devin);
      expect(updatedState?.occupierFactionId).toBeNull();
    });

    it('should get all zupa war states', () => {
      const allStates = engine.getAllZupaWarStates();
      expect(allStates.length).toBe(4);
    });
  });

  describe('Battle Management', () => {
    it('should start new battle', () => {
      const battle = engine.startBattle(
        'war_hungarian_invasion',
        ZUPA_IDS.devin,
        'field',
        'army_hungarian_main',
        'army_moravian_main'
      );

      expect(battle).not.toBeNull();
      expect(battle?.id).toContain('war_hungarian_invasion');
      expect(battle?.terrain).toBe('field');
    });

    it('should add battle directly', () => {
      const battle: Battle = {
        id: 'battle1',
        warId: 'war_hungarian_invasion',
        zupaId: ZUPA_IDS.devin,
        terrain: 'field',
        attackerArmyId: 'army_hungarian_main',
        defenderArmyId: 'army_moravian_main',
        currentPhase: 'attack',
        phaseLogs: [],
        result: null,
        winnerArmyId: null,
        isAutoResolved: false,
        startTick: 0,
        seed: 'battle-seed',
        rngState: null,
      };

      engine.addBattle(battle);
      expect(engine.getBattle('battle1')).not.toBeNull();
    });

    it('should get all battles', () => {
      engine.startBattle(
        'war_hungarian_invasion',
        ZUPA_IDS.devin,
        'field',
        'army_hungarian_main',
        'army_moravian_main'
      );

      const allBattles = engine.getAllBattles();
      expect(allBattles.length).toBe(1);
    });
  });

  describe('Zupa Liberation (9.1)', () => {
    it('should mark objective as completed when zupa is liberated', () => {
      // Remove Hungarian army from Hungarian zupa
      engine.updateArmy('army_hungarian_main', { locationZupaId: ZUPA_IDS.nitra });

      // Check if Hungarian zupa is liberated
      const isLiberated = engine.checkZupaLiberated(ZUPA_IDS.devin, 'war_hungarian_invasion');
      
      expect(isLiberated).toBe(true);

      // Check if objective is completed
      const war = engine.getWar('war_hungarian_invasion');
      const objective = war?.objectives.find(o => o.zupaId === ZUPA_IDS.devin);
      expect(objective?.completed).toBe(true);
    });

    it('should update zupa state when liberated', () => {
      // Remove Hungarian army from Hungarian zupa
      engine.updateArmy('army_hungarian_main', { locationZupaId: ZUPA_IDS.nitra });

      // Check if Hungarian zupa is liberated
      engine.checkZupaLiberated(ZUPA_IDS.devin, 'war_hungarian_invasion');

      // Check zupa state
      const zupaState = engine.getZupaWarState(ZUPA_IDS.devin);
      expect(zupaState?.occupierFactionId).toBeNull();
    });
  });

  describe('Army Retreat (9.2)', () => {
    it('should retreat to adjacent friendly zupa', () => {
      // Set up: Hungarian army in Devín, Moravian army in Nitra
      engine.updateArmy('army_hungarian_main', { locationZupaId: ZUPA_IDS.devin });
      engine.updateArmy('army_moravian_main', { locationZupaId: ZUPA_IDS.nitra });

      // Bratislava (adjacent to Devín) is Moravian-controlled, not Hungarian
      engine.addZupaWarState({
        zupaId: ZUPA_IDS.bratislava,
        controllerFactionId: 'moravian',
        occupierFactionId: null,
      });

      // Retreat Hungarian army: no Hungarian-controlled zupa adjacent to Devín
      // (Devín's neighbors are Bratislava and Trnava, both Moravian), so it's destroyed
      const retreated = engine.retreatArmy('army_hungarian_main', 'war_hungarian_invasion');

      expect(retreated).toBe(false);
      expect(engine.getArmy('army_hungarian_main')).toBeNull();
    });

    it('should retreat to friendly zupa when available', () => {
      // Trnava (adjacent to Devín) is controlled by the Hungarians
      engine.addZupaWarState({
        zupaId: ZUPA_IDS.trnava,
        controllerFactionId: 'hungarian',
        occupierFactionId: null,
      });
      engine.updateArmy('army_hungarian_main', { locationZupaId: ZUPA_IDS.devin });

      const retreated = engine.retreatArmy('army_hungarian_main', 'war_hungarian_invasion');

      expect(retreated).toBe(true);
      expect(engine.getArmy('army_hungarian_main')?.locationZupaId).toBe(ZUPA_IDS.trnava);
    });

    it('should destroy army when no retreat path available', () => {
      // Set up: Army in a zupa with no friendly adjacent zupy - Devín and both
      // of its neighbors (Bratislava, Trnava) all fall under Hungarian control.
      engine.updateArmy('army_moravian_main', { locationZupaId: ZUPA_IDS.devin });

      engine.updateZupaWarState(ZUPA_IDS.devin, {
        controllerFactionId: 'hungarian',
        occupierFactionId: 'hungarian',
      });
      engine.updateZupaWarState(ZUPA_IDS.bratislava, {
        controllerFactionId: 'hungarian',
        occupierFactionId: 'hungarian',
      });
      engine.updateZupaWarState(ZUPA_IDS.trnava, {
        controllerFactionId: 'hungarian',
        occupierFactionId: 'hungarian',
      });

      // Retreat Moravian army from Hungarian-controlled zupa
      const retreated = engine.retreatArmy('army_moravian_main', 'war_hungarian_invasion');

      // Should be destroyed as there are no friendly adjacent zupy
      expect(retreated).toBe(false);
      expect(engine.getArmy('army_moravian_main')).toBeNull();
    });
  });

  describe('War End Conditions (9.4)', () => {
    it('should end war when all objectives completed', () => {
      // Complete all objectives
      const war = engine.getWar('war_hungarian_invasion');
      if (war) {
        war.objectives.forEach(o => o.completed = true);
        engine.updateWar('war_hungarian_invasion', { objectives: [...war.objectives] });
      }

      const result = engine.checkWarEnd('war_hungarian_invasion');
      expect(result.ended).toBe(true);
      expect(result.result).toBe('victory');

      const updatedWar = engine.getWar('war_hungarian_invasion');
      expect(updatedWar?.result).toBe('victory');
    });

    it('should end war when player army is destroyed', () => {
      // Destroy Moravian army
      engine.removeArmy('army_moravian_main');

      const result = engine.checkWarEnd('war_hungarian_invasion');
      expect(result.ended).toBe(true);
      expect(result.result).toBe('defeat');

      const updatedWar = engine.getWar('war_hungarian_invasion');
      expect(updatedWar?.result).toBe('defeat');
    });

    it('should end war on timeout', () => {
      // Set current tick to timeout
      engine.setCurrentTick(SCENARIO_CONSTANTS.timeoutTicks);

      const result = engine.checkWarEnd('war_hungarian_invasion');
      expect(result.ended).toBe(true);
      expect(result.result).toBe('defeat');

      const updatedWar = engine.getWar('war_hungarian_invasion');
      expect(updatedWar?.result).toBe('defeat');
    });

    it('should not end war when conditions not met', () => {
      const result = engine.checkWarEnd('war_hungarian_invasion');
      expect(result.ended).toBe(false);
      expect(result.result).toBeNull();
    });
  });

  describe('Adjacency', () => {
    it('should return adjacent zupy', () => {
      const adjacent = engine.getAdjacentZupy(ZUPA_IDS.devin);
      expect(adjacent).toContain(ZUPA_IDS.bratislava);
      expect(adjacent).toContain(ZUPA_IDS.trnava);
    });

    it('should return empty array for unknown zupa', () => {
      const adjacent = engine.getAdjacentZupy('unknown_zupa');
      expect(adjacent).toEqual([]);
    });

    it('should return adjacency matrix', () => {
      const matrix = engine.getAdjacencyMatrix();
      expect(matrix).toEqual(ZUPA_ADJACENCY);
    });
  });

  describe('Scenario Integration', () => {
    it('should initialize Hungarian war scenario correctly', () => {
      const { war, armies, zupyWarState } = initializeHungarianWarScenario(0);
      
      expect(war.id).toBe('war_hungarian_invasion');
      expect(war.attackerFactionId).toBe(FACTION_IDS.hungarian);
      expect(war.defenderFactionId).toBe(FACTION_IDS.moravian);
      expect(war.objectives.length).toBe(2);
      expect(war.timeoutTicks).toBe(SCENARIO_CONSTANTS.timeoutTicks);
      
      expect(armies.length).toBe(2);
      expect(armies[0].factionId).toBe(FACTION_IDS.hungarian);
      expect(armies[0].size).toBe(SCENARIO_CONSTANTS.hungarianArmySize);
      expect(armies[1].factionId).toBe(FACTION_IDS.moravian);
      expect(armies[1].size).toBe(SCENARIO_CONSTANTS.moravianArmySize);
      
      expect(zupyWarState.length).toBe(4);
    });

    it('should have correct initial zupa states', () => {
      const zupyWarState = createInitialZupaWarStates();
      
      const devinZupa = zupyWarState.find(z => z.zupaId === ZUPA_IDS.devin);
      expect(devinZupa).not.toBeUndefined();
      expect(devinZupa?.occupierFactionId).toBe(FACTION_IDS.hungarian);

      const nitraZupa = zupyWarState.find(z => z.zupaId === ZUPA_IDS.nitra);
      expect(nitraZupa).not.toBeUndefined();
      expect(nitraZupa?.occupierFactionId).toBeNull();
    });
  });
});
