import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';
import 'commun_caisse.dart';
import 'encaissement.dart';
import 'tables_ouvertes.dart';

// ======================================================== Factures du jour

class VueFacturesDuJour extends ConsumerStatefulWidget {
  const VueFacturesDuJour({super.key});
  @override
  ConsumerState<VueFacturesDuJour> createState() => _VueFacturesDuJourState();
}

class _VueFacturesDuJourState extends ConsumerState<VueFacturesDuJour> {
  StatutFacture? _filtre;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final async = ref.watch(facturesDepuisProvider(debutJour()));
    final journee = ref.watch(journeeOuverteProvider).value;
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (factures) {
        int somme(StatutFacture s) => factures.where((f) => f.statut == s).fold(0, (t, f) => t + f.total);
        int nombre(StatutFacture? s) => s == null ? factures.length : factures.where((f) => f.statut == s).length;
        final visibles = _filtre == null ? factures : factures.where((f) => f.statut == _filtre).toList();
        final largeur = MediaQuery.sizeOf(context).width;
        final colonnes = largeur >= 1300 ? 3 : (largeur >= 860 ? 2 : 1);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Chiffre(
                  titre: 'Payées',
                  valeur: somme(StatutFacture.payee),
                  couleur: p.libre,
                  icone: Icons.check_circle_rounded,
                ),
                _Chiffre(
                  titre: 'À encaisser',
                  valeur: somme(StatutFacture.emise),
                  couleur: p.occupee,
                  icone: Icons.hourglass_top_rounded,
                ),
                _Chiffre(
                  titre: 'À crédit',
                  valeur: somme(StatutFacture.credit),
                  couleur: p.addition,
                  icone: Icons.menu_book_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (s, nom) in const [
                  (null, 'Toutes'),
                  (StatutFacture.emise, 'À encaisser'),
                  (StatutFacture.payee, 'Payées'),
                  (StatutFacture.credit, 'À crédit'),
                ])
                  _Filtre(texte: '$nom · ${nombre(s)}', actif: _filtre == s, onTap: () => setState(() => _filtre = s)),
              ],
            ),
            const SizedBox(height: 16),
            if (visibles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('Aucune facture', style: AppTypo.etiquette(p.texteSecondaire, taille: 15))),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final l = (c.maxWidth - (colonnes - 1) * 12) / colonnes;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (i, f) in visibles.indexed)
                        SizedBox(
                          width: l,
                          child: StaggeredEntrance(
                            key: ValueKey('f-${f.id}'),
                            index: i,
                            child: CarteFacture(facture: f, journee: journee),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _Chiffre extends StatelessWidget {
  final String titre;
  final int valeur;
  final Color couleur;
  final IconData icone;
  const _Chiffre({required this.titre, required this.valeur, required this.couleur, required this.icone});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: p.bordure),
        boxShadow: AppOmbres.douce(p, force: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icone, color: couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
                SmoothCounterText(valeur, style: AppTypo.montant(p.texte, taille: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  final String texte;
  final bool actif;
  final VoidCallback onTap;
  const _Filtre({required this.texte, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      selected: actif,
      label: texte,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duree(context, 240),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: actif ? identite.secondaire : p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: actif ? identite.secondaire : p.bordure),
          ),
          child: Text(
            texte,
            style: AppTypo.chiffres(
              AppTypo.etiquette(actif ? Colors.white : p.texte, taille: 14, poids: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ Ardoises

class VueArdoises extends ConsumerWidget {
  const VueArdoises({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final async = ref.watch(ardoisesProvider);
    final journee = ref.watch(journeeOuverteProvider).value;
    final maintenant = ref.watch(horlogeProvider).value ?? DateTime.now();
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final enCours = liste.where((a) => a.montantDu > 0).toList()..sort((a, b) => a.creeLe.compareTo(b.creeLe));
        if (enCours.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 46, color: p.libre),
                const SizedBox(height: 10),
                Text('Aucune ardoise en cours', style: AppTypo.titre(p.texte, taille: 20)),
                Text('Tous les clients sont à jour.', style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
              ],
            ),
          );
        }
        final total = enCours.fold(0, (s, a) => s + a.montantDu);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            PanneauCaisse(
              couleur: identite.secondaire,
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${enCours.length} client${enCours.length > 1 ? 's' : ''} à crédit',
                      style: AppTypo.etiquette(Colors.white, taille: 16),
                    ),
                  ),
                  SmoothCounterText(total, style: AppTypo.montant(Colors.white, taille: 28)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, a) in enCours.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StaggeredEntrance(
                  index: i,
                  child: _CarteArdoise(
                    ardoise: a,
                    jours: maintenant.difference(a.creeLe).inDays,
                    onRembourser: () => _rembourser(context, ref, a, journee),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _rembourser(BuildContext context, WidgetRef ref, Ardoise a, JourneeCaisse? journee) async {
    if (journee == null) {
      afficherMessage(context, 'Ouvrez d’abord la caisse (onglet Journée)', erreur: true);
      return;
    }
    final recu = await demanderEncaissement(
      context,
      aPayer: a.montantDu,
      titre: 'Remboursement · ${a.client}',
      sousTitre: 'Versement partiel accepté',
      partiel: true,
      libelleBouton: 'Enregistrer le versement',
    );
    if (recu == null || !context.mounted) return;
    final montant = recu > a.montantDu ? a.montantDu : recu;
    final ok = await essayer(context, () async {
      await ref
          .read(caisseServiceProvider)
          .rembourserArdoise(caissier: ref.read(acteurProvider)!, ardoise: a, montant: montant, journee: journee);
      return true;
    });
    if (ok != true || !context.mounted) return;
    final reste = a.montantDu - montant;
    showSuccessBurst(context, reste == 0 ? 'Ardoise soldée' : 'Reste ${fcfa(reste)}');
    if (recu > montant) afficherMessage(context, 'Rendre ${fcfa(recu - montant)} au client');
  }
}

class _CarteArdoise extends StatelessWidget {
  final Ardoise ardoise;
  final int jours;
  final VoidCallback onRembourser;
  const _CarteArdoise({required this.ardoise, required this.jours, required this.onRembourser});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final a = ardoise;
    final ancienne = jours >= 30;
    return PanneauCaisse(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.addition.withValues(alpha: 0.12),
            child: Text(a.client.characters.first.toUpperCase(), style: AppTypo.titre(p.addition, taille: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.client, style: AppTypo.etiquette(p.texte, taille: 16, poids: FontWeight.w700)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (a.telephone.isNotEmpty)
                      Text(a.telephone, style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13))),
                    Text(
                      '${a.idsFactures.length} facture${a.idsFactures.length > 1 ? 's' : ''}',
                      style: AppTypo.etiquette(p.texteSecondaire, taille: 13),
                    ),
                    Pastille(
                      jours == 0
                          ? 'aujourd’hui'
                          : 'depuis $jours jour${jours > 1 ? 's' : ''}${ancienne ? ' · ancienne' : ''}',
                      ancienne ? p.occupee : p.texteSecondaire,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SmoothCounterText(a.montantDu, style: AppTypo.montant(p.texte, taille: 20)),
          const SizedBox(width: 14),
          GradientActionButton(
            label: 'Rembourser',
            icone: Icons.payments_rounded,
            hauteur: 52,
            couleur: p.libre,
            onPressed: onRembourser,
          ),
        ],
      ),
    );
  }
}
