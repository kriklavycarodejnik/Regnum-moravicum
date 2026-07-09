// Regnum Moravicum v2.1 - Main App Component
import { useState, useEffect } from 'react';
import { useGame } from './hooks/useGame';
import { MainMenu } from './ui/pages/MainMenu';
import { GameScreen } from './ui/pages/GameScreen';
import { LoadingScreen } from './ui/pages/LoadingScreen';
import styles from './styles/App.module.css';

type AppState = 'loading' | 'menu' | 'game';

export function App() {
  const {
    gameState,
    isLoading,
    error,
    tick,
    newGame,
    loadSavedGame,
    hasSavedGame,
    startWar,
    startBattle,
    playBattlePhase,
    autoResolveBattle
  } = useGame();
  
  const [appState, setAppState] = useState<AppState>('loading');

  // Initialize app state
  useEffect(() => {
    if (!isLoading) {
      // If there's a saved game, show menu with option to load
      // Otherwise, show menu
      setAppState('menu');
    }
  }, [isLoading]);

  const handleStartGame = (scenario: any, seed?: string) => {
    newGame(scenario, seed);
    setAppState('game');
  };

  const handleLoadGame = () => {
    loadSavedGame();
    setAppState('game');
  };

  const handleBackToMenu = () => {
    setAppState('menu');
  };

  // Show loading screen
  if (appState === 'loading') {
    return <LoadingScreen />;
  }

  // Show error if any
  if (error) {
    return (
      <div className={styles.errorContainer}>
        <h1>Chyba</h1>
        <p>{error}</p>
        <button onClick={() => setAppState('menu')}>Späť do menu</button>
      </div>
    );
  }

  // Show menu
  if (appState === 'menu') {
    return (
      <MainMenu
        onStartGame={handleStartGame}
        onLoadGame={handleLoadGame}
        hasSavedGame={hasSavedGame}
      />
    );
  }

  // Show game
  if (appState === 'game' && gameState) {
    return (
      <GameScreen
        gameState={gameState}
        onTick={tick}
        onBackToMenu={handleBackToMenu}
        onStartWar={startWar}
        onStartBattle={startBattle}
        onPlayBattlePhase={playBattlePhase}
        onAutoResolveBattle={autoResolveBattle}
      />
    );
  }

  // Fallback
  return <LoadingScreen />;
}

export default App;
