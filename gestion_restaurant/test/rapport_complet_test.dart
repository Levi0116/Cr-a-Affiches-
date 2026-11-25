import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/donnees/base.dart';
import 'package:gestion_restaurant/models/modeles.dart';
import 'package:gestion_restaurant/services/caisse_service.dart';
import 'package:gestion_restaurant/services/commande_service.dart';
import 'package:gestion_restaurant/services/db.dart';
import 'package:gestion_restaurant/services/donnees_demo.dart';
import 'package:gestion_restaurant/services/rapport_complet.dart';

const awa = Acteur(id: 'e-awa', nom: 'Awa', role: Role.serveuse);
const koffi = Acteur(id: 'e-koffi', nom: 'Koffi', role: Role.caissier);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapport complet PDF : toutes les sections, sur une soirée', () async {
    final db = RestoDb(fs: BaseLocale.autonome(), idRestaurant: 'demo', appareil: 'test');
    await remplirDemo(db);
    final cmd = CommandeService(db);
    final caisse = CaisseService(db);
    final resto = Restaurant.fromDoc(await db.resto.get());
    final j = JourneeCaisse.fromDoc(await db.journeesCaisse.doc(await caisse.ouvrirCaisse(koffi, 20000)).get());
    for (final (table, articles) in [
      ('t-1', {'a-flag': 3, 'a-poulet': 1}),
      ('t-2', {'a-kedjenou': 2, 'a-bissap': 2}),
      ('t-5', {'a-garba': 3, 'a-castel': 2}),
    ]) {
      final panier = [
        for (final e in articles.entries) ElementPanier(Article.fromDoc(await db.articles.doc(e.key).get()), quantite: e.value),
      ];
      final s = await cmd.validerTour(serveuse: awa, panier: panier, table: TableResto.fromDoc(await db.tables.doc(table).get()));
      final ids = await caisse.emettreFactures(caissier: koffi, session: SessionTable.fromDoc(await db.sessions.doc(s).get()), restaurant: resto);
      final f = Facture.fromDoc(await db.factures.doc(ids.single).get());
      await caisse.encaisser(caissier: koffi, facture: f, montantRecu: f.total + 500, journee: j);
    }
    await caisse.cloturerCaisse(koffi, j, 20000 + 6100 + 11000 + 4400);

    final octets = await rapportCompletPdf(db, const PeriodeRapport('Tout l’historique', null, null), genereePar: 'Patron');
    expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    expect(octets.length, greaterThan(20000));
    final sortie = Platform.environment['AMANI_PDF_SORTIE'];
    if (sortie != null) File(sortie).writeAsBytesSync(octets);
  });
}
