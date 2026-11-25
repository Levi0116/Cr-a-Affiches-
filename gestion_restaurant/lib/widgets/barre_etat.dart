import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/providers.dart';
import '../theme/animated_widgets.dart';
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

/// Badge réseau : connexion de l'appareil + écritures pas encore confirmées
/// par le serveur (section 6.3).
class IndicateurConnexion extends ConsumerWidget {
  final bool compact;
  const IndicateurConnexion({super.key, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final reseau = ref.watch(reseauProvider).value ?? true;
    return ValueListenableBuilder<bool>(
      valueListenable: db.enLigne,
      builder: (context, serveur, _) => ValueListenableBuilder<int>(
        valueListenable: db.enAttente,
        builder: (context, n, _) => OfflineStatusPill(enLigne: reseau && serveur, enAttente: n, compact: compact),
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
