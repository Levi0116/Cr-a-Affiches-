/**
 * Outils partagés par toutes les Cloud Functions.
 */
import { createHash } from 'node:crypto';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue, Firestore } from 'firebase-admin/firestore';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

if (getApps().length === 0) initializeApp();

/** Région des fonctions : à aligner sur l'emplacement Firestore du projet. */
export const REGION = process.env.REGION_FONCTIONS ?? 'europe-west1';

export const db = (): Firestore => getFirestore();

export const resto = (rid: string) => db().collection('restaurants').doc(rid);

/** Même hachage que l'application (lib/core/pin.dart). */
export function hacherPin(idRestaurant: string, idEmploye: string, pin: string): string {
  return createHash('sha256').update(`${idRestaurant}:${idEmploye}:${pin}`, 'utf8').digest('hex');
}

export interface Jetons {
  restaurantId?: string;
  admin?: boolean;
  /** Fin (en secondes) d'une élévation administrateur temporaire. */
  adminJusqua?: number;
  appareil?: string;
}

export function jetons(req: CallableRequest<unknown>): Jetons {
  return (req.auth?.token ?? {}) as Jetons;
}

/** Exige un appareil lié et renvoie l'identifiant de son restaurant. */
export function exigerAppareilLie(req: CallableRequest<unknown>): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Appareil non connecté.');
  const rid = jetons(req).restaurantId;
  if (!rid) throw new HttpsError('permission-denied', 'Cet appareil n’est lié à aucun restaurant.');
  return rid;
}

export function estAdmin(j: Jetons, maintenantSec = Date.now() / 1000): boolean {
  return j.admin === true || (j.adminJusqua ?? 0) > maintenantSec;
}

/** Exige les droits administrateur (téléphone du gérant ou élévation par PIN). */
export function exigerAdmin(req: CallableRequest<unknown>): string {
  const rid = exigerAppareilLie(req);
  if (!estAdmin(jetons(req))) {
    throw new HttpsError('permission-denied', 'Réservé à l’administrateur.');
  }
  return rid;
}

/** Ajoute une entrée au journal d'audit (même format que l'application). */
export async function auditer(rid: string, action: string, detail: string, auteur = 'serveur', appareil = 'cloud-functions') {
  await resto(rid).collection('journalAudit').add({
    creeLe: FieldValue.serverTimestamp(),
    heureAppareil: FieldValue.serverTimestamp(),
    employe: auteur,
    appareil,
    action,
    detail,
  });
}

/** Notification visible dans l'application (cloche) — et poussée si possible. */
export async function notifier(rid: string, n: { type: string; titre: string; message: string; cible: 'admin' | 'stock' | 'tous' }) {
  await resto(rid).collection('notifications').add({
    ...n,
    lue: false,
    creeLe: FieldValue.serverTimestamp(),
    heureAppareil: FieldValue.serverTimestamp(),
  });
}
