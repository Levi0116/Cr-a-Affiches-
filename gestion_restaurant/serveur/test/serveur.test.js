import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import { hacherPin, pinCorrect, verifierFormatPin } from '../src/securite.js';
import { demarrer, lot, PIN_ADMIN, PIN_SERVEUSE } from './outils.js';

describe('codes PIN', () => {
  test('6 à 10 chiffres, codes trop simples refusés', () => {
    assert.match(verifierFormatPin('12345'), /6 à 10/);
    assert.match(verifierFormatPin('12345678901'), /6 à 10/);
    assert.match(verifierFormatPin('12ab56'), /chiffres/);
    assert.match(verifierFormatPin('111111'), /identiques/);
    assert.match(verifierFormatPin('123456'), /suite/);
    assert.match(verifierFormatPin('987654'), /suite/);
    assert.match(verifierFormatPin('121212'), /répété/);
    assert.equal(verifierFormatPin('482615'), null);
  });
  test('empreinte salée, vérification à temps constant', () => {
    const a = hacherPin('482615');
    const b = hacherPin('482615');
    assert.notEqual(a.hash, b.hash);
    assert.ok(pinCorrect('482615', a));
    assert.ok(!pinCorrect('482616', a));
    assert.ok(!pinCorrect('482615', null));
  });
});

describe('API', () => {
  let t;
  let tablette;
  let telephone;
  let caisse;
  before(async () => {
    t = await demarrer();
    tablette = await t.lier({ type: 'tablette' });
    telephone = await t.lier({ type: 'telephone', admin: true });
    caisse = await t.lier({ type: 'caisse' });
  });
  after(() => t.fermer());

  test('liaison : code à usage unique, jeton exigé ensuite', async () => {
    assert.ok(tablette.jeton.length > 30);
    assert.equal(tablette.restaurant.nom, 'Restaurant Chez les Amani');
    const r = await t.appel('POST', '/liaison', { corps: { code: 'ZZZZZZZZ' } });
    assert.equal(r.statut, 400);
    assert.equal((await t.appel('GET', '/sync/pull')).statut, 401);
    assert.equal((await t.appel('GET', '/appareil', { jeton: tablette.jeton })).statut, 200);
  });

  test('connexion : PIN vérifié par le serveur, blocage après 5 erreurs', async () => {
    const ok = await t.connecter(tablette.jeton, t.idServeuse, PIN_SERVEUSE);
    assert.equal(ok.statut, 200);
    assert.equal(ok.corps.employe.role, 'serveuse');
    for (let i = 0; i < 4; i++) assert.equal((await t.connecter(tablette.jeton, t.idServeuse, '000001')).statut, 401);
    const bloque = await t.connecter(tablette.jeton, t.idServeuse, '000001');
    assert.equal(bloque.statut, 423);
    // Même le bon code est refusé pendant le blocage.
    assert.equal((await t.connecter(tablette.jeton, t.idServeuse, PIN_SERVEUSE)).statut, 423);
    await t.pool.query('DELETE FROM essais_pin');
  });

  test('comptes : seul l’administrateur connecté crée, modifie, supprime', async () => {
    const serveuse = (await t.connecter(tablette.jeton, t.idServeuse, PIN_SERVEUSE)).corps.session;
    const admin = (await t.connecter(caisse.jeton, t.idAdmin, PIN_ADMIN)).corps.session;

    const interdit = await t.appel('POST', '/employes', { jeton: tablette.jeton, session: serveuse, corps: { nom: 'Awa', role: 'serveuse', pin: '583920' } });
    assert.equal(interdit.statut, 403);
    const sansSession = await t.appel('POST', '/employes', { jeton: telephone.jeton, corps: { nom: 'Awa', role: 'serveuse', pin: '583920' } });
    assert.equal(sansSession.statut, 401, 'le téléphone du gérant seul ne suffit pas');
    // La session est liée à l'appareil où elle a été ouverte.
    const autreAppareil = await t.appel('POST', '/employes', { jeton: tablette.jeton, session: admin, corps: { nom: 'Awa', role: 'serveuse', pin: '583920' } });
    assert.equal(autreAppareil.statut, 401);

    const faible = await t.appel('POST', '/employes', { jeton: caisse.jeton, session: admin, corps: { nom: 'Awa', role: 'serveuse', pin: '123456' } });
    assert.equal(faible.statut, 400);
    const doublon = await t.appel('POST', '/employes', { jeton: caisse.jeton, session: admin, corps: { nom: 'Awa', role: 'serveuse', pin: PIN_SERVEUSE } });
    assert.equal(doublon.statut, 400);

    const cree = await t.appel('POST', '/employes', { jeton: caisse.jeton, session: admin, corps: { nom: 'Awa', role: 'serveuse', pin: '583920' } });
    assert.equal(cree.statut, 201);
    const id = cree.corps.id;
    assert.equal((await t.connecter(tablette.jeton, id, '583920')).statut, 200);

    const modif = await t.appel('PATCH', `/employes/${id}`, { jeton: caisse.jeton, session: admin, corps: { pin: '640281', role: 'caissier' } });
    assert.equal(modif.statut, 200);
    assert.equal((await t.connecter(tablette.jeton, id, '583920')).statut, 401);
    assert.equal((await t.connecter(tablette.jeton, id, '640281')).corps.employe.role, 'caissier');

    assert.equal((await t.appel('DELETE', `/employes/${id}`, { jeton: caisse.jeton, session: admin })).statut, 200);
    assert.equal((await t.connecter(tablette.jeton, id, '640281')).statut, 400);
    // Le dernier administrateur ne peut pas être supprimé ni rétrogradé.
    assert.equal((await t.appel('DELETE', `/employes/${t.idAdmin}`, { jeton: caisse.jeton, session: admin })).statut, 400);
    assert.equal((await t.appel('PATCH', `/employes/${t.idAdmin}`, { jeton: caisse.jeton, session: admin, corps: { role: 'serveuse' } })).statut, 400);
    // Les comptes ne passent jamais par la synchronisation.
    const triche = await t.appel('POST', '/sync/push', {
      jeton: caisse.jeton,
      corps: { lots: [lot(t.idAdmin, [{ type: 'set', chemin: `employes/${t.idServeuse}`, donnees: { role: 'admin' } }], { session: admin })] },
    });
    assert.equal(triche.corps.resultats[0].ok, false);
    await t.pool.query('DELETE FROM essais_pin');
  });

  test('synchro : droits, incréments sans conflit, lot appliqué une seule fois', async () => {
    const push = (jeton, lots) => t.appel('POST', '/sync/push', { jeton, corps: { lots } });

    const prix = await push(tablette.jeton, [lot(t.idServeuse, [{ type: 'update', chemin: 'articles/flag', donnees: { prix: 100 } }])]);
    assert.equal(prix.corps.resultats[0].ok, false);
    assert.match(prix.corps.resultats[0].erreur, /administrateur/);

    // Deux tablettes vendent hors ligne : les incréments s'additionnent.
    const vente = (n) => lot(t.idServeuse, [{ type: 'update', chemin: 'articles/flag', donnees: { stock: { __op: 'inc', n: -n }, nbVentes: { __op: 'inc', n } } }]);
    const l1 = vente(2);
    await push(tablette.jeton, [l1]);
    await push(caisse.jeton, [vente(3)]);
    await push(tablette.jeton, [l1]); // renvoyé après une coupure : ignoré
    const docs = (await t.appel('GET', '/sync/pull?depuis=0', { jeton: tablette.jeton })).corps.docs;
    const flag = docs.find((d) => d.chemin === 'articles/flag').donnees;
    assert.equal(flag.stock, 15);
    assert.equal(flag.nbVentes, 5);

    const suppr = await push(tablette.jeton, [lot(t.idServeuse, [{ type: 'delete', chemin: 'tables/t1' }])]);
    assert.equal(suppr.corps.resultats[0].ok, false);

    // Lot tout ou rien : une opération refusée annule tout le lot.
    const mixte = await push(tablette.jeton, [
      lot(t.idServeuse, [
        { type: 'update', chemin: 'tables/t1', donnees: { statut: 'occupee' } },
        { type: 'update', chemin: 'tables/t1', donnees: { numero: 99 } },
      ]),
    ]);
    assert.equal(mixte.corps.resultats[0].ok, false);
    const t1 = (await t.appel('GET', '/sync/pull?depuis=0', { jeton: tablette.jeton })).corps.docs.find((d) => d.chemin === 'tables/t1').donnees;
    assert.equal(t1.statut, 'libre');
  });

  test('administrateur : téléphone du gérant, ou session admin valide même pour un lot fait hors ligne', async () => {
    const push = (jeton, l) => t.appel('POST', '/sync/push', { jeton, corps: { lots: [l] } });
    const prix = (p) => [{ type: 'update', chemin: 'articles/flag', donnees: { prix: p } }];
    assert.equal((await push(telephone.jeton, lot(t.idAdmin, prix(750)))).corps.resultats[0].ok, true);
    assert.equal((await push(caisse.jeton, lot(t.idAdmin, prix(800)))).corps.resultats[0].ok, false, 'sans session');
    const session = (await t.connecter(caisse.jeton, t.idAdmin, PIN_ADMIN)).corps.session;
    assert.equal((await push(caisse.jeton, lot(t.idAdmin, prix(800), { session }))).corps.resultats[0].ok, true);
    assert.equal((await push(caisse.jeton, lot(t.idServeuse, prix(900), { session }))).corps.resultats[0].ok, false, 'auteur différent de la session');
  });

  test('factures et journées : une facture réglée ne change plus, journée verrouillée', async () => {
    const push = (l) => t.appel('POST', '/sync/push', { jeton: caisse.jeton, corps: { lots: [l] } });
    const date = { __t: Date.now() };
    await push(lot(t.idServeuse, [
      { type: 'set', chemin: 'journeesCaisse/j1', donnees: { ouverture: { __t: Date.now() - 3600_000 }, verrouillee: false, fond: 5000 } },
      { type: 'set', chemin: 'factures/f1', donnees: { numero: 'FAC-2026-000001', total: 5400, statut: 'emise', date, nomServeuse: 'Fatou', lignes: [{ nom: 'Poulet braisé', quantite: 1, prixUnitaire: 4000 }, { nom: 'Castel', quantite: 2, prixUnitaire: 700 }] } },
    ]));
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: 'factures/f1', donnees: { statut: 'payee', montantRecu: 6000, monnaieRendue: 600 } }]))).corps.resultats[0].ok, true);
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: 'factures/f1', donnees: { total: 1 } }]))).corps.resultats[0].ok, false);
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: 'factures/f1', donnees: { nbImpressions: { __op: 'inc', n: 1 } } }]))).corps.resultats[0].ok, true);

    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: 'journeesCaisse/j1', donnees: { verrouillee: true, cloture: { __op: 'now' } } }]))).corps.resultats[0].ok, true);
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: 'journeesCaisse/j1', donnees: { fond: 0 } }]))).corps.resultats[0].ok, false);
    const docs = (await t.appel('GET', '/sync/pull?depuis=0', { jeton: caisse.jeton })).corps.docs;
    const rapport = docs.find((d) => d.chemin === 'rapportsJour/j1').donnees;
    assert.equal(rapport.chiffreAffaires, 5400);
    assert.equal(rapport.encaisse, 5400);
    assert.equal(rapport.articles[0].nom, 'Poulet braisé');
  });

  test('alertes : stock sous le seuil et demande de validation créent une notification', async () => {
    const push = (l) => t.appel('POST', '/sync/push', { jeton: tablette.jeton, corps: { lots: [l] } });
    const avant = (await t.appel('GET', '/sync/pull?depuis=0', { jeton: tablette.jeton })).corps.rev;
    await push(lot(t.idServeuse, [{ type: 'update', chemin: 'articles/flag', donnees: { stock: { __op: 'inc', n: -5 } } }]));
    await push(lot(t.idServeuse, [{ type: 'set', chemin: 'demandesValidation/d1', donnees: { type: 'annulation', demandeur: 'Fatou', motif: 'Erreur de table', detail: { quantite: 3, nom: 'Guinness', numeroTable: 5 } } }]));
    const notifs = (await t.appel('GET', `/sync/pull?depuis=${avant}`, { jeton: tablette.jeton })).corps.docs.filter((d) => d.chemin.startsWith('notifications/'));
    assert.deepEqual(notifs.map((n) => n.donnees.type).sort(), ['stock_seuil', 'validation']);
    const id = notifs[0].chemin.split('/')[1];
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: `notifications/${id}`, donnees: { lue: true } }]))).corps.resultats[0].ok, true);
    assert.equal((await push(lot(t.idServeuse, [{ type: 'update', chemin: `notifications/${id}`, donnees: { titre: 'x' } }]))).corps.resultats[0].ok, false);
  });

  test('temps réel : un appareil en écoute est réveillé par l’écriture d’un autre', async () => {
    const rev = (await t.appel('GET', '/sync/pull?depuis=0', { jeton: tablette.jeton })).corps.rev;
    const ecoute = t.appel('GET', `/sync/attendre?depuis=${rev}`, { jeton: tablette.jeton });
    await new Promise((r) => setTimeout(r, 100));
    await t.appel('POST', '/sync/push', { jeton: caisse.jeton, corps: { lots: [lot(t.idServeuse, [{ type: 'update', chemin: 'tables/t1', donnees: { statut: 'occupee' } }])] } });
    const r = await ecoute;
    assert.ok(r.corps.rev > rev);
  });

  test('CORS : seul le domaine de l’application peut appeler l’API', async () => {
    const ok = await t.appel('OPTIONS', '/sante', { entetes: { origin: 'https://restaurant-chez-amani.com', 'access-control-request-method': 'POST' } });
    assert.equal(ok.statut, 204);
    assert.equal(ok.entetes.get('access-control-allow-origin'), 'https://restaurant-chez-amani.com');
    assert.match(ok.entetes.get('access-control-allow-headers'), /X-Session/);
    const pirate = await t.appel('OPTIONS', '/sante', { entetes: { origin: 'https://site-pirate.example', 'access-control-request-method': 'POST' } });
    assert.equal(pirate.statut, 403);
    assert.equal(pirate.entetes.get('access-control-allow-origin'), null);
    const lecture = await t.appel('GET', '/sante', { entetes: { origin: 'https://site-pirate.example' } });
    assert.equal(lecture.entetes.get('access-control-allow-origin'), null);
  });

  test('poste de l’appareil : seuls les comptes de ce poste peuvent s’y connecter', async () => {
    const session = (await t.connecter(caisse.jeton, t.idAdmin, PIN_ADMIN)).corps.session;
    const code = await t.appel('POST', '/appareils/codes', { jeton: caisse.jeton, session, corps: { type: 'tablette', nom: 'Tablette Salle' } });
    assert.deepEqual(code.corps.roles, ['serveuse'], 'tablette : poste serveuse par défaut');
    const tab = (await t.appel('POST', '/liaison', { corps: { code: code.corps.code } })).corps;
    assert.deepEqual(tab.appareil.roles, ['serveuse']);
    assert.equal((await t.connecter(tab.jeton, t.idServeuse, PIN_SERVEUSE)).statut, 200);
    const refus = await t.connecter(tab.jeton, t.idAdmin, PIN_ADMIN);
    assert.equal(refus.statut, 403, 'le patron ne se connecte pas sur une tablette serveuse, même avec son code');
    assert.match(refus.corps.erreur, /poste/);
    const multi = await t.appel('POST', '/appareils/codes', { jeton: caisse.jeton, session, corps: { type: 'caisse', nom: 'Caisse', roles: ['caissier', 'admin', 'pirate'] } });
    assert.deepEqual(multi.corps.roles, ['caissier', 'admin']);
    const vide = await t.appel('POST', '/appareils/codes', { jeton: caisse.jeton, session, corps: { type: 'caisse', roles: [] } });
    assert.equal(vide.statut, 400);
    assert.deepEqual((await t.appel('GET', '/appareil', { jeton: tab.jeton })).corps.appareil.roles, ['serveuse']);
    await t.pool.query('DELETE FROM essais_pin');
  });

  test('appareil retiré : plus aucun accès', async () => {
    const session = (await t.connecter(caisse.jeton, t.idAdmin, PIN_ADMIN)).corps.session;
    const code = await t.appel('POST', '/appareils/codes', { jeton: caisse.jeton, session, corps: { type: 'tablette', nom: 'Tablette Terrasse' } });
    assert.equal(code.statut, 201);
    const nouvelle = await t.appel('POST', '/liaison', { corps: { code: code.corps.code } });
    assert.equal(nouvelle.statut, 200);
    assert.equal((await t.appel('DELETE', `/appareils/${nouvelle.corps.appareil.id}`, { jeton: caisse.jeton, session })).statut, 200);
    assert.equal((await t.appel('GET', '/sync/pull', { jeton: nouvelle.corps.jeton })).statut, 401);
  });
});
