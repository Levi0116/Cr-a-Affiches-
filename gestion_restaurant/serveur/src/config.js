import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const ici = path.dirname(fileURLToPath(import.meta.url));
// Fichier .env à la racine du dossier serveur, quel que soit le dossier de lancement.
dotenv.config({ path: path.join(ici, '..', '.env'), quiet: true });

function exiger(nom, defaut) {
  const v = process.env[nom] ?? defaut;
  if (v === undefined || v === '') throw new Error(`Variable d'environnement manquante : ${nom} (voir .env.exemple)`);
  return v;
}

/** Configuration lue une fois au démarrage (fichier .env). */
export function lireConfig(surcharges = {}) {
  const c = {
    // alwaysdata fournit ALWAYSDATA_HTTPD_PORT / ALWAYSDATA_HTTPD_IP ; Render fournit PORT.
    port: Number(process.env.PORT ?? process.env.ALWAYSDATA_HTTPD_PORT ?? 3000),
    hote: process.env.HOTE ?? process.env.ALWAYSDATA_HTTPD_IP ?? process.env.IP ?? '127.0.0.1',
    mysql: {
      host: process.env.MYSQL_HOTE ?? '127.0.0.1',
      port: Number(process.env.MYSQL_PORT ?? 3306),
      database: exiger('MYSQL_BASE', 'amani'),
      user: exiger('MYSQL_UTILISATEUR', 'amani'),
      password: process.env.MYSQL_MOT_DE_PASSE ?? '',
      // Connexion chiffrée (bases hébergées ailleurs, ex. TiDB Cloud) : MYSQL_SSL=true
      ...(process.env.MYSQL_SSL === 'true' ? { ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true } } : {}),
    },
    // Adresses autorisées à appeler l'API depuis un autre domaine (application
    // hébergée ailleurs, ex. https://restaurant-chez-amani.com), séparées par des virgules.
    origines: (process.env.ORIGINES ?? '')
      .split(',')
      .map((o) => o.trim().replace(/\/$/, ''))
      .filter(Boolean),
    secret: process.env.SECRET_SESSIONS ?? '',
    dureeSessionH: Number(process.env.DUREE_SESSION_H ?? 12),
    dossierPwa: path.resolve(ici, '..', process.env.DOSSIER_PWA ?? '../build/web'),
    version: {
      derniere: process.env.VERSION_DERNIERE ?? '2.0.0',
      minimale: process.env.VERSION_MINIMALE ?? '2.0.0',
      notes: process.env.VERSION_NOTES ?? '',
    },
    ...surcharges,
  };
  if (!c.secret || c.secret.length < 32) {
    throw new Error('SECRET_SESSIONS doit contenir au moins 32 caractères aléatoires (voir .env.exemple).');
  }
  return c;
}
