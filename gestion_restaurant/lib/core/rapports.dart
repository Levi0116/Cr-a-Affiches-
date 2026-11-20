import '../models/modeles.dart';

/// Période d'un rapport (section 5.3) : jour, semaine (lundi → dimanche) ou mois.
enum TypePeriode { jour, semaine, mois }

class Periode {
  final TypePeriode type;
  final DateTime debut; // inclus
  final DateTime fin; // exclu
  const Periode(this.type, this.debut, this.fin);

  factory Periode.contenant(TypePeriode type, DateTime d) {
    final jour = DateTime(d.year, d.month, d.day);
    return switch (type) {
      TypePeriode.jour => Periode(type, jour, DateTime(d.year, d.month, d.day + 1)),
      TypePeriode.semaine => Periode(
        type,
        DateTime(d.year, d.month, d.day - (d.weekday - 1)),
        DateTime(d.year, d.month, d.day - (d.weekday - 1) + 7),
      ),
      TypePeriode.mois => Periode(type, DateTime(d.year, d.month), DateTime(d.year, d.month + 1)),
    };
  }

  Periode get precedente => Periode.contenant(type, debut.subtract(const Duration(days: 1)));
  Periode get suivante => Periode.contenant(type, fin);
  bool contient(DateTime d) => !d.isBefore(debut) && d.isBefore(fin);
}

class VenteArticle {
  final String nom;
  final String idArticle;
  int quantite = 0;
  int montant = 0;
  int cout = 0;
  VenteArticle(this.idArticle, this.nom);
  int get marge => montant - cout;
  double get tauxMarge => montant == 0 ? 0 : marge / montant;
}

class PerfServeuse {
  final String nom;
  final Set<String> tables = {};
  int montant = 0;
  int annulations = 0;
  PerfServeuse(this.nom);
}

class Rapport {
  final Periode periode;
  final int chiffreAffaires; // factures payées + à crédit
  final int nbFactures;
  final int encaisse; // factures payées
  final int aCredit;
  final int avoirs;
  final int coutMarchandises;
  final int depenses;
  final Map<String, int> depensesParCategorie;
  final List<VenteArticle> articles; // triés par montant décroissant
  final Map<String, int> ventesParCategorie;
  final List<int> ventesParHeure; // 24 cases
  final List<PerfServeuse> serveuses;
  final List<Article> nonVendus;

  const Rapport({
    required this.periode,
    required this.chiffreAffaires,
    required this.nbFactures,
    required this.encaisse,
    required this.aCredit,
    required this.avoirs,
    required this.coutMarchandises,
    required this.depenses,
    required this.depensesParCategorie,
    required this.articles,
    required this.ventesParCategorie,
    required this.ventesParHeure,
    required this.serveuses,
    required this.nonVendus,
  });

  int get ventesNettes => chiffreAffaires - avoirs;
  int get panierMoyen => nbFactures == 0 ? 0 : (chiffreAffaires / nbFactures).round();

  /// Bénéfice estimé = ventes − coût des marchandises vendues − dépenses.
  int get beneficeEstime => ventesNettes - coutMarchandises - depenses;
  int get margeBrute => ventesNettes - coutMarchandises;
}

/// Évolution en % par rapport à la période précédente (null si pas de base).
double? evolution(num actuel, num precedent) => precedent == 0 ? null : (actuel - precedent) / precedent * 100;

/// Calcule un rapport à partir des documents bruts.
///
/// - Les factures en parts égales répètent les lignes : elles ne sont
///   comptées qu'une fois (part « 1/n ») pour les ventes par article.
/// - Le coût d'un plat à fiche technique = somme des ingrédients au coût
///   moyen ; sinon le coût moyen de l'article.
Rapport calculerRapport({
  required Periode periode,
  required List<Facture> factures,
  required List<Article> articles,
  Map<String, Recette> recettes = const {},
  List<({int montant, DateTime date})> avoirs = const [],
  List<({String categorie, int montant, DateTime date})> depenses = const [],
  List<({String demandeur, DateTime date})> annulations = const [],
  Map<String, String> nomsCategories = const {},
}) {
  final parId = {for (final a in articles) a.id: a};
  int coutUnitaire(String idArticle) {
    final r = recettes[idArticle];
    if (r != null && (parId[idArticle]?.aRecette ?? false)) {
      return r.ingredients.fold<num>(0, (s, i) => s + i.quantite * (parId[i.idArticle]?.coutMoyen ?? 0)).round();
    }
    return parId[idArticle]?.coutMoyen ?? 0;
  }

  final vendues = factures.where((f) => f.statut != StatutFacture.emise && periode.contient(f.date)).toList();
  final ventes = <String, VenteArticle>{};
  final categories = <String, int>{};
  final heures = List.filled(24, 0);
  final serveuses = <String, PerfServeuse>{};
  var ca = 0, encaisse = 0, credit = 0, cmv = 0;

  for (final f in vendues) {
    ca += f.total;
    if (f.statut == StatutFacture.payee) {
      encaisse += f.total;
    } else {
      credit += f.total;
    }
    heures[f.date.hour] += f.total;
    final perf = serveuses.putIfAbsent(f.nomServeuse, () => PerfServeuse(f.nomServeuse));
    perf.montant += f.total;
    perf.tables.add(f.idSession);
    final premierePart = f.partie == null || f.partie!.startsWith('1/');
    if (!premierePart) continue;
    for (final l in f.lignes.where((l) => !l.annulee)) {
      final v = ventes.putIfAbsent(l.idArticle, () => VenteArticle(l.idArticle, l.nom));
      final cout = coutUnitaire(l.idArticle) * l.quantite;
      v.quantite += l.quantite;
      v.montant += l.montant;
      v.cout += cout;
      cmv += cout;
      final cat = nomsCategories[parId[l.idArticle]?.idCategorie] ?? 'Autre';
      categories[cat] = (categories[cat] ?? 0) + l.montant;
    }
  }
  for (final a in annulations.where((a) => periode.contient(a.date))) {
    serveuses.putIfAbsent(a.demandeur, () => PerfServeuse(a.demandeur)).annulations++;
  }
  final dep = <String, int>{};
  for (final d in depenses.where((d) => periode.contient(d.date))) {
    dep[d.categorie] = (dep[d.categorie] ?? 0) + d.montant;
  }
  final listeVentes = ventes.values.toList()..sort((a, b) => b.montant.compareTo(a.montant));
  return Rapport(
    periode: periode,
    chiffreAffaires: ca,
    nbFactures: vendues.length,
    encaisse: encaisse,
    aCredit: credit,
    avoirs: avoirs.where((a) => periode.contient(a.date)).fold(0, (s, a) => s + a.montant.abs()),
    coutMarchandises: cmv,
    depenses: dep.values.fold(0, (s, v) => s + v),
    depensesParCategorie: dep,
    articles: listeVentes,
    ventesParCategorie: Map.fromEntries(categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value))),
    ventesParHeure: heures,
    serveuses: serveuses.values.toList()..sort((a, b) => b.montant.compareTo(a.montant)),
    nonVendus: articles.where((a) => a.auMenu && !ventes.containsKey(a.id)).toList(),
  );
}
