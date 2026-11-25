import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

const ici = path.dirname(fileURLToPath(import.meta.url));

export function creerPool(cfg) {
  return mysql.createPool({
    ...cfg,
    connectionLimit: 10,
    charset: 'utf8mb4',
    timezone: 'Z',
    dateStrings: false,
    supportBigNumbers: true,
    bigNumberStrings: false,
  });
}

/** Crée les tables manquantes (sans rien effacer). */
export async function migrer(pool) {
  const sql = await fs.readFile(path.join(ici, 'schema.sql'), 'utf8');
  const instructions = sql
    .split(/;\s*\n/)
    .map((s) => s.replace(/^\s*--.*$/gm, '').trim())
    .filter(Boolean);
  for (const i of instructions) await pool.query(i);
  // Évolutions de tables déjà créées (version 2.1 : poste des appareils).
  await ajouterColonne(pool, 'appareils', 'roles', "VARCHAR(100) NOT NULL DEFAULT ''");
  await ajouterColonne(pool, 'codes_liaison', 'roles', "VARCHAR(100) NOT NULL DEFAULT ''");
}

async function ajouterColonne(pool, table, colonne, definition) {
  const [r] = await pool.query(
    'SELECT COUNT(*) AS n FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?',
    [table, colonne],
  );
  if (Number(r[0].n) === 0) await pool.query(`ALTER TABLE ${table} ADD COLUMN ${colonne} ${definition}`);
}

/** Exécute `fn` dans une transaction (validation ou annulation automatique). */
export async function transaction(pool, fn) {
  const cx = await pool.getConnection();
  try {
    await cx.beginTransaction();
    const r = await fn(cx);
    await cx.commit();
    return r;
  } catch (e) {
    await cx.rollback().catch(() => {});
    throw e;
  } finally {
    cx.release();
  }
}
