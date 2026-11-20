import { creerApp } from './app.js';
import { creerPool, migrer } from './bd.js';
import { lireConfig } from './config.js';
import { publierVersion } from './version.js';

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
await migrer(pool);
await publierVersion(pool, cfg.version);
const app = creerApp(pool, cfg);
// HOTE=127.0.0.1 en production (derrière Nginx) ; 0.0.0.0 pour un test sur le Wi-Fi local.
const hote = process.env.HOTE ?? '127.0.0.1';
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
