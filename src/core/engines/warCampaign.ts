// Regnum Moravicum v2.1 - War Campaign Bridge Engine
//
// Connects the core GameState tick loop to the battle/war layer (src/battle,
// src/war, src/scenarios). Every function here is pure: it reconstructs a
// fresh WarEngine/BattleEngine from the serializable GameState.warCampaign
// slice, performs the operation, and extracts the result back into plain
// data - GameState never holds a live class instance, so save/load and the
// "processTick is a pure function" guarantee both keep holding.

import type { GameState } from '../types/gameState';
import type { WarCampaignState } from '../types/warCampaign';
import type { Army as BattleArmy, Battle, BattleAction, Terrain } from '../../battle/types';
import { WarEngine } from '../../war/warEngine';
import { BattleEngine, createBattle } from '../../battle/engine';
import { autoResolve, shouldAutoResolve } from '../../battle/autoResolve';
import { Narrator } from '../../battle/narration/narrator';
import { ALL_TEMPLATES } from '../../battle/narration/templates/loader';
import type { TemplatePlaceholders } from '../../battle/narration/templates';
import {
  initializeHungarianWarScenario,
  getScenarioEvents,
  applyScenarioEvent,
  SCENARIO_REWARDS,
  SCENARIO_CONSTANTS,
  BATTLE_TERRAINS,
  FACTION_IDS,
  ZUPA_IDS,
} from '../../scenarios/hungarianWar';

const MORAVIAN_ARMY_ID = 'army_moravian_main';

/** Reconstruct a WarEngine from the current campaign state. */
function loadWarEngine(state: GameState, wc: WarCampaignState): WarEngine {
  const engine = new WarEngine();
  engine.initialize([wc.war], wc.armies, wc.zupyWarState, [], state.tick);
  return engine;
}

function extractCampaign(engine: WarEngine, prev: WarCampaignState): WarCampaignState {
  return {
    war: engine.getWar(prev.war.id) ?? prev.war,
    armies: engine.getAllArmies(),
    zupyWarState: engine.getAllZupaWarStates(),
    activeBattle: prev.activeBattle,
    appliedEventTicks: prev.appliedEventTicks,
    log: prev.log,
  };
}

export function canStartHungarianWar(state: GameState): boolean {
  return !state.warCampaign && state.year >= 905;
}

/** Maďari vtrhnú do Moravy - spustí kánonickú Bitku pri Devíne (907). */
export function startHungarianWar(state: GameState): GameState {
  if (state.warCampaign) return state;

  const scenario = initializeHungarianWarScenario(state.tick);
  const warCampaign: WarCampaignState = {
    war: scenario.war,
    armies: scenario.armies,
    zupyWarState: scenario.zupyWarState,
    activeBattle: null,
    appliedEventTicks: [],
    log: ['Maďari pod velením Árpáda vtrhli do Moravy a obsadili Devín. Radomír zvoláva vojsko.'],
  };

  return { ...state, warCampaign };
}

/** A front is an incomplete objective zupa currently occupied by an enemy army. */
export interface BattleFront {
  zupaId: string;
  enemyArmyId: string;
  terrain: Terrain;
}

export function getAvailableBattleFronts(state: GameState): BattleFront[] {
  const wc = state.warCampaign;
  if (!wc || wc.activeBattle || wc.war.result !== 'ongoing') return [];

  const fronts: BattleFront[] = [];
  for (const objective of wc.war.objectives) {
    if (objective.completed) continue;
    const enemy = wc.armies.find(
      (a) => a.locationZupaId === objective.zupaId && a.factionId === FACTION_IDS.hungarian
    );
    if (enemy) {
      fronts.push({
        zupaId: objective.zupaId,
        enemyArmyId: enemy.id,
        terrain: BATTLE_TERRAINS[objective.zupaId] ?? 'field',
      });
    }
  }
  return fronts;
}

/** Called once per tick (from tickEngine's processWarsPhase). Applies scripted
 * events, occupation looting, liberation/war-end checks and their rewards. */
export function processWarCampaignTick(state: GameState): GameState {
  const wc = state.warCampaign;
  if (!wc || wc.activeBattle || wc.war.result !== 'ongoing') return state;

  const engine = loadWarEngine(state, wc);
  const log: string[] = [];
  const appliedEventTicks = [...wc.appliedEventTicks];

  // Scripted events (raid, reinforcement)
  for (const event of getScenarioEvents()) {
    if (event.tick <= state.tick && !appliedEventTicks.includes(event.tick)) {
      applyScenarioEvent(event, engine);
      appliedEventTicks.push(event.tick);
      log.push(event.description);
    }
  }

  // Occupation looting (9.3): -1 loyalty / -50 gold per tick per occupied objective zupa
  let zupy = state.zupy;
  let resources = state.resources;
  for (const zs of engine.getAllZupaWarStates()) {
    if (zs.occupierFactionId === FACTION_IDS.hungarian && zupy[zs.zupaId]) {
      zupy = {
        ...zupy,
        [zs.zupaId]: {
          ...zupy[zs.zupaId],
          loyalty: Math.max(0, zupy[zs.zupaId].loyalty - SCENARIO_CONSTANTS.loyaltyPenaltyPerTick),
        },
      };
      resources = { ...resources, gold: Math.max(0, resources.gold - SCENARIO_CONSTANTS.goldPenaltyPerTick) };
    }
  }

  // Liberation checks + rewards
  const war = engine.getWar(wc.war.id)!;
  for (const objective of war.objectives) {
    if (objective.completed) continue;
    if (engine.checkZupaLiberated(objective.zupaId, wc.war.id)) {
      const reward = objective.zupaId === ZUPA_IDS.devin ? SCENARIO_REWARDS.liberatedDevin : SCENARIO_REWARDS.liberatedNitra;
      resources = {
        ...resources,
        gold: resources.gold + reward.gold,
        prestige: resources.prestige + reward.prestige,
      };
      if (zupy[objective.zupaId]) {
        zupy = {
          ...zupy,
          [objective.zupaId]: {
            ...zupy[objective.zupaId],
            loyalty: Math.min(100, zupy[objective.zupaId].loyalty + reward.loyaltyBonus),
          },
        };
      }
      log.push(`${zupy[objective.zupaId]?.name ?? objective.zupaId} oslobodená spod maďarskej nadvlády!`);
    }
  }

  // War end (victory / timeout defeat / army destroyed)
  const endCheck = engine.checkWarEnd(wc.war.id);
  if (endCheck.ended && endCheck.result === 'defeat') {
    resources = {
      ...resources,
      gold: Math.max(0, resources.gold + SCENARIO_REWARDS.warDefeat.gold),
      prestige: resources.prestige + SCENARIO_REWARDS.warDefeat.prestige,
    };
    log.push('Vojna s Maďarmi je prehratá - Nitra padla.');
  } else if (endCheck.ended && endCheck.result === 'victory') {
    log.push('Víťazstvo! Maďari boli vyhnaní z Moravy natrvalo.');
  }

  const warCampaign = extractCampaign(engine, { ...wc, appliedEventTicks });
  warCampaign.log = [...wc.log, ...log];

  return { ...state, zupy, resources, warCampaign };
}

/** Player triggers a battle on one of the available fronts. */
export function startBattleOnFront(state: GameState, front: BattleFront): GameState {
  const wc = state.warCampaign;
  if (!wc || wc.activeBattle) return state;

  const enemyArmy = wc.armies.find((a) => a.id === front.enemyArmyId);
  const moravianArmy = wc.armies.find((a) => a.id === MORAVIAN_ARMY_ID);
  if (!enemyArmy || !moravianArmy) return state;

  const battle = createBattle(
    wc.war.id,
    front.zupaId,
    front.terrain,
    enemyArmy.id, // Hungarians are always the battle attacker (they invaded)
    moravianArmy.id,
    state.tick
  );

  return {
    ...state,
    warCampaign: {
      ...wc,
      activeBattle: {
        battle,
        attackerArmy: enemyArmy,
        defenderArmy: moravianArmy,
        narrationLog: [],
      },
    },
  };
}

function buildPlaceholders(state: GameState, attacker: BattleArmy, defender: BattleArmy, zupaId: string): TemplatePlaceholders {
  return {
    attackerName: 'Maďari',
    defenderName: 'Moravania',
    attackerCommander: attacker.commander.name,
    defenderCommander: defender.commander.name,
    losses: 0,
    unitDominant: 'pechota',
    zupaName: state.zupy[zupaId]?.name ?? zupaId,
  };
}

function narratePhase(state: GameState, battle: Battle, attacker: BattleArmy, defender: BattleArmy, phaseIndex: number): string[] {
  const narrator = new Narrator(ALL_TEMPLATES, `${battle.seed}:narration:${phaseIndex}`);
  const placeholders = buildPlaceholders(state, attacker, defender, battle.zupaId);
  const lastLog = battle.phaseLogs[battle.phaseLogs.length - 1];
  if (!lastLog) return [];

  const sentences = narrator.narratePhase(lastLog, battle, placeholders);
  if (battle.currentPhase === 'finished') {
    if (battle.result === 'victory_rout') {
      sentences.push(...narrator.narrateSpecial('rout', battle, placeholders));
    } else if (battle.result === 'retreat') {
      sentences.push(...narrator.narrateSpecial('retreat', battle, placeholders));
    }
  }
  return sentences;
}

/** Advance the active battle by one phase. attackerAction is chosen by the AI
 * (Hungarians); defenderAction is the player's choice (Moravians). */
export function playBattlePhase(state: GameState, defenderAction: BattleAction): GameState {
  const wc = state.warCampaign;
  if (!wc || !wc.activeBattle) return state;

  const { battle, attackerArmy, defenderArmy } = wc.activeBattle;
  const originalAttacker = wc.armies.find((a) => a.id === battle.attackerArmyId) ?? attackerArmy;
  const originalDefender = wc.armies.find((a) => a.id === battle.defenderArmyId) ?? defenderArmy;

  const engine = new BattleEngine(battle, attackerArmy, defenderArmy, {
    attacker: originalAttacker.size,
    defender: originalDefender.size,
  });

  const attackerAction = engine.selectAIAction(true);
  const currentPhase = engine.getCurrentPhase();
  if (currentPhase === 'decision') {
    engine.executeDecisionPhase(attackerAction, defenderAction);
  } else if (currentPhase !== 'finished') {
    engine.executeNextPhase(attackerAction, defenderAction);
  }

  const updatedBattle = engine.getBattle();
  const armies = engine.getArmies();
  const sentences = narratePhase(state, updatedBattle, armies.attacker, armies.defender, updatedBattle.phaseLogs.length);
  const narrationLog = [...wc.activeBattle.narrationLog, ...sentences];

  if (!engine.isFinished()) {
    return {
      ...state,
      warCampaign: {
        ...wc,
        activeBattle: { battle: updatedBattle, attackerArmy: armies.attacker, defenderArmy: armies.defender, narrationLog },
      },
    };
  }

  return concludeBattle(state, wc, updatedBattle, armies.attacker, armies.defender, narrationLog);
}

/** Skip phase-by-phase play and resolve the whole engagement instantly. */
export function autoResolveBattleOnFront(state: GameState, front: BattleFront): GameState {
  const wc = state.warCampaign;
  if (!wc || wc.activeBattle) return state;

  const enemyArmy = wc.armies.find((a) => a.id === front.enemyArmyId);
  const moravianArmy = wc.armies.find((a) => a.id === MORAVIAN_ARMY_ID);
  if (!enemyArmy || !moravianArmy) return state;

  const { battle, result } = autoResolve(enemyArmy, moravianArmy, front.terrain, wc.war.id, front.zupaId, state.tick);

  const isAttackerWinner = result.winnerArmyId === enemyArmy.id;
  const updatedAttacker: BattleArmy = {
    ...enemyArmy,
    size: Math.max(0, enemyArmy.size - result.attackerLosses),
    morale: Math.max(0, Math.min(100, enemyArmy.morale + result.attackerMoraleChange)),
  };
  const updatedDefender: BattleArmy = {
    ...moravianArmy,
    size: Math.max(0, moravianArmy.size - result.defenderLosses),
    morale: Math.max(0, Math.min(100, moravianArmy.morale + result.defenderMoraleChange)),
  };

  const narrator = new Narrator(ALL_TEMPLATES, `${battle.seed}:auto`);
  const placeholders = buildPlaceholders(state, updatedAttacker, updatedDefender, front.zupaId);
  const narrationLog = narrator.narrateAutoResolve(battle, placeholders, isAttackerWinner ? 'attacker' : 'defender');

  return concludeBattle(state, wc, battle, updatedAttacker, updatedDefender, narrationLog);
}

function concludeBattle(
  state: GameState,
  wc: WarCampaignState,
  battle: Battle,
  attackerArmy: BattleArmy,
  defenderArmy: BattleArmy,
  narrationLog: string[]
): GameState {
  const armiesAfter = wc.armies.map((a) => {
    if (a.id === attackerArmy.id) return attackerArmy;
    if (a.id === defenderArmy.id) return defenderArmy;
    return a;
  });

  const engine = new WarEngine();
  engine.initialize([wc.war], armiesAfter, wc.zupyWarState, [battle], state.tick);

  const loserArmyId = battle.winnerArmyId === battle.attackerArmyId ? battle.defenderArmyId : battle.attackerArmyId;
  const loserArmy = engine.getArmy(loserArmyId);
  if (loserArmy && loserArmy.size <= 0) {
    engine.removeArmy(loserArmyId);
  } else if (loserArmy) {
    engine.retreatArmy(loserArmyId, wc.war.id);
  }
  engine.checkZupaLiberated(battle.zupaId, wc.war.id);
  const endCheck = engine.checkWarEnd(wc.war.id);

  let resources = state.resources;
  let zupy = state.zupy;
  const log = [...wc.log, ...narrationLog];

  const war = engine.getWar(wc.war.id)!;
  for (const objective of war.objectives) {
    if (!objective.completed) continue;
    const alreadyRewarded = wc.war.objectives.find((o) => o.zupaId === objective.zupaId)?.completed;
    if (alreadyRewarded) continue;
    const reward = objective.zupaId === ZUPA_IDS.devin ? SCENARIO_REWARDS.liberatedDevin : SCENARIO_REWARDS.liberatedNitra;
    resources = { ...resources, gold: resources.gold + reward.gold, prestige: resources.prestige + reward.prestige };
    if (zupy[objective.zupaId]) {
      zupy = { ...zupy, [objective.zupaId]: { ...zupy[objective.zupaId], loyalty: Math.min(100, zupy[objective.zupaId].loyalty + reward.loyaltyBonus) } };
    }
    log.push(`${zupy[objective.zupaId]?.name ?? objective.zupaId} oslobodená!`);
  }

  if (endCheck.ended && endCheck.result === 'defeat') {
    resources = { ...resources, gold: Math.max(0, resources.gold + SCENARIO_REWARDS.warDefeat.gold), prestige: resources.prestige + SCENARIO_REWARDS.warDefeat.prestige };
    log.push('Vojna s Maďarmi je prehratá.');
  } else if (endCheck.ended && endCheck.result === 'victory') {
    log.push('Víťazstvo nad Maďarmi!');
  }

  const warCampaign: WarCampaignState = {
    war,
    armies: engine.getAllArmies(),
    zupyWarState: engine.getAllZupaWarStates(),
    activeBattle: null,
    appliedEventTicks: wc.appliedEventTicks,
    log,
  };

  return { ...state, resources, zupy, warCampaign };
}

export { shouldAutoResolve };
