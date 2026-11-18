import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/providers.dart';
import 'commun.dart';

/// « En ligne » en vert, ou « Hors ligne – N actions en attente » en orange
/// (section 6.3).
class IndicateurConnexion extends ConsumerWidget {
  const IndicateurConnexion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return ValueListenableBuilder<int>(
      valueListenable: db.enAttente,
      builder: (context, n, _) => Pastille(
        n == 0 ? '● En ligne' : '● Hors ligne – $n action${n > 1 ? 's' : ''} en attente',
        n == 0 ? couleurLibre : couleurOccupee,
      ),
    );
  }
}

/// Actions communes de la barre du haut : indicateur, employé connecté,
/// changement d'utilisateur rapide.
List<Widget> actionsBarre(BuildContext context, WidgetRef ref) {
  final e = ref.watch(utilisateurProvider);
  return [
    const Center(child: IndicateurConnexion()),
    const SizedBox(width: 12),
    if (e != null)
      TextButton.icon(
        onPressed: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          ref.read(utilisateurProvider.notifier).deconnecter();
        },
        icon: const Icon(Icons.logout),
        label: Text('${e.nom} · Changer'),
      ),
    const SizedBox(width: 8),
  ];
}
