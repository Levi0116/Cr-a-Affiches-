import crypto from 'node:crypto';
import { creerApp } from '../src/app.js';
import { creerPool, migrer } from '../src/bd.js';
import { hacherPin, nouveauCode } from '../src/securite.js';
import { ecrireServeur } from '../src/sync.js';

export const cfg = {
  port: 0,
  mysql: {
    host: process.env.MYSQL_HOTE ?? '127.0.0.1',
    port: Number(process.env.MYSQL_PORT ?? 3306),
    database: process.env.MYSQL_BASE_TEST ?? 'amani_test',
    user: process.env.MYSQL_UTILISATEUR ?? 'amani',
    password: process.env.MYSQL_MOT_DE_PASSE ?? 'amani-test',
  },
  secret: 'secret-de-test-suffisamment-long-pour-hs256-0123456789',
  dureeSessionH: 12,
  dossierPwa: '/inexistant',
  version: { derniere: '2.0.0', minimale: '2.0.0', notes: '' },
};

export const RID = 'chez-amani';
export const PIN_ADMIN = '482615';
export const PIN_SERVEUSE = '739204';

/** Base vide + restaurant + admin + serveuse ; serveur HTTP lancé. */
export async function demarrer() {
  const pool = creerPool(cfg.mysql);
  await migrer(pool);
  await pool.query('SET FOREIGN_KEY_CHECKS = 0');
  for (const t of ['documents', 'lots_appliques', 'appareils', 'codes_liaison', 'essais_pin', 'restaurants']) await pool.query(`TRUNCATE ${t}`);
  await pool.query('SET FOREIGN_KEY_CHECKS = 1');
  await pool.query('INSERT INTO restaurants (id, nom) VALUES (?, ?)', [RID, 'Restaurant Chez les Amani']);
  const idAdmin = crypto.randomUUID();
  const idServeuse = crypto.randomUUID();
  await ecrireServeur(pool, RID, [
    { chemin: '@', donnees: { nom: 'Restaurant Chez les Amani' } },
    { chemin: `employes/${idAdmin}`, donnees: { nom: 'Patron', role: 'admin', actif: true, pinVerif: hacherPin(PIN_ADMIN) } },
    { chemin: `employes/${idServeuse}`, donnees: { nom: 'Fatou', role: 'serveuse', actif: true, pinVerif: hacherPin(PIN_SERVEUSE) } },
    { chemin: 'articles/flag', donnees: { nom: 'Flag 65 cl', prix: 700, stock: 20, seuilAlerte: 12, unite: 'bouteille' } },
    { chemin: 'tables/t1', donnees: { numero: 1, statut: 'libre' } },
  ]);
  const app = creerApp(pool, cfg);
  const serveur = await new Promise((ok) => {
    const s = app.listen(0, '127.0.0.1', () => ok(s));
  });
  const base = `http://127.0.0.1:${serveur.address().port}/api`;

  async function appel(methode, chemin, { corps, jeton, session } = {}) {
    const r = await fetch(base + chemin, {
      method: methode,
      headers: {
        'content-type': 'application/json',
        ...(jeton ? { authorization: `Appareil ${jeton}` } : {}),
        ...(session ? { 'x-session': session } : {}),
      },
      body: corps ? JSON.stringify(corps) : undefined,
    });
    return { statut: r.status, corps: await r.json().catch(() => null) };
  }

  async function lier({ type = 'tablette', admin = false } = {}) {
    const code = nouveauCode();
    await pool.query('INSERT INTO codes_liaison (code, restaurant_id, nom, type, admin, expire) VALUES (?, ?, ?, ?, ?, ?)', [
      code, RID, `${type} test`, type, admin, new Date(Date.now() + 600_000),
    ]);
    const r = await appel('POST', '/liaison', { corps: { code } });
    return r.corps;
  }

  async function connecter(jeton, idEmploye, pin) {
    return appel('POST', '/connexion', { jeton, corps: { employeId: idEmploye, pin } });
  }

  const fermer = async () => {
    serveur.closeAllConnections?.();
    await new Promise((ok) => serveur.close(ok));
    await pool.end();
  };
  return { pool, appel, lier, connecter, idAdmin, idServeuse, fermer, port: serveur.address().port };
}

export const lot = (auteur, ops, extra = {}) => ({ id: crypto.randomUUID(), auteur, faitLe: Date.now(), ops, ...extra });
