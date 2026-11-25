import 'package:material_ui/material_ui.dart';

import 'theme/app_theme.dart';

/// Application (thème, langue, écran d'accueil).
class GestionRestaurantApp extends StatelessWidget {
  final Widget accueil;
  const GestionRestaurantApp({super.key, required this.accueil});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Chez les Amani',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: accueil,
    );
  }
}
