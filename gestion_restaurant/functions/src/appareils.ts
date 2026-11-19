/**
 * Appareils (section 2.1 et phase 3 du cahier des charges) :
 * - liaison d'une tablette ou d'un ordinateur par code / QR code ;
 * - élévation administrateur temporaire par PIN sur l'ordinateur partagé ;
 * - retrait à distance d'un appareil perdu ou volé.
 */
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { auditer, db, estAdmin, exigerAdmin, exigerAppareilLie, hacherPin, jetons, REGION, resto } from './commun';

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O ni 1/I
export const DUREE_CODE_MIN = 15;
export const DUREE_ELEVATION_MIN = 15;
export const ESSAIS_PIN_MAX = 5;
export const BLOCAGE_PIN_MIN = 15;

function nouveauCode(): string {
  let c = '';
  for (let i = 0; i < 6; i++) c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  return c;
}

type TypeAppareil = 'tablette' | 'caisse' | 'telephone';

/** L'administrateur crée un code de liaison à usage unique (affiché en QR). */
export const creerCodeLiaison = onCall<{ nom?: string; type?: TypeAppareil; admin?: boolean }>(
  { region: REGION },
  async (req) => {
    const rid = exigerAdmin(req);
    const nom = (req.data?.nom ?? '').toString().trim().slice(0, 60);
    const type = req.data?.type ?? 'tablette';
    if (!nom) throw new HttpsError('invalid-argument', 'Donnez un nom à l’appareil.');
    if (!['tablette', 'caisse', 'telephone'].includes(type)) throw new HttpsError('invalid-argument', 'Type inconnu.');
    // Seul un téléphone de gérant peut recevoir les droits administrateur permanents.
    const admin = req.data?.admin === true && type === 'telephone';
    let code = nouveauCode();
    for (let essai = 0; essai < 5 && (await db().collection('codesLiaison').doc(code).get()).exists; essai++) {
      code = nouveauCode();
    }
    const expire = Timestamp.fromMillis(Date.now() + DUREE_CODE_MIN * 60_000);
    await db().collection('codesLiaison').doc(code).set({
      restaurantId: rid,
      nom,
      type,
      admin,
      expire,
      utilise: false,
      creeLe: FieldValue.serverTimestamp(),
      creePar: req.auth!.uid,
    });
    await auditer(rid, 'code_liaison', `${nom} (${type}${admin ? ', administrateur' : ''})`);
    return { code, expire: expire.toMillis(), restaurantId: rid };
  },
);

/**
 * Un nouvel appareil (connecté en anonyme) présente le code : il reçoit les
 * jetons de son restaurant. Le code ne sert qu'une fois.
 */
export const lierAppareil = onCall<{ code?: string }>({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Connexion requise.');
  const code = (req.data?.code ?? '').toString().trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (code.length !== 6) throw new HttpsError('invalid-argument', 'Le code comporte 6 caractères.');
  const uid = req.auth.uid;
  const ref = db().collection('codesLiaison').doc(code);
  const infos = await db().runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Code inconnu.');
    const c = snap.data()!;
    if (c.utilise) throw new HttpsError('failed-precondition', 'Ce code a déjà servi.');
    if ((c.expire as Timestamp).toMillis() < Date.now()) throw new HttpsError('deadline-exceeded', 'Ce code a expiré.');
    t.update(ref, { utilise: true, utilisePar: uid, utiliseLe: FieldValue.serverTimestamp() });
    t.set(resto(c.restaurantId).collection('appareils').doc(uid), {
      nom: c.nom,
      type: c.type,
      admin: c.admin === true,
      actif: true,
      lieLe: FieldValue.serverTimestamp(),
      echecsPin: 0,
    });
    return c as { restaurantId: string; nom: string; type: string; admin: boolean };
  });
  await getAuth().setCustomUserClaims(uid, {
    restaurantId: infos.restaurantId,
    appareil: uid,
    ...(infos.admin ? { admin: true } : {}),
  });
  await auditer(infos.restaurantId, 'liaison_appareil', `${infos.nom} (${infos.type})`);
  return { restaurantId: infos.restaurantId, nom: infos.nom, type: infos.type, admin: infos.admin };
});

/**
 * Ordinateur de caisse partagé : l'administrateur tape son PIN, vérifié ici
 * (jamais seulement sur l'appareil), et l'appareil reçoit les droits
 * administrateur pour 15 minutes. 5 erreurs → blocage 15 minutes.
 */
export const elevationAdmin = onCall<{ idEmploye?: string; pin?: string }>({ region: REGION }, async (req) => {
  const rid = exigerAppareilLie(req);
  const uid = req.auth!.uid;
  const idEmploye = (req.data?.idEmploye ?? '').toString();
  const pin = (req.data?.pin ?? '').toString();
  if (!/^\d{4}$/.test(pin) || !idEmploye) throw new HttpsError('invalid-argument', 'PIN invalide.');
  const refAppareil = resto(rid).collection('appareils').doc(uid);
  const appareil = (await refAppareil.get()).data() ?? {};
  if (appareil.actif === false) throw new HttpsError('permission-denied', 'Appareil retiré.');
  const bloque = (appareil.bloqueJusqua as Timestamp | undefined)?.toMillis() ?? 0;
  if (bloque > Date.now()) {
    throw new HttpsError('resource-exhausted', 'Trop d’essais : réessayez dans quelques minutes.');
  }
  const emp = (await resto(rid).collection('employes').doc(idEmploye).get()).data();
  const ok = emp && emp.role === 'admin' && emp.actif !== false && emp.pinHash === hacherPin(rid, idEmploye, pin);
  if (!ok) {
    const echecs = (appareil.echecsPin ?? 0) + 1;
    await refAppareil.set(
      {
        echecsPin: echecs >= ESSAIS_PIN_MAX ? 0 : echecs,
        ...(echecs >= ESSAIS_PIN_MAX ? { bloqueJusqua: Timestamp.fromMillis(Date.now() + BLOCAGE_PIN_MIN * 60_000) } : {}),
      },
      { merge: true },
    );
    await auditer(rid, 'echec_pin_admin', `Essai ${echecs} sur l’appareil ${appareil.nom ?? uid}`);
    throw new HttpsError('permission-denied', 'Code incorrect.');
  }
  const jusqua = Math.floor(Date.now() / 1000) + DUREE_ELEVATION_MIN * 60;
  const actuels = jetons(req);
  await getAuth().setCustomUserClaims(uid, {
    restaurantId: rid,
    appareil: uid,
    ...(actuels.admin ? { admin: true } : {}),
    adminJusqua: jusqua,
  });
  await refAppareil.set({ echecsPin: 0 }, { merge: true });
  await auditer(rid, 'elevation_admin', `${emp!.nom} sur ${appareil.nom ?? uid} (15 min)`, emp!.nom, uid);
  return { jusqua: jusqua * 1000 };
});

/** Fin anticipée de l'élévation (l'administrateur se déconnecte). */
export const finElevationAdmin = onCall({ region: REGION }, async (req) => {
  const rid = exigerAppareilLie(req);
  const actuels = jetons(req);
  await getAuth().setCustomUserClaims(req.auth!.uid, {
    restaurantId: rid,
    appareil: req.auth!.uid,
    ...(actuels.admin ? { admin: true } : {}),
  });
  return { ok: true };
});

/** Retrait à distance d'un appareil perdu ou volé (section 6.6). */
export const revoquerAppareil = onCall<{ uid?: string }>({ region: REGION }, async (req) => {
  const rid = exigerAdmin(req);
  const cible = (req.data?.uid ?? '').toString();
  if (!cible) throw new HttpsError('invalid-argument', 'Appareil manquant.');
  if (cible === req.auth!.uid) throw new HttpsError('failed-precondition', 'Impossible de retirer cet appareil depuis lui-même.');
  const ref = resto(rid).collection('appareils').doc(cible);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Appareil inconnu.');
  await getAuth().setCustomUserClaims(cible, {});
  await getAuth().revokeRefreshTokens(cible);
  await getAuth().updateUser(cible, { disabled: true });
  await ref.update({ actif: false, retireLe: FieldValue.serverTimestamp(), retirePar: req.auth!.uid });
  await auditer(rid, 'retrait_appareil', snap.data()!.nom ?? cible);
  return { ok: true };
});

export { estAdmin };
