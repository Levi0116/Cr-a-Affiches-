/**
 * Rapport du jour pré-calculé à la clôture de caisse (section 7, phase 9) :
 * document `rapportsJour/{idJournee}`, lu par le tableau de bord sans
 * relire toutes les factures.
 */
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { REGION, resto } from './commun';

export interface LigneFacture {
  idArticle?: string;
  nom: string;
  quantite: number;
  prixUnitaire: number;
  statut?: string;
  offert?: boolean;
}

export interface FactureBrute {
  total: number;
  statut: string;
  nomServeuse?: string;
  partie?: string;
  lignes?: LigneFacture[];
}

/** Agrégation pure (testée) : mêmes règles que lib/core/rapports.dart. */
export function agreger(factures: FactureBrute[]) {
  const vendues = factures.filter((f) => f.statut !== 'emise');
  const articles = new Map<string, { nom: string; quantite: number; montant: number }>();
  const serveuses = new Map<string, number>();
  let ca = 0;
  let encaisse = 0;
  let credit = 0;
  for (const f of vendues) {
    ca += f.total;
    if (f.statut === 'payee') encaisse += f.total;
    else credit += f.total;
    const s = f.nomServeuse ?? '—';
    serveuses.set(s, (serveuses.get(s) ?? 0) + f.total);
    // Partage en parts égales : les lignes ne comptent qu'une fois.
    if (f.partie && !f.partie.startsWith('1/')) continue;
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

export const rapportJour = onDocumentUpdated(
  { document: 'restaurants/{rid}/journeesCaisse/{idJournee}', region: REGION },
  async (event) => {
    const avant = event.data?.before.data();
    const apres = event.data?.after.data();
    if (!avant || !apres || avant.verrouillee === true || apres.verrouillee !== true) return;
    const rid = event.params.rid;
    const debut = apres.ouverture as Timestamp;
    const fin = (apres.cloture as Timestamp | undefined) ?? Timestamp.now();
    const snap = await resto(rid)
      .collection('factures')
      .where('date', '>=', debut)
      .where('date', '<=', fin)
      .get();
    const agg = agreger(snap.docs.map((d) => d.data() as FactureBrute));
    await resto(rid)
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
        calculeLe: FieldValue.serverTimestamp(),
      });
  },
);
