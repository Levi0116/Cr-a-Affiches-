/**
 * Assistant de configuration (hébergement alwaysdata ou autre) : pose les
 * questions, vérifie la connexion à la base, crée le fichier .env avec un
 * secret aléatoire, puis crée les tables.
 *
 *   npm run configurer
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

const racine = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const fichier = path.join(racine, '.env');
// Lecture ligne par ligne (fonctionne au clavier comme avec un copier-coller de plusieurs lignes).
const rl = readline.createInterface({ input: process.stdin });
const lignes = [];
const attentes = [];
rl.on('line', (l) => (attentes.length ? attentes.shift()(l) : lignes.push(l)));
rl.on('close', () => attentes.splice(0).forEach((r) => r('')));
const demander = async (q, defaut = '') => {
  process.stdout.write(defaut ? `${q} [${defaut}] : ` : `${q} : `);
  const l = lignes.length ? lignes.shift() : await new Promise((r) => attentes.push(r));
  return l.trim() || defaut;
};

console.log('\n=== Configuration du serveur Restaurant Chez les Amani ===\n');
if (fs.existsSync(fichier)) {
  const r = await demander('Un fichier .env existe déjà. Le remplacer ? (oui/non)', 'non');
  if (r.toLowerCase() !== 'oui') {
    console.log('Rien n’a été modifié.');
    process.exit(0);
  }
}

const compte = await demander('Nom de votre compte alwaysdata (laisser vide si autre hébergeur)');
const hote = await demander('Serveur de la base MySQL/MariaDB', compte ? `mysql-${compte}.alwaysdata.net` : '127.0.0.1');
const base = await demander('Nom de la base', compte ? `${compte}_amani` : 'amani');
const utilisateur = await demander('Utilisateur de la base', compte || 'amani');
const mdp = await demander('Mot de passe de la base (il s’affiche : vérifiez que personne ne regarde)');
const origines = await demander(
  'Adresse(s) de l’application, séparées par des virgules',
  'https://restaurant-chez-amani.com,https://www.restaurant-chez-amani.com',
);

process.stdout.write('\nVérification de la connexion à la base… ');
try {
  const cx = await mysql.createConnection({ host: hote, port: 3306, user: utilisateur, password: mdp, database: base });
  await cx.query('SELECT 1');
  await cx.end();
  console.log('OK');
} catch (e) {
  console.log('ÉCHEC');
  console.error(`→ ${e.message}\nVérifiez le serveur, le nom de la base, l’utilisateur et le mot de passe (alwaysdata : Bases de données → MySQL).`);
  process.exit(1);
}

const secret = crypto.randomBytes(48).toString('base64url');
fs.writeFileSync(
  fichier,
  [
    '# Créé par npm run configurer — ne jamais publier ce fichier.',
    `MYSQL_HOTE=${hote}`,
    'MYSQL_PORT=3306',
    `MYSQL_BASE=${base}`,
    `MYSQL_UTILISATEUR=${utilisateur}`,
    `MYSQL_MOT_DE_PASSE=${mdp}`,
    `SECRET_SESSIONS=${secret}`,
    'DUREE_SESSION_H=12',
    `ORIGINES=${origines}`,
    'DOSSIER_PWA=../web',
    'VERSION_DERNIERE=2.0.0',
    'VERSION_MINIMALE=2.0.0',
    '',
  ].join('\n'),
  { mode: 0o600 },
);
console.log(`Fichier .env créé (${fichier}).`);

const { creerPool, migrer } = await import('../src/bd.js');
const { lireConfig } = await import('../src/config.js');
const pool = creerPool(lireConfig().mysql);
await migrer(pool);
await pool.end();
console.log('Tables créées. Étape suivante : npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin VOTRECODE\n');
rl.close();
