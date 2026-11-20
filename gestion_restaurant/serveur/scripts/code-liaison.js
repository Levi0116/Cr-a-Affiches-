/**
 * Secours : nouveau code de liaison administrateur (téléphone du gérant
 * perdu ou remplacé), à lancer sur le serveur.
 *   npm run code-liaison -- --id chez-amani [--nom "Nouveau téléphone"]
 */
import { creerPool } from '../src/bd.js';
import { lireConfig } from '../src/config.js';
import { DUREE_CODE_MIN, nouveauCode } from '../src/securite.js';

const arg = (n) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const id = arg('id');
if (!id) {
  console.error('Usage : --id identifiant-du-restaurant [--nom "Téléphone du gérant"]');
  process.exit(1);
}
const pool = creerPool(lireConfig().mysql);
const code = nouveauCode();
await pool.query('INSERT INTO codes_liaison (code, restaurant_id, nom, type, admin, expire) VALUES (?, ?, ?, ?, 1, ?)', [
  code, id, arg('nom') ?? 'Téléphone du gérant', 'telephone', new Date(Date.now() + DUREE_CODE_MIN * 60_000),
]);
console.log(`Code de liaison administrateur (valable ${DUREE_CODE_MIN} min) : ${code}`);
await pool.end();
