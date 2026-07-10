// Regnum Moravicum v2.1 - Procedural Coat of Arms Component
//
// Deterministically derives a heraldic shield from stable id strings (no
// server/state storage needed - it's pure presentation, always in sync).
// `familyId` seeds the field tincture + partition ("house" look shared by
// relatives); `nobleId` seeds the charge + its tincture (personal cadency).
import type { NobleTitle } from '../../core/types/entities';

interface CoatOfArmsProps {
  nobleId: string;
  familyId?: string;
  title?: NobleTitle;
  size?: number;
  className?: string;
}

const TINCTURES = [
  '#d4af37', // or (gold)
  '#b8453f', // gules (red)
  '#4a7a9c', // azure (blue)
  '#5a9c5a', // vert (green)
  '#8b5fbf', // purpure (purple)
  '#2a2420', // sable (black)
  '#e8e0d0', // argent (off-white)
  '#c9902f', // tenné (orange-brown)
];

const PARTITIONS = ['plain', 'pale', 'fesse', 'bend', 'chevron', 'quarterly'] as const;
const CHARGES = ['cross', 'star', 'roundel', 'lozenge', 'crescent', 'triangle', 'bar', 'chevron'] as const;

const SHIELD_PATH = 'M 5,5 H 95 V 55 C 95,90 70,110 50,118 C 30,110 5,90 5,55 Z';

function hashString(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function starPoints(cx: number, cy: number, outerR: number, innerR: number): string {
  const points: string[] = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? outerR : innerR;
    const angle = (Math.PI / 5) * i - Math.PI / 2;
    points.push(`${cx + r * Math.cos(angle)},${cy + r * Math.sin(angle)}`);
  }
  return points.join(' ');
}

export function CoatOfArms({ nobleId, familyId, title, size = 40, className }: CoatOfArmsProps) {
  const familySeed = hashString(familyId ?? nobleId);
  const nobleSeed = hashString(nobleId);

  const fieldIndex = familySeed % TINCTURES.length;
  const secondaryIndex = (fieldIndex + 1 + (familySeed % (TINCTURES.length - 1))) % TINCTURES.length;
  const chargeIndex = (fieldIndex + 2 + (nobleSeed % (TINCTURES.length - 2))) % TINCTURES.length;

  const fieldColor = TINCTURES[fieldIndex];
  const secondaryColor = TINCTURES[secondaryIndex];
  const chargeColor = TINCTURES[chargeIndex];

  const partition = PARTITIONS[familySeed % PARTITIONS.length];
  const charge = CHARGES[nobleSeed % CHARGES.length];
  const uid = `${nobleId}-${familyId ?? ''}`.replace(/[^a-zA-Z0-9]/g, '');

  const showCrown = title === 'Kráľ';
  const showCoronet = title === 'Palatín' || title === 'Regent';

  return (
    <svg width={size} height={size} viewBox="0 0 100 130" className={className}>
      <defs>
        <clipPath id={`shield-clip-${uid}`}>
          <path d={SHIELD_PATH} />
        </clipPath>
        {charge === 'crescent' && (
          <mask id={`crescent-mask-${uid}`}>
            <circle cx={50} cy={58} r={15} fill="#fff" />
            <circle cx={58} cy={52} r={13} fill="#000" />
          </mask>
        )}
      </defs>

      <g clipPath={`url(#shield-clip-${uid})`}>
        <rect x={0} y={0} width={100} height={120} fill={fieldColor} />
        {partition === 'pale' && <rect x={50} y={0} width={50} height={120} fill={secondaryColor} />}
        {partition === 'fesse' && <rect x={0} y={58} width={100} height={62} fill={secondaryColor} />}
        {partition === 'bend' && <polygon points="0,120 100,0 100,35 35,120" fill={secondaryColor} />}
        {partition === 'chevron' && <polygon points="50,45 100,120 0,120" fill={secondaryColor} />}
        {partition === 'quarterly' && (
          <>
            <rect x={0} y={0} width={50} height={60} fill={secondaryColor} />
            <rect x={50} y={60} width={50} height={60} fill={secondaryColor} />
          </>
        )}

        {charge === 'cross' && (
          <>
            <rect x={42} y={20} width={16} height={78} fill={chargeColor} />
            <rect x={18} y={45} width={64} height={16} fill={chargeColor} />
          </>
        )}
        {charge === 'star' && <polygon points={starPoints(50, 58, 22, 9)} fill={chargeColor} />}
        {charge === 'roundel' && <circle cx={50} cy={58} r={20} fill={chargeColor} />}
        {charge === 'lozenge' && <polygon points="50,36 74,58 50,80 26,58" fill={chargeColor} />}
        {charge === 'crescent' && (
          <circle cx={50} cy={58} r={15} fill={chargeColor} mask={`url(#crescent-mask-${uid})`} />
        )}
        {charge === 'triangle' && <polygon points="50,32 78,88 22,88" fill={chargeColor} />}
        {charge === 'bar' && <rect x={16} y={46} width={68} height={24} fill={chargeColor} />}
        {charge === 'chevron' && <polygon points="50,38 84,88 66,88 50,64 34,88 16,88" fill={chargeColor} />}
      </g>

      <path d={SHIELD_PATH} fill="none" stroke="#1a120b" strokeWidth={2.5} />
      <path d={SHIELD_PATH} fill="none" stroke="#d4af37" strokeWidth={1} opacity={0.7} />

      {showCrown && (
        <g transform="translate(50, 4)">
          <polygon points="-22,10 -22,0 -14,7 -7,-6 0,4 7,-6 14,7 22,0 22,10" fill="#d4af37" stroke="#8a6d1f" strokeWidth={1} />
          <circle cx={-14} cy={-2} r={2} fill="#b8453f" />
          <circle cx={0} cy={-6} r={2} fill="#4a7a9c" />
          <circle cx={14} cy={-2} r={2} fill="#b8453f" />
        </g>
      )}
      {showCoronet && (
        <g transform="translate(50, 6)">
          <rect x={-20} y={2} width={40} height={6} fill="#d4af37" stroke="#8a6d1f" strokeWidth={0.75} />
          <polygon points="-16,2 -16,-6 -10,2" fill="#d4af37" />
          <polygon points="0,2 0,-9 6,2" fill="#d4af37" />
          <polygon points="16,2 16,-6 10,2" fill="#d4af37" />
        </g>
      )}
    </svg>
  );
}

export default CoatOfArms;
