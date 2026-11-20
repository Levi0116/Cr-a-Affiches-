import { lireDoc } from './documents.js';
import { ecrireServeur } from './sync.js';

/** Publie dans chaque restaurant la version proposée aux appareils (bandeau « mise à jour »). */
export async function publierVersion(pool, version) {
  const [restos] = await pool.query('SELECT id FROM restaurants');
  for (const { id } of restos) {
    const actuel = await lireDoc(pool, id, 'config/version');
    if (JSON.stringify(actuel) === JSON.stringify(version)) continue;
    await ecrireServeur(pool, id, [{ chemin: 'config/version', donnees: version }]);
  }
}
