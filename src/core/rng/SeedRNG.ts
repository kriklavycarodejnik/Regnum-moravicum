// Regnum Moravicum v2.1 - Reproducible RNG Implementation
import seedrandom from 'seedrandom';
import { v4 as uuidv4 } from 'uuid';
import type {
  RNGInstance,
  RNGState,
  RNGManager
} from '../../types/rngTypes';

/**
 * SeedRNG - Reproducible Random Number Generator
 * Uses seedrandom library for deterministic PRNG
 */
export class SeedRNG implements RNGInstance {
  private prng: seedrandom.PRNG;
  private state: RNGState;
  private initialSeed: string;

  constructor(seed: string) {
    this.initialSeed = seed;
    this.prng = seedrandom(seed);
    this.state = {
      seed,
      counter: 0
    };
  }

  getState(): RNGState {
    return { ...this.state };
  }

  setState(state: RNGState): void {
    this.state = { ...state };
    this.prng = seedrandom(`${state.seed}:${state.counter}`);
    // Fast-forward to the saved state
    for (let i = 0; i < state.counter; i++) {
      this.prng();
    }
  }

  random(): number {
    const value = this.prng();
    this.state.counter++;
    return value;
  }

  randomInt(min: number, max: number): number {
    const range = max - min + 1;
    const value = min + Math.floor(this.random() * range);
    return Math.min(value, max); // Ensure we don't exceed max due to floating point
  }

  randomFloat(min: number, max: number): number {
    return min + this.random() * (max - min);
  }

  shuffle<T>(array: T[]): T[] {
    const shuffled = [...array];
    // Fisher-Yates shuffle
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = this.randomInt(0, i);
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  choose<T>(items: T[]): T {
    if (items.length === 0) {
      throw new Error('Cannot choose from empty array');
    }
    return items[this.randomInt(0, items.length - 1)];
  }

  weightedChoose<T>(items: T[], weights: number[]): T {
    if (items.length === 0) {
      throw new Error('Cannot choose from empty array');
    }
    if (items.length !== weights.length) {
      throw new Error('Items and weights arrays must have the same length');
    }

    const totalWeight = weights.reduce((sum, w) => sum + w, 0);
    if (totalWeight <= 0) {
      throw new Error('Total weight must be positive');
    }

    let random = this.random() * totalWeight;
    for (let i = 0; i < items.length; i++) {
      random -= weights[i];
      if (random <= 0) {
        return items[i];
      }
    }
    return items[items.length - 1]; // Fallback
  }

  reset(): void {
    this.prng = seedrandom(this.initialSeed);
    this.state.counter = 0;
  }

  /**
   * Create a new RNG instance with a derived seed
   */
  fork(suffix: string = ''): SeedRNG {
    const newSeed = `${this.initialSeed}:${suffix}:${uuidv4()}`;
    return new SeedRNG(newSeed);
  }
}

/**
 * RNGManager - Manages multiple RNG instances
 */
export class RNGManagerImpl implements RNGManager {
  private globalRNG: SeedRNG;
  private rngCache: Map<string, SeedRNG> = new Map();

  constructor(initialSeed: string = 'regnum-moravicum-default') {
    this.globalRNG = new SeedRNG(initialSeed);
  }

  createRNG(seed: string): RNGInstance {
    if (this.rngCache.has(seed)) {
      return this.rngCache.get(seed)!;
    }
    const rng = new SeedRNG(seed);
    this.rngCache.set(seed, rng);
    return rng;
  }

  getGlobalRNG(): RNGInstance {
    return this.globalRNG;
  }

  setGlobalRNG(seed: string): void {
    this.globalRNG = new SeedRNG(seed);
  }

  withRNG<T>(seed: string, callback: () => T): T {
    const rng = new SeedRNG(seed);
    
    // Temporarily replace global RNG
    const originalGlobal = this.globalRNG;
    this.globalRNG = rng as SeedRNG;
    
    try {
      const result = callback();
      return result;
    } finally {
      // Restore original RNG
      this.globalRNG = originalGlobal;
    }
  }

  /**
   * Clear cached RNG instances
   */
  clearCache(): void {
    this.rngCache.clear();
  }

  /**
   * Generate a deterministic seed from a base seed and additional parameters
   */
  generateSeed(base: string, ...params: (string | number)[]): string {
    return `${base}:${params.join(':')}`;
  }
}

// Singleton instance
export const rngManager = new RNGManagerImpl();

export default SeedRNG;
