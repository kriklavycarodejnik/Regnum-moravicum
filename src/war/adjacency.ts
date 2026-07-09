// Regnum Moravicum - Zupa Adjacency Matrix
// TODO: Verify with actual SVG map data

// Adjacency matrix for zupy
export const ZUPA_ADJACENCY: Record<string, string[]> = {
  // Moravian zupy
  'moravia_brno': ['moravia_velehrad', 'moravia_olomouc', 'moravia_znojmo', 'moravia_uherske_hradiste'],
  'moravia_velehrad': ['moravia_brno', 'moravia_olomouc', 'moravia_mikulcice'],
  'moravia_olomouc': ['moravia_brno', 'moravia_velehrad', 'moravia_stare_mesto'],
  'moravia_stare_mesto': ['moravia_olomouc', 'moravia_pozvadov'],
  'moravia_pozvadov': ['moravia_stare_mesto', 'moravia_znojmo'],
  'moravia_znojmo': ['moravia_brno', 'moravia_pozvadov', 'moravia_uherske_hradiste'],
  'moravia_uherske_hradiste': ['moravia_brno', 'moravia_znojmo', 'moravia_mikulcice'],
  'moravia_mikulcice': ['moravia_velehrad', 'moravia_uherske_hradiste'],
  
  // Hungarian zupy (for the war scenario)
  'hungarian_zupa': ['moravia_uherske_hradiste', 'moravia_znojmo', 'madarska_zupa'],
  'nitra_zupa': ['moravia_brno', 'moravia_velehrad', 'nitrianska_zupa'],
  
  // Additional zupy for the Hungarian war scenario
  'nitrianska_zupa': ['nitra_zupa', 'moravia_brno', 'hungarian_zupa'],
  'madarska_zupa': ['hungarian_zupa'],
} as const;

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
