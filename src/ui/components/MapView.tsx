// Regnum Moravicum v2.1 - Map View Component
import { useState } from 'react';
import type { GameState, ZupaId } from '../../core/types/gameState';
import type { Zupa } from '../../core/types/entities';
import styles from '../../styles/MapView.module.css';

interface MapViewProps {
  gameState: GameState;
}

// Approximate real-world positions of the 11 canon župy, normalized into the
// map's viewBox so the layout reads as an actual map of Moravia/Slovakia
// rather than an arbitrary ring. Keyed by name since zupa ids are generated
// slugs but names are the stable canon strings from generators.ts.
const ZUPA_COORDS: Record<string, { x: number; y: number }> = {
  'Devín': { x: 75, y: 315 },
  Bratislava: { x: 150, y: 375 },
  Trnava: { x: 230, y: 300 },
  Nitra: { x: 320, y: 320 },
  Zvolen: { x: 460, y: 275 },
  'Banská Bystrica': { x: 460, y: 205 },
  Žilina: { x: 400, y: 110 },
  Poprad: { x: 620, y: 155 },
  Prešov: { x: 780, y: 175 },
  Bardejov: { x: 790, y: 95 },
  Košice: { x: 770, y: 245 },
};

function fallbackPosition(index: number, total: number): { x: number; y: number } {
  const angle = (2 * Math.PI * index) / total;
  return { x: 450 + 260 * Math.cos(angle), y: 225 + 140 * Math.sin(angle) };
}

function loyaltyTier(loyalty: number): 'high' | 'mid' | 'low' {
  if (loyalty >= 70) return 'high';
  if (loyalty >= 40) return 'mid';
  return 'low';
}

function CastleIcon({ scale, tier, selected }: { scale: number; tier: 'high' | 'mid' | 'low'; selected: boolean }) {
  const tierClass = tier === 'high' ? styles.towerHigh : tier === 'mid' ? styles.towerMid : styles.towerLow;
  return (
    <g transform={`scale(${scale})`} className={`${styles.tower} ${tierClass} ${selected ? styles.towerSelected : ''}`}>
      <rect x={-9} y={-1} width={18} height={15} className={styles.towerBody} />
      <rect x={-9} y={-6} width={4} height={5} className={styles.towerBody} />
      <rect x={-2} y={-6} width={4} height={5} className={styles.towerBody} />
      <rect x={5} y={-6} width={4} height={5} className={styles.towerBody} />
      <rect x={-3} y={4} width={6} height={10} className={styles.towerGate} />
      <line x1={0} y1={-6} x2={0} y2={-14} className={styles.towerFlagpole} />
      <path d="M 0,-14 L 9,-11 L 0,-8 Z" className={styles.towerFlag} />
    </g>
  );
}

function CompassRose() {
  return (
    <g className={styles.compass} transform="translate(825, 400)">
      <circle r={28} className={styles.compassRing} />
      <line x1={0} y1={-24} x2={0} y2={24} className={styles.compassLine} />
      <line x1={-24} y1={0} x2={24} y2={0} className={styles.compassLine} />
      <path d="M 0,-24 L 5,-8 L 0,-13 L -5,-8 Z" className={styles.compassNeedle} />
      <text x={0} y={-32} textAnchor="middle" className={styles.compassLabel}>S</text>
      <text x={0} y={40} textAnchor="middle" className={styles.compassLabel}>J</text>
      <text x={-34} y={4} textAnchor="middle" className={styles.compassLabel}>Z</text>
      <text x={34} y={4} textAnchor="middle" className={styles.compassLabel}>V</text>
    </g>
  );
}

export function MapView({ gameState }: MapViewProps) {
  const [selectedZupa, setSelectedZupa] = useState<ZupaId | null>(null);

  const handleZupaClick = (zupaId: ZupaId) => {
    setSelectedZupa(selectedZupa === zupaId ? null : zupaId);
  };

  const getZupaById = (id: ZupaId): Zupa | undefined => gameState.zupy[id];

  const getNobleName = (id: string): string => {
    const noble = gameState.nobles.find((n) => n.id === id);
    return noble ? noble.name : 'Neznámy';
  };

  const zupaIds = Object.keys(gameState.zupy);

  const getPosition = (zupaId: ZupaId, index: number): { x: number; y: number } => {
    const zupa = getZupaById(zupaId);
    if (zupa && ZUPA_COORDS[zupa.name]) return ZUPA_COORDS[zupa.name];
    return fallbackPosition(index, zupaIds.length);
  };

  const roads: { key: string; x1: number; y1: number; x2: number; y2: number }[] = [];
  const seen = new Set<string>();
  zupaIds.forEach((zupaId, index) => {
    const zupa = getZupaById(zupaId);
    if (!zupa) return;
    const pos = getPosition(zupaId, index);
    zupa.neighbors.forEach((neighborId) => {
      const pairKey = [zupaId, neighborId].sort().join('|');
      if (seen.has(pairKey)) return;
      seen.add(pairKey);
      const neighborIndex = zupaIds.indexOf(neighborId);
      if (neighborIndex === -1) return;
      const neighborPos = getPosition(neighborId, neighborIndex);
      roads.push({ key: pairKey, x1: pos.x, y1: pos.y, x2: neighborPos.x, y2: neighborPos.y });
    });
  });

  const selected = selectedZupa ? getZupaById(selectedZupa) : null;

  return (
    <div className={styles.container}>
      <h2>Mapa Veľkej Moravy</h2>

      <div className={styles.mapContainer}>
        <svg className={styles.mapSvg} viewBox="0 0 900 450" preserveAspectRatio="xMidYMid meet">
          <defs>
            <radialGradient id="parchment" cx="50%" cy="45%" r="75%">
              <stop offset="0%" stopColor="#3a2f20" />
              <stop offset="60%" stopColor="#241c12" />
              <stop offset="100%" stopColor="#0d0904" />
            </radialGradient>
          </defs>

          <rect x={0} y={0} width={900} height={450} fill="url(#parchment)" />
          <rect x={10} y={10} width={880} height={430} className={styles.borderOuter} />
          <rect x={16} y={16} width={868} height={418} className={styles.borderInner} />

          {/* Stylized Danube/Morava river near the south-west river zupy */}
          <path
            d="M 20,410 C 100,400 140,392 150,375 C 165,340 210,320 230,300 C 260,288 300,300 340,320"
            className={styles.river}
          />

          {roads.map((road) => {
            const midX = (road.x1 + road.x2) / 2;
            const midY = (road.y1 + road.y2) / 2 - 12;
            return (
              <path
                key={road.key}
                d={`M ${road.x1},${road.y1} Q ${midX},${midY} ${road.x2},${road.y2}`}
                className={styles.road}
              />
            );
          })}

          {zupaIds.map((zupaId, index) => {
            const zupa = getZupaById(zupaId);
            if (!zupa) return null;
            const pos = getPosition(zupaId, index);
            const isSelected = selectedZupa === zupaId;
            const tier = loyaltyTier(zupa.loyalty);
            const scale = 0.85 + Math.min(zupa.prosperity, 100) / 200;

            return (
              <g
                key={zupaId}
                onClick={() => handleZupaClick(zupaId)}
                className={styles.zupaGroup}
                transform={`translate(${pos.x}, ${pos.y})`}
              >
                <CastleIcon scale={scale} tier={tier} selected={isSelected} />

                <g transform="translate(0, 24)">
                  <rect x={-38} y={-2} width={76} height={16} className={styles.labelBanner} />
                  <text x={0} y={10} textAnchor="middle" className={styles.zupaText}>
                    {zupa.name}
                  </text>
                </g>
                <text x={0} y={44} textAnchor="middle" className={styles.ownerText}>
                  {getNobleName(zupa.owner)}
                </text>
              </g>
            );
          })}

          <CompassRose />
        </svg>
      </div>

      {selected && (
        <div className={styles.zupaDetails}>
          <div className={styles.charterHeader}>
            <div className={styles.wax}>{Math.round(selected.loyalty)}%</div>
            <h3>{selected.name}</h3>
          </div>
          <div className={styles.detailsGrid}>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vlastník:</span>
              <span className={styles.detailValue}>{getNobleName(selected.owner)}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vernosť:</span>
              <span className={styles.detailValue}>{selected.loyalty}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Blahobyt:</span>
              <span className={styles.detailValue}>{selected.prosperity}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Obrana:</span>
              <span className={styles.detailValue}>{selected.defense}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Potrava:</span>
              <span className={styles.detailValue}>{selected.food}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Populácia:</span>
              <span className={styles.detailValue}>{selected.population}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Rekrut. bazén:</span>
              <span className={styles.detailValue}>{selected.recruitmentPool}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Posádka:</span>
              <span className={styles.detailValue}>{selected.garrison}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default MapView;
