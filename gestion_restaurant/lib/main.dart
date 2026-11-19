import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'features/connexion/accueil.dart';
import 'firebase_options.dart';
import 'services/db.dart';
import 'services/donnees_demo.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

/// `--dart-define=FIREBASE=true` : vraie base Firestore (après
/// `flutterfire configure`). Sinon : mode démonstration en mémoire.
const modeFirebase = bool.fromEnvironment('FIREBASE');
const idRestaurantDefini = String.fromEnvironment('RESTAURANT', defaultValue: 'demo');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final appareil = kIsWeb ? 'caisse-web' : 'tablette';
  final RestoDb db;
  if (modeFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final fs = FirebaseFirestore.instance;
    // Copie locale + file d'attente hors ligne (section 6.3).
    fs.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
    db = RestoDb(fs: fs, idRestaurant: idRestaurantDefini, appareil: appareil);
  } else {
    db = RestoDb(fs: FakeFirebaseFirestore(), idRestaurant: 'demo', appareil: appareil);
    await remplirDemo(db);
  }
  runApp(ProviderScope(overrides: [dbProvider.overrideWithValue(db)], child: const GestionRestaurantApp()));
}

class GestionRestaurantApp extends StatelessWidget {
  const GestionRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion restaurant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Accueil(),
    );
  }
}
