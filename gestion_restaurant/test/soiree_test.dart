import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/core/calculs.dart';
import 'package:gestion_restaurant/models/modeles.dart';
import 'package:gestion_restaurant/services/admin_service.dart';
import 'package:gestion_restaurant/services/caisse_service.dart';
import 'package:gestion_restaurant/services/commande_service.dart';
import 'package:gestion_restaurant/services/db.dart';
import 'package:gestion_restaurant/services/donnees_demo.dart';
import 'package:gestion_restaurant/services/stock_service.dart';
import 'package:gestion_restaurant/services/ticket.dart';

const awa = Acteur(id: 'e-awa', nom: 'Awa', role: Role.serveuse);
const fatou = Acteur(id: 'e-fatou', nom: 'Fatou', role: Role.serveuse);
const koffi = Acteur(id: 'e-koffi', nom: 'Koffi', role: Role.caissier);
const moussa = Acteur(id: 'e-moussa', nom: 'Moussa', role: Role.gestionnaire);
const patron = Acteur(id: 'e-patron', nom: 'Patron', role: Role.admin);

late RestoDb db;
late CommandeService cmd;
late CaisseService caisse;
late StockService stock;
late AdminService admin;

Future<Article> art(String id) async => Article.fromDoc(await db.articles.doc(id).get());
Future<TableResto> table(String id) async => TableResto.fromDoc(await db.tables.doc(id).get());
Future<SessionTable> session(String id) async => SessionTable.fromDoc(await db.sessions.doc(id).get());
Future<Restaurant> resto() async => Restaurant.fromDoc(await db.resto.get());
Future<Facture> facture(String id) async => Facture.fromDoc(await db.factures.doc(id).get());

Future<String> commander(Acteur s, String idTable, Map<String, int> articles, {String? idSession}) async {
  final panier = [for (final e in articles.entries) ElementPanier(await art(e.key), quantite: e.value)];
  return cmd.validerTour(
    serveuse: s,
    panier: panier,
    table: await table(idTable),
    session: idSession == null ? null : await session(idSession),
  );
}

void main() {
  setUp(() async {
    db = RestoDb(fs: FakeFirebaseFirestore(), idRestaurant: 'demo', appareil: 'test');
    await remplirDemo(db);
    cmd = CommandeService(db);
    caisse = CaisseService(db);
    stock = StockService(db);
    admin = AdminService(db);
  });

  test('commande, tours, addition, facture, encaissement, clôture', () async {
    final j = await caisse.journeeOuverte() ?? JourneeCaisse.fromDoc(
        await db.journeesCaisse.doc(await caisse.ouvrirCaisse(koffi, 20000)).get());

    final s = await commander(awa, 't-1', {'a-flag': 3, 'a-poulet': 1});
    expect((await table('t-1')).statut, StatutTable.occupee);
    expect((await session(s)).total, 6100);
    expect((await art('a-flag')).stock, 45);
    expect((await art('a-poulet')).stock, 9);

    await commander(awa, 't-1', {'a-coca': 2}, idSession: s);
    var ss = await session(s);
    expect(ss.total, 7100);
    expect(ss.nbTours, 2);

    await cmd.demanderAddition(awa, ss);
    expect((await table('t-1')).statut, StatutTable.addition);
    // Plus d'ajout après la demande d'addition.
    expect(() => commander(awa, 't-1', {'a-coca': 1}, idSession: s), throwsA(isA<ErreurMetier>()));

    final ids = await caisse.emettreFactures(caissier: koffi, session: await session(s), restaurant: await resto());
    final f = await facture(ids.single);
    expect(f.numero, 'FAC-${DateTime.now().year}-000001');
    expect(f.total, 7100);
    expect(f.lignes.length, 3);

    final monnaie = await caisse.encaisser(caissier: koffi, facture: f, montantRecu: 10000, journee: j);
    expect(monnaie, 2900);
    expect((await facture(f.id)).statut, StatutFacture.payee);
    expect((await session(s)).statut, StatutSession.payee);
    expect((await table('t-1')).statut, StatutTable.libre);

    // Deuxième table, numérotation continue.
    final s2 = await commander(fatou, 't-2', {'a-castel': 2});
    final ids2 = await caisse.emettreFactures(caissier: koffi, session: await session(s2), restaurant: await resto());
    expect((await facture(ids2.single)).numero, 'FAC-${DateTime.now().year}-000002');
    await caisse.encaisser(caissier: koffi, facture: await facture(ids2.single), montantRecu: 1400, journee: j);

    final jc = await caisse.cloturerCaisse(koffi, j, 28400);
    expect(jc.totalTheorique, 20000 + 7100 + 1400);
    expect(jc.ecart, -100);
    expect(jc.verrouillee, isTrue);
    expect(() => caisse.encaisser(caissier: koffi, facture: f, montantRecu: 1, journee: jc), throwsA(isA<ErreurMetier>()));
    expect(ticketCloture(await resto(), jc, nbFactures: 2), contains('ÉCART'));
  });

  test('annulation validée par l’admin : ligne marquée, stock remis, total corrigé', () async {
    final s = await commander(awa, 't-3', {'a-flag': 2, 'a-brochette': 3});
    final ligne = (await caisse.lignesSession(s)).firstWhere((l) => l.idArticle == 'a-flag');
    await cmd.demanderAnnulation(awa, await session(s), ligne, 'Erreur de saisie');
    final dem = DemandeValidation.fromDoc((await db.demandesValidation.get()).docs.single);
    expect(dem.statut, StatutValidation.enAttente);

    expect(() => admin.traiterDemande(koffi, dem, true), throwsA(isA<ErreurMetier>()));
    await admin.traiterDemande(patron, dem, true);

    final l = (await caisse.lignesSession(s)).firstWhere((l) => l.id == ligne.id);
    expect(l.annulee, isTrue);
    expect(l.validePar, 'Patron');
    expect((await session(s)).total, 3000);
    expect((await art('a-flag')).stock, 48);
    final audit = await db.journalAudit.get();
    expect(audit.docs.map((d) => d.data()['action']), contains('validation_annulation'));
  });

  test('remise validée, partage en parts égales et partage par article', () async {
    final s = await commander(awa, 't-4', {'a-poisson': 2, 'a-coca': 2}); // 10 000
    await caisse.demanderRemise(koffi, await session(s), type: TypeRemise.pourcentage, valeur: 10, motif: 'Client fidèle');
    final dem = DemandeValidation.fromDoc((await db.demandesValidation.get()).docs.single);
    await admin.traiterDemande(patron, dem, true);
    final ids = await caisse.emettreFactures(caissier: koffi, session: await session(s), restaurant: await resto(), nombreParts: 3);
    final fs = [for (final id in ids) await facture(id)];
    expect(fs.map((f) => f.total), [3000, 3000, 3000]);
    expect(fs.map((f) => f.partie), ['1/3', '2/3', '3/3']);
    expect(fs.first.remise, 1000);

    final s2 = await commander(fatou, 't-5', {'a-flag': 1, 'a-garba': 1});
    final lignes = await caisse.lignesSession(s2);
    final idFlag = lignes.firstWhere((l) => l.idArticle == 'a-flag').id;
    final p1 = await caisse.emettreFactures(caissier: koffi, session: await session(s2), restaurant: await resto(), idsLignes: {idFlag});
    expect((await facture(p1.single)).total, 700);
    expect((await session(s2)).statut, StatutSession.ouverte);
    final p2 = await caisse.emettreFactures(caissier: koffi, session: await session(s2), restaurant: await resto());
    expect((await facture(p2.single)).total, 1000);
    expect((await session(s2)).statut, StatutSession.facturee);
  });

  test('ardoise : vente à crédit puis remboursement', () async {
    final jid = await caisse.ouvrirCaisse(koffi, 0);
    final j = JourneeCaisse.fromDoc(await db.journeesCaisse.doc(jid).get());
    final s = await commander(awa, 't-6', {'a-choukouya': 1});
    final ids = await caisse.emettreFactures(caissier: koffi, session: await session(s), restaurant: await resto());
    await caisse.mettreEnArdoise(caissier: koffi, facture: await facture(ids.single), client: 'M. Kouassi', telephone: '0102030405');
    expect((await session(s)).statut, StatutSession.credit);
    expect((await table('t-6')).statut, StatutTable.libre);
    final a = Ardoise.fromDoc((await db.ardoises.get()).docs.single);
    expect(a.montantDu, 3000);
    await caisse.rembourserArdoise(caissier: koffi, ardoise: a, montant: 1000, journee: j);
    expect(Ardoise.fromDoc(await db.ardoises.doc(a.id).get()).montantDu, 2000);
    expect(JourneeCaisse.fromDoc(await db.journeesCaisse.doc(j.id).get()).totalEncaisse, 1000);
  });

  test('transfert et fusion de tables', () async {
    final s1 = await commander(awa, 't-7', {'a-flag': 1});
    await cmd.transferer(awa, await session(s1), await table('t-8'));
    expect((await table('t-7')).statut, StatutTable.libre);
    expect((await table('t-8')).idSession, s1);
    final s2 = await commander(fatou, 't-9', {'a-castel': 2});
    await cmd.fusionner(fatou, await session(s2), await session(s1));
    expect((await session(s1)).total, 2100);
    expect((await caisse.lignesSession(s1)).length, 2);
    expect((await table('t-9')).statut, StatutTable.libre);
    expect((await session(s2)).statut, StatutSession.fusionnee);
  });

  test('stock : rupture, livraison en casiers, perte, inventaire validé', () async {
    final fanta = await art('a-fanta');
    expect(fanta.vendable, isFalse);
    expect(() => commander(awa, 't-10', {'a-fanta': 1}), throwsA(isA<ErreurMetier>()));
    await stock.saisirLivraison(a: moussa, article: fanta, casiers: 2, unites: 4, prixAchatUnitaire: 320, fournisseur: 'Solibra');
    final f2 = await art('a-fanta');
    expect(f2.stock, 52);
    expect(f2.coutMoyen, 320);
    expect(f2.vendable, isTrue);

    await stock.saisirPerte(moussa, f2, 2, 'Casse');
    expect((await art('a-fanta')).stock, 50);

    await stock.soumettreInventaire(moussa, await art('a-fanta'), 47);
    final dem = DemandeValidation.fromDoc((await db.demandesValidation.get()).docs.single);
    expect(dem.detail['ecart'], -3);
    await admin.traiterDemande(patron, dem, true);
    expect((await art('a-fanta')).stock, 47);

    // Vente de la dernière unité deux fois (hors ligne) : stock négatif, pas de blocage.
    final g = await art('a-guinness');
    await commander(awa, 't-11', {'a-guinness': 3});
    expect((await art('a-guinness')).stock, 0);
    await cmd.validerTour(serveuse: fatou, panier: [ElementPanier(g, quantite: 1)], table: await table('t-12'));
    expect((await art('a-guinness')).stock, -1);
    expect((await art('a-guinness')).vendable, isFalse);

    final mvts = await db.mouvementsStock.where('idArticle', isEqualTo: 'a-fanta').get();
    expect(mvts.docs.map((d) => d.data()['type']).toSet(), {'entree', 'perte', 'inventaire'});
  });

  test('avoir réservé à l’admin, série AV séparée ; changement de prix historisé', () async {
    final s = await commander(awa, 't-1', {'a-flag': 1});
    final ids = await caisse.emettreFactures(caissier: koffi, session: await session(s), restaurant: await resto());
    final f = await facture(ids.single);
    expect(() => caisse.creerAvoir(koffi, f, 700, 'x'), throwsA(isA<ErreurMetier>()));
    final num = await caisse.creerAvoir(patron, f, 700, 'Bouteille cassée');
    expect(num, 'AV-${DateTime.now().year}-000001');

    final flag = await art('a-flag');
    await admin.enregistrerArticle(patron, Article(id: flag.id, nom: flag.nom, idCategorie: flag.idCategorie, prixVente: 800), ancien: flag);
    expect((await art('a-flag')).prixVente, 800);
    expect((await db.historiquePrix.get()).docs.single.data()['ancienPrix'], 700);
    // La facture déjà émise garde l'ancien prix.
    expect((await facture(f.id)).lignes.single.prixUnitaire, 700);
  });
}
