"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.estAdmin = exports.revoquerAppareil = exports.finElevationAdmin = exports.elevationAdmin = exports.lierAppareil = exports.creerCodeLiaison = exports.BLOCAGE_PIN_MIN = exports.ESSAIS_PIN_MAX = exports.DUREE_ELEVATION_MIN = exports.DUREE_CODE_MIN = void 0;
/**
 * Appareils (section 2.1 et phase 3 du cahier des charges) :
 * - liaison d'une tablette ou d'un ordinateur par code / QR code ;
 * - élévation administrateur temporaire par PIN sur l'ordinateur partagé ;
 * - retrait à distance d'un appareil perdu ou volé.
 */
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const commun_1 = require("./commun");
Object.defineProperty(exports, "estAdmin", { enumerable: true, get: function () { return commun_1.estAdmin; } });
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O ni 1/I
exports.DUREE_CODE_MIN = 15;
exports.DUREE_ELEVATION_MIN = 15;
exports.ESSAIS_PIN_MAX = 5;
exports.BLOCAGE_PIN_MIN = 15;
function nouveauCode() {
    let c = '';
    for (let i = 0; i < 6; i++)
        c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
    return c;
}
/** L'administrateur crée un code de liaison à usage unique (affiché en QR). */
exports.creerCodeLiaison = (0, https_1.onCall)({ region: commun_1.REGION }, async (req) => {
    const rid = (0, commun_1.exigerAdmin)(req);
    const nom = (req.data?.nom ?? '').toString().trim().slice(0, 60);
    const type = req.data?.type ?? 'tablette';
    if (!nom)
        throw new https_1.HttpsError('invalid-argument', 'Donnez un nom à l’appareil.');
    if (!['tablette', 'caisse', 'telephone'].includes(type))
        throw new https_1.HttpsError('invalid-argument', 'Type inconnu.');
    // Seul un téléphone de gérant peut recevoir les droits administrateur permanents.
    const admin = req.data?.admin === true && type === 'telephone';
    let code = nouveauCode();
    for (let essai = 0; essai < 5 && (await (0, commun_1.db)().collection('codesLiaison').doc(code).get()).exists; essai++) {
        code = nouveauCode();
    }
    const expire = firestore_1.Timestamp.fromMillis(Date.now() + exports.DUREE_CODE_MIN * 60_000);
    await (0, commun_1.db)().collection('codesLiaison').doc(code).set({
        restaurantId: rid,
        nom,
        type,
        admin,
        expire,
        utilise: false,
        creeLe: firestore_1.FieldValue.serverTimestamp(),
        creePar: req.auth.uid,
    });
    await (0, commun_1.auditer)(rid, 'code_liaison', `${nom} (${type}${admin ? ', administrateur' : ''})`);
    return { code, expire: expire.toMillis(), restaurantId: rid };
});
/**
 * Un nouvel appareil (connecté en anonyme) présente le code : il reçoit les
 * jetons de son restaurant. Le code ne sert qu'une fois.
 */
exports.lierAppareil = (0, https_1.onCall)({ region: commun_1.REGION }, async (req) => {
    if (!req.auth)
        throw new https_1.HttpsError('unauthenticated', 'Connexion requise.');
    const code = (req.data?.code ?? '').toString().trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (code.length !== 6)
        throw new https_1.HttpsError('invalid-argument', 'Le code comporte 6 caractères.');
    const uid = req.auth.uid;
    const ref = (0, commun_1.db)().collection('codesLiaison').doc(code);
    const infos = await (0, commun_1.db)().runTransaction(async (t) => {
        const snap = await t.get(ref);
        if (!snap.exists)
            throw new https_1.HttpsError('not-found', 'Code inconnu.');
        const c = snap.data();
        if (c.utilise)
            throw new https_1.HttpsError('failed-precondition', 'Ce code a déjà servi.');
        if (c.expire.toMillis() < Date.now())
            throw new https_1.HttpsError('deadline-exceeded', 'Ce code a expiré.');
        t.update(ref, { utilise: true, utilisePar: uid, utiliseLe: firestore_1.FieldValue.serverTimestamp() });
        t.set((0, commun_1.resto)(c.restaurantId).collection('appareils').doc(uid), {
            nom: c.nom,
            type: c.type,
            admin: c.admin === true,
            actif: true,
            lieLe: firestore_1.FieldValue.serverTimestamp(),
            echecsPin: 0,
        });
        return c;
    });
    await (0, auth_1.getAuth)().setCustomUserClaims(uid, {
        restaurantId: infos.restaurantId,
        appareil: uid,
        ...(infos.admin ? { admin: true } : {}),
    });
    await (0, commun_1.auditer)(infos.restaurantId, 'liaison_appareil', `${infos.nom} (${infos.type})`);
    return { restaurantId: infos.restaurantId, nom: infos.nom, type: infos.type, admin: infos.admin };
});
/**
 * Ordinateur de caisse partagé : l'administrateur tape son PIN, vérifié ici
 * (jamais seulement sur l'appareil), et l'appareil reçoit les droits
 * administrateur pour 15 minutes. 5 erreurs → blocage 15 minutes.
 */
exports.elevationAdmin = (0, https_1.onCall)({ region: commun_1.REGION }, async (req) => {
    const rid = (0, commun_1.exigerAppareilLie)(req);
    const uid = req.auth.uid;
    const idEmploye = (req.data?.idEmploye ?? '').toString();
    const pin = (req.data?.pin ?? '').toString();
    if (!/^\d{4}$/.test(pin) || !idEmploye)
        throw new https_1.HttpsError('invalid-argument', 'PIN invalide.');
    const refAppareil = (0, commun_1.resto)(rid).collection('appareils').doc(uid);
    const appareil = (await refAppareil.get()).data() ?? {};
    if (appareil.actif === false)
        throw new https_1.HttpsError('permission-denied', 'Appareil retiré.');
    const bloque = appareil.bloqueJusqua?.toMillis() ?? 0;
    if (bloque > Date.now()) {
        throw new https_1.HttpsError('resource-exhausted', 'Trop d’essais : réessayez dans quelques minutes.');
    }
    const emp = (await (0, commun_1.resto)(rid).collection('employes').doc(idEmploye).get()).data();
    const ok = emp && emp.role === 'admin' && emp.actif !== false && emp.pinHash === (0, commun_1.hacherPin)(rid, idEmploye, pin);
    if (!ok) {
        const echecs = (appareil.echecsPin ?? 0) + 1;
        await refAppareil.set({
            echecsPin: echecs >= exports.ESSAIS_PIN_MAX ? 0 : echecs,
            ...(echecs >= exports.ESSAIS_PIN_MAX ? { bloqueJusqua: firestore_1.Timestamp.fromMillis(Date.now() + exports.BLOCAGE_PIN_MIN * 60_000) } : {}),
        }, { merge: true });
        await (0, commun_1.auditer)(rid, 'echec_pin_admin', `Essai ${echecs} sur l’appareil ${appareil.nom ?? uid}`);
        throw new https_1.HttpsError('permission-denied', 'Code incorrect.');
    }
    const jusqua = Math.floor(Date.now() / 1000) + exports.DUREE_ELEVATION_MIN * 60;
    const actuels = (0, commun_1.jetons)(req);
    await (0, auth_1.getAuth)().setCustomUserClaims(uid, {
        restaurantId: rid,
        appareil: uid,
        ...(actuels.admin ? { admin: true } : {}),
        adminJusqua: jusqua,
    });
    await refAppareil.set({ echecsPin: 0 }, { merge: true });
    await (0, commun_1.auditer)(rid, 'elevation_admin', `${emp.nom} sur ${appareil.nom ?? uid} (15 min)`, emp.nom, uid);
    return { jusqua: jusqua * 1000 };
});
/** Fin anticipée de l'élévation (l'administrateur se déconnecte). */
exports.finElevationAdmin = (0, https_1.onCall)({ region: commun_1.REGION }, async (req) => {
    const rid = (0, commun_1.exigerAppareilLie)(req);
    const actuels = (0, commun_1.jetons)(req);
    await (0, auth_1.getAuth)().setCustomUserClaims(req.auth.uid, {
        restaurantId: rid,
        appareil: req.auth.uid,
        ...(actuels.admin ? { admin: true } : {}),
    });
    return { ok: true };
});
/** Retrait à distance d'un appareil perdu ou volé (section 6.6). */
exports.revoquerAppareil = (0, https_1.onCall)({ region: commun_1.REGION }, async (req) => {
    const rid = (0, commun_1.exigerAdmin)(req);
    const cible = (req.data?.uid ?? '').toString();
    if (!cible)
        throw new https_1.HttpsError('invalid-argument', 'Appareil manquant.');
    if (cible === req.auth.uid)
        throw new https_1.HttpsError('failed-precondition', 'Impossible de retirer cet appareil depuis lui-même.');
    const ref = (0, commun_1.resto)(rid).collection('appareils').doc(cible);
    const snap = await ref.get();
    if (!snap.exists)
        throw new https_1.HttpsError('not-found', 'Appareil inconnu.');
    await (0, auth_1.getAuth)().setCustomUserClaims(cible, {});
    await (0, auth_1.getAuth)().revokeRefreshTokens(cible);
    await (0, auth_1.getAuth)().updateUser(cible, { disabled: true });
    await ref.update({ actif: false, retireLe: firestore_1.FieldValue.serverTimestamp(), retirePar: req.auth.uid });
    await (0, commun_1.auditer)(rid, 'retrait_appareil', snap.data().nom ?? cible);
    return { ok: true };
});
//# sourceMappingURL=appareils.js.map