// Tests des Cloud Functions sur l'émulateur (auth + Firestore + fonctions).
// Les variables FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST… sont
// posées par `firebase emulators:exec`.
const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { hacherPin } = require('../lib/commun');
const { alerteStock } = require('../lib/alertes');
const { agreger } = require('../lib/rapports');

const PROJET = 'demo-resto';
const REGION = 'europe-west1';
const AUTH = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;
const FONCTIONS = `http://${process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001'}/${PROJET}/${REGION}`;
const R = 'chez-amani';

let db;
before(() => {
  // L'application Firebase Admin est initialisée par lib/commun (importé ci-dessus).
  db = getFirestore();
});

/** Nouvel appareil connecté en anonyme. */
async function appareilAnonyme() {
  const r = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, idToken: j.idToken, refreshToken: j.refreshToken };
}

/** Rafraîchit le jeton pour récupérer les nouveaux droits (custom claims). */
async function rafraichir(a) {
  const r = await fetch(`${AUTH}/securetoken.googleapis.com/v1/token?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=refresh_token&refresh_token=${a.refreshToken}`,
  });
  const j = await r.json();
  if (!r.ok) return { ...a, erreur: j.error?.message };
  return { ...a, idToken: j.id_token, refreshToken: j.refresh_token };
}

async function appeler(nom, a, data) {
  const r = await fetch(`${FONCTIONS}/${nom}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(a ? { Authorization: `Bearer ${a.idToken}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const j = await r.json();
  if (j.error) {
    const e = new Error(j.error.message);
    e.statut = j.error.status;
    throw e;
  }
  return j.result;
}

const attendre = (ms) => new Promise((r) => setTimeout(r, ms));
async function sonder(fn, essais = 40) {
  for (let i = 0; i < essais; i++) {
    const v = await fn();
    if (v) return v;
    await attendre(250);
  }
  return null;
}

function claims(a) {
  return JSON.parse(Buffer.from(a.idToken.split('.')[1], 'base64url').toString());
}

test('fonctions pures : alertes de stock et agrégation du rapport', () => {
  assert.equal(alerteStock({ stock: 13, seuilAlerte: 12 }, { stock: 11, seuilAlerte: 12 }), 'seuil');
  assert.equal(alerteStock({ stock: 1 }, { stock: 0 }), 'rupture');
  assert.equal(alerteStock({ stock: 0 }, { stock: -1 }), 'negatif');
  assert.equal(alerteStock({ stock: 5, seuilAlerte: 2 }, { stock: 4, seuilAlerte: 2 }), null);
  assert.equal(alerteStock({ stock: 1 }, { stock: 30 }), null); // livraison
  const a = agreger([
    { total: 3000, statut: 'payee', nomServeuse: 'Awa', partie: '1/2', lignes: [{ nom: 'Poulet', idArticle: 'p', quantite: 1, prixUnitaire: 6000 }] },
    { total: 3000, statut: 'payee', nomServeuse: 'Awa', partie: '2/2', lignes: [{ nom: 'Poulet', idArticle: 'p', quantite: 1, prixUnitaire: 6000 }] },
    { total: 700, statut: 'credit', nomServeuse: 'Fatou', lignes: [{ nom: 'Flag', idArticle: 'f', quantite: 1, prixUnitaire: 700 }] },
    { total: 500, statut: 'emise', lignes: [] },
  ]);
  assert.equal(a.chiffreAffaires, 6700);
  assert.equal(a.encaisse, 6000);
  assert.equal(a.credit, 700);
  assert.equal(a.nbFactures, 3);
  assert.deepEqual(a.articles[0], { nom: 'Poulet', quantite: 1, montant: 6000 });
});

test('parcours complet : liaison, élévation admin par PIN, blocage, retrait', async () => {
  // Restaurant + administrateur + code de liaison du téléphone du gérant
  // (ce que fait le script creer-restaurant).
  await db.doc(`restaurants/${R}`).set({ nom: 'Restaurant Chez les Amani' });
  await db.doc(`restaurants/${R}/employes/patron`).set({ nom: 'Patron', role: 'admin', actif: true, pinHash: hacherPin(R, 'patron', '4826') });
  await db.doc(`restaurants/${R}/employes/awa`).set({ nom: 'Awa', role: 'serveuse', actif: true, pinHash: hacherPin(R, 'awa', '1111') });
  await db.doc('codesLiaison/PATRON').set({
    restaurantId: R, nom: 'Téléphone du patron', type: 'telephone', admin: true,
    expire: Timestamp.fromMillis(Date.now() + 600_000), utilise: false,
  });

  // 1. Le téléphone du gérant se lie et reçoit les droits admin permanents.
  let tel = await appareilAnonyme();
  const lien = await appeler('lierAppareil', tel, { code: 'patron' });
  assert.equal(lien.restaurantId, R);
  tel = await rafraichir(tel);
  assert.equal(claims(tel).restaurantId, R);
  assert.equal(claims(tel).admin, true);
  // Un code ne sert qu'une fois.
  const intrus = await appareilAnonyme();
  await assert.rejects(appeler('lierAppareil', intrus, { code: 'PATRON' }), /déjà servi/);

  // 2. Le gérant crée un code pour l'ordinateur de caisse ; une tablette
  //    sans droits ne le peut pas.
  const { code } = await appeler('creerCodeLiaison', tel, { nom: 'Caisse', type: 'caisse', admin: true });
  assert.match(code, /^[A-HJ-NP-Z2-9]{6}$/);
  let caisse = await appareilAnonyme();
  const l2 = await appeler('lierAppareil', caisse, { code });
  assert.equal(l2.admin, false, 'une caisse ne reçoit jamais les droits admin permanents');
  caisse = await rafraichir(caisse);
  assert.equal(claims(caisse).admin, undefined);
  await assert.rejects(appeler('creerCodeLiaison', caisse, { nom: 'X', type: 'tablette' }), /administrateur/);

  // 3. Élévation par PIN : une serveuse ne peut pas, mauvais PIN refusé.
  await assert.rejects(appeler('elevationAdmin', caisse, { idEmploye: 'awa', pin: '1111' }), /incorrect/);
  await assert.rejects(appeler('elevationAdmin', caisse, { idEmploye: 'patron', pin: '0000' }), /incorrect/);
  const el = await appeler('elevationAdmin', caisse, { idEmploye: 'patron', pin: '4826' });
  assert.ok(el.jusqua > Date.now() + 14 * 60_000);
  caisse = await rafraichir(caisse);
  assert.ok(claims(caisse).adminJusqua * 1000 > Date.now());
  await appeler('creerCodeLiaison', caisse, { nom: 'Tablette 1', type: 'tablette' }); // désormais permis
  await appeler('finElevationAdmin', caisse, {});
  caisse = await rafraichir(caisse);
  assert.equal(claims(caisse).adminJusqua, undefined);

  // 4. Cinq PIN faux → blocage, même avec le bon PIN ensuite.
  for (let i = 0; i < 5; i++) {
    await assert.rejects(appeler('elevationAdmin', caisse, { idEmploye: 'patron', pin: '9999' }));
  }
  await assert.rejects(appeler('elevationAdmin', caisse, { idEmploye: 'patron', pin: '4826' }), /Trop d’essais/);

  // 5. Retrait à distance : l'appareil ne peut plus rafraîchir son jeton.
  await appeler('revoquerAppareil', tel, { uid: caisse.uid });
  const apres = await rafraichir(caisse);
  assert.ok(apres.erreur, 'le jeton d’un appareil retiré ne se rafraîchit plus');
  const doc = await db.doc(`restaurants/${R}/appareils/${caisse.uid}`).get();
  assert.equal(doc.data().actif, false);
  const audit = await db.collection(`restaurants/${R}/journalAudit`).get();
  const actions = audit.docs.map((d) => d.data().action);
  for (const a of ['liaison_appareil', 'code_liaison', 'elevation_admin', 'echec_pin_admin', 'retrait_appareil']) {
    assert.ok(actions.includes(a), `audit : ${a}`);
  }
});

test('déclencheurs : alerte de stock, demande de validation, rapport du jour', async () => {
  const art = db.doc(`restaurants/${R}/articles/guinness`);
  await art.set({ nom: 'Guinness', stock: 7, seuilAlerte: 6, suiviStock: true, unite: 'bouteille' });
  await art.update({ stock: 5 });
  const notif = await sonder(async () => {
    const q = await db.collection(`restaurants/${R}/notifications`).where('type', '==', 'stock_seuil').get();
    return q.empty ? null : q.docs[0].data();
  });
  assert.ok(notif, 'notification de stock bas créée');
  assert.match(notif.message, /Il reste 5/);

  await db.collection(`restaurants/${R}/demandesValidation`).add({
    type: 'annulation', demandeur: 'Awa', motif: 'Erreur', statut: 'enAttente',
    detail: { quantite: 1, nom: 'Flag', numeroTable: '3' },
  });
  const v = await sonder(async () => {
    const q = await db.collection(`restaurants/${R}/notifications`).where('type', '==', 'validation').get();
    return q.empty ? null : q.docs[0].data();
  });
  assert.ok(v && /Annulation : 1 × Flag/.test(v.message), 'notification de validation créée');

  const ouverture = Timestamp.fromMillis(Date.now() - 3600_000);
  await db.doc(`restaurants/${R}/factures/f1`).set({
    date: Timestamp.fromMillis(Date.now() - 600_000), total: 5400, statut: 'payee', nomServeuse: 'Awa',
    lignes: [{ nom: 'Poulet braisé', idArticle: 'p', quantite: 1, prixUnitaire: 4000 }, { nom: 'Flag', idArticle: 'f', quantite: 2, prixUnitaire: 700 }],
  });
  const j = db.doc(`restaurants/${R}/journeesCaisse/j1`);
  await j.set({ ouverture, fond: 10000, verrouillee: false, caissier: 'Koffi' });
  await j.update({ verrouillee: true, cloture: Timestamp.now(), totalTheorique: 15400, totalCompte: 15300, ecart: -100 });
  const rap = await sonder(async () => (await db.doc(`restaurants/${R}/rapportsJour/j1`).get()).data());
  assert.ok(rap, 'rapport du jour calculé à la clôture');
  assert.equal(rap.chiffreAffaires, 5400);
  assert.equal(rap.ecart, -100);
  assert.equal(rap.articles[0].nom, 'Poulet braisé');
});
