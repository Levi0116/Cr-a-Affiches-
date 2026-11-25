/**
 * Valeurs spéciales échangées avec les appareils (JSON) :
 *   {"__t": 1700000000000}        horodatage (millisecondes)
 *   {"__op": "now"}               heure du serveur
 *   {"__op": "inc", "n": 2}       incrément (additionné côté serveur : jamais de conflit)
 *   {"__op": "union", "v": [...]} ajout sans doublon dans une liste
 *   {"__op": "del"}               suppression d'un champ
 */
const estObjet = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function resoudre(v, ancien, maintenant) {
  if (estObjet(v) && typeof v.__op === 'string') {
    switch (v.__op) {
      case 'now':
        return { __t: maintenant };
      case 'inc':
        return (typeof ancien === 'number' ? ancien : 0) + Number(v.n ?? 0);
      case 'union': {
        const base = Array.isArray(ancien) ? [...ancien] : [];
        for (const x of v.v ?? []) if (!base.some((b) => JSON.stringify(b) === JSON.stringify(x))) base.push(x);
        return base;
      }
      case 'del':
        return undefined;
      default:
        throw new Error(`Opération inconnue : ${v.__op}`);
    }
  }
  if (estObjet(v) && !('__t' in v)) {
    const r = {};
    for (const [k, x] of Object.entries(v)) {
      const y = resoudre(x, estObjet(ancien) ? ancien[k] : undefined, maintenant);
      if (y !== undefined) r[k] = y;
    }
    return r;
  }
  return v;
}

/** Applique une opération d'écriture à un document (null = inexistant). */
export function appliquer(existant, op, maintenant = Date.now()) {
  if (op.type === 'set') {
    if (op.fusion && existant) {
      const r = { ...existant };
      for (const [k, v] of Object.entries(op.donnees ?? {})) {
        const y = resoudre(v, existant[k], maintenant);
        if (y === undefined) delete r[k];
        else r[k] = y;
      }
      return r;
    }
    return resoudre(op.donnees ?? {}, undefined, maintenant);
  }
  if (op.type === 'update') {
    if (!existant) throw new Error('document introuvable');
    const r = { ...existant };
    for (const [k, v] of Object.entries(op.donnees ?? {})) {
      const y = resoudre(v, existant[k], maintenant);
      if (y === undefined) delete r[k];
      else r[k] = y;
    }
    return r;
  }
  throw new Error(`Type d'écriture refusé : ${op.type}`);
}

/** Champs dont la valeur a changé entre deux versions d'un document. */
export function champsModifies(avant, apres) {
  const cles = new Set([...Object.keys(avant ?? {}), ...Object.keys(apres ?? {})]);
  return [...cles].filter((k) => JSON.stringify(avant?.[k]) !== JSON.stringify(apres?.[k]));
}

export const horodatage = (d = Date.now()) => ({ __t: d });
export const millis = (v) => (estObjet(v) && typeof v.__t === 'number' ? v.__t : null);
