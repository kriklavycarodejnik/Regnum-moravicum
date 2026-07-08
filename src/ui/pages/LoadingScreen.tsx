// Regnum Moravicum v2.1 - Loading Screen Page
import styles from '../../styles/LoadingScreen.module.css';

export function LoadingScreen() {
  return (
    <div className={styles.container}>
      <div className={styles.content}>
        <h1>Regnum Moravicum v2.1</h1>
        <p>Načítavam hru...</p>
        <div className={styles.spinner} />
      </div>
    </div>
  );
}

export default LoadingScreen;
