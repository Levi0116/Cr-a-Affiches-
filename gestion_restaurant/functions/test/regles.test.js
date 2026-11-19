// Tests des règles de sécurité Firestore (phase 10.2), sur l'émulateur.
// Lancement : cd functions && npm test
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, increment } = require('firebase/firestore');

let env;
const R = 'resto-a';
const AUTRE = 'resto-b';
const maintenant = () => Math.floor(Date.now() / 1000);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-resto',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, `restaurants/${R}`), { nom: 'Chez les Amani' });
    await setDoc(doc(db, `restaurants/${AUTRE}`), { nom: 'Concurrent' });
    await setDoc(doc(db, `restaurants/${R}/articles/flag`), { nom: 'Flag', prixVente: 700, stock: 10, nbVentes: 0 });
    await setDoc(doc(db, `restaurants/${R}/factures/f1`), { numero: 'FAC-1', total: 700, statut: 'emise' });
    await setDoc(doc(db, `restaurants/${R}/factures/f2`), { numero: 'FAC-2', total: 700, statut: 'payee' });
    await setDoc(doc(db, `restaurants/${R}/journeesCaisse/j1`), { verrouillee: true, fond: 0 });
    await setDoc(doc(db, `restaurants/${R}/journeesCaisse/j2`), { verrouillee: false, fond: 0, totalEncaisse: 0 });
    await setDoc(doc(db, `restaurants/${R}/sessions/s1`), { statut: 'ouverte', total: 700 });
    await setDoc(doc(db, `restaurants/${R}/sessions/s1/lignes/l1`), { nom: 'Flag', statut: 'validee' });
    await setDoc(doc(db, `restaurants/${R}/notifications/n1`), { titre: 'Stock bas', lue: false });
    await setDoc(doc(db, `restaurants/${R}/journalAudit/a1`), { action: 'x' });
    await setDoc(doc(db, `codesLiaison/ABC234`), { restaurantId: R });
  });
});

const tablette = () => env.authenticatedContext('tab1', { restaurantId: R }).firestore();
const telephoneGerant = () => env.authenticatedContext('tel1', { restaurantId: R, admin: true }).firestore();
const caisseEleve = (decalage) =>
  env.authenticatedContext('caisse1', { restaurantId: R, adminJusqua: maintenant() + decalage }).firestore();

test('un inconnu ne lit rien', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `restaurants/${R}`)));
});

test('un appareil ne voit que son restaurant', async () => {
  await assertSucceeds(getDoc(doc(tablette(), `restaurants/${R}/articles/flag`)));
  await assertFails(getDoc(doc(tablette(), `restaurants/${AUTRE}`)));
});

test('prix réservés à l’admin, stock modifiable par incrément', async () => {
  await assertFails(updateDoc(doc(tablette(), `restaurants/${R}/articles/flag`), { prixVente: 100 }));
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/articles/flag`), { stock: increment(-2), nbVentes: increment(2) }));
  await assertSucceeds(updateDoc(doc(telephoneGerant(), `restaurants/${R}/articles/flag`), { prixVente: 800 }));
});

test('élévation admin temporaire : valable 15 min, refusée une fois expirée', async () => {
  await assertSucceeds(updateDoc(doc(caisseEleve(600), `restaurants/${R}/articles/flag`), { prixVente: 900 }));
  await assertFails(updateDoc(doc(caisseEleve(-60), `restaurants/${R}/articles/flag`), { prixVente: 950 }));
});

test('facture réglée intouchable, facture émise encaissable, jamais supprimée', async () => {
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/factures/f1`), { statut: 'payee', montantRecu: 1000, monnaieRendue: 300 }));
  await assertFails(updateDoc(doc(tablette(), `restaurants/${R}/factures/f2`), { total: 1 }));
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/factures/f2`), { nbImpressions: 2 })); // duplicata
  await assertFails(deleteDoc(doc(telephoneGerant(), `restaurants/${R}/factures/f2`)));
});

test('journal d’audit : ajout seul', async () => {
  await assertSucceeds(addDoc(collection(tablette(), `restaurants/${R}/journalAudit`), { action: 'test' }));
  await assertFails(updateDoc(doc(telephoneGerant(), `restaurants/${R}/journalAudit/a1`), { action: 'effacé' }));
  await assertFails(deleteDoc(doc(telephoneGerant(), `restaurants/${R}/journalAudit/a1`)));
});

test('journée de caisse verrouillée après la clôture', async () => {
  await assertFails(updateDoc(doc(telephoneGerant(), `restaurants/${R}/journeesCaisse/j1`), { fond: 5000 }));
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/journeesCaisse/j2`), { totalEncaisse: increment(700) }));
});

test('annulation d’une ligne réservée à l’admin', async () => {
  await assertFails(updateDoc(doc(tablette(), `restaurants/${R}/sessions/s1/lignes/l1`), { statut: 'annulee' }));
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/sessions/s1/lignes/l1`), { annulationDemandee: true }));
  await assertSucceeds(updateDoc(doc(telephoneGerant(), `restaurants/${R}/sessions/s1/lignes/l1`), { statut: 'annulee' }));
});

test('codes de liaison et rapports : jamais accessibles en écriture', async () => {
  await assertFails(getDoc(doc(telephoneGerant(), 'codesLiaison/ABC234')));
  await assertFails(setDoc(doc(telephoneGerant(), `restaurants/${R}/rapportsJour/x`), { ca: 1 }));
  await assertFails(setDoc(doc(telephoneGerant(), `restaurants/${R}/appareils/x`), { actif: true }));
});

test('notifications : seulement marquées comme lues', async () => {
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/notifications/n1`), { lue: true }));
  await assertFails(updateDoc(doc(tablette(), `restaurants/${R}/notifications/n1`), { titre: 'Faux' }));
  await assertFails(addDoc(collection(tablette(), `restaurants/${R}/notifications`), { titre: 'Faux' }));
});

test('fiches techniques et consignes', async () => {
  await assertFails(setDoc(doc(tablette(), `restaurants/${R}/recettes/poulet`), { ingredients: [] }));
  await assertSucceeds(setDoc(doc(telephoneGerant(), `restaurants/${R}/recettes/poulet`), { ingredients: [] }));
  await assertSucceeds(getDoc(doc(tablette(), `restaurants/${R}/recettes/poulet`)));
  await assertSucceeds(addDoc(collection(tablette(), `restaurants/${R}/mouvementsConsignes`), { quantite: -4 }));
  await assertSucceeds(updateDoc(doc(tablette(), `restaurants/${R}/articles/flag`), { vides: increment(1) }));
});
