import 'package:material_ui/material_ui.dart';

import 'identite.dart';

/// ============================================================================
///  THÈME « PREMIUM POS » — Restaurant Chez les Amani
/// ============================================================================
///
/// Deux ambiances, choisies par module :
/// - **sombre** (obsidienne verte) : plan de salle, prise de commande,
///   connexion — moins d'éblouissement le soir, couleurs d'état plus vives ;
/// - **clair** (crème) : caisse, stock, administration.
///
/// Les écrans lisent leurs couleurs avec `context.pal` (jamais de couleur
/// codée en dur), ce qui les rend compatibles avec les deux ambiances.

/// Palette sémantique, injectée dans le thème (`ThemeExtension`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color fond;
  final Color surface;
  final Color surfaceElevee;
  final Color bordure;
  final Color texte;
  final Color texteSecondaire;
  final Color texteDiscret;
  final Color principale;
  final Color secondaire;
  final Color accent;
  final Color libre;
  final Color occupee;
  final Color addition;
  final Color erreur;
  final Color ombre;
  final bool sombre;

  const AppPalette({
    required this.fond,
    required this.surface,
    required this.surfaceElevee,
    required this.bordure,
    required this.texte,
    required this.texteSecondaire,
    required this.texteDiscret,
    required this.principale,
    required this.secondaire,
    required this.accent,
    required this.libre,
    required this.occupee,
    required this.addition,
    required this.erreur,
    required this.ombre,
    required this.sombre,
  });

  static final AppPalette clair = AppPalette(
    fond: identite.fond,
    surface: identite.surface,
    surfaceElevee: identite.surface,
    bordure: const Color(0xFFE6D9C2),
    texte: identite.texte,
    texteSecondaire: identite.texte.withValues(alpha: 0.68),
    texteDiscret: identite.texte.withValues(alpha: 0.45),
    principale: identite.principale,
    secondaire: identite.secondaire,
    accent: identite.accent,
    libre: identite.tableLibre,
    occupee: identite.tableOccupee,
    addition: identite.tableAddition,
    erreur: identite.erreur,
    ombre: identite.secondaire,
    sombre: false,
  );

  static final AppPalette fonce = AppPalette(
    fond: identite.nuit,
    surface: identite.surfaceSombre,
    surfaceElevee: identite.surfaceSombreElevee,
    bordure: identite.accent.withValues(alpha: 0.10),
    texte: identite.texteSombre,
    texteSecondaire: identite.texteSombre.withValues(alpha: 0.72),
    texteDiscret: identite.texteSombre.withValues(alpha: 0.45),
    principale: identite.principale,
    secondaire: identite.secondaire,
    accent: identite.accent,
    libre: identite.tableLibre,
    occupee: identite.tableOccupee,
    addition: identite.tableAddition,
    erreur: identite.erreur,
    ombre: Colors.black,
    sombre: true,
  );

  /// Couleur d'un état de table.
  Color etat({required bool occupee, required bool addition}) =>
      addition ? this.addition : (occupee ? this.occupee : libre);

  @override
  AppPalette copyWith({Color? fond, Color? surface, Color? texte}) => AppPalette(
    fond: fond ?? this.fond,
    surface: surface ?? this.surface,
    surfaceElevee: surfaceElevee,
    bordure: bordure,
    texte: texte ?? this.texte,
    texteSecondaire: texteSecondaire,
    texteDiscret: texteDiscret,
    principale: principale,
    secondaire: secondaire,
    accent: accent,
    libre: libre,
    occupee: occupee,
    addition: addition,
    erreur: erreur,
    ombre: ombre,
    sombre: sombre,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      fond: l(fond, other.fond),
      surface: l(surface, other.surface),
      surfaceElevee: l(surfaceElevee, other.surfaceElevee),
      bordure: l(bordure, other.bordure),
      texte: l(texte, other.texte),
      texteSecondaire: l(texteSecondaire, other.texteSecondaire),
      texteDiscret: l(texteDiscret, other.texteDiscret),
      principale: l(principale, other.principale),
      secondaire: l(secondaire, other.secondaire),
      accent: l(accent, other.accent),
      libre: l(libre, other.libre),
      occupee: l(occupee, other.occupee),
      addition: l(addition, other.addition),
      erreur: l(erreur, other.erreur),
      ombre: l(ombre, other.ombre),
      sombre: t < 0.5 ? sombre : other.sombre,
    );
  }
}

extension PaletteContexte on BuildContext {
  /// Palette de l'ambiance courante (claire ou sombre).
  AppPalette get pal => Theme.of(this).extension<AppPalette>() ?? AppPalette.clair;
}

/// Styles de texte. Tous les montants, compteurs et heures utilisent des
/// chiffres à chasse fixe : un total qui passe de 9 900 F à 10 100 F ne fait
/// pas « trembler » la ligne.
abstract final class AppTypo {
  static const chiffresFixes = [FontFeature.tabularFigures()];

  /// Ajoute les chiffres tabulaires à n'importe quel style.
  static TextStyle chiffres(TextStyle base) => base.copyWith(fontFeatures: [...?base.fontFeatures, ...chiffresFixes]);

  static TextStyle titre(Color couleur, {double taille = 22, FontWeight poids = FontWeight.w800}) => TextStyle(
    fontFamily: identite.policeTitres,
    fontSize: taille,
    fontWeight: poids,
    color: couleur,
    letterSpacing: -0.4,
    height: 1.15,
  );

  /// Montant en FCFA : police de titre + chiffres fixes.
  static TextStyle montant(Color couleur, {double taille = 18, FontWeight poids = FontWeight.w800}) =>
      chiffres(titre(couleur, taille: taille, poids: poids).copyWith(letterSpacing: -0.2));

  static TextStyle etiquette(Color couleur, {double taille = 13, FontWeight poids = FontWeight.w600}) =>
      TextStyle(fontFamily: identite.policeTexte, fontSize: taille, fontWeight: poids, color: couleur, height: 1.25);

  /// Police de marque (serif chaleureuse) : titres d'écran, nom, slogan.
  static TextStyle marque(Color couleur, {double taille = 28, FontWeight poids = FontWeight.w700, bool italique = false}) =>
      TextStyle(
        fontFamily: identite.policeMarque,
        fontSize: taille,
        fontWeight: poids,
        fontStyle: italique ? FontStyle.italic : FontStyle.normal,
        color: couleur,
        letterSpacing: -0.3,
        height: 1.12,
      );

  /// Sur-titre en petites capitales espacées (« CAISSE », « PILOTAGE »).
  static TextStyle surTitre(Color couleur, {double taille = 12}) => TextStyle(
    fontFamily: identite.policeTexte,
    fontSize: taille,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.2,
    color: couleur,
  );
}

/// Ombres douces multicouches (proche + diffuse), plus marquées en sombre.
abstract final class AppOmbres {
  static List<BoxShadow> douce(AppPalette p, {double force = 1}) => [
    BoxShadow(
      color: p.ombre.withValues(alpha: (p.sombre ? 0.35 : 0.06) * force),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: p.ombre.withValues(alpha: (p.sombre ? 0.30 : 0.07) * force),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: p.ombre.withValues(alpha: (p.sombre ? 0.20 : 0.04) * force),
      blurRadius: 40,
      offset: const Offset(0, 18),
    ),
  ];

  /// Lueur colorée sous un élément (carte de table, bouton principal).
  static List<BoxShadow> lueur(Color c, {double force = 1}) => [
    BoxShadow(
      color: c.withValues(alpha: 0.28 * force),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: c.withValues(alpha: 0.12 * force),
      blurRadius: 36,
      offset: const Offset(0, 16),
    ),
  ];
}

/// Dégradé subtil des actions principales (orange cloche du logo).
LinearGradient degradePrincipal([Color? base]) {
  final c = base ?? identite.principale;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(c, Colors.white, 0.10)!, c, Color.lerp(c, Colors.black, 0.14)!],
    stops: const [0, 0.55, 1],
  );
}

abstract final class AppTheme {
  static final ThemeData clair = _construire(AppPalette.clair, Brightness.light);
  static final ThemeData sombre = _construire(AppPalette.fonce, Brightness.dark);

  static ThemeData _construire(AppPalette p, Brightness luminosite) {
    final schema = ColorScheme.fromSeed(
      seedColor: identite.principale,
      brightness: luminosite,
      primary: p.principale,
      onPrimary: Colors.white,
      secondary: p.sombre ? p.accent : p.secondaire,
      tertiary: p.addition,
      surface: p.surface,
      onSurface: p.texte,
      error: p.erreur,
    );
    final rayon = BorderRadius.circular(identite.arrondi);
    final rayonPetit = BorderRadius.circular(identite.arrondi * 0.7);
    final base = ThemeData(
      useMaterial3: true,
      brightness: luminosite,
      colorScheme: schema,
      fontFamily: identite.policeTexte,
    );
    TextStyle? titre(TextStyle? s, FontWeight poids) =>
        s?.copyWith(fontFamily: identite.policeTitres, fontWeight: poids, color: p.texte, letterSpacing: -0.4);
    TextStyle? marque(TextStyle? s) =>
        s?.copyWith(fontFamily: identite.policeMarque, fontWeight: FontWeight.w700, color: p.texte, letterSpacing: -0.3);

    final textes = base.textTheme
        .apply(bodyColor: p.texte, displayColor: p.texte)
        .copyWith(
          displayLarge: marque(base.textTheme.displayLarge),
          displayMedium: marque(base.textTheme.displayMedium),
          displaySmall: marque(base.textTheme.displaySmall),
          headlineLarge: marque(base.textTheme.headlineLarge),
          headlineMedium: marque(base.textTheme.headlineMedium),
          headlineSmall: titre(base.textTheme.headlineSmall, FontWeight.w700),
          titleLarge: titre(base.textTheme.titleLarge, FontWeight.w700),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: p.texte),
        );

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.fond,
      canvasColor: p.fond,
      textTheme: textes,
      visualDensity: VisualDensity.comfortable,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransitionAmani(),
          TargetPlatform.windows: TransitionAmani(),
          TargetPlatform.linux: TransitionAmani(),
          TargetPlatform.macOS: TransitionAmani(),
          TargetPlatform.iOS: TransitionAmani(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.sombre ? p.fond : identite.secondaire,
        foregroundColor: identite.accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypo.marque(identite.texteSombre, taille: 24),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: rayon,
          side: BorderSide(color: p.bordure),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          backgroundColor: p.principale,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.texte.withValues(alpha: 0.10),
          shape: const StadiumBorder(),
          textStyle: TextStyle(fontFamily: identite.policeTexte, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          foregroundColor: p.sombre ? p.accent : p.secondaire,
          shape: const StadiumBorder(),
          side: BorderSide(color: p.sombre ? p.accent.withValues(alpha: 0.35) : p.secondaire.withValues(alpha: 0.35), width: 1.5),
          textStyle: TextStyle(fontFamily: identite.policeTexte, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.sombre ? p.accent : p.principale,
          minimumSize: const Size(48, 48),
          textStyle: TextStyle(fontFamily: identite.policeTexte, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.bordure)),
        selectedColor: p.principale,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(fontFamily: identite.policeTexte, fontWeight: FontWeight.w600, color: p.texte),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevee,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(identite.arrondi * 1.4),
          side: BorderSide(color: p.bordure),
        ),
        titleTextStyle: AppTypo.marque(p.texte, taille: 26),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevee,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(identite.arrondi * 1.4)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.sombre ? p.surfaceElevee : identite.secondaire,
        shape: RoundedRectangleBorder(
          borderRadius: rayonPetit,
          side: BorderSide(color: p.bordure),
        ),
        contentTextStyle: TextStyle(fontFamily: identite.policeTexte, fontSize: 16, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.sombre ? identite.accent.withValues(alpha: 0.05) : const Color(0xFFFBF5EA),
        border: OutlineInputBorder(borderRadius: rayonPetit, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: rayonPetit,
          borderSide: BorderSide(color: p.bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: rayonPetit,
          borderSide: BorderSide(color: p.principale, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.principale.withValues(alpha: 0.14),
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: p.principale),
        unselectedIconTheme: IconThemeData(color: p.texteSecondaire),
        selectedLabelTextStyle: TextStyle(
          fontFamily: identite.policeTexte,
          fontWeight: FontWeight.w700,
          color: p.principale,
        ),
        unselectedLabelTextStyle: TextStyle(fontFamily: identite.policeTexte, color: p.texteSecondaire),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.principale,
        unselectedLabelColor: p.texteSecondaire,
        indicatorColor: p.principale,
        labelStyle: TextStyle(fontFamily: identite.policeTexte, fontWeight: FontWeight.w700, fontSize: 15),
        dividerColor: p.bordure,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.principale.withValues(alpha: 0.15),
          selectedForegroundColor: p.principale,
          side: BorderSide(color: p.bordure),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.bordure),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: rayonPetit),
        textColor: p.texte,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.principale),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.sombre ? p.surfaceElevee : identite.secondaire,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.bordure),
        ),
        textStyle: AppTypo.chiffres(const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

/// Transition entre écrans : fondu + léger glissement vers le haut, et l'écran
/// quitté recule légèrement. Les éléments `Hero` (carte de table → en-tête de
/// commande) volent par-dessus.
class TransitionAmani extends PageTransitionsBuilder {
  const TransitionAmani();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entree = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final sortie = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: entree,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(entree),
        child: ScaleTransition(scale: Tween(begin: 1.0, end: 0.97).animate(sortie), child: child),
      ),
    );
  }
}
