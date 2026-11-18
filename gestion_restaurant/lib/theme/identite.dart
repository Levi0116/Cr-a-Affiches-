import 'package:material_ui/material_ui.dart';

/// ============================================================================
///  IDENTITÉ VISUELLE DU RESTAURANT — le seul fichier à modifier
/// ============================================================================
///
/// Tout le design de l'application (couleurs, polices, arrondis, motif,
/// logo, animations) est lu depuis [identite]. Quand la charte graphique du
/// restaurant sera prête, il suffit de remplacer les valeurs ci-dessous :
///
/// - couleurs : codes hexadécimaux 0xFF + RRGGBB (ex. #C4512B → 0xFFC4512B) ;
/// - polices : déposer les fichiers .ttf dans assets/fonts/, les déclarer
///   dans pubspec.yaml (rubrique fonts) puis mettre leur nom ici ;
/// - logo : déposer l'image dans assets/images/ et indiquer son chemin.
///
/// Identité provisoire « Braise » : terre cuite, or du mil, nuit d'ébène,
/// indigo, et un motif géométrique original inspiré des tissages d'Afrique
/// de l'Ouest.
class IdentiteVisuelle {
  // --- Couleurs de marque ---------------------------------------------------
  /// Couleur principale (boutons, éléments actifs).
  final Color principale;

  /// Couleur d'accent (montants, mises en avant, motif).
  final Color accent;

  /// Couleur sombre (barres, fond de l'écran de connexion).
  final Color nuit;

  /// Fond général clair.
  final Color fond;

  /// Fond des cartes et panneaux.
  final Color surface;

  /// Texte principal.
  final Color texte;

  // --- Couleurs d'état des tables (section 3.1 du cahier des charges) -------
  final Color tableLibre;
  final Color tableOccupee;
  final Color tableAddition;
  final Color erreur;

  // --- Typographie -----------------------------------------------------------
  /// Police des titres, des numéros de table et des montants.
  final String policeTitres;

  /// Police du texte courant et des boutons.
  final String policeTexte;

  // --- Formes ------------------------------------------------------------------
  final double arrondi;

  // --- Logo et motif -----------------------------------------------------------
  /// Chemin d'une image dans assets/ (null : monogramme généré à partir du
  /// nom du restaurant).
  final String? logoAsset;

  /// Affiche le motif géométrique décoratif dans les bandeaux.
  final bool motif;

  // --- Animations --------------------------------------------------------------
  /// 1.0 = vitesse normale ; 0 = aucune animation (les réglages
  /// d'accessibilité de l'appareil sont aussi respectés).
  final double vitesseAnimations;

  const IdentiteVisuelle({
    required this.principale,
    required this.accent,
    required this.nuit,
    required this.fond,
    required this.surface,
    required this.texte,
    required this.tableLibre,
    required this.tableOccupee,
    required this.tableAddition,
    required this.erreur,
    required this.policeTitres,
    required this.policeTexte,
    this.arrondi = 18,
    this.logoAsset,
    this.motif = true,
    this.vitesseAnimations = 1,
  });
}

/// Identité active.
const identite = IdentiteVisuelle(
  principale: Color(0xFFC4512B), // terre cuite / braise
  accent: Color(0xFFE3A33B), // or du mil
  nuit: Color(0xFF1F1A17), // ébène
  fond: Color(0xFFFBF5EC), // calebasse
  surface: Color(0xFFFFFCF7),
  texte: Color(0xFF2A211C),
  tableLibre: Color(0xFF2F8F5B), // feuille
  tableOccupee: Color(0xFFE07A2E), // braise vive
  tableAddition: Color(0xFF2E5AAC), // indigo
  erreur: Color(0xFFB3261E),
  policeTitres: 'Fraunces',
  policeTexte: 'Outfit',
  arrondi: 18,
  logoAsset: null,
  motif: true,
  vitesseAnimations: 1,
);
