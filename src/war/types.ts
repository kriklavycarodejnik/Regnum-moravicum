// Regnum Moravicum - War Types

export interface WarObjective {
  zupaId: string;
  type: 'expel'; // vyhnať nepriateľa zo župy
  completed: boolean;
}

export interface War {
  id: string;
  attackerFactionId: string;
  defenderFactionId: string;
  objectives: WarObjective[];
  startTick: number;
  timeoutTicks: number; // po uplynutí → prehra hráča
  result: 'ongoing' | 'victory' | 'defeat';
}

export interface ZupaWarState {
  zupaId: string;
  controllerFactionId: string;
  occupierFactionId: string | null; // null = neokupovaná
}
