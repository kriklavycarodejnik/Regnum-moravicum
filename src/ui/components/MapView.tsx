// Regnum Moravicum v2.1 - Map View Component
import { useState } from 'react';
import type { GameState, ZupaId } from '../../core/types/gameState';
import type { Zupa } from '../../core/types/entities';
import styles from '../../styles/MapView.module.css';

interface MapViewProps {
  gameState: GameState;
}

export function MapView({ gameState }: MapViewProps) {
  const [selectedZupa, setSelectedZupa] = useState<ZupaId | null>(null);

  const handleZupaClick = (zupaId: ZupaId) => {
    setSelectedZupa(selectedZupa === zupaId ? null : zupaId);
  };

  const getZupaById = (id: ZupaId): Zupa | undefined => {
    return gameState.zupy[id];
  };

  // Get noble name by ID
  const getNobleName = (id: string): string => {
    const noble = gameState.nobles.find(n => n.id === id);
    return noble ? noble.name : 'Neznámy';
  };

  // Calculate position for each zupa (simple grid layout)
  const getZupaPosition = (index: number, total: number): { x: number; y: number } => {
    const angle = (2 * Math.PI * index) / total;
    const radius = 200;
    const centerX = 300;
    const centerY = 200;
    
    return {
      x: centerX + radius * Math.cos(angle),
      y: centerY + radius * Math.sin(angle)
    };
  };

  const zupaIds = Object.keys(gameState.zupy);

  return (
    <div className={styles.container}>
      <h2>Mapa Veľkej Moravy</h2>
      
      <div className={styles.mapContainer}>
        <svg 
          className={styles.mapSvg}
          viewBox="0 0 600 400"
          preserveAspectRatio="xMidYMid meet"
        >
          {/* Draw connections between neighbors */}
          {zupaIds.map(zupaId => {
            const zupa = getZupaById(zupaId);
            if (!zupa) return null;
            
            const index = zupaIds.indexOf(zupaId);
            const pos = getZupaPosition(index, zupaIds.length);
            
            return zupa.neighbors.map(neighborId => {
              const neighbor = getZupaById(neighborId);
              if (!neighbor) return null;
              
              const neighborIndex = zupaIds.indexOf(neighborId);
              const neighborPos = getZupaPosition(neighborIndex, zupaIds.length);
              
              return (
                <line
                  key={`conn_${zupaId}_${neighborId}`}
                  x1={pos.x}
                  y1={pos.y}
                  x2={neighborPos.x}
                  y2={neighborPos.y}
                  stroke="#8b7d6b"
                  strokeWidth="2"
                  strokeDasharray="5,5"
                />
              );
            });
          })}
          
          {/* Draw zupy */}
          {zupaIds.map(zupaId => {
            const zupa = getZupaById(zupaId);
            if (!zupa) return null;
            
            const index = zupaIds.indexOf(zupaId);
            const pos = getZupaPosition(index, zupaIds.length);
            const isSelected = selectedZupa === zupaId;
            
            // Calculate loyalty color
            const loyaltyColor = zupa.loyalty >= 70 ? '#4a6b4a' : 
                                zupa.loyalty >= 40 ? '#8b7d6b' : '#6b4a4a';
            
            return (
              <g 
                key={zupaId}
                onClick={() => handleZupaClick(zupaId)}
                className={styles.zupaGroup}
              >
                {/* Zupa circle */}
                <circle
                  cx={pos.x}
                  cy={pos.y}
                  r={isSelected ? 35 : 25}
                  fill={loyaltyColor}
                  stroke="#d4af37"
                  strokeWidth={isSelected ? 3 : 1}
                  className={styles.zupaCircle}
                />
                
                {/* Zupa name */}
                <text
                  x={pos.x}
                  y={pos.y + 40}
                  textAnchor="middle"
                  fill="#e0d8c0"
                  fontSize="12"
                  fontFamily="Georgia, serif"
                >
                  {zupa.name}
                </text>
                
                {/* Owner indicator */}
                <text
                  x={pos.x}
                  y={pos.y + 55}
                  textAnchor="middle"
                  fill="#d4af37"
                  fontSize="10"
                  fontFamily="Georgia, serif"
                >
                  {getNobleName(zupa.owner)}
                </text>
              </g>
            );
          })}
        </svg>
      </div>

      {/* Selected zupa details */}
      {selectedZupa && (
        <div className={styles.zupaDetails}>
          <h3>{getZupaById(selectedZupa)?.name || 'Neznáma župa'}</h3>
          <div className={styles.detailsGrid}>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vlastník:</span>
              <span className={styles.detailValue}>{getNobleName(getZupaById(selectedZupa)?.owner || '')}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vernosť:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.loyalty || 0}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Blahobyt:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.prosperity || 0}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Obrana:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.defense || 0}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Potrava:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.food || 0}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Populácia:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.population || 0}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Rekrut. bazén:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.recruitmentPool || 0}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Posádka:</span>
              <span className={styles.detailValue}>{getZupaById(selectedZupa)?.garrison || 0}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default MapView;
