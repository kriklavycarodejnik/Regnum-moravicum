// Regnum Moravicum - Save Types

export interface SaveFile {
  version: 1;
  timestamp: number;
  gameVersion: string;
  data: {
    tick: number;
    wars: import('../war/types').War[];
    battles: import('../battle/types').Battle[];
    armies: import('../battle/types').Army[];
    zupyWarState: import('../war/types').ZupaWarState[];
    playerResources: { gold: number; prestige: number };
  };
}

export class IncompatibleSaveError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IncompatibleSaveError';
  }
}
