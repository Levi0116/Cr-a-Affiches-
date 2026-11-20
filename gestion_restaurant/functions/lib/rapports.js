"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rapportJour = void 0;
exports.agreger = agreger;
/**
 * Rapport du jour pré-calculé à la clôture de caisse (section 7, phase 9) :
 * document `rapportsJour/{idJournee}`, lu par le tableau de bord sans
 * relire toutes les factures.
 */
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const commun_1 = require("./commun");
/** Agrégation pure (testée) : mêmes règles que lib/core/rapports.dart. */
function agreger(factures) {
    const vendues = factures.filter((f) => f.statut !== 'emise');
    const articles = new Map();
    const serveuses = new Map();
    let ca = 0;
    let encaisse = 0;
    let credit = 0;
    for (const f of vendues) {
        ca += f.total;
        if (f.statut === 'payee')
            encaisse += f.total;
        else
            credit += f.total;
        const s = f.nomServeuse ?? '—';
        serveuses.set(s, (serveuses.get(s) ?? 0) + f.total);
        // Partage en parts égales : les lignes ne comptent qu'une fois.
        if (f.partie && !f.partie.startsWith('1/'))
            continue;
        for (const l of f.lignes ?? []) {
            if (l.statut === 'annulee')
                continue;
            const cle = l.idArticle ?? l.nom;
            const a = articles.get(cle) ?? { nom: l.nom, quantite: 0, montant: 0 };
            a.quantite += l.quantite;
            a.montant += l.offert ? 0 : l.quantite * l.prixUnitaire;
            articles.set(cle, a);
        }
    }
    return {
        chiffreAffaires: ca,
        encaisse,
        credit,
        nbFactures: vendues.length,
        panierMoyen: vendues.length ? Math.round(ca / vendues.length) : 0,
        articles: [...articles.values()].sort((a, b) => b.montant - a.montant).slice(0, 50),
        serveuses: [...serveuses.entries()].map(([nom, montant]) => ({ nom, montant })).sort((a, b) => b.montant - a.montant),
    };
}
exports.rapportJour = (0, firestore_2.onDocumentUpdated)({ document: 'restaurants/{rid}/journeesCaisse/{idJournee}', region: commun_1.REGION }, async (event) => {
    const avant = event.data?.before.data();
    const apres = event.data?.after.data();
    if (!avant || !apres || avant.verrouillee === true || apres.verrouillee !== true)
        return;
    const rid = event.params.rid;
    const debut = apres.ouverture;
    const fin = apres.cloture ?? firestore_1.Timestamp.now();
    const snap = await (0, commun_1.resto)(rid)
        .collection('factures')
        .where('date', '>=', debut)
        .where('date', '<=', fin)
        .get();
    const agg = agreger(snap.docs.map((d) => d.data()));
    await (0, commun_1.resto)(rid)
        .collection('rapportsJour')
        .doc(event.params.idJournee)
        .set({
        ...agg,
        ouverture: debut,
        cloture: fin,
        fond: apres.fond ?? 0,
        totalTheorique: apres.totalTheorique ?? 0,
        totalCompte: apres.totalCompte ?? 0,
        ecart: apres.ecart ?? 0,
        caissier: apres.caissier ?? '',
        calculeLe: firestore_1.FieldValue.serverTimestamp(),
    });
});
//# sourceMappingURL=rapports.js.map