// Regnum Moravicum - Narrator

import type {
  Battle,
  PhaseLog,
} from '../types';
import type { NarrationTemplate, SlotType, Intensity, Outcome, TemplatePlaceholders } from './templates';
import { BattleRNG, type RNGState } from '../rng';
import { replacePlaceholders } from './templates';

// Narrator class - compositonal engine
export class Narrator {
  private templates: NarrationTemplate[];
  private seed: string;
  private rng: BattleRNG;
  private usedTemplateIds: string[] = [];
  private antiRepetitionWindow: number;

  constructor(templates: NarrationTemplate[], seed: string, antiRepetitionWindow: number = 5) {
    this.templates = [...templates];
    this.seed = seed;
    this.rng = new BattleRNG(seed);
    this.antiRepetitionWindow = antiRepetitionWindow;
  }

  // Set RNG state for save/load
  setRNGState(state: object): void {
    this.rng = new BattleRNG(this.seed, state as RNGState);
  }

  // Get RNG state for save
  getRNGState(): object {
    return this.rng.getState();
  }

  // Add templates
  addTemplates(templates: NarrationTemplate[]): void {
    this.templates = [...this.templates, ...templates];
  }

  // Get templates by slot
  private getTemplatesBySlot(slot: SlotType): NarrationTemplate[] {
    return this.templates.filter(t => t.slot === slot);
  }

  // Filter templates by conditions
  private filterTemplates(
    templates: NarrationTemplate[],
    conditions: Partial<NarrationTemplate['conditions']>
  ): NarrationTemplate[] {
    return templates.filter(template => {
      for (const [key, value] of Object.entries(conditions)) {
        if (value !== undefined && template.conditions[key as keyof NarrationTemplate['conditions']] !== value) {
          return false;
        }
      }
      return true;
    });
  }

  // Get available templates (excluding recently used ones)
  private getAvailableTemplates(
    slot: SlotType,
    conditions: Partial<NarrationTemplate['conditions']>
  ): NarrationTemplate[] {
    const slotTemplates = this.getTemplatesBySlot(slot);
    const filtered = this.filterTemplates(slotTemplates, conditions);
    
    // Exclude recently used templates
    return filtered.filter(t => !this.usedTemplateIds.includes(t.id));
  }

  // Select a random template
  private selectTemplate(
    slot: SlotType,
    conditions: Partial<NarrationTemplate['conditions']>
  ): NarrationTemplate | null {
    const available = this.getAvailableTemplates(slot, conditions);
    
    if (available.length === 0) {
      // Fallback: allow repetition if no other templates available
      const allTemplates = this.filterTemplates(this.getTemplatesBySlot(slot), conditions);
      if (allTemplates.length === 0) {
        return null;
      }
      return this.rng.weighted(
        allTemplates.map(t => ({ value: t, weight: t.weight }))
      );
    }

    const selected = this.rng.weighted(
      available.map(t => ({ value: t, weight: t.weight }))
    );
    
    // Add to used templates
    this.usedTemplateIds.push(selected.id);
    if (this.usedTemplateIds.length > this.antiRepetitionWindow) {
      this.usedTemplateIds.shift();
    }
    
    return selected;
  }

  // Narrate a phase
  narratePhase(
    phaseLog: PhaseLog,
    battle: Battle,
    placeholders: TemplatePlaceholders
  ): string[] {
    const sentences: string[] = [];
    const phase = phaseLog.phase;
    const attackerAction = phaseLog.attackerAction;
    const terrain = battle.terrain;
    
    // Determine intensity based on losses
    const totalLosses = phaseLog.attackerLosses + phaseLog.defenderLosses;
    const maxSize = Math.max(
      battle.phaseLogs.reduce((sum, log) => sum + log.attackerLosses, 0) + (phaseLog.attackerLosses || 0),
      battle.phaseLogs.reduce((sum, log) => sum + log.defenderLosses, 0) + (phaseLog.defenderLosses || 0)
    );
    const intensity: Intensity = totalLosses > maxSize * 0.05 ? 'heavy' : 'light';
    
    // Determine outcome
    let outcome: Outcome;
    if (phaseLog.attackerLosses < phaseLog.defenderLosses) {
      outcome = 'attacker_wins';
    } else if (phaseLog.attackerLosses > phaseLog.defenderLosses) {
      outcome = 'defender_wins';
    } else {
      outcome = 'draw';
    }

    // 1. Opener
    const opener = this.selectTemplate('opener', { phase });
    if (opener) {
      sentences.push(replacePlaceholders(opener.text, placeholders));
    }

    // 2. Action clause (based on attacker's action × outcome, §8)
    const actionTemplate = this.selectTemplate('action', {
      attackerAction,
      outcome,
    });
    if (actionTemplate) {
      sentences.push(replacePlaceholders(actionTemplate.text, placeholders));
    }

    // 3. Terrain detail
    const terrainTemplate = this.selectTemplate('terrain', { terrain });
    if (terrainTemplate) {
      sentences.push(replacePlaceholders(terrainTemplate.text, placeholders));
    }

    // 4. Outcome
    const outcomeTemplate = this.selectTemplate('outcome', {
      outcome,
      intensity,
    });
    if (outcomeTemplate) {
      sentences.push(replacePlaceholders(outcomeTemplate.text, placeholders));
    }

    // 5. Morale
    const moraleChange = phaseLog.attackerMoraleChange + phaseLog.defenderMoraleChange;
    const moraleDirection = moraleChange > 0 ? 'rise' : moraleChange < 0 ? 'fall' : 'fluctuate';
    const moraleTemplate = this.selectTemplate('morale', {
      outcome: moraleDirection as Outcome,
    });
    if (moraleTemplate) {
      sentences.push(replacePlaceholders(moraleTemplate.text, placeholders));
    }

    // Update phase log with narration
    phaseLog.narration = [...sentences];

    return sentences;
  }

  // Narrate special events (rout, retreat, etc.)
  narrateSpecial(
    specialType: import('./templates').SpecialType,
    _battle: Battle,
    placeholders: TemplatePlaceholders
  ): string[] {
    const sentences: string[] = [];
    
    const specialTemplate = this.selectTemplate('special', { special: specialType });
    if (specialTemplate) {
      sentences.push(replacePlaceholders(specialTemplate.text, placeholders));
    }
    
    return sentences;
  }

  // Narrate auto-resolve (shortened mode)
  narrateAutoResolve(
    _battle: Battle,
    placeholders: TemplatePlaceholders,
    winner: 'attacker' | 'defender'
  ): string[] {
    const sentences: string[] = [];
    const outcome: Outcome = winner === 'attacker' ? 'attacker_wins' : 'defender_wins';

    // Opener for auto-resolve (use decision phase opener)
    const opener = this.selectTemplate('opener', { phase: 'decision' });
    if (opener) {
      sentences.push(replacePlaceholders(opener.text, placeholders));
    }

    // Outcome
    const outcomeTemplate = this.selectTemplate('outcome', {
      outcome,
      intensity: 'heavy', // Auto-resolve is typically heavy
    });
    if (outcomeTemplate) {
      sentences.push(replacePlaceholders(outcomeTemplate.text, placeholders));
    }

    // Special (víťaz prenasleduje utekajúceho porazeného, viď §7/§9.2)
    const specialTemplate = this.selectTemplate('special', {
      special: 'pursue'
    });
    if (specialTemplate) {
      sentences.push(replacePlaceholders(specialTemplate.text, placeholders));
    }

    // Morale
    const moraleTemplate = this.selectTemplate('morale', {
      outcome: 'rise' as Outcome,
    });
    if (moraleTemplate) {
      sentences.push(replacePlaceholders(moraleTemplate.text, placeholders));
    }

    return sentences;
  }

  // Narrate full battle (all phases)
  narrateBattle(
    battle: Battle,
    placeholders: TemplatePlaceholders
  ): string[] {
    const allSentences: string[] = [];
    
    for (const phaseLog of battle.phaseLogs) {
      const sentences = this.narratePhase(phaseLog, battle, placeholders);
      allSentences.push(...sentences);
    }
    
    // Add special narration for battle result
    if (battle.result === 'victory_rout') {
      const specialSentences = this.narrateSpecial('rout', battle, placeholders);
      allSentences.push(...specialSentences);
    } else if (battle.result === 'retreat') {
      const specialSentences = this.narrateSpecial('retreat', battle, placeholders);
      allSentences.push(...specialSentences);
    }
    
    return allSentences;
  }

  // Reset used templates (for new battle)
  reset(): void {
    this.usedTemplateIds = [];
  }
}

// Create narrator with templates
export function createNarrator(
  templates: NarrationTemplate[],
  seed: string,
  antiRepetitionWindow: number = 5
): Narrator {
  return new Narrator(templates, seed, antiRepetitionWindow);
}
