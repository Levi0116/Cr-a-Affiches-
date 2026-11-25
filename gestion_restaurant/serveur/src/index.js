import { creerApp } from './app.js';
import { creerPool, migrer } from './bd.js';
import { lireConfig } from './config.js';
import { publierVersion } from './version.js';

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
await migrer(pool);
await publierVersion(pool, cfg.version);
// Ménage : les accusés des lots déjà synchronisés de plus de 60 jours ne
// servent plus (un appareil renvoie ses lots en quelques minutes ou jours).
async function purger() {
  try {
    await pool.query('DELETE FROM lots_appliques WHERE applique_le < NOW() - INTERVAL 60 DAY');
    await pool.query('DELETE FROM codes_liaison WHERE expire < NOW() - INTERVAL 1 DAY');
  } catch (e) {
    console.error('Ménage impossible :', e.message);
  }
}
await purger();
setInterval(purger, 24 * 3600 * 1000).unref();
const app = creerApp(pool, cfg);
// HOTE=127.0.0.1 derrière Nginx ; 0.0.0.0 pour un test sur le Wi-Fi local ;
// adresse fournie automatiquement chez alwaysdata.
const hote = cfg.hote;
const serveur = app.listen(cfg.port, hote, () => {
  console.log(`Serveur Amani prêt sur http://${hote === '0.0.0.0' ? 'localhost' : hote}:${cfg.port}`);
});
// Les appareils en écoute (long polling) gardent la connexion jusqu'à 25 s.
serveur.keepAliveTimeout = 65_000;
serveur.headersTimeout = 66_000;

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    serveur.close(() => pool.end().then(() => process.exit(0)));
    setTimeout(() => process.exit(0), 5000).unref();
  });
}
