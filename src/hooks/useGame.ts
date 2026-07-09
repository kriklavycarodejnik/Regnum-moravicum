// Regnum Moravicum v2.1 - useGame Hook
import { useState, useEffect, useCallback } from 'react';
import type { GameState, ScenarioType } from '../core/types/gameState';
import { processTick } from '../core/engines/tickEngine';
import { generateInitialState } from '../core/utils/generators';
import { initRNG } from '../core/utils/rng';
import { saveGame, loadGame, hasSave, deleteSave } from '../core/utils/saveLoad';
import {
  startHungarianWar,
  startBattleOnFront,
  playBattlePhase as playBattlePhaseEngine,
  autoResolveBattleOnFront,
  type BattleFront,
} from '../core/engines/warCampaign';
import { resolveEventChoice } from '../core/engines/eventEngine';
import { performDiplomaticAction as performDiplomaticActionEngine, type DiplomaticActionType } from '../core/engines/diplomacyEngine';
import type { BattleAction } from '../battle/types';

const SAVE_DEBOUNCE_MS = 500;

interface UseGameReturn {
  gameState: GameState | null;
  isLoading: boolean;
  error: string | null;
  tick: () => void;
  newGame: (scenario: ScenarioType, seed?: string) => void;
  loadSavedGame: () => void;
  deleteSavedGame: () => void;
  hasSavedGame: boolean;
  startWar: () => void;
  startBattle: (front: BattleFront) => void;
  playBattlePhase: (action: BattleAction) => void;
  autoResolveBattle: (front: BattleFront) => void;
  resolveEvent: (eventId: string, choiceIndex: number) => void;
  performDiplomaticAction: (factionId: string, action: DiplomaticActionType) => void;
}

export function useGame(): UseGameReturn {
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [hasSavedGame, setHasSavedGame] = useState<boolean>(false);
  
  // Auto-save timeout
  const [saveTimeout, setSaveTimeout] = useState<ReturnType<typeof setTimeout> | null>(null);
  
  // Check for saved game on mount
  useEffect(() => {
    setHasSavedGame(hasSave());
    setIsLoading(false);
  }, []);
  
  // Auto-save on state change
  useEffect(() => {
    if (gameState) {
      // Clear existing timeout
      if (saveTimeout) {
        clearTimeout(saveTimeout);
      }
      
      // Set new timeout
      const newTimeout = setTimeout(() => {
        saveGame(gameState);
      }, SAVE_DEBOUNCE_MS);
      
      setSaveTimeout(newTimeout);
      
      return () => clearTimeout(newTimeout);
    }
  }, [gameState]);
  
  const tick = useCallback(() => {
    if (!gameState || gameState.gameOver) return;

    try {
      const newState = processTick({ ...gameState });
      setGameState(newState);
    } catch (err) {
      setError(`Error processing tick: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);
  
  const newGame = useCallback((scenario: ScenarioType, seed?: string) => {
    try {
      const actualSeed = seed || `regnum_${Date.now()}`;
      initRNG(actualSeed);
      const initialState = generateInitialState(scenario, actualSeed);
      setGameState(initialState);
      setError(null);
    } catch (err) {
      setError(`Error creating new game: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, []);
  
  const loadSavedGame = useCallback(async () => {
    try {
      const savedState = await loadGame();
      if (savedState) {
        setGameState(savedState);
        setError(null);
      } else {
        setError('No saved game found');
      }
    } catch (err) {
      setError(`Error loading game: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, []);
  
  const deleteSavedGame = useCallback(() => {
    try {
      deleteSave();
      setHasSavedGame(false);
    } catch (err) {
      setError(`Error deleting game: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, []);

  const startWar = useCallback(() => {
    if (!gameState) return;
    try {
      setGameState(startHungarianWar(gameState));
    } catch (err) {
      setError(`Error starting war: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  const startBattle = useCallback((front: BattleFront) => {
    if (!gameState) return;
    try {
      setGameState(startBattleOnFront(gameState, front));
    } catch (err) {
      setError(`Error starting battle: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  const playBattlePhase = useCallback((action: BattleAction) => {
    if (!gameState) return;
    try {
      setGameState(playBattlePhaseEngine(gameState, action));
    } catch (err) {
      setError(`Error resolving battle phase: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  const autoResolveBattle = useCallback((front: BattleFront) => {
    if (!gameState) return;
    try {
      setGameState(autoResolveBattleOnFront(gameState, front));
    } catch (err) {
      setError(`Error auto-resolving battle: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  const resolveEvent = useCallback((eventId: string, choiceIndex: number) => {
    if (!gameState) return;
    try {
      setGameState(resolveEventChoice(gameState, eventId, choiceIndex));
    } catch (err) {
      setError(`Error resolving event: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  const performDiplomaticAction = useCallback((factionId: string, action: DiplomaticActionType) => {
    if (!gameState) return;
    try {
      setGameState(performDiplomaticActionEngine(gameState, factionId, action));
    } catch (err) {
      setError(`Error performing diplomatic action: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [gameState]);

  return {
    gameState,
    isLoading,
    error,
    tick,
    newGame,
    loadSavedGame,
    deleteSavedGame,
    hasSavedGame,
    startWar,
    startBattle,
    playBattlePhase,
    autoResolveBattle,
    resolveEvent,
    performDiplomaticAction
  };
}

export default useGame;
