/**
 * Sauvegarde Firestore quotidienne (section 9.6), conservée 7 à 14 jours
 * via une règle de cycle de vie sur le bucket (voir DEPLOIEMENT.md).
 */
import { v1 } from '@google-cloud/firestore';
import * as logger from 'firebase-functions/logger';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { REGION } from './commun';

export const sauvegardeQuotidienne = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'Africa/Ouagadougou', region: REGION },
  async () => {
    const projet = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
    if (!projet) throw new Error('Projet introuvable');
    const bucket = process.env.BUCKET_SAUVEGARDES ?? `gs://${projet}-sauvegardes`;
    const client = new v1.FirestoreAdminClient();
    const date = new Date().toISOString().slice(0, 10);
    const [op] = await client.exportDocuments({
      name: client.databasePath(projet, '(default)'),
      outputUriPrefix: `${bucket}/${date}`,
      collectionIds: [],
    });
    logger.info('Sauvegarde lancée', { operation: op.name, destination: `${bucket}/${date}` });
  },
);
