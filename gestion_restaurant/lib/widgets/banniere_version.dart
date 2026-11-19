import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/plateforme/plateforme.dart';
import '../state/providers.dart';
import '../theme/animated_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/identite.dart';
import 'commun.dart';

/// « Nouvelle version disponible » (section 9.3 et 9.4) : rechargement en un
/// clic sur la caisse web, téléchargement de l'APK sur tablette.
class BanniereVersion extends ConsumerWidget {
  const BanniereVersion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(infosVersionProvider).value;
    final visible = v != null && v.miseAJourDisponible;
    return AnimatedSize(
      duration: duree(context, 320),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Material(
              color: v.obligatoire ? identite.erreur : identite.secondaire,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        v.obligatoire ? Icons.priority_high_rounded : Icons.system_update_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          v.obligatoire
                              ? 'Mise à jour obligatoire : version ${v.derniere} (vous avez ${v.actuelle}).'
                              : 'Nouvelle version ${v.derniere} disponible${v.notes == null ? '' : ' · ${v.notes}'}',
                          style: AppTypo.chiffres(AppTypo.etiquette(Colors.white, taille: 14)),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => _mettreAJour(context, ref, v),
                        child: const Text('Mettre à jour'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _mettreAJour(BuildContext context, WidgetRef ref, InfosVersion v) async {
    final enCours = (ref.read(sessionsEnCoursProvider).value ?? const []).length;
    if (enCours > 0) {
      final ok = await confirmer(
        context,
        'Mettre à jour maintenant ?',
        '$enCours addition(s) en cours. Rien n’est perdu (tout est enregistré), mais mieux vaut le faire entre deux services.',
      );
      if (!ok) return;
    }
    if (rechargerPage()) return;
    final url = v.urlApk;
    if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (context.mounted) afficherMessage(context, 'Lien de mise à jour indisponible', erreur: true);
    }
  }
}

/// Pastille de l'administrateur : droits serveur actifs, en attente de
/// réseau ou refusés (validations impossibles tant qu'ils ne sont pas actifs).
class PastilleDroitsAdmin extends ConsumerWidget {
  const PastilleDroitsAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final e = ref.watch(elevationProvider);
    final (String txt, Color c, IconData i) = switch (e.statut) {
      StatutElevation.active => ('Droits administrateur', p.libre, Icons.verified_user_rounded),
      StatutElevation.enCours => ('Vérification…', p.addition, Icons.hourglass_top_rounded),
      StatutElevation.horsLigne => ('Droits en attente de réseau', p.occupee, Icons.cloud_off_rounded),
      StatutElevation.refusee => ('Droits refusés', p.erreur, Icons.gpp_bad_rounded),
      StatutElevation.inutile => ('', p.texte, Icons.check),
    };
    if (e.statut == StatutElevation.inutile) return const SizedBox.shrink();
    return Tooltip(
      message:
          e.message ??
          (e.jusqua == null
              ? txt
              : '$txt jusqu’à ${TimeOfDay.fromDateTime(e.jusqua!).format(context)} (renouvelés automatiquement)'),
      child: AnimatedContainer(
        duration: duree(context, 300),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 17, color: c),
            const SizedBox(width: 6),
            Text(txt, style: AppTypo.etiquette(c, taille: 13, poids: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
