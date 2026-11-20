"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resto = exports.db = exports.REGION = void 0;
exports.hacherPin = hacherPin;
exports.jetons = jetons;
exports.exigerAppareilLie = exigerAppareilLie;
exports.estAdmin = estAdmin;
exports.exigerAdmin = exigerAdmin;
exports.auditer = auditer;
exports.notifier = notifier;
/**
 * Outils partagés par toutes les Cloud Functions.
 */
const node_crypto_1 = require("node:crypto");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
if ((0, app_1.getApps)().length === 0)
    (0, app_1.initializeApp)();
/** Région des fonctions : à aligner sur l'emplacement Firestore du projet. */
exports.REGION = process.env.REGION_FONCTIONS ?? 'europe-west1';
const db = () => (0, firestore_1.getFirestore)();
exports.db = db;
const resto = (rid) => (0, exports.db)().collection('restaurants').doc(rid);
exports.resto = resto;
/** Même hachage que l'application (lib/core/pin.dart). */
function hacherPin(idRestaurant, idEmploye, pin) {
    return (0, node_crypto_1.createHash)('sha256').update(`${idRestaurant}:${idEmploye}:${pin}`, 'utf8').digest('hex');
}
function jetons(req) {
    return (req.auth?.token ?? {});
}
/** Exige un appareil lié et renvoie l'identifiant de son restaurant. */
function exigerAppareilLie(req) {
    if (!req.auth)
        throw new https_1.HttpsError('unauthenticated', 'Appareil non connecté.');
    const rid = jetons(req).restaurantId;
    if (!rid)
        throw new https_1.HttpsError('permission-denied', 'Cet appareil n’est lié à aucun restaurant.');
    return rid;
}
function estAdmin(j, maintenantSec = Date.now() / 1000) {
    return j.admin === true || (j.adminJusqua ?? 0) > maintenantSec;
}
/** Exige les droits administrateur (téléphone du gérant ou élévation par PIN). */
function exigerAdmin(req) {
    const rid = exigerAppareilLie(req);
    if (!estAdmin(jetons(req))) {
        throw new https_1.HttpsError('permission-denied', 'Réservé à l’administrateur.');
    }
    return rid;
}
/** Ajoute une entrée au journal d'audit (même format que l'application). */
async function auditer(rid, action, detail, auteur = 'serveur', appareil = 'cloud-functions') {
    await (0, exports.resto)(rid).collection('journalAudit').add({
        creeLe: firestore_1.FieldValue.serverTimestamp(),
        heureAppareil: firestore_1.FieldValue.serverTimestamp(),
        employe: auteur,
        appareil,
        action,
        detail,
    });
}
/** Notification visible dans l'application (cloche) — et poussée si possible. */
async function notifier(rid, n) {
    await (0, exports.resto)(rid).collection('notifications').add({
        ...n,
        lue: false,
        creeLe: firestore_1.FieldValue.serverTimestamp(),
        heureAppareil: firestore_1.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=commun.js.map