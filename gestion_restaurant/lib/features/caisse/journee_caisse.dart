import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../services/ticket.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';
import 'commun_caisse.dart';
import 'comptage.dart';

/// Ouverture et clôture de caisse (section 3.2) + historique des écarts.
class VueJournee extends ConsumerWidget {
  const VueJournee({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final async = ref.watch(journeeOuverteProvider);
    final historique = (ref.watch(journeesProvider).value ?? const <JourneeCaisse>[])
        .where((h) => h.verrouillee)
        .toList();
    final enCours = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final maintenant = ref.watch(horlogeProvider).value ?? DateTime.now();
    if (async.isLoading) return const Chargement();
    final j = async.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (j == null)
          const _CaisseFermee()
        else
          _JourneeOuverte(journee: j, tablesOuvertes: enCours.length, maintenant: maintenant),
        const SizedBox(height: 22),
        TitreSection(icone: Icons.history_rounded, titre: 'Historique des clôtures'),
        const SizedBox(height: 12),
        if (historique.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Aucune clôture pour l’instant.', style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
          ),
        for (final (i, h) in historique.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaggeredEntrance(
              index: i,
              child: _LigneCloture(journee: h),
            ),
          ),
      ],
    );
  }
}

class _CaisseFermee extends ConsumerWidget {
  const _CaisseFermee();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    return PanneauCaisse(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: p.occupee.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.lock_rounded, color: p.occupee, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('La caisse est fermée', style: AppTypo.titre(p.texte, taille: 22)),
                Text(
                  'Comptez le fond de caisse pour commencer la journée et encaisser.',
                  style: AppTypo.etiquette(p.texteSecondaire, taille: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GradientActionButton(
            label: 'Ouvrir la caisse',
            icone: Icons.lock_open_rounded,
            onPressed: () => ouvrirCaisse(context, ref),
          ),
        ],
      ),
    );
  }
}

class _JourneeOuverte extends ConsumerWidget {
  final JourneeCaisse journee;
  final int tablesOuvertes;
  final DateTime maintenant;
  const _JourneeOuverte({required this.journee, required this.tablesOuvertes, required this.maintenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final j = journee;
    final theorique = j.fond + j.totalEncaisse;
    return PanneauCaisse(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LiveDot(couleur: p.libre),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Journée en cours · ouverte ${depuis(j.ouverture, maintenant)} par ${j.caissier}',
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _Bloc(titre: 'Fond de caisse', valeur: j.fond, icone: Icons.savings_rounded, couleur: p.texteSecondaire),
              _Bloc(
                titre: 'Encaissements',
                valeur: j.totalEncaisse,
                icone: Icons.trending_up_rounded,
                couleur: p.libre,
              ),
              _Bloc(
                titre: 'Total théorique en caisse',
                valeur: theorique,
                icone: Icons.account_balance_wallet_rounded,
                couleur: p.principale,
                fort: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (tablesOuvertes > 0)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: p.occupee),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$tablesOuvertes addition${tablesOuvertes > 1 ? 's' : ''} pas encore réglée${tablesOuvertes > 1 ? 's' : ''}',
                          style: AppTypo.etiquette(p.occupee, taille: 14, poids: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              GradientActionButton(
                label: 'Clôturer la caisse',
                icone: Icons.lock_rounded,
                couleur: identite.secondaire,
                onPressed: () => _cloturer(context, ref, theorique),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cloturer(BuildContext context, WidgetRef ref, int theorique) async {
    if (tablesOuvertes > 0) {
      final ok = await confirmer(
        context,
        'Tables encore ouvertes',
        '$tablesOuvertes addition(s) ne sont pas réglées. Clôturer quand même ?',
      );
      if (!ok || !context.mounted) return;
    }
    final compte = await demanderComptage(
      context,
      titre: 'Clôture de caisse',
      sousTitre: 'Comptez l’argent présent dans la caisse',
      theorique: theorique,
      libelleBouton: 'Clôturer et imprimer',
    );
    if (compte == null || !context.mounted) return;
    final resto = ref.read(restaurantProvider).value;
    final db = ref.read(dbProvider);
    final caisse = ref.read(caisseServiceProvider);
    final cloturee = await essayer(context, () => caisse.cloturerCaisse(ref.read(acteurProvider)!, journee, compte));
    if (cloturee == null || !context.mounted) return;
    final ecart = cloturee.ecart ?? 0;
    showStamp(
      context,
      ecart == 0 ? 'JUSTE' : (ecart < 0 ? 'MANQUE' : 'EXCÉDENT'),
      couleur: ecart == 0 ? identite.tableLibre : (ecart < 0 ? identite.erreur : identite.tableOccupee),
    );
    final nb = (await db.encaissements.where('idJournee', isEqualTo: journee.id).get()).docs.length;
    if (resto != null && context.mounted) {
      await imprimer(context, ticketCloture(resto, cloturee, nbFactures: nb));
    }
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final int valeur;
  final IconData icone;
  final Color couleur;
  final bool fort;
  const _Bloc({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
    this.fort = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fort ? Color.alphaBlend(couleur.withValues(alpha: 0.07), p.surface) : p.fond,
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: fort ? couleur.withValues(alpha: 0.4) : p.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: couleur),
              const SizedBox(width: 6),
              Flexible(child: Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 13))),
            ],
          ),
          const SizedBox(height: 6),
          SmoothCounterText(valeur, style: AppTypo.montant(fort ? couleur : p.texte, taille: fort ? 28 : 24)),
        ],
      ),
    );
  }
}

class _LigneCloture extends StatelessWidget {
  final JourneeCaisse journee;
  const _LigneCloture({required this.journee});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final h = journee;
    final ecart = h.ecart ?? 0;
    final (String txt, Color c, IconData i) = ecart == 0
        ? ('Juste', p.libre, Icons.check_circle_rounded)
        : (ecart < 0
              ? ('Manquant', p.erreur, Icons.trending_down_rounded)
              : ('Excédent', p.occupee, Icons.trending_up_rounded));
    return PanneauCaisse(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(i, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dateHeure(h.ouverture)} → ${h.cloture == null ? '…' : heure(h.cloture!)}',
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texte, taille: 15, poids: FontWeight.w700)),
                ),
                Text(
                  'Théorique ${fcfa(h.totalTheorique)} · compté ${fcfa(h.totalCompte ?? 0)} · ${h.caissier}',
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$txt${ecart == 0 ? '' : ' ${ecart > 0 ? '+' : ''}${fcfa(ecart)}'}',
              style: AppTypo.chiffres(AppTypo.etiquette(c, taille: 14, poids: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
