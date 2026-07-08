// Regnum Moravicum v2.1 - Helper Functions
import type { ResourcePool, GameDate } from '../types/gameTypes';

/**
 * Deep clone an object
 */
export function deepClone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}

/**
 * Merge multiple objects deeply
 */
export function deepMerge<T extends Record<string, unknown>>(target: T, ...sources: Partial<T>[]): T {
  const result = { ...target };
  
  for (const source of sources) {
    for (const key in source) {
      if (source[key] !== null && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        if (result[key] && typeof result[key] === 'object') {
          result[key] = deepMerge(result[key] as Record<string, unknown>, source[key] as Record<string, unknown>) as T[Extract<keyof T, string>];
        } else {
          result[key] = deepClone(source[key]) as T[Extract<keyof T, string>];
        }
      } else {
        result[key] = source[key] as T[Extract<keyof T, string>];
      }
    }
  }
  
  return result;
}

/**
 * Generate a unique ID
 */
export function generateId(prefix: string = 'id'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Format a game date as string
 */
export function formatDate(date: GameDate): string {
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return `${monthNames[date.month - 1]} ${date.day}, ${date.year}`;
}

/**
 * Format a number with commas
 */
export function formatNumber(num: number): string {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Format a resource amount with icon/emoji
 */
export function formatResource(resource: string, amount: number): string {
  const resourceIcons: Record<string, string> = {
    gold: '💰',
    wood: '🪵',
    stone: '🪨',
    food: '🍞',
    iron: '⚔️',
    faith: '⛪',
    knowledge: '📜',
    influence: '👑'
  };
  
  const icon = resourceIcons[resource] || '❓';
  return `${icon} ${formatNumber(amount)}`;
}

/**
 * Format resources as a string
 */
export function formatResources(resources: ResourcePool): string {
  return Object.entries(resources)
    .map(([resource, amount]) => formatResource(resource, amount))
    .join(', ');
}

/**
 * Clamp a value between min and max
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/**
 * Linear interpolation
 */
export function lerp(start: number, end: number, t: number): number {
  return start + (end - start) * t;
}

/**
 * Inverse linear interpolation
 */
export function inverseLerp(start: number, end: number, value: number): number {
  if (start === end) return 0;
  return (value - start) / (end - start);
}

/**
 * Remap a value from one range to another
 */
export function remap(value: number, fromMin: number, fromMax: number, toMin: number, toMax: number): number {
  const t = inverseLerp(fromMin, fromMax, value);
  return lerp(toMin, toMax, t);
}

/**
 * Check if a value is within a range
 */
export function isInRange(value: number, min: number, max: number): boolean {
  return value >= min && value <= max;
}

/**
 * Get a random element from an array
 */
export function randomElement<T>(array: T[]): T {
  return array[Math.floor(Math.random() * array.length)];
}

/**
 * Get multiple random elements from an array without repetition
 */
export function randomElements<T>(array: T[], count: number): T[] {
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

/**
 * Shuffle an array (Fisher-Yates)
 */
export function shuffleArray<T>(array: T[]): T[] {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

/**
 * Weighted random selection
 */
export function weightedRandom<T>(items: T[], weights: number[]): T {
  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  let random = Math.random() * totalWeight;
  
  for (let i = 0; i < items.length; i++) {
    random -= weights[i];
    if (random <= 0) {
      return items[i];
    }
  }
  return items[items.length - 1];
}

/**
 * Debounce a function
 */
export function debounce<T extends (...args: unknown[]) => unknown>(fn: T, delay: number): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout>;
  return (...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
}

/**
 * Throttle a function
 */
export function throttle<T extends (...args: unknown[]) => unknown>(fn: T, limit: number): (...args: Parameters<T>) => void {
  let inThrottle = false;
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      fn(...args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

/**
 * Sleep for a specified duration
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry a function with exponential backoff
 */
export async function retry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 3,
  delay: number = 1000,
  backoff: number = 2
): Promise<T> {
  let attempt = 0;
  
  while (attempt < maxAttempts) {
    try {
      return await fn();
    } catch (error) {
      attempt++;
      if (attempt >= maxAttempts) {
        throw error;
      }
      await sleep(delay * Math.pow(backoff, attempt - 1));
    }
  }
  
  throw new Error('Max retries exceeded');
}

/**
 * Format a percentage value
 */
export function formatPercentage(value: number, decimals: number = 0): string {
  return `${(value * 100).toFixed(decimals)}%`;
}

/**
 * Format a signed number (+/-)
 */
export function formatSigned(value: number): string {
  return value >= 0 ? `+${value}` : value.toString();
}

/**
 * Get ordinal suffix for a number
 */
export function getOrdinalSuffix(num: number): string {
  const j = num % 10, k = num % 100;
  if (j === 1 && k !== 11) return 'st';
  if (j === 2 && k !== 12) return 'nd';
  if (j === 3 && k !== 13) return 'rd';
  return 'th';
}

/**
 * Format a turn number with ordinal
 */
export function formatTurn(turn: number): string {
  return `Turn ${turn}${getOrdinalSuffix(turn)}`;
}
