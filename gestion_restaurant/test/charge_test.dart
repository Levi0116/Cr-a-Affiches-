import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/core/calculs.dart';
import 'package:gestion_restaurant/models/modeles.dart';
import 'package:gestion_restaurant/services/caisse_service.dart';
import 'package:gestion_restaurant/services/commande_service.dart';
import 'package:gestion_restaurant/services/db.dart';
import 'package:gestion_restaurant/services/donnees_demo.dart';

/// Phase 10.4 : soirée simulée avec 3 tablettes et 100 commandes, puis
/// facturation et clôture. Tout doit tomber juste, au franc près.
void main() {
  test('3 serveuses, 100 commandes, 12 tables : totaux, stock, numérotation et caisse cohérents', () async {
    final db = RestoDb(fs: FakeFirebaseFirestore(), idRestaurant: 'demo', appareil: 'test');
    await remplirDemo(db);
    final cmd = CommandeService(db);
    final caisse = CaisseService(db);
    const serveuses = [
      Acteur(id: 'e-awa', nom: 'Awa', role: Role.serveuse),
      Acteur(id: 'e-fatou', nom: 'Fatou', role: Role.serveuse),
      Acteur(id: 'e-mariam', nom: 'Mariam', role: Role.serveuse),
    ];
    const koffi = Acteur(id: 'e-koffi', nom: 'Koffi', role: Role.caissier);
    final hasard = Random(42); // reproductible
    final resto = Restaurant.fromDoc(await db.resto.get());
    final stockAvant = {for (final d in (await db.articles.get()).docs) d.id: (d.data()['stock'] as num? ?? 0)};
    // Articles vendables avec du stock largement suffisant pour la soirée.
    final vendables = [
      'a-flag',
      'a-castel',
      'a-beaufort',
      'a-coca',
      'a-eau',
      'a-youzou',
      'a-garba',
      'a-alloco',
      'a-brochette',
    ];
    for (final id in vendables) {
      await db.articles.doc(id).update({'stock': 500});
      stockAvant[id] = 500;
    }

    final sessionsParTable = <String, String>{};
    var montantAttendu = 0;
    final vendu = <String, int>{};
    for (var i = 0; i < 100; i++) {
      final s = serveuses[i % 3];
      final idTable = 't-${hasard.nextInt(12) + 1}';
      final panier = <ElementPanier>[];
      for (var k = 0; k < 1 + hasard.nextInt(3); k++) {
        final id = vendables[hasard.nextInt(vendables.length)];
        final a = Article.fromDoc(await db.articles.doc(id).get());
        final q = 1 + hasard.nextInt(3);
        panier.add(ElementPanier(a, quantite: q));
        montantAttendu += a.prixVente * q;
        vendu[id] = (vendu[id] ?? 0) + q;
      }
      final table = TableResto.fromDoc(await db.tables.doc(idTable).get());
      final idSession = sessionsParTable[idTable];
      final session = idSession == null ? null : SessionTable.fromDoc(await db.sessions.doc(idSession).get());
      sessionsParTable[idTable] = await cmd.validerTour(serveuse: s, panier: panier, table: table, session: session);
    }

    // 1. Total des additions = somme exacte des articles commandés.
    var totalSessions = 0;
    for (final id in sessionsParTable.values) {
      final s = SessionTable.fromDoc(await db.sessions.doc(id).get());
      final lignes = (await db.lignes(id).get()).docs.map(LigneCommande.fromDoc);
      expect(s.total, lignes.fold(0, (t, l) => t + l.montant), reason: 'total de la table ${s.numeroTable}');
      totalSessions += s.total;
    }
    expect(totalSessions, montantAttendu);

    // 2. Stock : baisse = quantités vendues, et une ligne de mouvement par vente.
    for (final e in vendu.entries) {
      final a = Article.fromDoc(await db.articles.doc(e.key).get());
      if (!a.suiviStock) continue; // plats sans suivi (garba, alloco) : stock inchangé, voulu
      expect(a.stock, stockAvant[e.key]! - e.value, reason: 'stock ${a.nom}');
      final mvts = await db.mouvementsStock.where('idArticle', isEqualTo: e.key).get();
      expect(mvts.docs.fold<num>(0, (t, d) => t + (d.data()['quantite'] as num)), -e.value);
    }

    // 3. Facturation et encaissement de toutes les tables : numéros continus.
    final jid = await caisse.ouvrirCaisse(koffi, 20000);
    final j = JourneeCaisse.fromDoc(await db.journeesCaisse.doc(jid).get());
    final numeros = <String>[];
    var encaisse = 0;
    for (final id in sessionsParTable.values) {
      final s = SessionTable.fromDoc(await db.sessions.doc(id).get());
      for (final fid in await caisse.emettreFactures(caissier: koffi, session: s, restaurant: resto)) {
        final f = Facture.fromDoc(await db.factures.doc(fid).get());
        numeros.add(f.numero);
        final recu = montantsRapides(f.total).last;
        final monnaie = await caisse.encaisser(caissier: koffi, facture: f, montantRecu: recu, journee: j);
        expect(monnaie, recu - f.total);
        encaisse += f.total;
      }
    }
    final an = DateTime.now().year;
    expect(numeros, [for (var n = 1; n <= sessionsParTable.length; n++) numeroFacture(an, n)]);
    expect(encaisse, montantAttendu);

    // 4. Toutes les tables libérées, clôture juste.
    final occupees = (await db.tables.get()).docs.where((d) => d.data()['statut'] != 'libre');
    expect(occupees, isEmpty);
    final cloture = await caisse.cloturerCaisse(koffi, j, 20000 + montantAttendu);
    expect(cloture.totalTheorique, 20000 + montantAttendu);
    expect(cloture.ecart, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
