// Regnum Moravicum - Zupa Adjacency Matrix
//
// Mirrors the 11 zupy generated in src/core/utils/generators.ts
// (id = `zupa_${name.toLowerCase().replace(/\s+/g, '_')}`): Nitra, Devín,
// Bratislava, Trnava, Zvolen, Banská Bystrica, Košice, Prešov, Žilina,
// Poprad, Bardejov. Neighbor relationships are an approximation of real
// Slovak regional geography (west -> east), not the generated ring topology
// used for the core zupy - the war layer needs a graph with more than two
// neighbors per zupa for retreat routing to make sense.

export const ZUPA_ADJACENCY: Record<string, string[]> = {
  zupa_bratislava: ['zupa_devín', 'zupa_trnava'],
  zupa_devín: ['zupa_bratislava', 'zupa_trnava'],
  zupa_trnava: ['zupa_bratislava', 'zupa_devín', 'zupa_nitra', 'zupa_žilina'],
  zupa_nitra: ['zupa_trnava', 'zupa_zvolen', 'zupa_banská_bystrica'],
  zupa_zvolen: ['zupa_nitra', 'zupa_banská_bystrica', 'zupa_poprad'],
  zupa_banská_bystrica: ['zupa_nitra', 'zupa_zvolen', 'zupa_žilina', 'zupa_poprad'],
  zupa_žilina: ['zupa_trnava', 'zupa_banská_bystrica', 'zupa_poprad'],
  zupa_poprad: ['zupa_zvolen', 'zupa_banská_bystrica', 'zupa_žilina', 'zupa_prešov'],
  zupa_prešov: ['zupa_poprad', 'zupa_košice', 'zupa_bardejov'],
  zupa_košice: ['zupa_prešov', 'zupa_bardejov'],
  zupa_bardejov: ['zupa_prešov', 'zupa_košice'],
};

// Check if two zupy are adjacent
export function areAdjacent(zupaId1: string, zupaId2: string): boolean {
  const adjacent = ZUPA_ADJACENCY[zupaId1] || [];
  return adjacent.includes(zupaId2);
}

// Get all adjacent zupy for a given zupa
export function getAdjacentZupy(zupaId: string): string[] {
  return ZUPA_ADJACENCY[zupaId] || [];
}

// Validate adjacency matrix (check if it's symmetric)
export function validateAdjacencyMatrix(): boolean {
  for (const [zupaId, adjacent] of Object.entries(ZUPA_ADJACENCY)) {
    for (const neighbor of adjacent) {
      const neighborAdjacent = ZUPA_ADJACENCY[neighbor] || [];
      if (!neighborAdjacent.includes(zupaId)) {
        console.warn(`Adjacency matrix is not symmetric: ${zupaId} -> ${neighbor} but not ${neighbor} -> ${zupaId}`);
        return false;
      }
    }
  }
  return true;
}
