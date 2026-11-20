import '../models/modeles.dart';

/// Portions encore possibles d'un plat à fiche technique : le minimum, sur
/// tous ses ingrédients, de stock ÷ quantité par portion (arrondi en bas).
int portionsPossibles(Recette r, Map<String, Article> articles) {
  if (r.ingredients.isEmpty) return 0;
  var min = 1 << 30;
  for (final i in r.ingredients) {
    if (i.quantite <= 0) continue;
    final stock = articles[i.idArticle]?.stock ?? 0;
    // Petite tolérance pour les arrondis des décimales (0,1 kg × 3).
    final p = stock <= 0 ? 0 : ((stock + 1e-9) / i.quantite).floor();
    if (p < min) min = p;
  }
  return min == 1 << 30 ? 0 : min;
}

/// Ingrédients à déduire pour [quantite] portions.
List<Ingredient> deductionsPour(Recette r, int quantite) => [
  for (final i in r.ingredients)
    Ingredient(idArticle: i.idArticle, nom: i.nom, quantite: arrondiQte(i.quantite * quantite), unite: i.unite),
];

/// Arrondit une quantité à 3 décimales (évite 0,30000000000000004).
num arrondiQte(num q) {
  final r = (q * 1000).round() / 1000;
  return r == r.roundToDouble() ? r.round() : r;
}

/// « 4,7 kg », « 12 » : affichage d'une quantité de stock.
String qte(num q, [String unite = '']) {
  final r = arrondiQte(q);
  final t = r is int ? '$r' : r.toString().replaceAll('.', ',');
  return unite.isEmpty ? t : '$t $unite';
}
