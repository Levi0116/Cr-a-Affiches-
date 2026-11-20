"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sauvegardeQuotidienne = exports.rapportJour = exports.notifierDemande = exports.surveillerStock = exports.revoquerAppareil = exports.finElevationAdmin = exports.elevationAdmin = exports.lierAppareil = exports.creerCodeLiaison = void 0;
/**
 * Cloud Functions du logiciel de gestion de restaurant.
 * Déploiement : firebase deploy --only functions (voir DEPLOIEMENT.md).
 */
const v2_1 = require("firebase-functions/v2");
const commun_1 = require("./commun");
(0, v2_1.setGlobalOptions)({ region: commun_1.REGION, maxInstances: 10 });
var appareils_1 = require("./appareils");
Object.defineProperty(exports, "creerCodeLiaison", { enumerable: true, get: function () { return appareils_1.creerCodeLiaison; } });
Object.defineProperty(exports, "lierAppareil", { enumerable: true, get: function () { return appareils_1.lierAppareil; } });
Object.defineProperty(exports, "elevationAdmin", { enumerable: true, get: function () { return appareils_1.elevationAdmin; } });
Object.defineProperty(exports, "finElevationAdmin", { enumerable: true, get: function () { return appareils_1.finElevationAdmin; } });
Object.defineProperty(exports, "revoquerAppareil", { enumerable: true, get: function () { return appareils_1.revoquerAppareil; } });
var alertes_1 = require("./alertes");
Object.defineProperty(exports, "surveillerStock", { enumerable: true, get: function () { return alertes_1.surveillerStock; } });
Object.defineProperty(exports, "notifierDemande", { enumerable: true, get: function () { return alertes_1.notifierDemande; } });
var rapports_1 = require("./rapports");
Object.defineProperty(exports, "rapportJour", { enumerable: true, get: function () { return rapports_1.rapportJour; } });
var sauvegarde_1 = require("./sauvegarde");
Object.defineProperty(exports, "sauvegardeQuotidienne", { enumerable: true, get: function () { return sauvegarde_1.sauvegardeQuotidienne; } });
//# sourceMappingURL=index.js.map