import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';

/** Codes PIN : 6 à 10 chiffres, sans suites évidentes. */
export const PIN_MIN = 6;
export const PIN_MAX = 10;
export const ESSAIS_MAX = 5;
export const BLOCAGE_MIN = 15;
export const DUREE_CODE_MIN = 15;
const ITERATIONS = 120_000;

export class ErreurApi extends Error {
  constructor(statut, message, code = 'erreur') {
    super(message);
    this.statut = statut;
    this.code = code;
  }
}

/** Refuse les PIN trop faciles à deviner. Renvoie un message ou null. */
export function verifierFormatPin(pin) {
  if (typeof pin !== 'string' || !/^\d+$/.test(pin)) return 'Le code doit contenir uniquement des chiffres.';
  if (pin.length < PIN_MIN || pin.length > PIN_MAX) return `Le code doit contenir de ${PIN_MIN} à ${PIN_MAX} chiffres.`;
  if (/^(\d)\1+$/.test(pin)) return 'Code trop simple : tous les chiffres sont identiques.';
  const montant = '01234567890123456789';
  const descendant = '98765432109876543210';
  if (montant.includes(pin) || descendant.includes(pin)) return 'Code trop simple : suite de chiffres.';
  for (let p = 2; p <= pin.length / 2; p++) {
    if (pin.length % p === 0 && pin.slice(0, p).repeat(pin.length / p) === pin) return 'Code trop simple : motif répété.';
  }
  return null;
}

/**
 * Empreinte PBKDF2-SHA256 salée. Le même format sert à la vérification
 * en ligne (serveur) et hors ligne (appareil lié).
 */
export function hacherPin(pin, sel = crypto.randomBytes(16).toString('base64'), iterations = ITERATIONS) {
  const hash = crypto.pbkdf2Sync(pin, sel, iterations, 32, 'sha256').toString('base64');
  return { algo: 'pbkdf2-sha256', iter: iterations, sel, hash };
}

export function pinCorrect(pin, verif) {
  if (!verif?.sel || !verif?.hash) return false;
  const calcule = crypto.pbkdf2Sync(pin, verif.sel, verif.iter ?? ITERATIONS, 32, 'sha256');
  const attendu = Buffer.from(verif.hash, 'base64');
  return calcule.length === attendu.length && crypto.timingSafeEqual(calcule, attendu);
}

export const empreinte = (jeton) => crypto.createHash('sha256').update(jeton).digest('hex');
export const nouveauJeton = () => crypto.randomBytes(32).toString('base64url');

/** Code de liaison lisible (sans 0/O, 1/I). */
export function nouveauCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const octets = crypto.randomBytes(8);
  return Array.from(octets, (o) => alphabet[o % 32]).join('');
}

export function signerSession(secret, charge, dureeH) {
  return jwt.sign(charge, secret, { algorithm: 'HS256', expiresIn: `${dureeH}h`, issuer: 'amani' });
}

/** Vérifie une session ; `toleranceS` permet d'accepter un lot créé hors ligne avant l'expiration. */
export function lireSession(secret, jeton, toleranceS = 0) {
  try {
    return jwt.verify(jeton, secret, { algorithms: ['HS256'], issuer: 'amani', clockTolerance: toleranceS });
  } catch {
    return null;
  }
}
