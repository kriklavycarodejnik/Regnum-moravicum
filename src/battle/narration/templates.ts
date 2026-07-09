// Regnum Moravicum - Narration Templates Types

import type { BattlePhaseType, BattleAction, Terrain } from '../types';

export type Intensity = 'light' | 'heavy';
export type Outcome = 'attacker_wins' | 'defender_wins' | 'draw';
export type SpecialType = 
  | 'rout' 
  | 'pursue' 
  | 'retreat' 
  | 'river_crossing' 
  | 'fortress_assault';

export type SlotType = 'opener' | 'action' | 'terrain' | 'outcome' | 'morale' | 'special';

export interface NarrationTemplate {
  id: string;
  slot: SlotType;
  conditions: {
    phase?: BattlePhaseType;
    attackerAction?: BattleAction;
    defenderAction?: BattleAction;
    terrain?: Terrain;
    intensity?: Intensity;
    outcome?: Outcome;
    special?: SpecialType;
  };
  text: string;
  weight: number;
}

export interface TemplateLoader {
  loadTemplates(): NarrationTemplate[];
  getTemplatesBySlot(slot: SlotType): NarrationTemplate[];
  getTemplatesByConditions(conditions: Partial<NarrationTemplate['conditions']>): NarrationTemplate[];
}

// Template placeholder types
export interface TemplatePlaceholders {
  attackerName: string;
  defenderName: string;
  attackerCommander: string;
  defenderCommander: string;
  losses: number;
  unitDominant: string;
  zupaName: string;
}

// Replace placeholders in template text
export function replacePlaceholders(
  text: string,
  placeholders: Partial<TemplatePlaceholders>
): string {
  return text.replace(/\{(\w+)\}/g, (match, key) => {
    const value = placeholders[key as keyof TemplatePlaceholders];
    return value !== undefined ? String(value) : match;
  });
}
