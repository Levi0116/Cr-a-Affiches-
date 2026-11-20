import { creerApp } from './app.js';
import { creerPool, migrer } from './bd.js';
import { lireConfig } from './config.js';
import { publierVersion } from './version.js';

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
await migrer(pool);
await publierVersion(pool, cfg.version);
const app = creerApp(pool, cfg);
const serveur = app.listen(cfg.port, '127.0.0.1', () => {
  console.log(`Serveur Amani prêt sur http://127.0.0.1:${cfg.port}`);
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
