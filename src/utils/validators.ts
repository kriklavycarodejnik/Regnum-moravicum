// Regnum Moravicum v2.1 - Validation Functions
import type { GameState, Region, Faction, Player, GameEvent, Decision } from '../types/gameTypes';
import type { SaveData } from '../types/saveTypes';

/**
 * Validate a game state object
 */
export function validateGameState(state: unknown): state is GameState {
  if (!state || typeof state !== 'object') return false;
  
  const requiredFields = ['turn', 'date', 'regions', 'factions', 'player', 'events', 'decisions', 'history'];
  
  for (const field of requiredFields) {
    if (!(field in state)) return false;
  }
  
  // Validate turn
  if (typeof (state as GameState).turn !== 'number' || (state as GameState).turn < 0) return false;
  
  // Validate date
  const date = (state as GameState).date;
  if (!date || typeof date !== 'object') return false;
  if (typeof date.year !== 'number' || typeof date.month !== 'number' || typeof date.day !== 'number') return false;
  if (date.month < 1 || date.month > 12) return false;
  if (date.day < 1 || date.day > 31) return false;
  
  // Validate regions
  const regions = (state as GameState).regions;
  if (!regions || typeof regions !== 'object') return false;
  for (const [, region] of Object.entries(regions)) {
    if (!validateRegion(region)) return false;
  }
  
  // Validate factions
  const factions = (state as GameState).factions;
  if (!factions || typeof factions !== 'object') return false;
  for (const [, faction] of Object.entries(factions)) {
    if (!validateFaction(faction)) return false;
  }
  
  // Validate player
  if (!validatePlayer((state as GameState).player)) return false;
  
  // Validate events
  const events = (state as GameState).events;
  if (!Array.isArray(events)) return false;
  for (const event of events) {
    if (!validateGameEvent(event)) return false;
  }
  
  // Validate decisions
  const decisions = (state as GameState).decisions;
  if (!Array.isArray(decisions)) return false;
  for (const decision of decisions) {
    if (!validateDecision(decision)) return false;
  }
  
  // Validate history
  const history = (state as GameState).history;
  if (!Array.isArray(history)) return false;
  
  return true;
}

/**
 * Validate a region object
 */
export function validateRegion(region: unknown): region is Region {
  if (!region || typeof region !== 'object') return false;
  
  const requiredFields = ['id', 'name', 'type', 'baseResources', 'currentResources', 'ownerId', 'development', 'loyalty', 'defense', 'population', 'connectedRegions'];
  
  for (const field of requiredFields) {
    if (!(field in region)) return false;
  }
  
  // Validate numeric fields
  if (typeof (region as Region).development !== 'number' || 
      typeof (region as Region).loyalty !== 'number' ||
      typeof (region as Region).defense !== 'number' ||
      typeof (region as Region).population !== 'number') return false;
  
  // Validate ranges
  if ((region as Region).development < 0 || (region as Region).development > 100) return false;
  if ((region as Region).loyalty < 0 || (region as Region).loyalty > 100) return false;
  if ((region as Region).defense < 0) return false;
  if ((region as Region).population < 0) return false;
  
  // Validate resources
  const baseResources = (region as Region).baseResources;
  const currentResources = (region as Region).currentResources;
  if (!baseResources || typeof baseResources !== 'object') return false;
  if (!currentResources || typeof currentResources !== 'object') return false;
  
  // Validate connected regions
  const connectedRegions = (region as Region).connectedRegions;
  if (!Array.isArray(connectedRegions)) return false;
  
  return true;
}

/**
 * Validate a faction object
 */
export function validateFaction(faction: unknown): faction is Faction {
  if (!faction || typeof faction !== 'object') return false;
  
  const requiredFields = ['id', 'name', 'type', 'strength', 'influence', 'wealth', 'relations', 'goals', 'traits'];
  
  for (const field of requiredFields) {
    if (!(field in faction)) return false;
  }
  
  // Validate numeric fields
  if (typeof (faction as Faction).strength !== 'number' ||
      typeof (faction as Faction).influence !== 'number' ||
      typeof (faction as Faction).wealth !== 'number') return false;
  
  // Validate ranges
  if ((faction as Faction).strength < 0 || (faction as Faction).strength > 100) return false;
  if ((faction as Faction).influence < 0 || (faction as Faction).influence > 100) return false;
  if ((faction as Faction).wealth < 0) return false;
  
  // Validate relations
  const relations = (faction as Faction).relations;
  if (!relations || typeof relations !== 'object') return false;
  for (const [, value] of Object.entries(relations)) {
    if (typeof value !== 'number' || value < -100 || value > 100) return false;
  }
  
  // Validate goals and traits
  const goals = (faction as Faction).goals;
  const traits = (faction as Faction).traits;
  if (!Array.isArray(goals) || !Array.isArray(traits)) return false;
  
  return true;
}

/**
 * Validate a player object
 */
export function validatePlayer(player: unknown): player is Player {
  if (!player || typeof player !== 'object') return false;
  
  const requiredFields = ['id', 'factionId', 'resources', 'achievements', 'decisions', 'reputation', 'piety', 'power'];
  
  for (const field of requiredFields) {
    if (!(field in player)) return false;
  }
  
  // Validate numeric fields
  if (typeof (player as Player).reputation !== 'number' ||
      typeof (player as Player).piety !== 'number' ||
      typeof (player as Player).power !== 'number') return false;
  
  // Validate ranges
  if ((player as Player).reputation < 0 || (player as Player).reputation > 100) return false;
  if ((player as Player).piety < 0 || (player as Player).piety > 100) return false;
  if ((player as Player).power < 0 || (player as Player).power > 100) return false;
  
  // Validate resources
  const resources = (player as Player).resources;
  if (!resources || typeof resources !== 'object') return false;
  
  // Validate achievements and decisions
  const achievements = (player as Player).achievements;
  const decisions = (player as Player).decisions;
  if (!Array.isArray(achievements) || !Array.isArray(decisions)) return false;
  
  return true;
}

/**
 * Validate a game event object
 */
export function validateGameEvent(event: unknown): event is GameEvent {
  if (!event || typeof event !== 'object') return false;
  
  const requiredFields = ['id', 'type', 'title', 'description', 'turn', 'priority', 'data', 'resolved', 'resolution'];
  
  for (const field of requiredFields) {
    if (!(field in event)) return false;
  }
  
  // Validate types
  if (typeof (event as GameEvent).id !== 'string') return false;
  if (typeof (event as GameEvent).type !== 'string') return false;
  if (typeof (event as GameEvent).title !== 'string') return false;
  if (typeof (event as GameEvent).description !== 'string') return false;
  if (typeof (event as GameEvent).turn !== 'number') return false;
  if (typeof (event as GameEvent).priority !== 'number') return false;
  if (typeof (event as GameEvent).resolved !== 'boolean') return false;
  
  // Validate data
  const data = (event as GameEvent).data;
  if (!data || typeof data !== 'object') return false;
  
  return true;
}

/**
 * Validate a decision object
 */
export function validateDecision(decision: unknown): decision is Decision {
  if (!decision || typeof decision !== 'object') return false;
  
  const requiredFields = ['id', 'type', 'title', 'description', 'choices', 'consequences', 'madeAtTurn', 'chosenIndex'];
  
  for (const field of requiredFields) {
    if (!(field in decision)) return false;
  }
  
  // Validate types
  if (typeof (decision as Decision).id !== 'string') return false;
  if (typeof (decision as Decision).type !== 'string') return false;
  if (typeof (decision as Decision).title !== 'string') return false;
  if (typeof (decision as Decision).description !== 'string') return false;
  if (typeof (decision as Decision).consequences !== 'string') return false;
  if (typeof (decision as Decision).madeAtTurn !== 'number') return false;
  
  // Validate choices
  const choices = (decision as Decision).choices;
  if (!Array.isArray(choices)) return false;
  
  for (const choice of choices) {
    if (!choice || typeof choice !== 'object') return false;
    if (typeof choice.text !== 'string') return false;
    if (!Array.isArray(choice.effects)) return false;
  }
  
  return true;
}

/**
 * Validate save data
 */
export function validateSaveData(data: unknown): data is SaveData {
  if (!data || typeof data !== 'object') return false;
  
  const requiredFields = ['version', 'timestamp', 'gameState', 'metadata'];
  
  for (const field of requiredFields) {
    if (!(field in data)) return false;
  }
  
  // Validate version
  if (typeof (data as SaveData).version !== 'string') return false;
  
  // Validate timestamp
  if (typeof (data as SaveData).timestamp !== 'number') return false;
  
  // Validate gameState
  if (!validateGameState((data as SaveData).gameState)) return false;
  
  // Validate metadata
  const metadata = (data as SaveData).metadata;
  if (!metadata || typeof metadata !== 'object') return false;
  
  return true;
}

/**
 * Check if a string is a valid seed
 */
export function isValidSeed(seed: string): boolean {
  return seed.length > 0 && seed.length <= 1000;
}

/**
 * Check if a number is within valid range
 */
export function isValidPercentage(value: number): boolean {
  return value >= 0 && value <= 100;
}

/**
 * Check if a string is a valid resource type
 */
export function isValidResourceType(resource: string): boolean {
  const validResources = ['gold', 'wood', 'stone', 'food', 'iron', 'faith', 'knowledge', 'influence'];
  return validResources.includes(resource);
}

/**
 * Check if a string is a valid region type
 */
export function isValidRegionType(type: string): boolean {
  const validTypes = ['plains', 'forest', 'mountains', 'river', 'city', 'village', 'fortress'];
  return validTypes.includes(type);
}

/**
 * Check if a string is a valid faction type
 */
export function isValidFactionType(type: string): boolean {
  const validTypes = ['player', 'noble', 'church', 'merchants', 'rebels', 'foreign'];
  return validTypes.includes(type);
}

/**
 * Check if a string is a valid event type
 */
export function isValidEventType(type: string): boolean {
  const validTypes = ['harvest', 'revolt', 'trade', 'diplomacy', 'disaster', 'blessing', 'quest'];
  return validTypes.includes(type);
}

/**
 * Check if a string is a valid decision type
 */
export function isValidDecisionType(type: string): boolean {
  const validTypes = ['tax', 'construction', 'diplomacy', 'military', 'religion', 'trade'];
  return validTypes.includes(type);
}
