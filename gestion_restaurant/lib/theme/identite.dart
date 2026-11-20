import 'package:material_ui/material_ui.dart';

/// ============================================================================
///  IDENTITÉ VISUELLE DU RESTAURANT — le seul fichier à modifier
/// ============================================================================
///
/// Tout le design de l'application (couleurs claires et sombres, polices,
/// arrondis, logo, animations) est lu depuis [identite]. Pour une autre
/// charte : remplacer les valeurs ci-dessous.
///
/// - couleurs : 0xFF + RRGGBB (ex. #F55A0A → 0xFFF55A0A) ;
/// - polices : fichiers .ttf dans assets/fonts/, déclarés dans pubspec.yaml ;
/// - logo : image dans assets/images/.
///
/// Identité actuelle : **Restaurant Chez les Amani**, d'après le logo :
/// orange cloche (#FD5D09), vert forêt (#0A3116) et crème (#FFF3D3).
class IdentiteVisuelle {
  // --- Couleurs de marque (tirées du logo) ----------------------------------
  /// Orange du logo : actions principales, éléments actifs.
  final Color principale;

  /// Vert forêt du logo : marque, en-têtes, mode clair.
  final Color secondaire;

  /// Crème du logo : accents sur fond sombre, surfaces chaudes.
  final Color accent;

  // --- Mode clair (administration, stock, caisse) ---------------------------
  final Color fond;
  final Color surface;
  final Color texte;

  // --- Mode sombre (plan de salle, prise de commande, connexion) ------------
  /// Obsidienne teintée du vert du logo.
  final Color nuit;
  final Color surfaceSombre;
  final Color surfaceSombreElevee;
  final Color texteSombre;

  // --- États des tables (section 3.1 du cahier des charges) -----------------
  // Validés (contraste, daltonisme) ; l'état est toujours écrit en toutes
  // lettres à côté, la couleur n'est jamais le seul indice.
  final Color tableLibre;
  final Color tableOccupee;
  final Color tableAddition;
  final Color erreur;

  /// Or chaud (dérivé de la crème du logo) : liserés, motif, distinctions.
  final Color or;

  // --- Typographie -------------------------------------------------------------
  /// Police de marque (titres d'écran, nom, slogan) : serif chaleureuse.
  final String policeMarque;

  /// Titres d'interface, numéros de table, montants.
  final String policeTitres;

  /// Interface et texte courant.
  final String policeTexte;

  // --- Formes, logo, motif, animations -------------------------------------------
  final double arrondi;
  final String? logoAsset;

  // --- Textes de marque --------------------------------------------------------
  final String nomRestaurant;
  final String slogan;
  final String prestations;
  final bool motif;

  /// 1.0 = vitesse normale ; 0 = aucune animation. Le réglage d'accessibilité
  /// « réduire les animations » de l'appareil est toujours respecté.
  final double vitesseAnimations;

  const IdentiteVisuelle({
    required this.principale,
    required this.secondaire,
    required this.accent,
    required this.fond,
    required this.surface,
    required this.texte,
    required this.nuit,
    required this.surfaceSombre,
    required this.surfaceSombreElevee,
    required this.texteSombre,
    required this.tableLibre,
    required this.tableOccupee,
    required this.tableAddition,
    required this.erreur,
    required this.or,
    required this.policeMarque,
    required this.policeTitres,
    required this.policeTexte,
    this.arrondi = 20,
    this.logoAsset,
    this.nomRestaurant = 'Restaurant',
    this.slogan = '',
    this.prestations = '',
    this.motif = true,
    this.vitesseAnimations = 1,
  });
}

/// Identité active : Restaurant Chez les Amani — « Signature Amani ».
///
/// Couleurs du logo (orange, vert forêt, crème) déclinées en deux ambiances :
/// nuit de forêt (service en salle) et sable chaud (caisse, gestion).
const identite = IdentiteVisuelle(
  principale: Color(0xFFF55A0A), // orange braise (logo)
  secondaire: Color(0xFF0B3A1C), // vert forêt (logo)
  accent: Color(0xFFFFE2AE), // crème (logo)
  or: Color(0xFFE5A53A), // or chaud
  fond: Color(0xFFF6EEDF), // sable
  surface: Color(0xFFFFFCF6), // ivoire
  texte: Color(0xFF13281B), // vert presque noir
  nuit: Color(0xFF06170D), // nuit de forêt
  surfaceSombre: Color(0xFF0C2516),
  surfaceSombreElevee: Color(0xFF133320),
  texteSombre: Color(0xFFFFF4DF), // crème
  tableLibre: Color(0xFF16A34A), // vert feuille
  tableOccupee: Color(0xFFE39A0E), // ocre doré
  tableAddition: Color(0xFF3B7BF2), // bleu
  erreur: Color(0xFFE5484D),
  policeMarque: 'Fraunces',
  policeTitres: 'PlusJakartaSans',
  policeTexte: 'Inter',
  arrondi: 22,
  logoAsset: 'assets/images/logo_amani.png',
  nomRestaurant: 'Restaurant Chez les Amani',
  slogan: 'Le goût de l’Afrique, la signature AMANI',
  prestations: 'Cuisine ivoirienne · Grillades · Boissons',
  motif: true,
  vitesseAnimations: 1,
);
