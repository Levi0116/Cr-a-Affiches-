/**
 * Droits d'écriture (repris des règles Firestore de la version 1, testées).
 *
 * - Rien n'est jamais supprimé.
 * - Les comptes employés et les appareils ne passent JAMAIS par la
 *   synchronisation : uniquement par les routes réservées à l'administrateur.
 * - `admin` : employé administrateur connecté en ligne (session vérifiée par
 *   le serveur) ou téléphone du gérant (appareil administrateur).
 */
import { champsModifies } from './valeurs.js';

const PARAMETRAGE = new Set(['zones', 'categories', 'fournisseurs', 'depenses', 'historiquePrix', 'recettes']);
const JOURNAUX = new Set(['encaissements', 'mouvementsStock', 'mouvementsConsignes', 'journalAudit', 'livraisons']);
const SERVEUR_SEUL = new Set(['employes', 'appareils', 'rapportsJour', 'config']);

const seulement = (modifies, permis) => modifies.every((c) => permis.includes(c));

/**
 * Décide si une écriture est permise. Renvoie null si oui, sinon la raison.
 * @param {object} p
 * @param {string[]} p.segments  chemin découpé, ex. ['sessions','abc','lignes','x']
 * @param {object|null} p.avant  document existant
 * @param {object} p.apres       document après écriture
 * @param {boolean} p.admin
 */
export function refus({ segments, avant, apres, admin }) {
  const col = segments[0];
  const creation = avant === null;
  const modifies = creation ? [] : champsModifies(avant, apres);

  if (segments.length === 1 && col === '@') {
    return admin ? null : 'paramètres du restaurant réservés à l’administrateur';
  }
  if (segments.length % 2 !== 0) return 'chemin invalide';
  if (SERVEUR_SEUL.has(col)) return `« ${col} » est géré uniquement par le serveur`;

  if (segments.length === 4) {
    const sous = segments[2];
    if (col === 'sessions' && sous === 'lignes') {
      if (creation) return null;
      return admin || seulement(modifies, ['annulationDemandee', 'idFacture']) ? null : 'ligne de commande : modification réservée à l’administrateur';
    }
    if (col === 'ardoises' && sous === 'remboursements') return creation ? null : 'un remboursement ne se modifie pas';
    return 'chemin non autorisé';
  }
  if (segments.length !== 2) return 'chemin non autorisé';

  if (PARAMETRAGE.has(col)) return admin ? null : 'paramétrage réservé à l’administrateur';
  if (JOURNAUX.has(col)) return creation ? null : 'un journal ne se modifie pas';

  switch (col) {
    case 'articles':
      if (admin) return null;
      if (creation) return 'création d’article réservée à l’administrateur';
      return seulement(modifies, ['stock', 'nbVentes', 'vides', 'disponible', 'coutMoyen', 'seuilAlerte', 'modifieLe', 'modifiePar'])
        ? null
        : 'prix et menu réservés à l’administrateur';
    case 'tables':
      if (admin) return null;
      if (creation) return 'création de table réservée à l’administrateur';
      return seulement(modifies, ['statut', 'idSession']) ? null : 'table : modification réservée à l’administrateur';
    case 'sessions':
    case 'ardoises':
    case 'compteurs':
      return null;
    case 'factures':
      if (creation) return null;
      if (seulement(modifies, ['nbImpressions'])) return null;
      return avant.statut === 'emise' &&
        seulement(modifies, ['statut', 'montantRecu', 'monnaieRendue', 'payeeLe', 'idJournee', 'idArdoise', 'nbImpressions'])
        ? null
        : 'une facture réglée ne se modifie pas (faire un avoir)';
    case 'avoirs':
      if (!creation) return 'un avoir ne se modifie pas';
      return admin ? null : 'avoir réservé à l’administrateur';
    case 'journeesCaisse':
      if (creation) return null;
      return avant.verrouillee === false ? null : 'journée de caisse clôturée et verrouillée';
    case 'demandesValidation':
      if (creation) return null;
      return admin ? null : 'validation réservée à l’administrateur';
    case 'notifications':
      if (creation) return 'les notifications sont créées par le serveur';
      return seulement(modifies, ['lue', 'lueLe', 'luePar']) ? null : 'notification : seul « lu » peut changer';
    default:
      return `collection inconnue : ${col}`;
  }
}
