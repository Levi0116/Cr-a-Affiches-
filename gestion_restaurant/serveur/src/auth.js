/**
 * Authentification à deux niveaux :
 *  1. l'APPAREIL (jeton remis à la liaison, révocable) : en-tête
 *     `Authorization: Appareil <jeton>` ;
 *  2. l'EMPLOYÉ connecté par code PIN vérifié par le serveur : en-tête
 *     `X-Session: <jeton signé>`.
 */
import { empreinte, ErreurApi, lireSession } from './securite.js';

export function exigerAppareil(pool) {
  return async (req, _res, next) => {
    const entete = req.get('authorization') ?? '';
    const m = /^Appareil ([A-Za-z0-9_-]{20,})$/.exec(entete);
    if (!m) throw new ErreurApi(401, 'Appareil non lié.', 'appareil_absent');
    const [r] = await pool.query(
      'SELECT id, restaurant_id, nom, type, admin, revoque, roles FROM appareils WHERE jeton_empreinte = ?',
      [empreinte(m[1])],
    );
    if (!r.length || r[0].revoque) throw new ErreurApi(401, 'Cet appareil a été retiré ou n’est pas lié.', 'appareil_revoque');
    req.appareil = { id: r[0].id, rid: r[0].restaurant_id, nom: r[0].nom, type: r[0].type, admin: !!r[0].admin, roles: lireRoles(r[0].roles) };
    pool.query('UPDATE appareils SET vu_le = CURRENT_TIMESTAMP(3) WHERE id = ?', [r[0].id]).catch(() => {});
    next();
  };
}

/** Session employé valide maintenant (sinon null). */
export function sessionDe(req, secret) {
  const j = req.get('x-session');
  if (!j) return null;
  const s = lireSession(secret, j);
  if (!s || s.rid !== req.appareil?.rid || s.app !== req.appareil?.id) return null;
  return s;
}

/**
 * Actions sensibles (comptes, appareils) : administrateur connecté EN LIGNE,
 * PIN vérifié par le serveur. Le téléphone du gérant seul ne suffit pas.
 */
export function exigerAdminEnLigne(secret) {
  return (req, _res, next) => {
    const s = sessionDe(req, secret);
    if (!s) throw new ErreurApi(401, 'Session expirée : reconnectez-vous.', 'session_absente');
    if (s.role !== 'admin') throw new ErreurApi(403, 'Réservé à l’administrateur.', 'interdit');
    req.session = s;
    next();
  };
}

/** Postes autorisés sur un appareil ('' = tous, pour les appareils liés avant la version 2.1). */
export function lireRoles(texte) {
  return String(texte ?? '').split(',').map((x) => x.trim()).filter(Boolean);
}
