// Regnum Moravicum v2.1 - RNG Utility
import seedrandom from 'seedrandom';

type RNGState = seedrandom.State.Arc4;

let prng: seedrandom.StatefulPRNG<RNGState> | null = null;

/**
 * Initialize RNG with a seed
 */
export function initRNG(seed: string): void {
  prng = seedrandom(seed, { state: true });
}

/**
 * Generate a random integer between min and max (inclusive)
 */
export function rng(min: number, max: number): number {
  if (prng === null) {
    throw new Error('RNG not initialized. Call initRNG(seed) first.');
  }
  
  return Math.floor(prng() * (max - min + 1)) + min;
}

/**
 * Generate a random integer between 0 and max (exclusive)
 */
export function rngMax(max: number): number {
  if (prng === null) {
    throw new Error('RNG not initialized. Call initRNG(seed) first.');
  }
  
  return Math.floor(prng() * max);
}

/**
 * Generate 0 or 1 randomly
 */
export function rngBit(): number {
  if (prng === null) {
    throw new Error('RNG not initialized. Call initRNG(seed) first.');
  }
  
  return prng() >= 0.5 ? 1 : 0;
}

/**
 * Generate a random float between min and max
 */
export function rngFloat(min: number, max: number): number {
  if (prng === null) {
    throw new Error('RNG not initialized. Call initRNG(seed) first.');
  }
  return min + prng() * (max - min);
}

/**
 * Check if a random chance succeeds
 * @param probability - Probability between 0 and 1 (e.g., 0.3 = 30%)
 */
export function rngChance(probability: number): boolean {
  if (prng === null) {
    throw new Error('RNG not initialized. Call initRNG(seed) first.');
  }
  return prng() < probability;
}

/**
 * Get the current RNG state for saving
 */
export function getRNGState(): RNGState | null {
  return prng ? prng.state() : null;
}

/**
 * Restore RNG state from a saved state
 */
export function setRNGState(state: RNGState): void {
  prng = seedrandom('', { state });
}

export default {
  initRNG,
  rng,
  rngFloat,
  rngChance,
  getRNGState,
  setRNGState
};
