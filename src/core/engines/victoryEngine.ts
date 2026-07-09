// Regnum Moravicum v2.1 - Victory Engine (Phase 3 M5)
import type { GameState } from '../types/gameState';

const VICTORY_YEAR = 1000; // ~100-year reign for the "prežitie" survival scenario
const RELIGION_DECAY_PER_TICK = 2;

/**
 * Religion axis (-100 Rím .. +100 Konštantínopol) slowly drifts back toward
 * neutral, mirroring the mood-decay pattern used for factions/armies.
 */
export function decayReligionAxis(state: GameState): GameState {
  const { value } = state.religion;
  if (value === 0) return state;

  const next = value > 0 ? Math.max(0, value - RELIGION_DECAY_PER_TICK) : Math.min(0, value + RELIGION_DECAY_PER_TICK);
  return { ...state, religion: { value: next } };
}

function averageZupaLoyalty(state: GameState): number {
  const zupy = Object.values(state.zupy);
  if (zupy.length === 0) return 0;
  return zupy.reduce((sum, z) => sum + z.loyalty, 0) / zupy.length;
}

/**
 * Passive prestige trickle tied to how well-governed the realm is (average
 * zupa loyalty). Keeps player.prestige (the displayed figure) and
 * resources.prestige in sync.
 */
export function growPrestige(state: GameState): GameState {
  const delta = Math.floor(averageZupaLoyalty(state) / 25);
  if (delta <= 0) return state;

  return {
    ...state,
    player: { ...state.player, prestige: state.player.prestige + delta },
    resources: { ...state.resources, prestige: state.resources.prestige + delta },
  };
}

function dynastyZupaCount(state: GameState): number {
  const dynastyNobleIds = new Set(state.nobles.filter((n) => n.familyId === state.player.dynasty).map((n) => n.id));
  return Object.values(state.zupy).filter((z) => dynastyNobleIds.has(z.owner)).length;
}

function isDynastyExtinct(state: GameState): boolean {
  return !state.nobles.some((n) => n.familyId === state.player.dynasty && n.status === 'alive');
}

/**
 * Check defeat (dynasty extinction, total loss of territory) and victory
 * (surviving to the target year while still ruling at least one zupa)
 * conditions. Once gameOver is set, this is a no-op.
 */
export function checkVictoryConditions(state: GameState): GameState {
  if (state.gameOver) return state;

  if (isDynastyExtinct(state)) {
    return {
      ...state,
      gameOver: true,
      gameOverVictory: false,
      gameOverReason: 'Dynastia vymrela bez žijúceho dediča. Vláda nad Moravou sa skončila.',
    };
  }

  if (dynastyZupaCount(state) === 0) {
    return {
      ...state,
      gameOver: true,
      gameOverVictory: false,
      gameOverReason: 'Dynastia stratila poslednú župu. Kráľovstvo zaniklo.',
    };
  }

  if (state.year >= VICTORY_YEAR) {
    return {
      ...state,
      gameOver: true,
      gameOverVictory: true,
      gameOverReason: `Dynastia úspešne vládla Morave až do roku ${state.year}. Kráľovstvo prežilo!`,
    };
  }

  return state;
}

export default {
  decayReligionAxis,
  growPrestige,
  checkVictoryConditions,
};
