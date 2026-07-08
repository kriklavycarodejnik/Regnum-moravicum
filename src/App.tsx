// Regnum Moravicum v2.1 - Main Application Component
import { useState, useEffect, useRef } from 'react';
import { GameImpl } from './core/game/Game';
import type { GameState, Region, Faction } from './types/gameTypes';

function App() {
  const [seed, setSeed] = useState<string>('moravia-830');
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const [selectedFaction, setSelectedFaction] = useState<Faction | null>(null);
  const [messages, setMessages] = useState<string[]>([]);
  
  const gameRef = useRef<GameImpl | null>(null);

  // Initialize game
  useEffect(() => {
    const newGame = new GameImpl();
    newGame.initialize(seed);
    gameRef.current = newGame;
    setGameState(newGame.state);
    addMessage(`Game initialized with seed: ${seed}`);
    
    return () => {
      newGame.stop();
    };
  }, [seed]);

  // Update game state when game changes
  useEffect(() => {
    if (gameRef.current) {
      const interval = setInterval(() => {
        if (gameRef.current) {
          setGameState({ ...gameRef.current.state });
        }
      }, 100);
      
      return () => clearInterval(interval);
    }
  }, []);

  const addMessage = (message: string) => {
    setMessages(prev => [...prev, `[Turn ${gameState?.turn || 0}] ${message}`].slice(-10));
  };

  const handleStart = () => {
    if (gameRef.current) {
      gameRef.current.start();
      setIsRunning(true);
      addMessage('Game started');
    }
  };

  const handleStop = () => {
    if (gameRef.current) {
      gameRef.current.stop();
      setIsRunning(false);
      addMessage('Game stopped');
    }
  };

  const handleTick = () => {
    if (gameRef.current) {
      gameRef.current.loop.tick();
      addMessage('Turn advanced');
    }
  };

  const handleNewGame = () => {
    const newSeed = `moravia-${Date.now()}`;
    setSeed(newSeed);
    addMessage(`New game with seed: ${newSeed}`);
  };

  const handleSave = async () => {
    if (gameRef.current) {
      // Create a save-compatible state
      const stateForSave = {
        ...gameRef.current.state,
        rngState: gameRef.current.rng.getState()
      };
      await gameRef.current.saveManager.saveAutoSave(stateForSave as any);
      addMessage('Game auto-saved');
    }
  };

  const handleLoad = async () => {
    if (gameRef.current) {
      const savedState = await gameRef.current.saveManager.getAutoSave();
      if (savedState) {
        // Convert saved state to game state
        const gameState = {
          ...savedState,
          events: savedState.eventQueue || [],
          decisions: [],
          history: []
        };
        gameRef.current.loop.setState(gameState as any);
        addMessage('Game loaded from auto-save');
      } else {
        addMessage('No auto-save found');
      }
    }
  };

  const selectRegion = (regionId: string) => {
    if (gameState?.regions[regionId]) {
      setSelectedRegion(gameState.regions[regionId]);
      setSelectedFaction(null);
    }
  };

  const selectFaction = (factionId: string) => {
    if (gameState?.factions[factionId]) {
      setSelectedFaction(gameState.factions[factionId]);
      setSelectedRegion(null);
    }
  };

  if (!gameState) {
    return (
      <div className="app">
        <h1>Regnum Moravicum v2.1</h1>
        <p>Initializing...</p>
      </div>
    );
  }

  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                     'July', 'August', 'September', 'October', 'November', 'December'];
  const currentDate = `${monthNames[gameState.date.month - 1]} ${gameState.date.day}, ${gameState.date.year}`;

  return (
    <div className="app">
      <header className="header">
        <h1>Regnum Moravicum v2.1</h1>
        <p>Phase 0: Foundations</p>
      </header>

      <div className="game-info">
        <div className="turn-info">
          <h2>Turn {gameState.turn}</h2>
          <p>{currentDate}</p>
        </div>
        
        <div className="player-info">
          <h3>Player: {gameState.player.factionId || 'Rastislav\'s Court'}</h3>
          <div className="resources">
            {Object.entries(gameState.player.resources).map(([resource, amount]) => (
              <span key={resource} className="resource">
                {resource}: {amount}
              </span>
            ))}
          </div>
          <div className="stats">
            <span>Reputation: {gameState.player.reputation}</span>
            <span>Piety: {gameState.player.piety}</span>
            <span>Power: {gameState.player.power}</span>
          </div>
        </div>
      </div>

      <div className="controls">
        <button onClick={handleStart} disabled={isRunning}>
          Start
        </button>
        <button onClick={handleStop} disabled={!isRunning}>
          Stop
        </button>
        <button onClick={handleTick} disabled={isRunning}>
          Next Turn
        </button>
        <button onClick={handleNewGame}>
          New Game
        </button>
        <button onClick={handleSave}>
          Save
        </button>
        <button onClick={handleLoad}>
          Load
        </button>
      </div>

      <div className="game-content">
        <div className="map-panel">
          <h3>Regions ({Object.keys(gameState.regions).length})</h3>
          <div className="region-list">
            {Object.values(gameState.regions).map(region => (
              <div 
                key={region.id}
                className={`region ${selectedRegion?.id === region.id ? 'selected' : ''}`}
                onClick={() => selectRegion(region.id)}
              >
                <strong>{region.name}</strong> ({region.type})
                <div className="region-details">
                  <span>Owner: {region.ownerId || 'None'}</span>
                  <span>Dev: {region.development}%</span>
                  <span>Loyalty: {region.loyalty}%</span>
                  <span>Pop: {region.population}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="factions-panel">
          <h3>Factions ({Object.keys(gameState.factions).length})</h3>
          <div className="faction-list">
            {Object.values(gameState.factions).map(faction => (
              <div 
                key={faction.id}
                className={`faction ${selectedFaction?.id === faction.id ? 'selected' : ''}`}
                onClick={() => selectFaction(faction.id)}
              >
                <strong>{faction.name}</strong> ({faction.type})
                <div className="faction-details">
                  <span>Strength: {faction.strength}</span>
                  <span>Influence: {faction.influence}</span>
                  <span>Wealth: {faction.wealth}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="events-panel">
        <h3>Events ({gameState.events.length})</h3>
        <div className="event-list">
          {gameState.events.slice().reverse().map(event => (
            <div key={event.id} className={`event ${event.resolved ? 'resolved' : 'pending'}`}>
              <strong>{event.title}</strong>
              <p>{event.description}</p>
              <small>Turn {event.turn}, Priority: {event.priority}</small>
              {event.resolution && <p className="resolution">Resolved: {event.resolution}</p>}
            </div>
          ))}
        </div>
      </div>

      <div className="messages-panel">
        <h3>Messages</h3>
        <div className="messages">
          {messages.map((msg, index) => (
            <p key={index}>{msg}</p>
          ))}
        </div>
      </div>

      {selectedRegion && (
        <div className="modal">
          <div className="modal-content">
            <h2>{selectedRegion.name}</h2>
            <button onClick={() => setSelectedRegion(null)}>Close</button>
            <pre>{JSON.stringify(selectedRegion, null, 2)}</pre>
          </div>
        </div>
      )}

      {selectedFaction && (
        <div className="modal">
          <div className="modal-content">
            <h2>{selectedFaction.name}</h2>
            <button onClick={() => setSelectedFaction(null)}>Close</button>
            <pre>{JSON.stringify(selectedFaction, null, 2)}</pre>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
