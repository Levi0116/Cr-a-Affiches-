/**
 * Traitements automatiques (anciennes Cloud Functions) : alertes de stock,
 * demandes de validation, rapport du jour à la clôture de caisse.
 * Appelés dans la même transaction que l'écriture qui les déclenche.
 */
import crypto from 'node:crypto';
import { horodatage, millis } from './valeurs.js';

export function alerteStock(avant, apres) {
  if (!avant || !apres || apres.suiviStock === false || apres.aRecette === true) return null;
  const s0 = Number(avant.stock ?? 0);
  const s1 = Number(apres.stock ?? 0);
  const seuil = Number(apres.seuilAlerte ?? 0);
  if (s1 >= s0) return null;
  if (s1 < 0 && s0 >= 0) return 'negatif';
  if (s1 <= 0 && s0 > 0) return 'rupture';
  if (s1 <= seuil && s0 > seuil) return 'seuil';
  return null;
}

export function messageStock(type, a) {
  const nom = String(a.nom ?? 'Article');
  const stock = Number(a.stock ?? 0);
  return {
    negatif: [`Stock négatif : ${nom}`, `${nom} est à ${stock} : vérifiez les ventes hors ligne et l’inventaire.`],
    rupture: [`Rupture : ${nom}`, `${nom} est épuisé : il est indisponible sur les tablettes.`],
    seuil: [`Stock bas : ${nom}`, `Il reste ${stock} ${a.unite ?? ''} (seuil ${a.seuilAlerte}).`.replace(/\s+\(/, ' (')],
  }[type];
}

export function messageDemande(d) {
  const det = d.detail ?? {};
  const quoi =
    {
      annulation: `Annulation : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
      offert: `Offert : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
      remise: `Remise ${det.valeur}${det.typeRemise === 'pourcentage' ? ' %' : ' F'} (table ${det.numeroTable})`,
      ajustement: `Inventaire : ${det.nom}, écart ${det.ecart}`,
    }[String(d.type)] ?? 'Nouvelle demande';
  return ['Validation demandée', `${quoi} — par ${d.demandeur}. Motif : ${d.motif}`];
}

export const notification = (type, titre, message, cible) => ({
  chemin: `notifications/${crypto.randomUUID()}`,
  donnees: { type, titre, message, cible, lue: false, creeLe: horodatage(), heureAppareil: horodatage() },
});

/** Agrégation du rapport du jour (mêmes règles que lib/core/rapports.dart). */
export function agreger(factures) {
  const vendues = factures.filter((f) => f.statut !== 'emise');
  const articles = new Map();
  const serveuses = new Map();
  let ca = 0;
  let encaisse = 0;
  let credit = 0;
  for (const f of vendues) {
    ca += f.total;
    if (f.statut === 'payee') encaisse += f.total;
    else credit += f.total;
    const s = f.nomServeuse ?? '—';
    serveuses.set(s, (serveuses.get(s) ?? 0) + f.total);
    if (f.partie && !String(f.partie).startsWith('1/')) continue;
    for (const l of f.lignes ?? []) {
      if (l.statut === 'annulee') continue;
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

export function rapportJour(journee, factures) {
  const debut = millis(journee.ouverture) ?? 0;
  const fin = millis(journee.cloture) ?? Date.now();
  const dansJournee = factures.filter((f) => {
    const d = millis(f.date);
    return d !== null && d >= debut && d <= fin;
  });
  return {
    ...agreger(dansJournee),
    ouverture: journee.ouverture ?? null,
    cloture: journee.cloture ?? horodatage(fin),
    fond: journee.fond ?? 0,
    totalTheorique: journee.totalTheorique ?? 0,
    totalCompte: journee.totalCompte ?? 0,
    ecart: journee.ecart ?? 0,
    caissier: journee.caissier ?? '',
    calculeLe: horodatage(),
  };
}
