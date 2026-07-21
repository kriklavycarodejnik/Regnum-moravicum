// Regnum Moravicum v3.0 — Rich terrain map (AoE2 × Veľká Morava)
import { useCallback, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent, type WheelEvent as ReactWheelEvent } from 'react';
import type { GameState, ZupaId } from '../../core/types/gameState';
import type { Zupa } from '../../core/types/entities';
import { CoatOfArms } from './CoatOfArms';
import styles from '../../styles/MapView.module.css';

interface MapViewProps {
  gameState: GameState;
}

const MIN_ZOOM = 1;
const MAX_ZOOM = 2.4;

const ZUPA_COORDS: Record<string, { x: number; y: number; biome: Biome }> = {
  Devín: { x: 78, y: 318, biome: 'river' },
  Bratislava: { x: 148, y: 372, biome: 'river' },
  Trnava: { x: 228, y: 298, biome: 'field' },
  Nitra: { x: 318, y: 318, biome: 'field' },
  Zvolen: { x: 458, y: 272, biome: 'forest' },
  'Banská Bystrica': { x: 458, y: 202, biome: 'hill' },
  Žilina: { x: 398, y: 108, biome: 'hill' },
  Poprad: { x: 618, y: 152, biome: 'hill' },
  Prešov: { x: 778, y: 172, biome: 'forest' },
  Bardejov: { x: 788, y: 92, biome: 'forest' },
  Košice: { x: 768, y: 242, biome: 'field' },
};

type Biome = 'field' | 'forest' | 'hill' | 'river';

function fallbackPosition(index: number, total: number): { x: number; y: number; biome: Biome } {
  const angle = (2 * Math.PI * index) / total;
  return { x: 450 + 260 * Math.cos(angle), y: 225 + 140 * Math.sin(angle), biome: 'field' };
}

function loyaltyTier(loyalty: number): 'high' | 'mid' | 'low' {
  if (loyalty >= 70) return 'high';
  if (loyalty >= 40) return 'mid';
  return 'low';
}

function SettlementIcon({
  scale,
  tier,
  selected,
  occupied,
  prosperity,
}: {
  scale: number;
  tier: 'high' | 'mid' | 'low';
  selected: boolean;
  occupied: boolean;
  prosperity: number;
}) {
  const tierClass =
    tier === 'high' ? styles.towerHigh : tier === 'mid' ? styles.towerMid : styles.towerLow;
  const size = prosperity >= 60 ? 'citadel' : prosperity >= 35 ? 'fort' : 'outpost';

  return (
    <g
      transform={`scale(${scale})`}
      className={`${styles.tower} ${tierClass} ${selected ? styles.towerSelected : ''} ${occupied ? styles.towerOccupied : ''}`}
    >
      {/* Selection / loyalty ring */}
      <circle r={22} className={styles.loyaltyRing} />
      {selected && <circle r={26} className={styles.selectPulse} />}

      {/* Base mound */}
      <ellipse cx={0} cy={12} rx={16} ry={5} className={styles.mound} />

      {size === 'outpost' && (
        <>
          <rect x={-8} y={-2} width={16} height={14} rx={1} className={styles.towerBody} />
          <rect x={-8} y={-7} width={3.5} height={5} className={styles.towerBody} />
          <rect x={-1.75} y={-7} width={3.5} height={5} className={styles.towerBody} />
          <rect x={4.5} y={-7} width={3.5} height={5} className={styles.towerBody} />
          <rect x={-2.5} y={4} width={5} height={8} className={styles.towerGate} />
        </>
      )}
      {size === 'fort' && (
        <>
          <rect x={-14} y={2} width={28} height={10} rx={1} className={styles.wallBody} />
          <rect x={-10} y={-8} width={8} height={20} rx={1} className={styles.towerBody} />
          <rect x={2} y={-4} width={8} height={16} rx={1} className={styles.towerBody} />
          <rect x={-10} y={-12} width={2.5} height={4} className={styles.merlon} />
          <rect x={-5.5} y={-12} width={2.5} height={4} className={styles.merlon} />
          <rect x={-1} y={-12} width={2.5} height={4} className={styles.merlon} />
          <rect x={2} y={-8} width={2.5} height={4} className={styles.merlon} />
          <rect x={6.5} y={-8} width={2.5} height={4} className={styles.merlon} />
          <rect x={-3} y={5} width={6} height={7} className={styles.towerGate} />
        </>
      )}
      {size === 'citadel' && (
        <>
          <rect x={-18} y={4} width={36} height={10} rx={1} className={styles.wallBody} />
          <rect x={-16} y={-6} width={10} height={20} rx={1} className={styles.towerBody} />
          <rect x={-4} y={-14} width={12} height={28} rx={1} className={styles.keep} />
          <rect x={10} y={-4} width={8} height={18} rx={1} className={styles.towerBody} />
          {/* Rotunda hint — Great Moravia */}
          <circle cx={0} cy={-18} r={5} className={styles.rotunda} />
          <path d="M -5,-18 L 0,-26 L 5,-18" className={styles.rotundaRoof} />
          <rect x={-3} y={6} width={6} height={8} className={styles.towerGate} />
        </>
      )}

      {/* Flag */}
      <line x1={0} y1={size === 'citadel' ? -26 : -12} x2={0} y2={size === 'citadel' ? -36 : -22} className={styles.towerFlagpole} />
      <path
        d={size === 'citadel' ? 'M 0,-36 L 10,-32 L 0,-28 Z' : 'M 0,-22 L 9,-18.5 L 0,-15 Z'}
        className={styles.towerFlag}
      />

      {occupied && (
        <g className={styles.smoke}>
          <circle cx={-6} cy={-20} r={3} className={styles.smokePuff} />
          <circle cx={2} cy={-28} r={4} className={styles.smokePuff} style={{ animationDelay: '0.4s' }} />
          <circle cx={8} cy={-22} r={2.5} className={styles.smokePuff} style={{ animationDelay: '0.8s' }} />
        </g>
      )}
    </g>
  );
}

function CompassRose() {
  return (
    <g className={styles.compass} transform="translate(830, 398)">
      <circle r={30} className={styles.compassRing} />
      <circle r={22} className={styles.compassInner} />
      <line x1={0} y1={-20} x2={0} y2={20} className={styles.compassLine} />
      <line x1={-20} y1={0} x2={20} y2={0} className={styles.compassLine} />
      <path d="M 0,-20 L 5,-6 L 0,-10 L -5,-6 Z" className={styles.compassNeedle} />
      <path d="M 0,20 L 4,8 L 0,12 L -4,8 Z" className={styles.compassNeedleSouth} />
      <text x={0} y={-28} textAnchor="middle" className={styles.compassLabel}>
        S
      </text>
      <text x={0} y={36} textAnchor="middle" className={styles.compassLabel}>
        J
      </text>
      <text x={-30} y={4} textAnchor="middle" className={styles.compassLabel}>
        Z
      </text>
      <text x={30} y={4} textAnchor="middle" className={styles.compassLabel}>
        V
      </text>
    </g>
  );
}

function TerrainBackdrop() {
  return (
    <g className={styles.terrainLayer} pointerEvents="none">
      {/* Distant Carpathian haze */}
      <path
        d="M 0,90 C 80,70 140,100 220,75 C 300,50 360,85 450,55 C 540,30 620,70 720,45 C 800,30 860,60 900,50 L 900,0 L 0,0 Z"
        className={styles.mountainHaze}
      />
      <path
        d="M 0,130 C 100,100 180,140 280,110 C 380,80 480,130 580,95 C 680,65 780,110 900,90 L 900,0 L 0,0 Z"
        className={styles.mountainBack}
      />

      {/* Forest blobs */}
      <ellipse cx={200} cy={200} rx={70} ry={40} className={styles.forestBlob} />
      <ellipse cx={480} cy={160} rx={90} ry={50} className={styles.forestBlob} />
      <ellipse cx={700} cy={140} rx={80} ry={45} className={styles.forestBlob} />
      <ellipse cx={620} cy={300} rx={55} ry={30} className={styles.forestBlob} />
      <ellipse cx={350} cy={180} rx={40} ry={25} className={styles.forestBlobSoft} />

      {/* Meadow patches */}
      <ellipse cx={280} cy={340} rx={95} ry={45} className={styles.meadowBlob} />
      <ellipse cx={520} cy={360} rx={70} ry={35} className={styles.meadowBlob} />
      <ellipse cx={750} cy={320} rx={60} ry={40} className={styles.meadowBlob} />

      {/* Danube / Morava system */}
      <path
        d="M 10,420 C 60,410 100,400 150,375 C 175,350 200,330 230,300 C 270,285 300,305 340,325 C 380,340 420,350 460,355"
        className={styles.riverWide}
      />
      <path
        d="M 10,420 C 60,410 100,400 150,375 C 175,350 200,330 230,300 C 270,285 300,305 340,325 C 380,340 420,350 460,355"
        className={styles.riverCore}
      />
      <path
        d="M 340,325 C 400,310 450,280 500,260 C 560,235 600,250 640,270"
        className={styles.riverBranch}
      />

      {/* Soft vignette fields */}
      <ellipse cx={450} cy={250} rx={420} ry={200} className={styles.landGlow} />
    </g>
  );
}

export function MapView({ gameState }: MapViewProps) {
  const [selectedZupa, setSelectedZupa] = useState<ZupaId | null>(null);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const dragRef = useRef<{
    pointerId: number;
    startX: number;
    startY: number;
    originX: number;
    originY: number;
    moved: boolean;
  } | null>(null);
  const mapSurfaceRef = useRef<HTMLDivElement | null>(null);

  const handleZupaClick = (zupaId: ZupaId) => {
    if (dragRef.current?.moved) return;
    setSelectedZupa(selectedZupa === zupaId ? null : zupaId);
  };

  const clampPan = useCallback((next: { x: number; y: number }, z: number) => {
    const el = mapSurfaceRef.current;
    if (!el) return next;
    const { clientWidth: w, clientHeight: h } = el;
    const maxX = ((z - 1) * w) / 2 + 40;
    const maxY = ((z - 1) * h) / 2 + 40;
    return {
      x: Math.max(-maxX, Math.min(maxX, next.x)),
      y: Math.max(-maxY, Math.min(maxY, next.y)),
    };
  }, []);

  const onWheel = (e: ReactWheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.12 : 0.12;
    setZoom((z) => {
      const next = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, z + delta));
      setPan((p) => clampPan(p, next));
      return next;
    });
  };

  const onPointerDown = (e: ReactPointerEvent) => {
    if (e.button !== 0) return;
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    dragRef.current = {
      pointerId: e.pointerId,
      startX: e.clientX,
      startY: e.clientY,
      originX: pan.x,
      originY: pan.y,
      moved: false,
    };
  };

  const onPointerMove = (e: ReactPointerEvent) => {
    const d = dragRef.current;
    if (!d || d.pointerId !== e.pointerId) return;
    const dx = e.clientX - d.startX;
    const dy = e.clientY - d.startY;
    if (Math.abs(dx) + Math.abs(dy) > 4) d.moved = true;
    setPan(clampPan({ x: d.originX + dx, y: d.originY + dy }, zoom));
  };

  const endDrag = (e: ReactPointerEvent) => {
    const d = dragRef.current;
    if (!d || d.pointerId !== e.pointerId) return;
    // Keep moved flag briefly so click handlers can ignore the release click
    window.setTimeout(() => {
      if (dragRef.current?.pointerId === e.pointerId) dragRef.current = null;
    }, 0);
  };

  const zoomBy = (delta: number) => {
    setZoom((z) => {
      const next = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, z + delta));
      setPan((p) => clampPan(p, next));
      return next;
    });
  };

  const resetView = () => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  };

  const getZupaById = (id: ZupaId): Zupa | undefined => gameState.zupy[id];
  const getNoble = (id: string) => gameState.nobles.find((n) => n.id === id);
  const getNobleName = (id: string): string => getNoble(id)?.name ?? 'Neznámy';

  const zupaIds = Object.keys(gameState.zupy);

  const occupiedSet = useMemo(() => {
    const set = new Set<string>();
    const wc = gameState.warCampaign;
    if (!wc) return set;
    // Contested objectives + any zupa with a non-Moravian army marker
    if (wc.war.result === 'ongoing') {
      for (const o of wc.war.objectives) {
        if (!o.completed) set.add(o.zupaId);
      }
    }
    for (const state of wc.zupyWarState) {
      if (state.occupierFactionId) set.add(state.zupaId);
    }
    return set;
  }, [gameState.warCampaign]);

  const getPosition = (zupaId: ZupaId, index: number) => {
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
      <div className={styles.titleRow}>
        <h2>Mapa Veľkej Moravy</h2>
        <div className={styles.titleActions}>
          <span className={styles.yearBadge}>
            Rok {gameState.year} · mesiac {(gameState.tick % 12) + 1}
          </span>
          <div className={styles.zoomControls}>
            <button type="button" className={styles.zoomBtn} onClick={() => zoomBy(-0.2)} aria-label="Oddialiť">
              −
            </button>
            <button type="button" className={styles.zoomBtn} onClick={resetView} aria-label="Reset pohľadu">
              {Math.round(zoom * 100)}%
            </button>
            <button type="button" className={styles.zoomBtn} onClick={() => zoomBy(0.2)} aria-label="Priblížiť">
              +
            </button>
          </div>
        </div>
      </div>

      <div
        className={styles.mapContainer}
        ref={mapSurfaceRef}
        onWheel={onWheel}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
      >
        <div
          className={styles.mapTransform}
          style={{ transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})` }}
        >
        <svg className={styles.mapSvg} viewBox="0 0 900 450" preserveAspectRatio="xMidYMid meet">
          <defs>
            <radialGradient id="parchment" cx="50%" cy="42%" r="78%">
              <stop offset="0%" stopColor="#3d3224" />
              <stop offset="45%" stopColor="#2a2116" />
              <stop offset="100%" stopColor="#0c0905" />
            </radialGradient>
            <linearGradient id="skyHaze" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#4a3a4a" stopOpacity="0.35" />
              <stop offset="100%" stopColor="#2a2030" stopOpacity="0" />
            </linearGradient>
            <linearGradient id="riverGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#2a5565" />
              <stop offset="50%" stopColor="#4a8a9a" />
              <stop offset="100%" stopColor="#2a5565" />
            </linearGradient>
            <filter id="softGlow" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="2.5" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
            <filter id="mapShadow" x="-20%" y="-20%" width="140%" height="140%">
              <feDropShadow dx="0" dy="2" stdDeviation="2" floodColor="#000" floodOpacity="0.45" />
            </filter>
          </defs>

          <rect x={0} y={0} width={900} height={450} fill="url(#parchment)" />
          <rect x={0} y={0} width={900} height={140} fill="url(#skyHaze)" />

          <TerrainBackdrop />

          {/* Decorative frame */}
          <rect x={8} y={8} width={884} height={434} className={styles.borderOuter} rx={4} />
          <rect x={14} y={14} width={872} height={422} className={styles.borderInner} rx={2} />

          {/* Roads */}
          {roads.map((road) => {
            const midX = (road.x1 + road.x2) / 2;
            const midY = (road.y1 + road.y2) / 2 - 14;
            return (
              <path
                key={road.key}
                d={`M ${road.x1},${road.y1} Q ${midX},${midY} ${road.x2},${road.y2}`}
                className={styles.road}
              />
            );
          })}

          {/* Settlements */}
          {zupaIds.map((zupaId, index) => {
            const zupa = getZupaById(zupaId);
            if (!zupa) return null;
            const pos = getPosition(zupaId, index);
            const isSelected = selectedZupa === zupaId;
            const tier = loyaltyTier(zupa.loyalty);
            const scale = 0.9 + Math.min(zupa.prosperity, 100) / 220;
            const occupied = occupiedSet.has(zupaId);

            return (
              <g
                key={zupaId}
                onClick={() => handleZupaClick(zupaId)}
                className={styles.zupaGroup}
                transform={`translate(${pos.x}, ${pos.y})`}
                filter="url(#mapShadow)"
              >
                <SettlementIcon
                  scale={scale}
                  tier={tier}
                  selected={isSelected}
                  occupied={occupied}
                  prosperity={zupa.prosperity}
                />

                <g transform="translate(0, 28)">
                  <rect x={-42} y={-3} width={84} height={18} rx={3} className={styles.labelBanner} />
                  <text x={0} y={10} textAnchor="middle" className={styles.zupaText}>
                    {zupa.name}
                  </text>
                </g>
                <text x={0} y={50} textAnchor="middle" className={styles.ownerText}>
                  {getNobleName(zupa.owner)}
                </text>
              </g>
            );
          })}

          <CompassRose />

          {/* Legend */}
          <g transform="translate(28, 400)" className={styles.legend}>
            <rect x={0} y={0} width={168} height={36} rx={6} className={styles.legendBg} />
            <circle cx={14} cy={18} r={5} className={styles.legendHigh} />
            <text x={24} y={22} className={styles.legendText}>
              vernosť
            </text>
            <circle cx={72} cy={18} r={5} className={styles.legendMid} />
            <text x={82} y={22} className={styles.legendText}>
              stred
            </text>
            <circle cx={118} cy={18} r={5} className={styles.legendLow} />
            <text x={128} y={22} className={styles.legendText}>
              nízka
            </text>
          </g>
        </svg>
        </div>
        <p className={styles.mapHint}>Ťahaj pre posun · koliesko / pinch zoom · +/− tlačidlá</p>
      </div>

      {selected && (
        <div className={`${styles.zupaDetails} animateSlideIn`}>
          <div className={styles.charterHeader}>
            <div className={styles.wax}>{Math.round(selected.loyalty)}%</div>
            <div>
              <h3>{selected.name}</h3>
              <p className={styles.charterSub}>župa · blahobyt {selected.prosperity}%</p>
            </div>
          </div>
          <div className={styles.detailsGrid}>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vlastník</span>
              <span className={styles.detailValue}>
                <span className={styles.ownerRow}>
                  <CoatOfArms
                    nobleId={selected.owner}
                    familyId={getNoble(selected.owner)?.familyId}
                    title={getNoble(selected.owner)?.title}
                    size={22}
                  />
                  {getNobleName(selected.owner)}
                </span>
              </span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Vernosť</span>
              <span className={styles.detailValue}>{selected.loyalty}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Blahobyt</span>
              <span className={styles.detailValue}>{selected.prosperity}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Obrana</span>
              <span className={styles.detailValue}>{selected.defense}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Potrava</span>
              <span className={styles.detailValue}>{selected.food}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Populácia</span>
              <span className={styles.detailValue}>{selected.population}%</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Rekrut. bazén</span>
              <span className={styles.detailValue}>{selected.recruitmentPool}</span>
            </div>
            <div className={styles.detailItem}>
              <span className={styles.detailLabel}>Posádka</span>
              <span className={styles.detailValue}>{selected.garrison}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default MapView;
