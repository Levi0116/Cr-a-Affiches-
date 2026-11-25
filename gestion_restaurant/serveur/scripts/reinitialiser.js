/**
 * Remise à zéro COMPLÈTE d'un restaurant : toutes les données (ventes,
 * factures, stock, menu, comptes, appareils liés, codes) sont effacées.
 * Les appareils liés sont déconnectés et effacent leur copie locale.
 *
 *   npm run reinitialiser -- --id chez-amani
 *
 * Une confirmation est demandée (taper le mot EFFACER).
 * Ensuite : npm run creer-restaurant -- ... pour repartir de zéro.
 */
import readline from 'node:readline';
import { creerPool } from '../src/bd.js';
import { lireConfig } from '../src/config.js';

const arg = (n) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const id = arg('id');
if (!id) {
  console.error('Usage : npm run reinitialiser -- --id chez-amani');
  process.exit(1);
}

const pool = creerPool(lireConfig().mysql);
const [[r]] = await pool.query('SELECT nom FROM restaurants WHERE id = ?', [id]);
if (!r) {
  console.error(`Restaurant « ${id} » introuvable.`);
  process.exit(1);
}
const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM documents WHERE restaurant_id = ?', [id]);
console.log(`\n⚠️  Vous allez EFFACER DÉFINITIVEMENT « ${r.nom} » : ${n} enregistrements,`);
console.log('   tous les comptes, appareils liés, ventes, factures, stock et menu.');
console.log('   Conseil : téléchargez d’abord le rapport complet PDF depuis l’application.\n');

let reponse = arg('confirmer');
if (reponse !== 'EFFACER') {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  reponse = await new Promise((ok) => rl.question('Tapez EFFACER pour confirmer : ', ok));
  rl.close();
}
if (reponse.trim() !== 'EFFACER') {
  console.log('Annulé : rien n’a été effacé.');
  await pool.end();
  process.exit(0);
}

const cx = await pool.getConnection();
try {
  await cx.beginTransaction();
  for (const table of ['documents', 'lots_appliques', 'appareils', 'codes_liaison', 'essais_pin']) {
    await cx.query(`DELETE FROM ${table} WHERE restaurant_id = ?`, [id]);
  }
  await cx.query('DELETE FROM restaurants WHERE id = ?', [id]);
  await cx.commit();
} catch (e) {
  await cx.rollback();
  throw e;
} finally {
  cx.release();
}
console.log('\n✅ Tout est effacé. Pour repartir de zéro :');
console.log(`   npm run creer-restaurant -- --id ${id} --nom "Restaurant Chez les Amani" --admin "Patron" --pin VOTRECODE\n`);
await pool.end();
