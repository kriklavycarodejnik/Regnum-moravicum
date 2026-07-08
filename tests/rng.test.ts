import { describe, it, expect, beforeEach } from 'vitest';
import { initRNG, rng, rngFloat, rngChance, getRNGState, setRNGState } from '../src/core/utils/rng';

describe('RNG Utilities', () => {
  describe('initRNG', () => {
    it('should initialize RNG with a seed', () => {
      initRNG('test-seed');
      const result = rng(0, 100);
      expect(result).toBeGreaterThanOrEqual(0);
      expect(result).toBeLessThanOrEqual(100);
    });

    it('should produce same sequence with same seed', () => {
      initRNG('same-seed');
      const first1 = rng(0, 100);
      const first2 = rng(0, 100);
      
      initRNG('same-seed');
      const second1 = rng(0, 100);
      const second2 = rng(0, 100);
      
      expect(first1).toBe(second1);
      expect(first2).toBe(second2);
    });

    it('should produce different sequence with different seed', () => {
      initRNG('seed-1');
      const fromSeed1 = rng(0, 100);
      
      initRNG('seed-2');
      const fromSeed2 = rng(0, 100);
      
      // With different seeds, values should likely be different
      // (though there's a tiny chance they could be the same)
      expect(fromSeed1).not.toBe(fromSeed2);
    });
  });

  describe('rng', () => {
    beforeEach(() => {
      initRNG('test-rng');
    });

    it('should return integer within range [min, max]', () => {
      const result = rng(10, 20);
      expect(result).toBeGreaterThanOrEqual(10);
      expect(result).toBeLessThanOrEqual(20);
      expect(Number.isInteger(result)).toBe(true);
    });

    it('should handle negative ranges', () => {
      const result = rng(-10, 10);
      expect(result).toBeGreaterThanOrEqual(-10);
      expect(result).toBeLessThanOrEqual(10);
    });

    it('should handle single value range', () => {
      const result = rng(42, 42);
      expect(result).toBe(42);
    });

    it('should be deterministic with same seed', () => {
      initRNG('deterministic');
      const sequence1 = Array.from({ length: 10 }, () => rng(0, 1000));
      
      initRNG('deterministic');
      const sequence2 = Array.from({ length: 10 }, () => rng(0, 1000));
      
      expect(sequence1).toEqual(sequence2);
    });
  });

  describe('rngFloat', () => {
    beforeEach(() => {
      initRNG('test-float');
    });

    it('should return float within range [min, max)', () => {
      const result = rngFloat(0, 1);
      expect(result).toBeGreaterThanOrEqual(0);
      expect(result).toBeLessThan(1);
    });

    it('should handle negative ranges', () => {
      const result = rngFloat(-1, 1);
      expect(result).toBeGreaterThanOrEqual(-1);
      expect(result).toBeLessThan(1);
    });

    it('should be deterministic with same seed', () => {
      initRNG('float-deterministic');
      const sequence1 = Array.from({ length: 10 }, () => rngFloat(0, 100));
      
      initRNG('float-deterministic');
      const sequence2 = Array.from({ length: 10 }, () => rngFloat(0, 100));
      
      expect(sequence1).toEqual(sequence2);
    });
  });

  describe('rngChance', () => {
    beforeEach(() => {
      initRNG('test-chance');
    });

    it('should return true for 100% chance', () => {
      expect(rngChance(1.0)).toBe(true);
    });

    it('should return false for 0% chance', () => {
      expect(rngChance(0.0)).toBe(false);
    });

    it('should return boolean', () => {
      const result = rngChance(0.5);
      expect(typeof result).toBe('boolean');
    });

    it('should be deterministic with same seed', () => {
      initRNG('chance-deterministic');
      const sequence1 = Array.from({ length: 10 }, () => rngChance(0.5));
      
      initRNG('chance-deterministic');
      const sequence2 = Array.from({ length: 10 }, () => rngChance(0.5));
      
      expect(sequence1).toEqual(sequence2);
    });

    it('should approximate expected probability over many trials', () => {
      initRNG('probability-test');
      const trials = 10000;
      const probability = 0.3;
      let successes = 0;

      for (let i = 0; i < trials; i++) {
        if (rngChance(probability)) {
          successes++;
        }
      }

      const actualProbability = successes / trials;
      // Allow 5% margin of error
      expect(actualProbability).toBeCloseTo(probability, 1);
    });
  });

  describe('getRNGState / setRNGState', () => {
    it('should save and restore RNG state', () => {
      initRNG('state-test');
      
      // Generate some values
      const beforeState = getRNGState();
      const value1 = rng(0, 100);
      const value2 = rng(0, 100);
      
      // Change state
      rng(0, 100);
      rng(0, 100);
      
      // Restore state
      setRNGState(beforeState!);
      
      // Should get same values
      expect(rng(0, 100)).toBe(value1);
      expect(rng(0, 100)).toBe(value2);
    });

    it('should return non-null state', () => {
      initRNG('state-test-2');
      const state = getRNGState();
      expect(state).not.toBeNull();
      expect(state).not.toBeUndefined();
    });
  });

  describe('Edge Cases', () => {
    it('should handle large ranges', () => {
      initRNG('large-range');
      const result = rng(0, Number.MAX_SAFE_INTEGER);
      expect(result).toBeGreaterThanOrEqual(0);
      expect(result).toBeLessThanOrEqual(Number.MAX_SAFE_INTEGER);
    });

    it('should handle negative to positive ranges', () => {
      initRNG('negative-positive');
      const result = rng(-1000, 1000);
      expect(result).toBeGreaterThanOrEqual(-1000);
      expect(result).toBeLessThanOrEqual(1000);
    });

    it('should handle very small probability', () => {
      initRNG('small-prob');
      // Even with very small probability, it should still work
      const result = rngChance(0.0001);
      expect(typeof result).toBe('boolean');
    });

    it('should handle probability close to 1', () => {
      initRNG('high-prob');
      const result = rngChance(0.9999);
      expect(typeof result).toBe('boolean');
    });
  });
});
