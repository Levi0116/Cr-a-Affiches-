/**
 * Premier démarrage : crée le restaurant, le compte administrateur et un
 * code de liaison (15 min) pour le premier appareil (téléphone du gérant).
 *
 *   npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" \
 *     --admin "Patron" --pin 482615 --telephone "+226 65 91 11 76"
 */
import crypto from 'node:crypto';
import { creerPool, migrer } from '../src/bd.js';
import { lireConfig } from '../src/config.js';
import { DUREE_CODE_MIN, hacherPin, nouveauCode, verifierFormatPin } from '../src/securite.js';
import { ecrireServeur } from '../src/sync.js';
import { horodatage } from '../src/valeurs.js';
import { publierVersion } from '../src/version.js';

const arg = (nom) => {
  const i = process.argv.indexOf(`--${nom}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};

const id = arg('id');
const nom = arg('nom');
const admin = arg('admin') ?? 'Administrateur';
const pin = arg('pin');
if (!id || !/^[a-z0-9-]{3,40}$/.test(id) || !nom || !pin) {
  console.error('Usage : --id identifiant-en-minuscules --nom "Nom du restaurant" --pin 482615 [--admin Nom] [--telephone ...] [--adresse ...]');
  process.exit(1);
}
const erreurPin = verifierFormatPin(pin);
if (erreurPin) {
  console.error(erreurPin);
  process.exit(1);
}

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
await migrer(pool);
const [deja] = await pool.query('SELECT id FROM restaurants WHERE id = ?', [id]);
if (deja.length) {
  console.error(`Le restaurant « ${id} » existe déjà.`);
  process.exit(1);
}
await pool.query('INSERT INTO restaurants (id, nom) VALUES (?, ?)', [id, nom]);
const idAdmin = crypto.randomUUID();
await ecrireServeur(pool, id, [
  {
    chemin: '@',
    donnees: {
      nom,
      slogan: arg('slogan') ?? 'Le goût de l’Afrique, la signature AMANI',
      adresse: arg('adresse') ?? '',
      telephone: arg('telephone') ?? '',
      mentionsFacture: '',
      messageBasTicket: 'Merci et à bientôt chez les Amani !',
      soumisTva: false,
      tauxTva: 18,
      deconnexionMinutes: 5,
      creeLe: horodatage(),
    },
  },
  { chemin: `employes/${idAdmin}`, donnees: { nom: admin, role: 'admin', actif: true, supprime: false, pinVerif: hacherPin(pin), creeLe: horodatage() } },
  { chemin: 'compteurs/principal', donnees: {} },
]);
await publierVersion(pool, cfg.version);
const code = nouveauCode();
await pool.query('INSERT INTO codes_liaison (code, restaurant_id, nom, type, admin, expire) VALUES (?, ?, ?, ?, 1, ?)', [
  code, id, `Téléphone de ${admin}`, 'telephone', new Date(Date.now() + DUREE_CODE_MIN * 60_000),
]);
console.log(`\nRestaurant « ${nom} » créé (${id}).`);
console.log(`Administrateur : ${admin}`);
console.log(`\nCode de liaison du premier appareil (valable ${DUREE_CODE_MIN} min) :  ${code}\n`);
await pool.end();
