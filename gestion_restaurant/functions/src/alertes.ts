/**
 * Alertes automatiques (section 5.1) : stock sous le seuil, rupture, stock
 * négatif, demandes de validation. Chaque alerte crée une notification
 * dans l'application et, si possible, une notification poussée (FCM).
 */
import { getMessaging } from 'firebase-admin/messaging';
import * as logger from 'firebase-functions/logger';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { notifier, REGION } from './commun';

/** Sujet FCM auquel s'abonnent les appareils concernés. */
export const sujet = (rid: string, cible: 'admin' | 'stock') => `${rid}-${cible}`;

async function pousser(rid: string, cibles: ('admin' | 'stock')[], titre: string, message: string) {
  for (const c of cibles) {
    try {
      await getMessaging().send({ topic: sujet(rid, c), notification: { title: titre, body: message } });
    } catch (e) {
      // Sans FCM configuré (ou dans l'émulateur), la notification reste dans l'application.
      logger.warn('Notification poussée impossible', { rid, c, erreur: String(e) });
    }
  }
}

/** Type d'alerte déclenchée par un changement de stock, ou null. */
export function alerteStock(avant: Record<string, unknown>, apres: Record<string, unknown>): 'negatif' | 'rupture' | 'seuil' | null {
  if (apres.suiviStock === false || apres.aRecette === true) return null;
  const s0 = Number(avant.stock ?? 0);
  const s1 = Number(apres.stock ?? 0);
  const seuil = Number(apres.seuilAlerte ?? 0);
  if (s1 >= s0) return null; // seules les baisses alertent
  if (s1 < 0 && s0 >= 0) return 'negatif';
  if (s1 <= 0 && s0 > 0) return 'rupture';
  if (s1 <= seuil && s0 > seuil) return 'seuil';
  return null;
}

export const surveillerStock = onDocumentUpdated(
  { document: 'restaurants/{rid}/articles/{idArticle}', region: REGION },
  async (event) => {
    const avant = event.data?.before.data();
    const apres = event.data?.after.data();
    if (!avant || !apres) return;
    const type = alerteStock(avant, apres);
    if (!type) return;
    const rid = event.params.rid;
    const nom = String(apres.nom ?? 'Article');
    const stock = Number(apres.stock ?? 0);
    const [titre, message] = {
      negatif: [`Stock négatif : ${nom}`, `${nom} est à ${stock} : vérifiez les ventes hors ligne et l’inventaire.`],
      rupture: [`Rupture : ${nom}`, `${nom} est épuisé : il est indisponible sur les tablettes.`],
      seuil: [`Stock bas : ${nom}`, `Il reste ${stock} ${apres.unite ?? ''} (seuil ${apres.seuilAlerte}).`.trim()],
    }[type];
    await notifier(rid, { type: `stock_${type}`, titre, message, cible: 'stock' });
    await pousser(rid, ['stock', 'admin'], titre, message);
  },
);

export const notifierDemande = onDocumentCreated(
  { document: 'restaurants/{rid}/demandesValidation/{id}', region: REGION },
  async (event) => {
    const d = event.data?.data();
    if (!d) return;
    const rid = event.params.rid;
    const det = (d.detail ?? {}) as Record<string, unknown>;
    const quoi =
      {
        annulation: `Annulation : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
        offert: `Offert : ${det.quantite} × ${det.nom} (table ${det.numeroTable})`,
        remise: `Remise ${det.valeur}${det.typeRemise === 'pourcentage' ? ' %' : ' F'} (table ${det.numeroTable})`,
        ajustement: `Inventaire : ${det.nom}, écart ${det.ecart}`,
      }[String(d.type)] ?? 'Nouvelle demande';
    const titre = 'Validation demandée';
    const message = `${quoi} — par ${d.demandeur}. Motif : ${d.motif}`;
    await notifier(rid, { type: 'validation', titre, message, cible: 'admin' });
    await pousser(rid, ['admin'], titre, message);
  },
);
