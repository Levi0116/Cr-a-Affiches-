import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/providers.dart';
import '../theme/animations.dart';
import '../theme/identite.dart';
import '../theme/motif.dart';

/// Barre du haut aux couleurs de l'identité : nuit, motif tissé, liseré or.
PreferredSizeWidget barreBraise({
  required Widget title,
  List<Widget>? actions,
  Widget? leading,
  PreferredSizeWidget? bottom,
}) => AppBar(
  title: title,
  leading: leading,
  actions: actions,
  bottom: bottom,
  flexibleSpace: const BandeauMotif(),
  toolbarHeight: 64,
);

/// « En ligne » en vert, ou « Hors ligne – N actions en attente » en orange
/// (section 6.3).
class IndicateurConnexion extends ConsumerWidget {
  const IndicateurConnexion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return ValueListenableBuilder<int>(
      valueListenable: db.enAttente,
      builder: (context, n, _) {
        final couleur = n == 0 ? identite.tableLibre : identite.tableOccupee;
        return AnimatedContainer(
          duration: duree(context, 300),
          padding: const EdgeInsets.fromLTRB(4, 3, 12, 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: couleur.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PointPulsant(couleur: couleur),
              AnimatedSize(
                duration: duree(context, 300),
                child: Text(
                  n == 0 ? 'En ligne' : 'Hors ligne – $n action${n > 1 ? 's' : ''} en attente',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
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
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        onPressed: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          ref.read(utilisateurProvider.notifier).deconnecter();
        },
        icon: CircleAvatar(
          radius: 14,
          backgroundColor: identite.accent,
          child: Text(
            e.nom.characters.first,
            style: TextStyle(color: identite.nuit, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        label: Text('${e.nom} · Changer'),
      ),
    const SizedBox(width: 8),
  ];
}
