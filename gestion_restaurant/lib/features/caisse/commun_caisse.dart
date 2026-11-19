import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/impression/impression.dart';
import '../../state/providers.dart';
import '../../widgets/commun.dart';
import 'comptage.dart';

export '../../widgets/panneaux.dart';

/// Imprime un ticket ; sur tablette (sans imprimante), prévient.
Future<void> imprimer(BuildContext context, String html) async {
  final ok = await imprimerHtml(html);
  if (!ok && context.mounted) {
    afficherMessage(context, 'Impression disponible sur l’ordinateur de la caisse');
  }
}

/// Ouverture de caisse : comptage du fond par billets et pièces.
Future<void> ouvrirCaisse(BuildContext context, WidgetRef ref) async {
  final fond = await demanderComptage(
    context,
    titre: 'Ouverture de caisse',
    sousTitre: 'Comptez le fond de caisse',
    libelleBouton: 'Ouvrir la caisse',
  );
  if (fond == null || !context.mounted) return;
  await essayer(
    context,
    () => ref.read(caisseServiceProvider).ouvrirCaisse(ref.read(acteurProvider)!, fond),
    succes: 'Caisse ouverte',
  );
}

/// « depuis 42 min », « depuis 1 h 05 ».
String depuis(DateTime debut, DateTime maintenant) {
  final d = maintenant.difference(debut);
  if (d.inMinutes < 1) return 'à l’instant';
  if (d.inMinutes < 60) return 'depuis ${d.inMinutes} min';
  return 'depuis ${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';
}
