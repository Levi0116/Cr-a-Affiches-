import fs from 'node:fs';
import path from 'node:path';
import compression from 'compression';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { routesComptes } from './routes/comptes.js';
import { routesSynchro } from './routes/synchro.js';
import { ErreurApi } from './securite.js';

/** Application Express : API sous /api, PWA servie à la racine. */
export function creerApp(pool, cfg) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1); // derrière Nginx

  app.use(
    helmet({
      contentSecurityPolicy: {
        useDefaults: true,
        directives: {
          // Flutter web : moteur WebAssembly local et script d'amorçage.
          'script-src': ["'self'", "'wasm-unsafe-eval'", "'unsafe-inline'"],
          'style-src': ["'self'", "'unsafe-inline'"],
          'img-src': ["'self'", 'data:', 'blob:'],
          'font-src': ["'self'", 'data:'],
          'connect-src': ["'self'"],
          'worker-src': ["'self'", 'blob:'],
          'media-src': ["'self'", 'blob:'],
          'upgrade-insecure-requests': null,
        },
      },
      crossOriginEmbedderPolicy: false,
      strictTransportSecurity: { maxAge: 31536000, includeSubDomains: true },
    }),
  );
  app.use(compression());
  app.use(express.json({ limit: '2mb' }));

  const api = express.Router();
  api.use(rateLimit({ windowMs: 60_000, limit: 600, standardHeaders: 'draft-8', legacyHeaders: false }));
  api.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });
  api.get('/sante', async (_req, res) => {
    await pool.query('SELECT 1');
    res.json({ ok: true, version: cfg.version.derniere });
  });
  api.use('/', routesComptes(pool, cfg));
  api.use('/sync', routesSynchro(pool, cfg));
  api.use((_req, _res) => {
    throw new ErreurApi(404, 'Route inconnue.');
  });
  app.use('/api', api);

  // PWA (flutter build web) : fichiers statiques + retour à index.html.
  if (fs.existsSync(cfg.dossierPwa)) {
    app.use(
      express.static(cfg.dossierPwa, {
        index: 'index.html',
        setHeaders(res, fichier) {
          const nom = path.basename(fichier);
          if (['index.html', 'flutter_service_worker.js', 'sw.js', 'version.json', 'manifest.json', 'flutter_bootstrap.js'].includes(nom)) {
            res.set('Cache-Control', 'no-cache');
          } else {
            res.set('Cache-Control', 'public, max-age=604800');
          }
        },
      }),
    );
    app.get(/^(?!\/api\/).*/, (_req, res) => res.set('Cache-Control', 'no-cache').sendFile(path.join(cfg.dossierPwa, 'index.html')));
  }

  // Erreurs : message lisible, jamais de détail interne.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    if (err instanceof ErreurApi) return res.status(err.statut).json({ erreur: err.message, code: err.code });
    if (err?.type === 'entity.parse.failed') return res.status(400).json({ erreur: 'Requête invalide.' });
    if (err?.type === 'entity.too.large') return res.status(413).json({ erreur: 'Requête trop volumineuse.' });
    console.error(new Date().toISOString(), req.method, req.path, err);
    res.status(500).json({ erreur: 'Erreur interne du serveur.' });
  });
  return app;
}
