// Regnum Moravicum v2.1 - Reproducible RNG Types

export interface RNGState {
  seed: string;
  counter: number;
}

export interface RNGConfig {
  seed: string;
  deterministic: boolean;
}

export type RNGValue = number;

export interface RNGInstance {
  getState(): RNGState;
  setState(state: RNGState): void;
  random(): RNGValue;
  randomInt(min: number, max: number): number;
  randomFloat(min: number, max: number): number;
  shuffle<T>(array: T[]): T[];
  choose<T>(items: T[]): T;
  weightedChoose<T>(items: T[], weights: number[]): T;
  reset(): void;
}

export interface RNGManager {
  createRNG(seed: string): RNGInstance;
  getGlobalRNG(): RNGInstance;
  setGlobalRNG(seed: string): void;
  withRNG<T>(seed: string, callback: () => T): T;
}
