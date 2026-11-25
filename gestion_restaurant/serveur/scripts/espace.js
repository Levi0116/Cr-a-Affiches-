/** Espace occupé par la base de données (à comparer au quota de l'hébergeur). */
import { creerPool } from '../src/bd.js';
import { lireConfig } from '../src/config.js';

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
const [tables] = await pool.query(
  `SELECT table_name AS t, ROUND((data_length + index_length) / 1048576, 2) AS mo, table_rows AS lignes
   FROM information_schema.tables WHERE table_schema = ? ORDER BY (data_length + index_length) DESC`,
  [cfg.mysql.database],
);
let total = 0;
console.log('\nTable                 Taille (Mo)   Lignes (env.)');
for (const r of tables) {
  total += Number(r.mo);
  console.log(`${String(r.t).padEnd(22)}${String(r.mo).padStart(10)}   ${String(r.lignes).padStart(12)}`);
}
console.log(`\nTotal base : ${total.toFixed(2)} Mo`);
await pool.end();
