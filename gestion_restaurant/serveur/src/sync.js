/**
 * Synchronisation hors ligne.
 *
 * - push : l'appareil envoie ses lots d'écritures (faits en ligne ou hors
 *   ligne). Chaque lot est appliqué en entier ou pas du tout, une seule fois
 *   (identifiant de lot), après vérification des droits.
 * - pull : l'appareil demande tous les documents modifiés depuis sa dernière
 *   révision connue.
 * - attendre : l'appareil reste en écoute ; la réponse arrive dès qu'une
 *   nouvelle révision existe (temps réel sans WebSocket).
 */
import { alerteStock, messageDemande, messageStock, notification, rapportJour } from './alertes.js';
import { transaction } from './bd.js';
import { annoncer, ecrireDoc, finirRevision, lireDoc, lireDocs, signaux, verrouillerResto } from './documents.js';
import { refus } from './regles.js';
import { appliquer } from './valeurs.js';

const CHEMIN = /^(@|[A-Za-z]+\/[A-Za-z0-9_-]{1,64}(\/[A-Za-z]+\/[A-Za-z0-9_-]{1,64})?)$/;
const MAX_OPS = 400;

/**
 * Applique un lot. Renvoie { ok: true } ou { ok: false, erreur }.
 * `estAdmin(lot)` dit si l'auteur du lot a les droits administrateur.
 */
async function appliquerLot(cx, rid, lot, admin, rev) {
  if (!Array.isArray(lot.ops) || lot.ops.length === 0 || lot.ops.length > MAX_OPS) {
    return { ok: false, erreur: 'lot vide ou trop gros' };
  }
  const maintenant = Date.now();
  const ecrits = new Map(); // chemin -> { avant, apres }
  for (const op of lot.ops) {
    if (typeof op.chemin !== 'string' || !CHEMIN.test(op.chemin)) return { ok: false, erreur: `chemin invalide : ${op.chemin}` };
    if (op.type !== 'set' && op.type !== 'update') return { ok: false, erreur: 'suppression interdite' };
    const deja = ecrits.get(op.chemin);
    const avant = deja ? deja.apres : await lireDoc(cx, rid, op.chemin, true);
    let apres;
    try {
      apres = appliquer(avant, op, maintenant);
    } catch (e) {
      return { ok: false, erreur: `${op.chemin} : ${e.message}` };
    }
    const avantOrigine = deja ? deja.avant : avant;
    const raison = refus({ segments: op.chemin.split('/'), avant: avantOrigine, apres, admin });
    if (raison) return { ok: false, erreur: `${op.chemin} : ${raison}` };
    ecrits.set(op.chemin, { avant: avantOrigine, apres });
  }

  const supplements = [];
  for (const [chemin, { avant, apres }] of ecrits) {
    const [col] = chemin.split('/');
    if (col === 'articles') {
      const type = alerteStock(avant, apres);
      if (type) {
        const [titre, message] = messageStock(type, apres);
        supplements.push(notification(`stock_${type}`, titre, message, 'stock'));
      }
    } else if (col === 'demandesValidation' && avant === null) {
      const [titre, message] = messageDemande(apres);
      supplements.push(notification('validation', titre, message, 'admin'));
    } else if (col === 'journeesCaisse' && avant && avant.verrouillee !== true && apres.verrouillee === true) {
      const factures = (await lireDocs(cx, rid, 'factures')).map((d) => d.donnees);
      for (const [c, e] of ecrits) if (c.startsWith('factures/')) factures.push(e.apres);
      supplements.push({ chemin: `rapportsJour/${chemin.split('/')[1]}`, donnees: rapportJour(apres, factures) });
    }
  }

  for (const [chemin, { apres }] of ecrits) await ecrireDoc(cx, rid, chemin, apres, ++rev.n);
  for (const s of supplements) await ecrireDoc(cx, rid, s.chemin, s.donnees, ++rev.n);
  return { ok: true };
}

export async function push(pool, rid, lots, estAdmin) {
  if (!Array.isArray(lots) || lots.length > 200) throw new Error('lots invalides');
  const resultats = [];
  let derniere = 0;
  for (const lot of lots) {
    if (typeof lot?.id !== 'string' || !/^[0-9a-f-]{36}$/i.test(lot.id)) {
      resultats.push({ id: lot?.id ?? null, ok: false, erreur: 'identifiant de lot invalide' });
      continue;
    }
    const r = await transaction(pool, async (cx) => {
      const rev = { n: await verrouillerResto(cx, rid) };
      const [deja] = await cx.query('SELECT resultat FROM lots_appliques WHERE restaurant_id = ? AND id_lot = ?', [rid, lot.id]);
      if (deja.length) {
        const ancien = typeof deja[0].resultat === 'string' ? JSON.parse(deja[0].resultat) : deja[0].resultat;
        return { ...ancien, rev: rev.n, doublon: true };
      }
      const admin = await estAdmin(cx, lot);
      const res = await appliquerLot(cx, rid, lot, admin, rev);
      await cx.query('INSERT INTO lots_appliques (restaurant_id, id_lot, resultat) VALUES (?, ?, ?)', [rid, lot.id, JSON.stringify(res)]);
      await finirRevision(cx, rid, rev.n);
      return { ...res, rev: rev.n };
    });
    derniere = Math.max(derniere, r.rev);
    resultats.push({ id: lot.id, ok: r.ok, erreur: r.erreur });
  }
  if (derniere) annoncer(rid, derniere);
  return { resultats, rev: derniere };
}

export async function pull(pool, rid, depuis, limite = 1000) {
  const [lignes] = await pool.query(
    'SELECT chemin, donnees, rev FROM documents WHERE restaurant_id = ? AND rev > ? ORDER BY rev LIMIT ?',
    [rid, depuis, limite + 1],
  );
  const plus = lignes.length > limite;
  const docs = lignes.slice(0, limite).map((l) => ({
    chemin: l.chemin,
    donnees: typeof l.donnees === 'string' ? JSON.parse(l.donnees) : l.donnees,
    rev: Number(l.rev),
  }));
  // La révision renvoyée est celle du dernier document envoyé : jamais de trou.
  return { docs, rev: docs.length ? docs[docs.length - 1].rev : depuis, plus };
}

/** Attend une révision supérieure à `depuis` (au plus `delaiMs`). */
export async function attendre(pool, rid, depuis, delaiMs = 25_000) {
  const [[r]] = await pool.query('SELECT rev FROM restaurants WHERE id = ?', [rid]);
  const actuelle = Number(r?.rev ?? 0);
  if (actuelle > depuis) return actuelle;
  return new Promise((resolve) => {
    const nom = `rev:${rid}`;
    const fin = (rev) => {
      clearTimeout(minuteur);
      signaux.off(nom, fin);
      resolve(rev ?? depuis);
    };
    const minuteur = setTimeout(() => fin(null), delaiMs);
    signaux.on(nom, fin);
  });
}

/** Écriture faite par le serveur lui-même (comptes, appareils, version). */
export async function ecrireServeur(pool, rid, ecritures) {
  const rev = await transaction(pool, async (cx) => {
    let n = await verrouillerResto(cx, rid);
    for (const { chemin, donnees, fusion } of ecritures) {
      const avant = fusion ? await lireDoc(cx, rid, chemin, true) : null;
      await ecrireDoc(cx, rid, chemin, fusion && avant ? { ...avant, ...donnees } : donnees, ++n);
    }
    await finirRevision(cx, rid, n);
    return n;
  });
  annoncer(rid, rev);
  return rev;
}
