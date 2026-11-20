"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifierDemande = exports.surveillerStock = exports.sujet = void 0;
exports.alerteStock = alerteStock;
/**
 * Alertes automatiques (section 5.1) : stock sous le seuil, rupture, stock
 * négatif, demandes de validation. Chaque alerte crée une notification
 * dans l'application et, si possible, une notification poussée (FCM).
 */
const messaging_1 = require("firebase-admin/messaging");
const logger = __importStar(require("firebase-functions/logger"));
const firestore_1 = require("firebase-functions/v2/firestore");
const commun_1 = require("./commun");
/** Sujet FCM auquel s'abonnent les appareils concernés. */
const sujet = (rid, cible) => `${rid}-${cible}`;
exports.sujet = sujet;
async function pousser(rid, cibles, titre, message) {
    for (const c of cibles) {
        try {
            await (0, messaging_1.getMessaging)().send({ topic: (0, exports.sujet)(rid, c), notification: { title: titre, body: message } });
        }
        catch (e) {
            // Sans FCM configuré (ou dans l'émulateur), la notification reste dans l'application.
            logger.warn('Notification poussée impossible', { rid, c, erreur: String(e) });
        }
    }
}
/** Type d'alerte déclenchée par un changement de stock, ou null. */
function alerteStock(avant, apres) {
    if (apres.suiviStock === false || apres.aRecette === true)
        return null;
    const s0 = Number(avant.stock ?? 0);
    const s1 = Number(apres.stock ?? 0);
    const seuil = Number(apres.seuilAlerte ?? 0);
    if (s1 >= s0)
        return null; // seules les baisses alertent
    if (s1 < 0 && s0 >= 0)
        return 'negatif';
    if (s1 <= 0 && s0 > 0)
        return 'rupture';
    if (s1 <= seuil && s0 > seuil)
        return 'seuil';
    return null;
}
exports.surveillerStock = (0, firestore_1.onDocumentUpdated)({ document: 'restaurants/{rid}/articles/{idArticle}', region: commun_1.REGION }, async (event) => {
    const avant = event.data?.before.data();
    const apres = event.data?.after.data();
    if (!avant || !apres)
        return;
    const type = alerteStock(avant, apres);
    if (!type)
        return;
    const rid = event.params.rid;
    const nom = String(apres.nom ?? 'Article');
    const stock = Number(apres.stock ?? 0);
    const [titre, message] = {
        negatif: [`Stock négatif : ${nom}`, `${nom} est à ${stock} : vérifiez les ventes hors ligne et l’inventaire.`],
        rupture: [`Rupture : ${nom}`, `${nom} est épuisé : il est indisponible sur les tablettes.`],
        seuil: [`Stock bas : ${nom}`, `Il reste ${stock} ${apres.unite ?? ''} (seuil ${apres.seuilAlerte}).`.trim()],
    }[type];
    await (0, commun_1.notifier)(rid, { type: `stock_${type}`, titre, message, cible: 'stock' });
    await pousser(rid, ['stock', 'admin'], titre, message);
});
exports.notifierDemande = (0, firestore_1.onDocumentCreated)({ document: 'restaurants/{rid}/demandesValidation/{id}', region: commun_1.REGION }, async (event) => {
    const d = event.data?.data();
    if (!d)
        return;
    const rid = event.params.rid;
    const det = (d.detail ?? {});
    const quoi = {
        annulation: `Annulation : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
        offert: `Offert : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
        remise: `Remise ${det.valeur}${det.typeRemise === 'pourcentage' ? ' %' : ' F'} (table ${det.numeroTable})`,
        ajustement: `Inventaire : ${det.nom}, écart ${det.ecart}`,
    }[String(d.type)] ?? 'Nouvelle demande';
    const titre = 'Validation demandée';
    const message = `${quoi} — par ${d.demandeur}. Motif : ${d.motif}`;
    await (0, commun_1.notifier)(rid, { type: 'validation', titre, message, cible: 'admin' });
    await pousser(rid, ['admin'], titre, message);
});
//# sourceMappingURL=alertes.js.map