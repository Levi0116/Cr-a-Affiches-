import 'dotenv/config';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = path.dirname(fileURLToPath(import.meta.url));

function exiger(nom, defaut) {
  const v = process.env[nom] ?? defaut;
  if (v === undefined || v === '') throw new Error(`Variable d'environnement manquante : ${nom} (voir .env.exemple)`);
  return v;
}

/** Configuration lue une fois au démarrage (fichier .env). */
export function lireConfig(surcharges = {}) {
  const c = {
    port: Number(process.env.PORT ?? 3000),
    mysql: {
      host: process.env.MYSQL_HOTE ?? '127.0.0.1',
      port: Number(process.env.MYSQL_PORT ?? 3306),
      database: exiger('MYSQL_BASE', 'amani'),
      user: exiger('MYSQL_UTILISATEUR', 'amani'),
      password: process.env.MYSQL_MOT_DE_PASSE ?? '',
    },
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
