/**
 * Liaison des appareils, connexion par PIN, gestion des comptes et des
 * appareils (réservée à l'administrateur connecté en ligne).
 */
import crypto from 'node:crypto';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { exigerAdminEnLigne, exigerAppareil } from '../auth.js';
import { transaction } from '../bd.js';
import { lireDoc, lireDocs } from '../documents.js';
import {
  BLOCAGE_MIN, DUREE_CODE_MIN, ErreurApi, ESSAIS_MAX, empreinte, hacherPin, nouveauCode, nouveauJeton, pinCorrect,
  signerSession, verifierFormatPin,
} from '../securite.js';
import { ecrireServeur } from '../sync.js';
import { horodatage } from '../valeurs.js';

const ROLES = ['serveuse', 'caissier', 'stock', 'admin'];
const TYPES = ['tablette', 'caisse', 'telephone'];
const texte = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : '');

export function routesComptes(pool, cfg) {
  const r = Router();
  const appareil = exigerAppareil(pool);
  const admin = exigerAdminEnLigne(cfg.secret);
  const limiteSensible = rateLimit({ windowMs: 15 * 60_000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false, message: { erreur: 'Trop de tentatives : réessayez dans quelques minutes.' } });

  const audit = (rid, auteur, action, detail) => ({
    chemin: `journalAudit/${crypto.randomUUID()}`,
    donnees: { creeLe: horodatage(), heureAppareil: horodatage(), employe: auteur, idEmploye: '', appareil: 'serveur', action, detail },
  });

  // --- Liaison d'un nouvel appareil avec un code créé par l'administrateur.
  r.post('/liaison', limiteSensible, async (req, res) => {
    const code = texte(req.body?.code, 12).toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (code.length !== 8) throw new ErreurApi(400, 'Code de liaison invalide.');
    const jeton = nouveauJeton();
    const lien = await transaction(pool, async (cx) => {
      const [c] = await cx.query('SELECT * FROM codes_liaison WHERE code = ? FOR UPDATE', [code]);
      if (!c.length || c[0].utilise || new Date(c[0].expire) < new Date()) throw new ErreurApi(400, 'Code inconnu, expiré ou déjà utilisé.');
      const id = crypto.randomUUID();
      await cx.query('UPDATE codes_liaison SET utilise = 1 WHERE code = ?', [code]);
      await cx.query(
        'INSERT INTO appareils (id, restaurant_id, nom, type, admin, jeton_empreinte) VALUES (?, ?, ?, ?, ?, ?)',
        [id, c[0].restaurant_id, c[0].nom, c[0].type, c[0].admin, empreinte(jeton)],
      );
      const [[resto]] = await cx.query('SELECT nom FROM restaurants WHERE id = ?', [c[0].restaurant_id]);
      return { id, rid: c[0].restaurant_id, nom: c[0].nom, type: c[0].type, admin: !!c[0].admin, nomResto: resto.nom };
    });
    await ecrireServeur(pool, lien.rid, [
      { chemin: `appareils/${lien.id}`, donnees: { nom: lien.nom, type: lien.type, admin: lien.admin, revoque: false, lieLe: horodatage() } },
      audit(lien.rid, 'serveur', 'liaison_appareil', `${lien.nom} (${lien.type})`),
    ]);
    res.json({
      jeton,
      appareil: { id: lien.id, nom: lien.nom, type: lien.type, admin: lien.admin },
      restaurant: { id: lien.rid, nom: lien.nomResto },
    });
  });

  r.get('/appareil', appareil, async (req, res) => {
    const [[resto]] = await pool.query('SELECT nom FROM restaurants WHERE id = ?', [req.appareil.rid]);
    res.json({ appareil: req.appareil, restaurant: { id: req.appareil.rid, nom: resto.nom }, version: cfg.version });
  });

  // --- Connexion d'un employé par PIN (blocage après 5 erreurs).
  r.post('/connexion', limiteSensible, appareil, async (req, res) => {
    const { rid } = req.appareil;
    const id = texte(req.body?.employeId, 36);
    const pin = texte(req.body?.pin, 12);
    const employe = id ? await lireDoc(pool, rid, `employes/${id}`) : null;
    if (!employe || employe.actif === false || employe.supprime === true) throw new ErreurApi(400, 'Employé inconnu ou désactivé.');
    const [[essai]] = await pool.query('SELECT echecs, bloque_jusqua FROM essais_pin WHERE restaurant_id = ? AND employe_id = ?', [rid, id]);
    if (essai?.bloque_jusqua && new Date(essai.bloque_jusqua) > new Date()) {
      const min = Math.ceil((new Date(essai.bloque_jusqua) - new Date()) / 60_000);
      throw new ErreurApi(423, `Trop d’erreurs : compte bloqué encore ${min} min.`, 'bloque');
    }
    if (!pinCorrect(pin, employe.pinVerif)) {
      const echecs = (essai?.echecs ?? 0) + 1;
      const bloque = echecs >= ESSAIS_MAX ? new Date(Date.now() + BLOCAGE_MIN * 60_000) : null;
      await pool.query(
        `INSERT INTO essais_pin (restaurant_id, employe_id, echecs, bloque_jusqua) VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE echecs = VALUES(echecs), bloque_jusqua = VALUES(bloque_jusqua)`,
        [rid, id, bloque ? 0 : echecs, bloque],
      );
      if (bloque) {
        await ecrireServeur(pool, rid, [audit(rid, employe.nom, 'pin_bloque', `${ESSAIS_MAX} codes faux sur ${req.appareil.nom}`)]);
        throw new ErreurApi(423, `Trop d’erreurs : compte bloqué ${BLOCAGE_MIN} min.`, 'bloque');
      }
      throw new ErreurApi(401, `Code incorrect (${ESSAIS_MAX - echecs} essai(s) restant(s)).`, 'pin_faux');
    }
    await pool.query('DELETE FROM essais_pin WHERE restaurant_id = ? AND employe_id = ?', [rid, id]);
    const session = signerSession(cfg.secret, { sub: id, rid, role: employe.role, app: req.appareil.id, nom: employe.nom }, cfg.dureeSessionH);
    res.json({ session, employe: { id, nom: employe.nom, role: employe.role }, expireDansH: cfg.dureeSessionH });
  });

  // --- Comptes employés : l'administrateur seul crée, modifie, supprime.
  r.post('/employes', appareil, admin, async (req, res) => {
    const nom = texte(req.body?.nom, 60);
    const role = req.body?.role;
    const pin = texte(req.body?.pin, 12);
    if (nom.length < 2) throw new ErreurApi(400, 'Nom trop court.');
    if (!ROLES.includes(role)) throw new ErreurApi(400, 'Rôle invalide.');
    const e = verifierFormatPin(pin);
    if (e) throw new ErreurApi(400, e);
    const { rid } = req.appareil;
    await refuserPinDejaPris(rid, pin);
    const id = crypto.randomUUID();
    await ecrireServeur(pool, rid, [
      { chemin: `employes/${id}`, donnees: { nom, role, actif: true, supprime: false, pinVerif: hacherPin(pin), creeLe: horodatage(), creePar: req.session.sub } },
      audit(rid, req.session.nom, 'compte_cree', `${nom} (${role})`),
    ]);
    res.status(201).json({ id, nom, role });
  });

  r.patch('/employes/:id', appareil, admin, async (req, res) => {
    const { rid } = req.appareil;
    const id = texte(req.params.id, 36);
    const avant = await lireDoc(pool, rid, `employes/${id}`);
    if (!avant || avant.supprime) throw new ErreurApi(404, 'Compte introuvable.');
    const maj = {};
    const changements = [];
    if (req.body?.nom !== undefined) {
      const nom = texte(req.body.nom, 60);
      if (nom.length < 2) throw new ErreurApi(400, 'Nom trop court.');
      maj.nom = nom;
      changements.push(`nom → ${nom}`);
    }
    if (req.body?.role !== undefined) {
      if (!ROLES.includes(req.body.role)) throw new ErreurApi(400, 'Rôle invalide.');
      if (avant.role === 'admin' && req.body.role !== 'admin') await garderUnAdmin(rid, id);
      maj.role = req.body.role;
      changements.push(`rôle → ${req.body.role}`);
    }
    if (req.body?.actif !== undefined) {
      if (req.body.actif === false) {
        if (id === req.session.sub) throw new ErreurApi(400, 'Vous ne pouvez pas désactiver votre propre compte.');
        if (avant.role === 'admin') await garderUnAdmin(rid, id);
      }
      maj.actif = req.body.actif === true;
      changements.push(maj.actif ? 'réactivé' : 'désactivé');
    }
    if (req.body?.pin !== undefined) {
      const pin = texte(req.body.pin, 12);
      const e = verifierFormatPin(pin);
      if (e) throw new ErreurApi(400, e);
      await refuserPinDejaPris(rid, pin, id);
      maj.pinVerif = hacherPin(pin);
      changements.push('code PIN changé');
      await pool.query('DELETE FROM essais_pin WHERE restaurant_id = ? AND employe_id = ?', [rid, id]);
    }
    if (!changements.length) throw new ErreurApi(400, 'Aucune modification.');
    maj.modifieLe = horodatage();
    maj.modifiePar = req.session.sub;
    await ecrireServeur(pool, rid, [
      { chemin: `employes/${id}`, donnees: maj, fusion: true },
      audit(rid, req.session.nom, 'compte_modifie', `${avant.nom} : ${changements.join(', ')}`),
    ]);
    res.json({ ok: true });
  });

  r.delete('/employes/:id', appareil, admin, async (req, res) => {
    const { rid } = req.appareil;
    const id = texte(req.params.id, 36);
    if (id === req.session.sub) throw new ErreurApi(400, 'Vous ne pouvez pas supprimer votre propre compte.');
    const avant = await lireDoc(pool, rid, `employes/${id}`);
    if (!avant || avant.supprime) throw new ErreurApi(404, 'Compte introuvable.');
    if (avant.role === 'admin') await garderUnAdmin(rid, id);
    // Le compte disparaît des listes ; son nom reste lisible dans l'historique (factures, journal).
    await ecrireServeur(pool, rid, [
      { chemin: `employes/${id}`, donnees: { actif: false, supprime: true, pinVerif: null, supprimeLe: horodatage(), supprimePar: req.session.sub }, fusion: true },
      audit(rid, req.session.nom, 'compte_supprime', avant.nom),
    ]);
    res.json({ ok: true });
  });

  async function employesActifs(rid) {
    return (await lireDocs(pool, rid, 'employes')).filter((d) => d.donnees.supprime !== true);
  }
  async function garderUnAdmin(rid, saufId) {
    const admins = (await employesActifs(rid)).filter((d) => d.donnees.role === 'admin' && d.donnees.actif !== false && d.chemin !== `employes/${saufId}`);
    if (!admins.length) throw new ErreurApi(400, 'Il doit toujours rester au moins un administrateur actif.');
  }
  /** Deux employés ne peuvent pas avoir le même code (sinon l'un se connecterait en tant que l'autre). */
  async function refuserPinDejaPris(rid, pin, saufId) {
    for (const d of await employesActifs(rid)) {
      if (d.chemin !== `employes/${saufId}` && pinCorrect(pin, d.donnees.pinVerif)) throw new ErreurApi(400, 'Ce code est déjà utilisé par un autre employé.');
    }
  }

  // --- Appareils : codes de liaison, liste, retrait à distance.
  r.post('/appareils/codes', appareil, admin, async (req, res) => {
    const { rid } = req.appareil;
    const type = TYPES.includes(req.body?.type) ? req.body.type : 'tablette';
    const nom = texte(req.body?.nom, 60) || { tablette: 'Tablette', caisse: 'Caisse', telephone: 'Téléphone' }[type];
    const estAdmin = req.body?.admin === true && type === 'telephone';
    const code = nouveauCode();
    const expire = new Date(Date.now() + DUREE_CODE_MIN * 60_000);
    await pool.query('INSERT INTO codes_liaison (code, restaurant_id, nom, type, admin, expire) VALUES (?, ?, ?, ?, ?, ?)', [code, rid, nom, type, estAdmin, expire]);
    res.status(201).json({ code, expire: expire.toISOString(), nom, type, admin: estAdmin });
  });

  r.delete('/appareils/:id', appareil, admin, async (req, res) => {
    const { rid } = req.appareil;
    const id = texte(req.params.id, 36);
    if (id === req.appareil.id) throw new ErreurApi(400, 'Retirez cet appareil depuis un autre appareil.');
    const [r2] = await pool.query('UPDATE appareils SET revoque = 1 WHERE id = ? AND restaurant_id = ?', [id, rid]);
    if (!r2.affectedRows) throw new ErreurApi(404, 'Appareil introuvable.');
    const [[a]] = await pool.query('SELECT nom FROM appareils WHERE id = ?', [id]);
    await ecrireServeur(pool, rid, [
      { chemin: `appareils/${id}`, donnees: { revoque: true, revoqueLe: horodatage() }, fusion: true },
      audit(rid, req.session.nom, 'appareil_retire', a.nom),
    ]);
    res.json({ ok: true });
  });

  return r;
}
