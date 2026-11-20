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
exports.sauvegardeQuotidienne = void 0;
/**
 * Sauvegarde Firestore quotidienne (section 9.6), conservée 7 à 14 jours
 * via une règle de cycle de vie sur le bucket (voir DEPLOIEMENT.md).
 */
const firestore_1 = require("@google-cloud/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const commun_1 = require("./commun");
exports.sauvegardeQuotidienne = (0, scheduler_1.onSchedule)({ schedule: 'every day 04:00', timeZone: 'Africa/Ouagadougou', region: commun_1.REGION }, async () => {
    const projet = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
    if (!projet)
        throw new Error('Projet introuvable');
    const bucket = process.env.BUCKET_SAUVEGARDES ?? `gs://${projet}-sauvegardes`;
    const client = new firestore_1.v1.FirestoreAdminClient();
    const date = new Date().toISOString().slice(0, 10);
    const [op] = await client.exportDocuments({
        name: client.databasePath(projet, '(default)'),
        outputUriPrefix: `${bucket}/${date}`,
        collectionIds: [],
    });
    logger.info('Sauvegarde lancée', { operation: op.name, destination: `${bucket}/${date}` });
});
//# sourceMappingURL=sauvegarde.js.map