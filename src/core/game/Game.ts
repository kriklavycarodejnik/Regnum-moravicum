// Regnum Moravicum v2.1 - Main Game Implementation
import { SeedRNG } from '../rng/SeedRNG';
import { GameLoopImpl } from './GameLoop';
import { InMemorySaveManager } from '../save/SaveSystem';
import type {
  Game,
  GameConfig,
  GameState,
  Region,
  Faction,
  Player,
  GameEvent,
  Decision,
  ResourcePool
} from '../../types/gameTypes';
import type { RNGInstance } from '../../types/rngTypes';
import type { SaveManager } from '../../types/saveTypes';

/**
 * Default game configuration
 */
const DEFAULT_CONFIG: GameConfig = {
  version: '2.1.0',
  phase: 0,
  startDate: { year: 830, month: 1, day: 1 },
  monthsPerTurn: 1,
  maxTurns: null,
  difficulty: 'normal'
};

/**
 * Default initial game state
 */
function createInitialState(config: GameConfig): GameState {
  return {
    turn: 0,
    date: { ...config.startDate },
    regions: {},
    factions: {},
    player: {
      id: 'player_1',
      factionId: '',
      resources: { gold: 100, wood: 50, stone: 50, food: 100, iron: 20, faith: 30, knowledge: 10, influence: 20 },
      achievements: [],
      decisions: [],
      reputation: 50,
      piety: 50,
      power: 50
    },
    events: [],
    decisions: [],
    history: []
  };
}

/**
 * Main Game class - Core game management
 */
export class GameImpl implements Game {
  config: GameConfig;
  state: GameState;
  loop: GameLoopImpl;
  rng: RNGInstance;
  saveManager: SaveManager;

  constructor(config: Partial<GameConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.state = createInitialState(this.config);
    this.rng = new SeedRNG('default-seed');
    this.loop = new GameLoopImpl(this.state, this.rng);
    this.saveManager = new InMemorySaveManager();
  }

  initialize(seed: string): void {
    // Reset game with new seed
    this.rng = new SeedRNG(seed);
    this.state = createInitialState(this.config);
    this.loop = new GameLoopImpl(this.state, this.rng);
    
    // Initialize game world
    this.initializeWorld();
    
    console.log(`Game initialized with seed: ${seed}`);
  }

  start(): void {
    this.loop.start();
  }

  stop(): void {
    this.loop.stop();
  }

  getRegion(id: string): Region | null {
    return this.state.regions[id] || null;
  }

  getFaction(id: string): Faction | null {
    return this.state.factions[id] || null;
  }

  getPlayer(): Player {
    return this.state.player;
  }

  addEvent(event: GameEvent): void {
    this.state.events.push(event);
  }

  resolveEvent(eventId: string, resolution: string): void {
    const event = this.state.events.find(e => e.id === eventId);
    if (event) {
      event.resolved = true;
      event.resolution = resolution;
    }
  }

  makeDecision(decision: Decision, choiceIndex: number): void {
    if (choiceIndex < 0 || choiceIndex >= decision.choices.length) {
      throw new Error('Invalid choice index');
    }

    decision.chosenIndex = choiceIndex;
    decision.madeAtTurn = this.state.turn;
    
    // Apply effects
    const choice = decision.choices[choiceIndex];
    for (const effect of choice.effects) {
      this.applyEffect(effect);
    }
    
    this.state.decisions.push(decision);
  }

  /**
   * Initialize the game world with starting regions and factions
   */
  private initializeWorld(): void {
    // Create starting regions
    const regions = this.createStartingRegions();
    const factions = this.createStartingFactions();
    
    this.state.regions = regions;
    this.state.factions = factions;
    
    // Assign player to a starting faction
    const playerFaction = Object.values(factions)[0];
    if (playerFaction) {
      this.state.player.factionId = playerFaction.id;
    }
    
    // Assign regions to factions
    this.assignRegionsToFactions();
  }

  private createStartingRegions(): Record<string, Region> {
    const regions: Record<string, Region> = {};
    
    // Create Moravia regions
    const moraviaRegions = [
      { id: 'moravia_brno', name: 'Brno', type: 'city' as const, baseResources: { gold: 10, wood: 5, stone: 5, food: 15 } },
      { id: 'moravia_olomouc', name: 'Olomouc', type: 'city' as const, baseResources: { gold: 8, wood: 3, stone: 4, food: 12 } },
      { id: 'moravia_plains', name: 'Moravian Plains', type: 'plains' as const, baseResources: { gold: 2, wood: 2, stone: 1, food: 8 } },
      { id: 'moravia_forest', name: 'Moravian Forest', type: 'forest' as const, baseResources: { gold: 1, wood: 8, stone: 1, food: 3 } },
      { id: 'moravia_mountains', name: 'Carpathian Foothills', type: 'mountains' as const, baseResources: { gold: 1, wood: 2, stone: 6, food: 1 } },
      { id: 'moravia_river', name: 'Morava River', type: 'river' as const, baseResources: { gold: 3, wood: 2, stone: 2, food: 6 } }
    ];
    
    moraviaRegions.forEach(regionData => {
      regions[regionData.id] = {
        id: regionData.id,
        name: regionData.name,
        type: regionData.type,
        baseResources: { ...regionData.baseResources },
        currentResources: { ...regionData.baseResources },
        ownerId: null,
        development: 30,
        loyalty: 70,
        defense: 10,
        population: this.rng.randomInt(1000, 5000),
        connectedRegions: []
      };
    });
    
    // Connect regions
    this.connectRegions(regions);
    
    return regions;
  }

  private createStartingFactions(): Record<string, Faction> {
    const factions: Record<string, Faction> = {};
    
    // Create starting factions
    const factionData = [
      { id: 'faction_player', name: 'Rastislav\'s Court', type: 'player' as const, strength: 60, influence: 50, wealth: 200 },
      { id: 'faction_nobles', name: 'Moravian Nobles', type: 'noble' as const, strength: 40, influence: 60, wealth: 150 },
      { id: 'faction_church', name: 'Great Moravian Church', type: 'church' as const, strength: 30, influence: 70, wealth: 100 },
      { id: 'faction_merchants', name: 'Frankish Merchants', type: 'merchants' as const, strength: 20, influence: 40, wealth: 300 },
      { id: 'faction_rebels', name: 'Pagan Rebels', type: 'rebels' as const, strength: 25, influence: 20, wealth: 50 }
    ];
    
    factionData.forEach(data => {
      factions[data.id] = {
        id: data.id,
        name: data.name,
        type: data.type,
        strength: data.strength,
        influence: data.influence,
        wealth: data.wealth,
        relations: {},
        goals: [],
        traits: []
      };
    });
    
    // Initialize relations
    this.initializeFactionRelations(factions);
    
    return factions;
  }

  private connectRegions(regions: Record<string, Region>): void {
    const regionIds = Object.keys(regions);
    
    // Connect each region to 2-3 others
    for (const regionId of regionIds) {
      const region = regions[regionId];
      const otherRegions = regionIds.filter(id => id !== regionId);
      const connections = this.rng.shuffle(otherRegions).slice(0, this.rng.randomInt(2, 3));
      region.connectedRegions = connections;
    }
  }

  private assignRegionsToFactions(): void {
    const regionIds = Object.keys(this.state.regions);
    const factionIds = Object.keys(this.state.factions);
    
    // Assign each region to a random faction
    for (const regionId of regionIds) {
      const region = this.state.regions[regionId];
      const factionId = this.rng.choose(factionIds);
      region.ownerId = factionId;
    }
    
    // Ensure player faction has at least one region
    const playerFactionId = this.state.player.factionId;
    if (playerFactionId && !regionIds.some(id => this.state.regions[id].ownerId === playerFactionId)) {
      const randomRegionId = this.rng.choose(regionIds);
      this.state.regions[randomRegionId].ownerId = playerFactionId;
    }
  }

  private initializeFactionRelations(factions: Record<string, Faction>): void {
    const factionIds = Object.keys(factions);
    
    for (const factionId of factionIds) {
      const faction = factions[factionId];
      
      for (const otherId of factionIds) {
        if (otherId !== factionId) {
          // Random relation between -50 and 50
          faction.relations[otherId] = this.rng.randomInt(-50, 50);
        }
      }
    }
  }

  private applyEffect(effect: any): void {
    // Implement effect application based on effect type
    console.log(`Applying effect: ${effect.type} to ${effect.target}`);
    
    // This will be expanded in later phases
    switch (effect.type) {
      case 'add_resource':
        if (this.state.player.resources[effect.target as keyof ResourcePool] !== undefined) {
          const value = typeof effect.value === 'number' ? effect.value : 0;
          this.state.player.resources[effect.target as keyof ResourcePool] += value;
        }
        break;
      case 'modify_reputation':
        this.state.player.reputation = Math.max(0, Math.min(100, 
          this.state.player.reputation + (typeof effect.value === 'number' ? effect.value : 0)));
        break;
      default:
        console.warn(`Unknown effect type: ${effect.type}`);
    }
  }

  /**
   * Get current game date as string
   */
  getCurrentDateString(): string {
    const date = this.state.date;
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                       'July', 'August', 'September', 'October', 'November', 'December'];
    return `${monthNames[date.month - 1]} ${date.day}, ${date.year}`;
  }

  /**
   * Get game summary
   */
  getSummary(): string {
    return `Regnum Moravicum v2.1 - Turn ${this.state.turn}, ${this.getCurrentDateString()}`;
  }
}

export default GameImpl;
