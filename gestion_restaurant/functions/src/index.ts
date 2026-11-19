/**
 * Cloud Functions du logiciel de gestion de restaurant.
 * Déploiement : firebase deploy --only functions (voir DEPLOIEMENT.md).
 */
import { setGlobalOptions } from 'firebase-functions/v2';
import { REGION } from './commun';

setGlobalOptions({ region: REGION, maxInstances: 10 });

export { creerCodeLiaison, lierAppareil, elevationAdmin, finElevationAdmin, revoquerAppareil } from './appareils';
export { surveillerStock, notifierDemande } from './alertes';
export { rapportJour } from './rapports';
export { sauvegardeQuotidienne } from './sauvegarde';
