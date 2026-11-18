import 'package:material_ui/material_ui.dart';

import 'identite.dart';

/// Construit le thème Material à partir de l'identité visuelle.
ThemeData construireTheme(IdentiteVisuelle id) {
  final schema = ColorScheme.fromSeed(
    seedColor: id.principale,
    primary: id.principale,
    secondary: id.accent,
    tertiary: id.tableAddition,
    surface: id.surface,
    error: id.erreur,
  ).copyWith(onSurface: id.texte);

  final rayon = BorderRadius.circular(id.arrondi);
  final rayonPetit = BorderRadius.circular(id.arrondi * 0.66);
  final base = ThemeData(useMaterial3: true, colorScheme: schema, fontFamily: id.policeTexte);

  TextStyle? titre(TextStyle? s, {FontWeight poids = FontWeight.w600}) =>
      s?.copyWith(fontFamily: id.policeTitres, fontWeight: poids, color: id.texte, letterSpacing: -0.3);

  final textes = base.textTheme.copyWith(
    displayLarge: titre(base.textTheme.displayLarge, poids: FontWeight.w800),
    displayMedium: titre(base.textTheme.displayMedium, poids: FontWeight.w800),
    displaySmall: titre(base.textTheme.displaySmall, poids: FontWeight.w800),
    headlineLarge: titre(base.textTheme.headlineLarge, poids: FontWeight.w800),
    headlineMedium: titre(base.textTheme.headlineMedium, poids: FontWeight.w800),
    headlineSmall: titre(base.textTheme.headlineSmall),
    titleLarge: titre(base.textTheme.titleLarge),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    scaffoldBackgroundColor: id.fond,
    textTheme: textes,
    visualDensity: VisualDensity.comfortable,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: TransitionBraise(),
        TargetPlatform.windows: TransitionBraise(),
        TargetPlatform.linux: TransitionBraise(),
        TargetPlatform.macOS: TransitionBraise(),
        TargetPlatform.iOS: TransitionBraise(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: id.nuit,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: id.policeTitres,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: id.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: rayon,
        side: BorderSide(color: id.texte.withValues(alpha: 0.08)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        shape: RoundedRectangleBorder(borderRadius: rayonPetit),
        textStyle: TextStyle(fontFamily: id.policeTexte, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: rayonPetit),
        side: BorderSide(color: id.principale.withValues(alpha: 0.5), width: 1.5),
        textStyle: TextStyle(fontFamily: id.policeTexte, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: StadiumBorder(side: BorderSide(color: id.texte.withValues(alpha: 0.12))),
      selectedColor: id.principale,
      secondarySelectedColor: id.principale,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(fontFamily: id.policeTexte, fontWeight: FontWeight.w600, color: id.texte),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: id.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(id.arrondi * 1.4)),
      titleTextStyle: TextStyle(
        fontFamily: id.policeTitres,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: id.texte,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: id.nuit,
      shape: RoundedRectangleBorder(borderRadius: rayonPetit),
      contentTextStyle: TextStyle(fontFamily: id.policeTexte, fontSize: 16, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: id.fond,
      border: OutlineInputBorder(borderRadius: rayonPetit, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: rayonPetit,
        borderSide: BorderSide(color: id.texte.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rayonPetit,
        borderSide: BorderSide(color: id.principale, width: 2),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: id.surface,
      indicatorColor: id.accent.withValues(alpha: 0.35),
      selectedIconTheme: IconThemeData(color: id.principale),
      selectedLabelTextStyle: TextStyle(fontFamily: id.policeTexte, fontWeight: FontWeight.w700, color: id.principale),
      unselectedLabelTextStyle: TextStyle(fontFamily: id.policeTexte, color: id.texte.withValues(alpha: 0.7)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: id.principale,
      unselectedLabelColor: id.texte.withValues(alpha: 0.6),
      indicatorColor: id.principale,
      labelStyle: TextStyle(fontFamily: id.policeTexte, fontWeight: FontWeight.w700, fontSize: 15),
      dividerColor: id.texte.withValues(alpha: 0.08),
    ),
    dividerTheme: DividerThemeData(color: id.texte.withValues(alpha: 0.08)),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: rayonPetit)),
  );
}

/// Transition entre écrans : fondu, léger glissement vers le haut et zoom.
class TransitionBraise extends PageTransitionsBuilder {
  const TransitionBraise();
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
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(entree),
        child: ScaleTransition(scale: Tween(begin: 1.0, end: 0.97).animate(sortie), child: child),
      ),
    );
  }
}
