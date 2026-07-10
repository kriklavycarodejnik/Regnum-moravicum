// Regnum Moravicum v2.1 - Battle Scene Illustration
import type { Terrain } from '../../battle/types';
import styles from '../../styles/BattleScene.module.css';

interface BattleSceneProps {
  terrain: Terrain;
}

function TerrainLayer({ terrain }: { terrain: Terrain }) {
  switch (terrain) {
    case 'forest':
      return (
        <g className={styles.forest}>
          {[40, 110, 180, 250, 330, 410, 490, 570, 650, 730, 800].map((x, i) => (
            <polygon
              key={i}
              points={`${x},${70 - (i % 3) * 6} ${x - 22},${118} ${x + 22},${118}`}
              className={styles.tree}
            />
          ))}
          <rect x={0} y={112} width={840} height={8} className={styles.groundLine} />
        </g>
      );
    case 'fortress':
      return (
        <g className={styles.fortress}>
          <rect x={0} y={90} width={840} height={30} className={styles.wall} />
          {Array.from({ length: 15 }, (_, i) => (
            <rect key={i} x={i * 60} y={72} width={30} height={20} className={styles.merlon} />
          ))}
          <polygon points="380,90 380,45 420,45 420,90" className={styles.tower} />
          <polygon points="380,45 400,25 420,45" className={styles.towerRoof} />
        </g>
      );
    case 'river':
      return (
        <g className={styles.river}>
          <rect x={0} y={70} width={840} height={50} className={styles.grassBand} />
          <path
            d="M 0,95 C 100,80 180,110 280,95 C 380,80 460,110 560,95 C 660,80 740,110 840,95"
            className={styles.riverBand}
          />
          <path
            d="M 0,100 C 100,85 180,115 280,100 C 380,85 460,115 560,100 C 660,85 740,115 840,100"
            className={styles.riverHighlight}
          />
        </g>
      );
    case 'hill':
      return (
        <g className={styles.hill}>
          <path d="M 0,120 C 150,40 300,110 470,60 C 620,20 760,90 840,70 L 840,120 Z" className={styles.hillShape} />
          <path d="M 0,120 C 120,90 260,120 420,100 C 580,80 700,120 840,105 L 840,120 Z" className={styles.hillShapeBack} />
        </g>
      );
    case 'field':
    default:
      return (
        <g className={styles.field}>
          <rect x={0} y={98} width={840} height={22} className={styles.grassBand} />
          {[30, 90, 150, 210, 270, 330, 390, 450, 510, 570, 630, 690, 750, 810].map((x, i) => (
            <line key={i} x1={x} y1={98} x2={x - 4} y2={112} className={styles.grassBlade} />
          ))}
        </g>
      );
  }
}

function Banner({ side, colorClass }: { side: 'left' | 'right'; colorClass: string }) {
  const x = side === 'left' ? 26 : 814;
  const flip = side === 'right' ? -1 : 1;
  return (
    <g transform={`translate(${x}, 10)`} className={styles.bannerGroup}>
      <line x1={0} y1={0} x2={0} y2={95} className={styles.pole} />
      <polygon
        points={`0,4 ${18 * flip},14 0,24 ${14 * flip},34 0,44`}
        className={`${styles.pennant} ${colorClass}`}
      />
    </g>
  );
}

export function BattleScene({ terrain }: BattleSceneProps) {
  return (
    <div className={styles.container}>
      <svg viewBox="0 0 840 120" preserveAspectRatio="none" className={styles.svg}>
        <defs>
          <linearGradient id="battleSky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#241c12" />
            <stop offset="100%" stopColor="#3a2f20" />
          </linearGradient>
        </defs>
        <rect x={0} y={0} width={840} height={120} fill="url(#battleSky)" />
        <TerrainLayer terrain={terrain} />
        <Banner side="left" colorClass={styles.attackerColor} />
        <Banner side="right" colorClass={styles.defenderColor} />
        <g className={styles.clash} transform="translate(420, 60)">
          <line x1={-11} y1={-11} x2={11} y2={11} className={styles.swordBlade} />
          <line x1={-11} y1={11} x2={11} y2={-11} className={styles.swordBlade} />
        </g>
      </svg>
    </div>
  );
}

export default BattleScene;
