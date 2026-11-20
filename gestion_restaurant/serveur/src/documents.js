/**
 * Stockage des documents et numéros de révision.
 * Toutes les écritures d'un restaurant sont sérialisées par le verrou
 * de sa ligne `restaurants` (SELECT … FOR UPDATE) : les révisions sont
 * strictement croissantes, sans trou ni doublon.
 */
import { EventEmitter } from 'node:events';

export const signaux = new EventEmitter();
signaux.setMaxListeners(0);

export async function verrouillerResto(cx, rid) {
  const [r] = await cx.query('SELECT rev FROM restaurants WHERE id = ? FOR UPDATE', [rid]);
  if (!r.length) throw new Error(`restaurant inconnu : ${rid}`);
  return Number(r[0].rev);
}

export async function lireDoc(cx, rid, chemin, pourMaj = false) {
  const [r] = await cx.query(
    `SELECT donnees FROM documents WHERE restaurant_id = ? AND chemin = ?${pourMaj ? ' FOR UPDATE' : ''}`,
    [rid, chemin],
  );
  if (!r.length) return null;
  return typeof r[0].donnees === 'string' ? JSON.parse(r[0].donnees) : r[0].donnees;
}

export async function ecrireDoc(cx, rid, chemin, donnees, rev) {
  const collection = chemin === '@' ? '@' : chemin.split('/')[0];
  await cx.query(
    `INSERT INTO documents (restaurant_id, chemin, collection, donnees, rev) VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE donnees = VALUES(donnees), rev = VALUES(rev)`,
    [rid, chemin, collection, JSON.stringify(donnees), rev],
  );
}

export async function finirRevision(cx, rid, rev) {
  await cx.query('UPDATE restaurants SET rev = ? WHERE id = ?', [rev, rid]);
}

/** Prévient les appareils en attente (long polling) après validation. */
export function annoncer(rid, rev) {
  signaux.emit(`rev:${rid}`, rev);
}

export async function lireDocs(cx, rid, collection) {
  const [r] = await cx.query('SELECT chemin, donnees FROM documents WHERE restaurant_id = ? AND collection = ?', [rid, collection]);
  return r.map((l) => ({ chemin: l.chemin, donnees: typeof l.donnees === 'string' ? JSON.parse(l.donnees) : l.donnees }));
}
