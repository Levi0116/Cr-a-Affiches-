import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestion_restaurant/core/rapports.dart';
import 'package:gestion_restaurant/models/modeles.dart';
import 'package:gestion_restaurant/services/caisse_service.dart';
import 'package:gestion_restaurant/services/commande_service.dart';
import 'package:gestion_restaurant/services/db.dart';
import 'package:gestion_restaurant/services/donnees_demo.dart';
import 'package:gestion_restaurant/services/export_rapport.dart';
import 'package:excel/excel.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('périodes : jour, semaine du lundi au dimanche, mois, précédente', () {
    final mer = DateTime(2026, 11, 18, 21, 30); // mercredi
    final j = Periode.contenant(TypePeriode.jour, mer);
    expect(j.debut, DateTime(2026, 11, 18));
    expect(j.fin, DateTime(2026, 11, 19));
    final s = Periode.contenant(TypePeriode.semaine, mer);
    expect(s.debut, DateTime(2026, 11, 16));
    expect(s.fin, DateTime(2026, 11, 23));
    expect(s.precedente.debut, DateTime(2026, 11, 9));
    final m = Periode.contenant(TypePeriode.mois, mer);
    expect(m.debut, DateTime(2026, 11));
    expect(m.precedente.debut, DateTime(2026, 10));
    expect(Periode.contenant(TypePeriode.mois, DateTime(2026, 12, 5)).fin, DateTime(2027, 1));
    expect(evolution(120, 100), 20);
    expect(evolution(5, 0), isNull);
  });

  test('rapport d’une soirée : CA, marges, heures, serveuses, bénéfice — il correspond aux factures', () async {
    const awa = Acteur(id: 'e-awa', nom: 'Awa', role: Role.serveuse);
    const fatou = Acteur(id: 'e-fatou', nom: 'Fatou', role: Role.serveuse);
    const koffi = Acteur(id: 'e-koffi', nom: 'Koffi', role: Role.caissier);
    final db = RestoDb(fs: FakeFirebaseFirestore(), idRestaurant: 'demo', appareil: 'test');
    await remplirDemo(db);
    final cmd = CommandeService(db);
    final caisse = CaisseService(db);
    final resto = Restaurant.fromDoc(await db.resto.get());
    Future<Article> art(String id) async => Article.fromDoc(await db.articles.doc(id).get());
    final jid = await caisse.ouvrirCaisse(koffi, 0);
    final j = JourneeCaisse.fromDoc(await db.journeesCaisse.doc(jid).get());

    Future<void> table(Acteur s, String t, Map<String, int> cmdes, {int parts = 1, bool credit = false}) async {
      final id = await cmd.validerTour(
        serveuse: s,
        panier: [for (final e in cmdes.entries) ElementPanier(await art(e.key), quantite: e.value)],
        table: TableResto.fromDoc(await db.tables.doc(t).get()),
      );
      final sess = SessionTable.fromDoc(await db.sessions.doc(id).get());
      final ids = await caisse.emettreFactures(caissier: koffi, session: sess, restaurant: resto, nombreParts: parts);
      for (final fid in ids) {
        final f = Facture.fromDoc(await db.factures.doc(fid).get());
        if (credit) {
          await caisse.mettreEnArdoise(caissier: koffi, facture: f, client: 'X');
        } else {
          await caisse.encaisser(caissier: koffi, facture: f, montantRecu: f.total, journee: j);
        }
      }
    }

    await table(awa, 't-1', {'a-flag': 4, 'a-poulet': 1}); // 2800 + 4000
    await table(fatou, 't-2', {'a-castel': 2, 'a-poisson': 2}, parts: 3); // 1400 + 9000 = 10400
    await table(fatou, 't-3', {'a-coca': 2}, credit: true); // 1000

    final factures = [for (final d in (await db.factures.get()).docs) Facture.fromDoc(d)];
    final articles = [for (final d in (await db.articles.get()).docs) Article.fromDoc(d)];
    final recettes = {for (final d in (await db.recettes.get()).docs) d.id: Recette.fromDoc(d)};
    final r = calculerRapport(
      periode: Periode.contenant(TypePeriode.jour, DateTime.now()),
      factures: factures,
      articles: articles,
      recettes: recettes,
      depenses: [(categorie: 'Gaz', montant: 3000, date: DateTime.now())],
      annulations: [(demandeur: 'Awa', date: DateTime.now())],
      avoirs: [(montant: -700, date: DateTime.now())],
      nomsCategories: {'c-bieres': 'Bières', 'c-plats': 'Plats', 'c-sucreries': 'Sucreries'},
    );

    // Le CA correspond exactement à la somme des factures réglées.
    expect(r.chiffreAffaires, factures.fold(0, (s, f) => s + f.total));
    expect(r.chiffreAffaires, 6800 + 10400 + 1000);
    expect(r.nbFactures, 1 + 3 + 1);
    expect(r.encaisse, 17200);
    expect(r.aCredit, 1000);
    expect(r.ventesParHeure.reduce((a, b) => a + b), r.chiffreAffaires);

    // Ventes par article : le partage en 3 parts ne triple pas les quantités.
    final poisson = r.articles.firstWhere((v) => v.idArticle == 'a-poisson');
    expect(poisson.quantite, 2);
    expect(poisson.montant, 9000);
    // Coût du poisson braisé (fiche) = 2200 + 0,1×600 + 0,02×1500 + 150 = 2440.
    expect(poisson.cout, 2 * 2440);
    final flag = r.articles.firstWhere((v) => v.idArticle == 'a-flag');
    expect(flag.cout, 4 * 520);
    expect(r.articles.first.idArticle, 'a-poisson');
    expect(r.ventesParCategorie['Plats'], 13000);

    // Serveuses.
    final f = r.serveuses.firstWhere((p) => p.nom == 'Fatou');
    expect(f.montant, 11400);
    expect(f.tables.length, 2);
    expect(r.serveuses.firstWhere((p) => p.nom == 'Awa').annulations, 1);

    // Bénéfice estimé = ventes − avoirs − coût des marchandises − dépenses.
    expect(r.avoirs, 700);
    expect(r.depenses, 3000);
    expect(r.beneficeEstime, r.chiffreAffaires - 700 - r.coutMarchandises - 3000);
    expect(r.nonVendus.map((a) => a.id), contains('a-guinness'));
    expect(r.nonVendus.map((a) => a.id), isNot(contains('i-poulet')));

    // Export Excel : le fichier se relit, avec une feuille par thème.
    final prec = calculerRapport(periode: r.periode.precedente, factures: factures, articles: articles);
    final xl = Excel.decodeBytes(rapportExcel(resto, r, prec));
    expect(xl.tables.keys, containsAll(['Synthèse', 'Articles', 'Catégories', 'Heures', 'Serveuses', 'Dépenses']));
    expect(xl.tables.keys, isNot(contains('Sheet1')));
    final ligneCa = xl.tables['Synthèse']!.rows.firstWhere(
      (l) => l.first?.value.toString().startsWith('Chiffre') ?? false,
    );
    expect((ligneCa[1]!.value as IntCellValue).value, r.chiffreAffaires);
    final html = rapportHtml(resto, r, prec);
    expect(html, contains('Poisson braisé'));
    expect(html, contains('@page { size: A4'));
  });
}
