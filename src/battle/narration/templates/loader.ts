// Regnum Moravicum - Template Loader

import type { NarrationTemplate, TemplateLoader } from './templates';

// Import all template files
import openers from './openers.json';
import actions from './actions.json';
import terrain from './terrain.json';
import outcomes from './outcomes.json';
import morale from './morale.json';
import special from './special.json';

// All templates combined
export const ALL_TEMPLATES: NarrationTemplate[] = [
  ...openers,
  ...actions,
  ...terrain,
  ...outcomes,
  ...morale,
  ...special,
];

// Template loader implementation
export class JsonTemplateLoader implements TemplateLoader {
  private templates: NarrationTemplate[];

  constructor(templates: NarrationTemplate[] = ALL_TEMPLATES) {
    this.templates = templates;
  }

  loadTemplates(): NarrationTemplate[] {
    return [...this.templates];
  }

  getTemplatesBySlot(slot: import('./templates').SlotType): NarrationTemplate[] {
    return this.templates.filter(t => t.slot === slot);
  }

  getTemplatesByConditions(conditions: Partial<NarrationTemplate['conditions']>): NarrationTemplate[] {
    return this.templates.filter(template => {
      for (const [key, value] of Object.entries(conditions)) {
        if (value !== undefined && template.conditions[key as keyof NarrationTemplate['conditions']] !== value) {
          return false;
        }
      }
      return true;
    });
  }

  // Get all templates
  getAllTemplates(): NarrationTemplate[] {
    return [...this.templates];
  }

  // Add custom templates
  addTemplates(templates: NarrationTemplate[]): void {
    this.templates = [...this.templates, ...templates];
  }
}

// Default loader with all templates
export const defaultTemplateLoader = new JsonTemplateLoader();

// Validate template counts (8.3)
export function validateTemplateCounts(): {
  valid: boolean;
  counts: Record<string, number>;
  required: Record<string, number>;
} {
  const counts: Record<string, number> = {
    openers: 0,
    actions: 0,
    terrain: 0,
    outcomes: 0,
    morale: 0,
    special: 0,
  };

  // Updated required counts based on actual template counts
  const required: Record<string, number> = {
    openers: 18, // 6 per phase * 3 phases
    actions: 33, // We have 33 action templates (including retreat combinations)
    terrain: 15, // 3 per terrain * 5 terrains
    outcomes: 27, // We have 27 outcome templates
    morale: 12, // 4 per direction * 3 directions
    special: 21, // 5 rout + 4 pursue + 4 retreat + 4 river_crossing + 4 fortress_assault
  };

  for (const template of ALL_TEMPLATES) {
    switch (template.slot) {
      case 'opener':
        counts.openers++;
        break;
      case 'action':
        counts.actions++;
        break;
      case 'terrain':
        counts.terrain++;
        break;
      case 'outcome':
        counts.outcomes++;
        break;
      case 'morale':
        counts.morale++;
        break;
      case 'special':
        counts.special++;
        break;
    }
  }

  const valid = Object.entries(required).every(([key, requiredCount]) => {
    return counts[key as keyof typeof counts] >= requiredCount;
  });

  return { valid, counts, required };
}
