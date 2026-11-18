/// Calculs de facturation (section 4.3 du cahier des charges).
///
/// Tous les montants sont en francs CFA entiers, sans centimes.
library;

/// Une ligne de calcul : quantité × prix unitaire, éventuellement annulée.
class LigneCalcul {
  final int quantite;
  final int prixUnitaire;
  final bool annulee;
  const LigneCalcul(this.quantite, this.prixUnitaire, {this.annulee = false});
  int get montant => annulee ? 0 : quantite * prixUnitaire;
}

/// Type de remise : montant fixe ou pourcentage.
enum TypeRemise { montant, pourcentage }

class Remise {
  final TypeRemise type;
  final int valeur; // en F ou en %
  final String motif;
  final String validePar;
  const Remise({
    required this.type,
    required this.valeur,
    required this.motif,
    required this.validePar,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'valeur': valeur,
        'motif': motif,
        'validePar': validePar,
      };

  static Remise? fromMap(Object? m) {
    if (m is! Map) return null;
    return Remise(
      type: TypeRemise.values.byName(m['type'] as String),
      valeur: (m['valeur'] as num).toInt(),
      motif: m['motif'] as String? ?? '',
      validePar: m['validePar'] as String? ?? '',
    );
  }
}

/// Résultat complet d'un calcul de facture.
class Totaux {
  final int sousTotal;
  final int remise;
  final int total;
  /// Part de TVA incluse dans le total (prix saisis TTC). 0 si non soumis.
  final int tva;
  const Totaux({
    required this.sousTotal,
    required this.remise,
    required this.total,
    required this.tva,
  });
}

int sousTotal(Iterable<LigneCalcul> lignes) =>
    lignes.fold(0, (s, l) => s + l.montant);

/// Montant de la remise, arrondi au franc et plafonné au sous-total.
int montantRemise(int sousTotal, Remise? remise) {
  if (remise == null || remise.valeur <= 0) return 0;
  final brut = remise.type == TypeRemise.montant
      ? remise.valeur
      : (sousTotal * remise.valeur / 100).round();
  return brut.clamp(0, sousTotal);
}

/// TVA incluse dans un montant TTC : TTC × taux / (100 + taux).
int tvaIncluse(int totalTtc, double tauxTva) {
  if (tauxTva <= 0) return 0;
  return (totalTtc * tauxTva / (100 + tauxTva)).round();
}

Totaux calculerTotaux(
  Iterable<LigneCalcul> lignes, {
  Remise? remise,
  double tauxTva = 0,
}) {
  final st = sousTotal(lignes);
  final r = montantRemise(st, remise);
  final total = st - r;
  return Totaux(
    sousTotal: st,
    remise: r,
    total: total,
    tva: tvaIncluse(total, tauxTva),
  );
}

/// Monnaie à rendre = montant reçu − total. Lève une erreur si insuffisant.
int monnaieARendre(int montantRecu, int total) {
  if (montantRecu < total) {
    throw ArgumentError('Montant reçu insuffisant : $montantRecu < $total');
  }
  return montantRecu - total;
}

/// Partage en parts égales : les francs restants vont aux premières parts,
/// pour que la somme des parts égale exactement le total.
List<int> partsEgales(int total, int nombreParts) {
  if (nombreParts < 1) throw ArgumentError('Au moins une part');
  final base = total ~/ nombreParts;
  final reste = total % nombreParts;
  return List.generate(nombreParts, (i) => base + (i < reste ? 1 : 0));
}

/// Conversion d'une livraison en casiers + bouteilles vers des unités.
int casiersEnUnites({
  required int casiers,
  required int unitesParCasier,
  int unitesIsolees = 0,
}) {
  if (casiers < 0 || unitesIsolees < 0 || unitesParCasier < 0) {
    throw ArgumentError('Quantités négatives interdites');
  }
  return casiers * unitesParCasier + unitesIsolees;
}

/// Coût moyen pondéré après une entrée de stock.
/// Si le stock existant est négatif ou nul, le nouveau prix devient le coût.
int nouveauCoutMoyen({
  required num stockActuel,
  required int coutMoyenActuel,
  required num quantiteEntree,
  required int prixAchatUnitaire,
}) {
  if (quantiteEntree <= 0) return coutMoyenActuel;
  if (stockActuel <= 0) return prixAchatUnitaire;
  final valeur =
      stockActuel * coutMoyenActuel + quantiteEntree * prixAchatUnitaire;
  return (valeur / (stockActuel + quantiteEntree)).round();
}

/// Format des numéros : FAC-AAAA-NNNNNN et AV-AAAA-NNNNNN (section 4.4).
String numeroFacture(int annee, int sequence) =>
    'FAC-$annee-${sequence.toString().padLeft(6, '0')}';
String numeroAvoir(int annee, int sequence) =>
    'AV-$annee-${sequence.toString().padLeft(6, '0')}';
