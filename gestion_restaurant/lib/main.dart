import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'donnees/base.dart';
import 'features/connexion/accueil.dart';
import 'features/liaison/racine.dart';
import 'services/db.dart';
import 'services/donnees_demo.dart';
import 'services/serveur_appareils.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

/// `--dart-define=SERVEUR=true` : PWA reliée au serveur Node.js + MySQL.
/// Sinon : mode démonstration, données en mémoire, sans serveur.
const modeServeur = bool.fromEnvironment('SERVEUR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  if (modeServeur) {
    runApp(const GestionRestaurantApp(accueil: RacineServeur()));
  } else {
    final appareil = kIsWeb ? 'caisse-web' : 'tablette';
    final db = RestoDb(fs: BaseLocale.autonome(), idRestaurant: 'demo', appareil: appareil);
    await remplirDemo(db);
    runApp(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), serveurAppareilsProvider.overrideWithValue(ServeurDemo(db))],
        child: const GestionRestaurantApp(accueil: Accueil()),
      ),
    );
  }
}

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
