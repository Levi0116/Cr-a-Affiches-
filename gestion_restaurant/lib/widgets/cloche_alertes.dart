import '../donnees/base.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/providers.dart';
import '../theme/animated_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/identite.dart';

/// Cloche d'alertes : stock bas, ruptures, validations en attente et
/// notifications du serveur. Le badge pulse tant qu'il reste des alertes.
class ClocheAlertes extends ConsumerWidget {
  const ClocheAlertes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final alertes = ref.watch(alertesProvider);
    final n = alertes.length;
    return Semantics(
      container: true,
      button: true,
      label: n == 0 ? 'Aucune alerte' : '$n alerte${n > 1 ? 's' : ''}',
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: () => _ouvrir(context),
        child: PulseGlow(
          active: n > 0,
          couleur: p.occupee,
          rayon: BorderRadius.circular(30),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: n > 0 ? p.occupee.withValues(alpha: 0.6) : p.bordure),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(n > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: p.texte),
                Positioned(right: -6, top: -6, child: QuantityBadge(n, couleur: p.occupee)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _ouvrir(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: duree(context, 260),
      pageBuilder: (_, _, _) => const _PanneauAlertes(),
      transitionBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, -0.02), end: Offset.zero).animate(c),
            child: child,
          ),
        );
      },
    );
  }
}

class _PanneauAlertes extends ConsumerWidget {
  const _PanneauAlertes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final alertes = ref.watch(alertesProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Material(
              type: MaterialType.transparency,
              child: GlassPanel(
                rayon: BorderRadius.circular(identite.arrondi * 1.2),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Alertes', style: AppTypo.titre(p.texte, taille: 20)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: p.texteSecondaire),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (alertes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 42, color: p.libre),
                            const SizedBox(height: 8),
                            Text('Tout est en ordre', style: AppTypo.etiquette(p.texteSecondaire, taille: 15)),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: alertes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => StaggeredEntrance(
                            index: i,
                            child: _LigneAlerte(alerte: alertes[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LigneAlerte extends ConsumerWidget {
  final Alerte alerte;
  const _LigneAlerte({required this.alerte});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final a = alerte;
    final (Color c, IconData i) = switch (a.type) {
      'validation' => (p.addition, Icons.verified_rounded),
      'stock' => (p.occupee, Icons.inventory_2_rounded),
      _ => (p.principale, Icons.campaign_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(i, color: c, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.titre, style: AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w700)),
                if (a.detail.isNotEmpty)
                  Text(
                    a.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 12, poids: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          if (a.idNotification != null)
            IconButton(
              tooltip: 'Marquer comme lue',
              icon: Icon(Icons.done_rounded, color: p.texteSecondaire),
              onPressed: () => ref.read(dbProvider).notifications.doc(a.idNotification).update({
                'lue': true,
                'lueLe': FieldValue.serverTimestamp(),
                'luePar': ref.read(utilisateurProvider)?.nom ?? '',
              }),
            ),
        ],
      ),
    );
  }
}
