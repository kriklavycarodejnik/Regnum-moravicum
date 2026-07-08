// Regnum Moravicum v2.1 - Game Loop Implementation
import type { GameDate, GameEvent, GameLoop, GameState, EventType } from '../../types/gameTypes';
import type { RNGInstance } from '../../types/rngTypes';

/**
 * Turn phases in order of execution
 */
export const TURN_PHASES = [
  'start',
  'income',
  'events',
  'decisions',
  'upkeep',
  'end'
] as const;

export type TurnPhaseName = typeof TURN_PHASES[number];

/**
 * GameLoop - Manages the monthly turn-based game loop
 */
export class GameLoopImpl implements GameLoop {
  private state: GameState;
  private rng: RNGInstance;
  private running: boolean;
  private paused: boolean;
  private intervalId: ReturnType<typeof setInterval> | null = null;
  private tickInterval: number;
  private phaseHandlers: Map<TurnPhaseName, () => void>;

  constructor(
    initialState: GameState,
    rng: RNGInstance,
    tickInterval: number = 1000
  ) {
    this.state = { ...initialState };
    this.rng = rng;
    this.tickInterval = tickInterval;
    this.running = false;
    this.paused = false;
    this.phaseHandlers = new Map();
    
    // Initialize phase handlers
    this.initializePhaseHandlers();
  }

  initializePhaseHandlers(): void {
    this.phaseHandlers.set('start', () => this.handleStartPhase());
    this.phaseHandlers.set('income', () => this.handleIncomePhase());
    this.phaseHandlers.set('events', () => this.handleEventsPhase());
    this.phaseHandlers.set('decisions', () => this.handleDecisionsPhase());
    this.phaseHandlers.set('upkeep', () => this.handleUpkeepPhase());
    this.phaseHandlers.set('end', () => this.handleEndPhase());
  }

  start(): void {
    if (this.running) return;
    
    this.running = true;
    this.paused = false;
    
    // Start the game loop
    this.intervalId = setInterval(() => {
      if (!this.paused) {
        this.tick();
      }
    }, this.tickInterval);
    
    console.log('Game loop started');
  }

  stop(): void {
    if (!this.running) return;
    
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    
    this.running = false;
    this.paused = false;
    
    console.log('Game loop stopped');
  }

  pause(): void {
    this.paused = true;
    console.log('Game loop paused');
  }

  resume(): void {
    this.paused = false;
    console.log('Game loop resumed');
  }

  tick(): void {
    // Process one turn
    this.advanceTurn();
  }

  advanceTurn(): void {
    console.log(`Advancing to turn ${this.state.turn + 1}`);
    
    // Process each phase in order
    for (const phase of TURN_PHASES) {
      const handler = this.phaseHandlers.get(phase);
      if (handler) {
        handler();
      }
    }
    
    // Increment turn counter
    this.state.turn++;
    this.advanceDate();
    
    // Add to history
    this.addToHistory();
  }

  processEvents(): void {
    // Process all pending events
    const unresolvedEvents = this.state.events.filter(e => !e.resolved);
    
    // Sort by priority (higher first) and then by turn
    unresolvedEvents.sort((a, b) => {
      if (b.priority !== a.priority) {
        return b.priority - a.priority;
      }
      return a.turn - b.turn;
    });
    
    for (const event of unresolvedEvents) {
      this.resolveEvent(event);
    }
  }

  getCurrentTurn(): number {
    return this.state.turn;
  }

  getCurrentDate(): GameDate {
    return { ...this.state.date };
  }

  isRunning(): boolean {
    return this.running && !this.paused;
  }

  // Phase handlers
  private handleStartPhase(): void {
    console.log(`Turn ${this.state.turn + 1} - Start phase`);
    // Initialize turn-specific data
  }

  private handleIncomePhase(): void {
    console.log(`Turn ${this.state.turn + 1} - Income phase`);
    // Process resource income for all regions and factions
    this.processResourceIncome();
  }

  private handleEventsPhase(): void {
    console.log(`Turn ${this.state.turn + 1} - Events phase`);
    // Generate and process random events
    this.generateRandomEvents();
    this.processEvents();
  }

  private handleDecisionsPhase(): void {
    console.log(`Turn ${this.state.turn + 1} - Decisions phase`);
    // Process player decisions
  }

  private handleUpkeepPhase(): void {
    console.log(`Turn ${this.state.turn + 1} - Upkeep phase`);
    // Process upkeep costs
    this.processUpkeep();
  }

  private handleEndPhase(): void {
    console.log(`Turn ${this.state.turn + 1} - End phase`);
    // Clean up and finalize turn
  }

  // Helper methods
  private processResourceIncome(): void {
    // For each region, add base resources to owner
    for (const region of Object.values(this.state.regions)) {
      if (region.ownerId && this.state.factions[region.ownerId]) {
        // Add resources to faction (simplified for now)
        for (const [resource, amount] of Object.entries(region.baseResources)) {
          // In a real implementation, we'd add these to the faction's resources
          console.log(`Region ${region.name} generates ${amount} ${resource}`);
        }
      }
    }
  }

  private generateRandomEvents(): void {
    // Generate random events based on game state
    const eventTypes: EventType[] = ['harvest', 'revolt', 'trade', 'diplomacy', 'disaster', 'blessing'];
    
    // Chance for events based on turn and other factors
    const eventCount = this.rng.randomInt(0, 2);
    
    for (let i = 0; i < eventCount; i++) {
      const eventType = this.rng.choose(eventTypes);
      const priority = this.rng.randomInt(1, 5);
      
      const event: GameEvent = {
        id: `event_${this.state.turn}_${i}`,
        type: eventType,
        title: `Random ${eventType} event`,
        description: `A ${eventType} event occurred`,
        turn: this.state.turn + 1,
        priority,
        data: {},
        resolved: false,
        resolution: null
      };
      
      this.state.events.push(event);
      console.log(`Generated event: ${eventType}`);
    }
  }

  private resolveEvent(event: GameEvent): void {
    console.log(`Resolving event: ${event.type}`);
    
    // Mark as resolved
    event.resolved = true;
    event.resolution = `Resolved at turn ${this.state.turn + 1}`;
    
    // In a real implementation, apply event effects here
  }

  private processUpkeep(): void {
    // Process upkeep costs for factions
    for (const faction of Object.values(this.state.factions)) {
      // Simplified: reduce wealth based on strength
      const upkeepCost = Math.floor(faction.strength / 10);
      faction.wealth = Math.max(0, faction.wealth - upkeepCost);
      console.log(`Faction ${faction.name} pays ${upkeepCost} gold upkeep`);
    }
  }

  private advanceDate(): void {
    // Advance date by one month
    const current = this.state.date;
    
    // Simple month advancement
    current.month++;
    if (current.month > 12) {
      current.month = 1;
      current.year++;
    }
    
    // Keep day within valid range
    current.day = Math.min(current.day, this.getDaysInMonth(current.month, current.year));
  }

  private getDaysInMonth(month: number, year: number): number {
    const daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    
    // Handle February in leap years
    if (month === 2) {
      const isLeapYear = (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0);
      return isLeapYear ? 29 : 28;
    }
    
    return daysInMonth[month - 1];
  }

  private addToHistory(): void {
    const currentTurn = this.state.turn;
    const currentDate = { ...this.state.date };
    
    // Get events and decisions from this turn
    const turnEvents = this.state.events
      .filter(e => e.turn === currentTurn + 1)
      .map(e => e.type);
    
    const turnDecisions = this.state.decisions
      .filter(d => d.madeAtTurn === currentTurn + 1)
      .map(d => d.type);
    
    this.state.history.push({
      turn: currentTurn + 1,
      date: currentDate,
      events: turnEvents as any[],
      decisions: turnDecisions as any[],
      summary: `Turn ${currentTurn + 1} completed`
    });
  }

  // Getters and setters
  getState(): GameState {
    return this.state;
  }

  setState(state: GameState): void {
    this.state = { ...state };
  }

  getRNG(): RNGInstance {
    return this.rng;
  }

  setRNG(rng: RNGInstance): void {
    this.rng = rng;
  }

  setTickInterval(interval: number): void {
    this.tickInterval = interval;
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = setInterval(() => {
        if (!this.paused) {
          this.tick();
        }
      }, this.tickInterval);
    }
  }
}

export default GameLoopImpl;
