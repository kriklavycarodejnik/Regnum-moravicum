// Regnum Moravicum v3.0 — Illustrated battle scene (AoE2-inspired)
import { useMemo } from 'react';
import type { Terrain, UnitType } from '../../battle/types';
import styles from '../../styles/BattleScene.module.css';

type UnitKind = 'infantry' | 'archer' | 'cavalry' | 'spear';
type Composition = Partial<Record<UnitType, number>>;

interface BattleSceneProps {
  terrain: Terrain;
  intensity?: number;
  attackerComposition?: Composition;
  defenderComposition?: Composition;
  attackerLabel?: string;
  defenderLabel?: string;
}

function UnitSilhouette({
  x,
  y,
  kind,
  side,
  delay = 0,
}: {
  x: number;
  y: number;
  kind: UnitKind;
  side: 'attacker' | 'defender';
  delay?: number;
}) {
  const flip = side === 'attacker' ? 1 : -1;
  const bodyClass = side === 'attacker' ? styles.unitAttacker : styles.unitDefender;

  return (
    <g
      transform={`translate(${x}, ${y}) scale(${flip}, 1)`}
      className={`${styles.unit} ${bodyClass}`}
      style={{ animationDelay: `${delay}s` }}
    >
      <ellipse cx={0} cy={18} rx={10} ry={3} className={styles.unitShadow} />

      {kind === 'cavalry' ? (
        <>
          <ellipse cx={2} cy={10} rx={12} ry={6} className={styles.unitBody} />
          <rect x={-8} y={10} width={3} height={8} rx={1} className={styles.unitBody} />
          <rect x={8} y={10} width={3} height={8} rx={1} className={styles.unitBody} />
          <circle cx={12} cy={6} r={4} className={styles.unitBody} />
          <rect x={-2} y={-4} width={6} height={10} rx={1} className={styles.unitBody} />
          <circle cx={1} cy={-7} r={3.5} className={styles.unitHead} />
          <line x1={6} y1={-2} x2={16} y2={-8} className={styles.weapon} />
        </>
      ) : kind === 'archer' ? (
        <>
          <rect x={-4} y={0} width={8} height={14} rx={2} className={styles.unitBody} />
          <circle cx={0} cy={-4} r={4} className={styles.unitHead} />
          <path d="M 8,-2 Q 16,6 8,14" className={styles.bow} />
          <line x1={8} y1={6} x2={18} y2={6} className={styles.weapon} />
        </>
      ) : kind === 'spear' ? (
        <>
          <rect x={-4} y={0} width={8} height={14} rx={2} className={styles.unitBody} />
          <circle cx={0} cy={-4} r={4} className={styles.unitHead} />
          <line x1={2} y1={16} x2={2} y2={-14} className={styles.spear} />
          <path d="M 2,-14 L 5,-10 L 2,-11 L -1,-10 Z" className={styles.spearTip} />
          <circle cx={-7} cy={6} r={5} className={styles.shield} />
        </>
      ) : (
        <>
          <rect x={-4} y={0} width={8} height={14} rx={2} className={styles.unitBody} />
          <circle cx={0} cy={-4} r={4} className={styles.unitHead} />
          <line x1={6} y1={2} x2={14} y2={-6} className={styles.weapon} />
          <circle cx={-7} cy={6} r={5} className={styles.shield} />
        </>
      )}
    </g>
  );
}

function TerrainLayer({ terrain }: { terrain: Terrain }) {
  switch (terrain) {
    case 'forest':
      return (
        <g className={styles.terrainForest}>
          {[40, 120, 200, 640, 720, 800].map((x, i) => (
            <g key={i} transform={`translate(${x}, 78)`}>
              <rect x={-3} y={10} width={6} height={14} fill="#3a2a18" />
              <ellipse cx={0} cy={4} rx={14} ry={16} fill="#1e3a1a" />
              <ellipse cx={-6} cy={0} rx={10} ry={12} fill="#2a4a22" />
            </g>
          ))}
          <rect x={0} y={100} width={840} height={60} className={styles.groundForest} />
        </g>
      );
    case 'hill':
      return (
        <g>
          <path d="M 0,120 C 140,70 260,90 420,65 C 580,90 700,70 840,110 L 840,160 L 0,160 Z" className={styles.groundHill} />
          <path d="M 0,130 C 180,95 320,115 500,85 C 660,110 760,95 840,120 L 840,160 L 0,160 Z" className={styles.groundHillFront} />
        </g>
      );
    case 'river':
      return (
        <g>
          <rect x={0} y={100} width={840} height={60} className={styles.groundField} />
          <path d="M 0,118 C 120,108 220,128 360,114 C 500,100 640,126 840,112 L 840,136 C 640,148 500,122 360,136 C 220,148 120,128 0,138 Z" className={styles.river} />
        </g>
      );
    case 'fortress':
      return (
        <g>
          <rect x={0} y={100} width={840} height={60} className={styles.groundStone} />
          {[480, 520, 560, 600, 640, 680, 720].map((x, i) => (
            <g key={i}>
              <rect x={x} y={70} width={28} height={40} className={styles.wall} />
              <rect x={x + 4} y={58} width={8} height={14} className={styles.wall} />
              <rect x={x + 16} y={58} width={8} height={14} className={styles.wall} />
            </g>
          ))}
        </g>
      );
    default:
      return <rect x={0} y={100} width={840} height={60} className={styles.groundField} />;
  }
}

function Banner({ side, label }: { side: 'left' | 'right'; label: string }) {
  const x = side === 'left' ? 70 : 770;
  const pole = side === 'left' ? styles.bannerPoleAttacker : styles.bannerPoleDefender;
  const cloth = side === 'left' ? styles.bannerClothAttacker : styles.bannerClothDefender;
  return (
    <g transform={`translate(${x}, 42)`} className={styles.banner}>
      <line x1={0} y1={0} x2={0} y2={48} className={pole} />
      <path d="M 0,2 L 28,10 L 0,18 Z" className={cloth} />
      <text x={side === 'left' ? 34 : -34} y={14} textAnchor={side === 'left' ? 'start' : 'end'} className={styles.bannerLabel}>
        {label}
      </text>
    </g>
  );
}

function DustPuffs() {
  return (
    <g className={styles.dust}>
      {[380, 400, 420, 440, 460].map((x, i) => (
        <circle key={i} cx={x} cy={118 + (i % 3) * 3} r={4 + (i % 2)} className={styles.dustPuff} style={{ animationDelay: `${i * 0.15}s` }} />
      ))}
    </g>
  );
}

function buildLine(
  composition: Composition | undefined,
  side: 'attacker' | 'defender',
  count = 8
): Array<{ kind: UnitKind; x: number }> {
  const defaults: Composition =
    side === 'attacker'
      ? { cavalry: 0.45, archers: 0.25, infantry: 0.3 }
      : { infantry: 0.45, archers: 0.25, cavalry: 0.3 };

  const c = composition ?? defaults;
  const inf = Math.max(0, c.infantry ?? 0);
  const cav = Math.max(0, c.cavalry ?? 0);
  const arc = Math.max(0, c.archers ?? 0);
  const total = inf + cav + arc || 1;

  const nCav = Math.round((cav / total) * count);
  const nArc = Math.round((arc / total) * count);
  const nInf = Math.max(0, count - nCav - nArc);

  const kinds: UnitKind[] = [];
  if (side === 'defender') {
    for (let i = 0; i < nInf; i++) kinds.push(i % 2 === 0 ? 'spear' : 'infantry');
    for (let i = 0; i < nArc; i++) kinds.push('archer');
    for (let i = 0; i < nCav; i++) kinds.push('cavalry');
  } else {
    for (let i = 0; i < nCav; i++) kinds.push('cavalry');
    for (let i = 0; i < nArc; i++) kinds.push('archer');
    for (let i = 0; i < nInf; i++) kinds.push(i % 2 === 0 ? 'spear' : 'infantry');
  }

  while (kinds.length < count) kinds.push('infantry');
  kinds.length = count;

  const startX = side === 'attacker' ? 90 : 500;
  const endX = side === 'attacker' ? 345 : 760;
  const step = (endX - startX) / Math.max(1, count - 1);

  return kinds.map((kind, i) => ({ kind, x: startX + i * step }));
}

export function BattleScene({
  terrain,
  intensity = 0.7,
  attackerComposition,
  defenderComposition,
  attackerLabel = 'Maďari',
  defenderLabel = 'Moravania',
}: BattleSceneProps) {
  const attackerLine = useMemo(() => buildLine(attackerComposition, 'attacker'), [attackerComposition]);
  const defenderLine = useMemo(() => buildLine(defenderComposition, 'defender'), [defenderComposition]);
  const clashScale = 0.7 + intensity * 0.6;

  return (
    <div className={styles.container} data-intensity={intensity.toFixed(2)}>
      <svg viewBox="0 0 840 160" preserveAspectRatio="xMidYMid slice" className={styles.svg}>
        <defs>
          <linearGradient id="battleSky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#3a2a3a" />
            <stop offset="55%" stopColor="#2a2030" />
            <stop offset="100%" stopColor="#1a1520" />
          </linearGradient>
          <radialGradient id="sunGlow" cx="78%" cy="22%" r="25%">
            <stop offset="0%" stopColor="#e8c84a" stopOpacity="0.45" />
            <stop offset="100%" stopColor="#e8c84a" stopOpacity="0" />
          </radialGradient>
          <filter id="unitSoft" x="-30%" y="-30%" width="160%" height="160%">
            <feDropShadow dx="0" dy="1" stdDeviation="1.2" floodOpacity="0.5" />
          </filter>
        </defs>

        <rect x={0} y={0} width={840} height={160} fill="url(#battleSky)" />
        <rect x={0} y={0} width={840} height={160} fill="url(#sunGlow)" />

        <path
          d="M 0,70 C 80,55 160,75 240,58 C 320,42 400,68 500,50 C 600,35 700,60 840,48 L 840,95 L 0,95 Z"
          className={styles.distantHills}
        />

        <TerrainLayer terrain={terrain} />

        <Banner side="left" label={attackerLabel} />
        <Banner side="right" label={defenderLabel} />

        <g filter="url(#unitSoft)">
          {attackerLine.map((u, i) => (
            <UnitSilhouette key={`a-${i}`} x={u.x} y={105} kind={u.kind} side="attacker" delay={i * 0.08} />
          ))}
          {defenderLine.map((u, i) => (
            <UnitSilhouette key={`d-${i}`} x={u.x} y={105} kind={u.kind} side="defender" delay={i * 0.08} />
          ))}
        </g>

        <DustPuffs />

        <g className={styles.clash} transform={`translate(420, 95) scale(${clashScale})`}>
          <circle r={18} className={styles.clashGlow} />
          <line x1={-12} y1={-12} x2={12} y2={12} className={styles.swordBlade} />
          <line x1={-12} y1={12} x2={12} y2={-12} className={styles.swordBlade} />
        </g>

        <rect x={350} y={4} width={140} height={20} rx={10} className={styles.terrainBadge} />
        <text x={420} y={18} textAnchor="middle" className={styles.terrainLabel}>
          {terrainLabel(terrain)}
        </text>
      </svg>
    </div>
  );
}

function terrainLabel(terrain: Terrain): string {
  const map: Record<Terrain, string> = {
    field: 'Pole',
    forest: 'Les',
    hill: 'Kopce',
    river: 'Rieka',
    fortress: 'Hradby',
  };
  return map[terrain] ?? terrain;
}

export default BattleScene;
