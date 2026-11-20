"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
/**
 * Création d'un restaurant (premier démarrage chez un client).
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=cle-service.json \
 *   npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" \
 *     --telephone "+226 65 91 11 76" --admin "Patron" --pin 4826
 *
 * Crée le restaurant, l'employé administrateur (PIN haché) et affiche un
 * code de liaison valable 15 minutes pour le premier appareil (le
 * téléphone du gérant, avec droits administrateur permanents).
 */
const node_crypto_1 = require("node:crypto");
const firestore_1 = require("firebase-admin/firestore");
const commun_1 = require("../commun");
function arg(nom) {
    const i = process.argv.indexOf(`--${nom}`);
    return i >= 0 ? process.argv[i + 1] : undefined;
}
async function main() {
    const id = arg('id');
    const nom = arg('nom');
    const admin = arg('admin') ?? 'Administrateur';
    const pin = arg('pin');
    if (!id || !nom || !pin || !/^\d{4}$/.test(pin) || !/^[a-z0-9-]{3,40}$/.test(id)) {
        console.error('Usage : --id identifiant-en-minuscules --nom "Nom" --pin 1234 [--admin Nom] [--telephone ...]');
        process.exit(1);
    }
    if ((await (0, commun_1.resto)(id).get()).exists) {
        console.error(`Le restaurant « ${id} » existe déjà.`);
        process.exit(1);
    }
    const idAdmin = (0, node_crypto_1.randomUUID)();
    await (0, commun_1.resto)(id).set({
        nom,
        adresse: arg('adresse') ?? '',
        telephone: arg('telephone') ?? '',
        mentionsFacture: '',
        messageBasTicket: 'Merci et à bientôt !',
        soumisTva: false,
        tauxTva: 18,
        deconnexionMinutes: 5,
        creeLe: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, commun_1.resto)(id).collection('employes').doc(idAdmin).set({
        nom: admin,
        role: 'admin',
        actif: true,
        pinHash: (0, commun_1.hacherPin)(id, idAdmin, pin),
    });
    const code = Array.from({ length: 6 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Math.floor(Math.random() * 32)]).join('');
    await (0, commun_1.db)().collection('codesLiaison').doc(code).set({
        restaurantId: id,
        nom: `Téléphone de ${admin}`,
        type: 'telephone',
        admin: true,
        expire: firestore_1.Timestamp.fromMillis(Date.now() + 15 * 60_000),
        utilise: false,
        creeLe: firestore_1.FieldValue.serverTimestamp(),
    });
    console.log(`Restaurant « ${nom} » créé (${id}).`);
    console.log(`Code de liaison du premier appareil (15 min) : ${code}`);
}
main().catch((e) => {
    console.error(e);
    process.exit(1);
});
//# sourceMappingURL=creer-restaurant.js.map