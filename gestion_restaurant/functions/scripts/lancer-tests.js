// Lance les tests (règles Firestore + Cloud Functions) sur les émulateurs.
// Fonctionne sous Windows, macOS et Linux : `npm test` dans le dossier functions.
const { execSync, spawnSync } = require('node:child_process');
const path = require('node:path');

const env = { ...process.env };
// Derrière un proxy d'entreprise, la CLI Firebase doit joindre ses émulateurs
// en direct : le module préchargé ne s'active que si FIREBASE_TOOLS_DIR est connu.
try {
  env.FIREBASE_TOOLS_DIR = path.join(execSync('npm root -g', { encoding: 'utf8' }).trim(), 'firebase-tools');
} catch {
  // npm introuvable : pas de correctif proxy, sans conséquence hors proxy.
}
const prechargement = path.join(__dirname, '..', 'test', 'emulateurs-sans-proxy-local.js');
env.NODE_OPTIONS = `${env.NODE_OPTIONS ?? ''} --require "${prechargement}"`.trim();

const r = spawnSync(
  'firebase',
  ['emulators:exec', '--project', 'demo-resto', '--only', 'auth,firestore,functions',
    '"node --test --test-concurrency=1 test/regles.test.js test/fonctions.test.js"'],
  { stdio: 'inherit', env, shell: true, cwd: path.join(__dirname, '..') },
);
process.exit(r.status ?? 1);
