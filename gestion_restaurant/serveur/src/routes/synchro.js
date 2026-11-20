import { Router } from 'express';
import { exigerAppareil } from '../auth.js';
import { lireDoc } from '../documents.js';
import { ErreurApi, lireSession } from '../securite.js';
import { attendre, pull, push } from '../sync.js';

export function routesSynchro(pool, cfg) {
  const r = Router();
  r.use(exigerAppareil(pool));

  r.get('/pull', async (req, res) => {
    const depuis = Math.max(0, Number.parseInt(req.query.depuis ?? '0', 10) || 0);
    res.json(await pull(pool, req.appareil.rid, depuis));
  });

  r.get('/attendre', async (req, res) => {
    const depuis = Math.max(0, Number.parseInt(req.query.depuis ?? '0', 10) || 0);
    res.set('Cache-Control', 'no-store');
    res.json({ rev: await attendre(pool, req.appareil.rid, depuis) });
  });

  r.post('/push', async (req, res) => {
    const lots = req.body?.lots;
    if (!Array.isArray(lots)) throw new ErreurApi(400, 'lots manquants');
    const { rid } = req.appareil;
    // Droits administrateur d'un lot : session administrateur valide au
    // moment où le lot a été créé (même hors ligne), ou téléphone du gérant
    // avec un auteur administrateur.
    const estAdmin = async (cx, lot) => {
      const auteur = typeof lot.auteur === 'string' ? await lireDoc(cx, rid, `employes/${lot.auteur.slice(0, 36)}`) : null;
      if (!auteur || auteur.role !== 'admin' || auteur.supprime === true) return false;
      if (req.appareil.admin) return true;
      if (typeof lot.session !== 'string') return false;
      const faitLe = Number(lot.faitLe ?? Date.now());
      const retardS = Math.max(0, Math.ceil((Date.now() - Math.min(faitLe, Date.now())) / 1000));
      const s = lireSession(cfg.secret, lot.session, Math.min(retardS, 7 * 24 * 3600));
      return !!s && s.rid === rid && s.app === req.appareil.id && s.role === 'admin' && s.sub === lot.auteur;
    };
    res.json(await push(pool, rid, lots, estAdmin));
  });

  return r;
}
