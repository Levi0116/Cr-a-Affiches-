// Génère build/web/sw.js après `flutter build web` : liste de tous les
// fichiers de l'application + empreinte de version. Le navigateur garde ainsi
// une copie complète de l'application (démarrage sans internet), et la met à
// jour d'un coup à chaque nouvelle version.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'build', 'web');
if (!fs.existsSync(racine)) {
  console.error('Lancez d’abord : flutter build web');
  process.exit(1);
}
const ignores = new Set(['sw.js', 'flutter_service_worker.js', '.last_build_id']);
const fichiers = [];
const empreinte = crypto.createHash('sha256');
(function parcourir(dossier) {
  for (const nom of fs.readdirSync(dossier).sort()) {
    const plein = path.join(dossier, nom);
    const rel = path.relative(racine, plein).split(path.sep).join('/');
    if (fs.statSync(plein).isDirectory()) parcourir(plein);
    else if (!ignores.has(rel) && !nom.startsWith('.') && !rel.endsWith('.map') && !rel.endsWith('.symbols')) {
      fichiers.push(rel);
      empreinte.update(rel).update(fs.readFileSync(plein));
    }
  }
})(racine);
const version = empreinte.digest('hex').slice(0, 16);

const sw = `// Généré par outils/generer-sw.mjs — ne pas modifier à la main.
const VERSION = 'amani-${version}';
const FICHIERS = ${JSON.stringify(['./', ...fichiers.filter((f) => f !== 'index.html')], null, 0)};

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FICHIERS.map((f) => new Request(f, { cache: 'reload' })))));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const cle of await caches.keys()) if (cle !== VERSION) await caches.delete(cle);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  // L'API (données, synchronisation) ne passe jamais par le cache.
  if (e.request.method !== 'GET' || url.origin !== location.origin || url.pathname.includes('/api/')) return;
  // config.json (adresse du serveur) : réseau d'abord, copie locale si hors ligne.
  if (url.pathname.endsWith('/config.json')) {
    e.respondWith(fetch(e.request).then((r) => {
      const copie = r.clone();
      caches.open(VERSION).then((c) => c.put(new Request('config.json'), copie));
      return r;
    }).catch(() => caches.match('config.json', { ignoreSearch: true })));
    return;
  }
  // Pages : réseau d'abord (nouvelle version), copie locale si hors ligne.
  if (e.request.mode === 'navigate') {
    e.respondWith(fetch(e.request).catch(() => caches.match('./', { ignoreSearch: true })));
    return;
  }
  // Fichiers de l'application : copie locale d'abord (démarrage instantané).
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((r) => r || fetch(e.request)));
});
`;
fs.writeFileSync(path.join(racine, 'sw.js'), sw);
console.log(`sw.js : ${fichiers.length} fichiers, version ${version}`);
