// Regnum Moravicum - Battle RNG

import seedrandom from 'seedrandom';

export class BattleRNG {
  private rng: seedrandom.StatefulPRNG<seedrandom.State.Arc4>;

  constructor(seed: string, state?: object) {
    this.rng = seedrandom(seed, { state: state ?? true });
  }

  next(): number {
    return this.rng();
  }

  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }

  int(min: number, max: number): number {
    return Math.floor(this.range(min, max + 1));
  }

  weighted<T>(items: { value: T; weight: number }[]): T {
    const totalWeight = items.reduce((sum, item) => sum + item.weight, 0);
    if (totalWeight <= 0) {
      throw new Error('Total weight must be positive');
    }

    let random = this.next() * totalWeight;
    for (const item of items) {
      random -= item.weight;
      if (random <= 0) {
        return item.value;
      }
    }
    return items[items.length - 1].value; // Fallback
  }

  getState(): object {
    return this.rng.state();
  }

  // Choose a random element from array
  choose<T>(items: T[]): T {
    if (items.length === 0) {
      throw new Error('Cannot choose from empty array');
    }
    return items[this.int(0, items.length - 1)];
  }

  // Shuffle array using Fisher-Yates
  shuffle<T>(array: T[]): T[] {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = this.int(0, i);
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }
}
