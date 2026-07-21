// Regnum Moravicum v3.0 - Loading Screen
import styles from '../../styles/LoadingScreen.module.css';

export function LoadingScreen() {
  return (
    <div className={styles.container}>
      <div className={styles.content}>
        <div className={styles.crest} aria-hidden>
          ✠
        </div>
        <h1>Regnum Moravicum</h1>
        <p>Pripravujem kráľovstvo…</p>
        <div className={styles.barTrack} aria-hidden>
          <div className={styles.barFill} />
        </div>
        <div className={styles.spinner} />
      </div>
    </div>
  );
}

export default LoadingScreen;
