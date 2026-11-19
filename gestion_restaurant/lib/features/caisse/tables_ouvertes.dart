import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/calculs.dart';
import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../services/ticket.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/animated_table_card.dart';
import '../../widgets/commun.dart';
import 'commun_caisse.dart';
import 'encaissement.dart';

/// Tables ouvertes en temps réel (section 3.2) : liste triée (additions
/// demandées d'abord) + ticket détaillé de la table choisie.
class VueTablesOuvertes extends ConsumerWidget {
  final String? selection;
  final ValueChanged<String?> onSelection;
  const VueTablesOuvertes({super.key, required this.selection, required this.onSelection});

  static int _priorite(SessionTable s) => switch (s.statut) {
    StatutSession.addition => 0,
    StatutSession.facturee => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final async = ref.watch(sessionsEnCoursProvider);
    final large = MediaQuery.sizeOf(context).width >= 1000;
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (sessions) {
        final triees = [...sessions]
          ..sort((a, b) {
            final c = _priorite(a).compareTo(_priorite(b));
            return c != 0 ? c : a.ouverture.compareTo(b.ouverture);
          });
        if (triees.isEmpty) return const _Vide();
        // Sur grand écran, la première table (la plus urgente) est ouverte
        // d'office : zéro touche pour voir ce qui presse.
        final choisie = triees.where((s) => s.id == selection).firstOrNull ?? (large ? triees.first : null);
        final liste = ListView.separated(
          // Marge haute : la pastille « Addition » dépasse de la carte.
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: triees.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final s = triees[i];
            return StaggeredEntrance(
              key: ValueKey('caisse-${s.id}'),
              index: i,
              child: _CarteSession(
                session: s,
                choisie: large && s.id == choisie?.id,
                onTap: () {
                  if (large) {
                    onSelection(s.id);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          backgroundColor: p.fond,
                          appBar: AppBar(title: Text(s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}')),
                          body: _DetailParId(idSession: s.id),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
        if (!large) return liste;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: liste),
            Expanded(
              child: AnimatedSwitcher(
                duration: duree(context, 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.02, 0), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: choisie == null
                    ? const SizedBox.shrink()
                    : DetailSession(key: ValueKey(choisie.id), session: choisie),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: p.libre.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.table_restaurant_rounded, size: 42, color: p.libre),
          ),
          const SizedBox(height: 14),
          Text('Aucune table ouverte', style: AppTypo.titre(p.texte, taille: 20)),
          Text(
            'Les commandes des serveuses apparaîtront ici en direct.',
            style: AppTypo.etiquette(p.texteSecondaire, taille: 14),
          ),
        ],
      ),
    );
  }
}

class _DetailParId extends ConsumerWidget {
  final String idSession;
  const _DetailParId({required this.idSession});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = (ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[])
        .where((x) => x.id == idSession)
        .firstOrNull;
    if (s == null) return const Center(child: Text('Addition close'));
    return DetailSession(session: s);
  }
}

// ======================================================= Carte de session

class _CarteSession extends ConsumerWidget {
  final SessionTable session;
  final bool choisie;
  final VoidCallback onTap;
  const _CarteSession({required this.session, required this.choisie, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final s = session;
    final maintenant = ref.watch(horlogeProvider).value ?? DateTime.now();
    final etat = etatDe(s);
    final couleur = s.aEmporter && etat == EtatTable.occupee ? p.principale : etat.couleur(p);
    final rayon = BorderRadius.circular(identite.arrondi);
    final facturee = s.statut == StatutSession.facturee;
    return Semantics(
      container: true,
      button: true,
      selected: choisie,
      label:
          '${s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}'}, ${facturee ? 'facturée' : etat.libelle}, ${fcfa(s.total)}, ${s.nomServeuse}',
      excludeSemantics: true,
      child: PulseAlertBadge(
        active: s.statut == StatutSession.addition,
        couleur: couleur,
        rayon: rayon,
        label: 'Addition',
        icone: Icons.notifications_active_rounded,
        child: BouncyTapWrapper(
          scale: 0.97,
          onTap: onTap,
          child: AnimatedContainer(
            duration: duree(context, 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: choisie ? Color.alphaBlend(couleur.withValues(alpha: 0.07), p.surface) : p.surface,
              borderRadius: rayon,
              border: Border.all(color: choisie ? couleur : p.bordure, width: choisie ? 2 : 1),
              boxShadow: choisie ? AppOmbres.lueur(couleur, force: 0.5) : AppOmbres.douce(p, force: 0.6),
            ),
            child: ClipRRect(
              borderRadius: rayon,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(duration: duree(context, 300), width: 6, color: couleur),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: duree(context, 300),
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: degradePrincipal(couleur),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: s.aEmporter
                                  ? const Icon(Icons.shopping_bag_rounded, color: Colors.white)
                                  : FittedBox(
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(s.numeroTable, style: AppTypo.montant(Colors.white, taille: 20)),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypo.etiquette(p.texte, taille: 16, poids: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.nomServeuse} · ${depuis(s.ouverture, maintenant)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypo.chiffres(
                                      AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        facturee ? Icons.request_quote_rounded : etat.icone,
                                        size: 14,
                                        color: couleur,
                                      ),
                                      const SizedBox(width: 4),
                                      // Flexible : jamais de débordement si la carte est étroite.
                                      Flexible(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: facturee
                                                    ? 'Facturée · à encaisser'
                                                    : (etat == EtatTable.addition ? 'Addition demandée' : 'En cours'),
                                                style: AppTypo.etiquette(couleur, taille: 12, poids: FontWeight.w700),
                                              ),
                                              TextSpan(
                                                text: ' · ${s.nbTours} tour${s.nbTours > 1 ? 's' : ''}',
                                                style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 12)),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SmoothCounterText(s.total, style: AppTypo.montant(p.texte, taille: 18)),
                          ],
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

// =========================================================== Détail / ticket

/// Ticket provisoire de la table, rempli automatiquement à chaque tour,
/// et toutes les actions de caisse.
class DetailSession extends ConsumerWidget {
  final SessionTable session;
  const DetailSession({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final lignes = ref.watch(lignesProvider(s.id)).value ?? const <LigneCommande>[];
    final factures = ref.watch(facturesSessionProvider(s.id)).value ?? const <Facture>[];
    final resto = ref.watch(restaurantProvider).value;
    final journee = ref.watch(journeeOuverteProvider).value;
    final aFacturer = lignes.where((l) => !l.annulee && l.idFacture == null).toList();
    final tot = calculerTotaux(aFacturer.map((l) => l.calcul), remise: s.remise, tauxTva: resto?.tauxTvaEffectif ?? 0);
    final large = MediaQuery.sizeOf(context).width >= 1280;

    final ticket = _Ticket(
      session: s,
      lignes: lignes,
      totaux: tot,
      totalFacture: factures.fold(0, (t, f) => t + f.total),
    );
    final actions = _Actions(
      session: s,
      aFacturer: aFacturer,
      totaux: tot,
      resto: resto,
      factures: factures,
      journee: journee,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 24),
      child: large
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: ticket),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: actions),
              ],
            )
          : Column(children: [ticket, const SizedBox(height: 16), actions]),
    );
  }
}

class _Ticket extends ConsumerWidget {
  final SessionTable session;
  final List<LigneCommande> lignes;
  final Totaux totaux;

  /// Somme des factures déjà émises pour cette table.
  final int totalFacture;
  const _Ticket({required this.session, required this.lignes, required this.totaux, required this.totalFacture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final s = session;
    final tours = <int, List<LigneCommande>>{};
    for (final l in lignes) {
      tours.putIfAbsent(l.tour, () => []).add(l);
    }
    final toutFacture = totaux.total == 0 && totalFacture > 0;
    final etat = etatDe(s);
    return PanneauCaisse(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}',
                      style: AppTypo.titre(p.texte, taille: 26),
                    ),
                    Text(
                      '${s.nomServeuse} · ouverte à ${heure(s.ouverture)}'
                      '${s.couverts > 0 ? ' · ${s.couverts} couverts' : ''}',
                      style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              Pastille(
                s.statut == StatutSession.facturee
                    ? 'Facturée'
                    : (etat == EtatTable.addition ? 'Addition demandée' : 'En cours'),
                etat.couleur(p),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Pointilles(),
          for (final e in tours.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: identite.secondaire, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Tour ${e.key}',
                      style: AppTypo.etiquette(Colors.white, taille: 12, poids: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${heure(e.value.first.heure)} · ${e.value.first.auteur}',
                    style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 12)),
                  ),
                ],
              ),
            ),
            for (final l in e.value) _LigneTicket(ligne: l, session: s),
          ],
          const SizedBox(height: 6),
          const Pointilles(),
          const SizedBox(height: 6),
          if (totalFacture > 0) _LigneTotal('Déjà facturé', totalFacture, discret: totaux.total > 0),
          if (totaux.total > 0 || totalFacture == 0) _LigneTotal('Sous-total', totaux.sousTotal),
          if (totaux.remise > 0)
            _LigneTotal(
              'Remise · ${s.remise!.motif} (validée par ${s.remise!.validePar})',
              -totaux.remise,
              couleur: p.libre,
            ),
          if (totaux.tva > 0) _LigneTotal('dont TVA', totaux.tva, discret: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: identite.secondaire,
              borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
            ),
            child: Row(
              children: [
                Text(
                  toutFacture ? 'Total facturé' : 'Reste à facturer',
                  style: AppTypo.etiquette(Colors.white, taille: 16),
                ),
                const Spacer(),
                SmoothCounterText(
                  toutFacture ? totalFacture : totaux.total,
                  style: AppTypo.montant(Colors.white, taille: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneTicket extends ConsumerWidget {
  final LigneCommande ligne;
  final SessionTable session;
  const _LigneTicket({required this.ligne, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final l = ligne;
    final barre = l.annulee ? TextDecoration.lineThrough : null;
    final c = l.annulee ? p.texteDiscret : p.texte;
    final offrable = !l.annulee && !l.offert && l.idFacture == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${l.quantite}×', style: AppTypo.montant(c, taille: 14).copyWith(decoration: barre)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.nom}${l.offert ? ' · offert' : ''}${l.idFacture != null ? ' · facturé' : ''}',
                  style: AppTypo.etiquette(c, taille: 14, poids: FontWeight.w500).copyWith(decoration: barre),
                ),
                if (l.annulee)
                  Text(
                    'Annulé : ${l.motifAnnulation} · validé par ${l.validePar}',
                    style: AppTypo.etiquette(p.erreur, taille: 12, poids: FontWeight.w500),
                  )
                else if (l.note.isNotEmpty)
                  Text(
                    '« ${l.note} »',
                    style: AppTypo.etiquette(p.texteSecondaire, taille: 12, poids: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Text(
            fcfa(l.montant),
            style: AppTypo.montant(c, taille: 14, poids: FontWeight.w700).copyWith(decoration: barre),
          ),
          SizedBox(
            width: 44,
            child: offrable
                ? IconButton(
                    tooltip: 'Offrir (validation administrateur)',
                    icon: Icon(Icons.redeem_rounded, size: 20, color: p.texteDiscret),
                    onPressed: () async {
                      final motif = await demanderTexte(context, 'Offrir ${l.quantite} × ${l.nom}', label: 'Motif');
                      if (motif == null || !context.mounted) return;
                      await essayer(
                        context,
                        () => ref
                            .read(caisseServiceProvider)
                            .demanderOffert(ref.read(acteurProvider)!, session, l, motif),
                        succes: 'Demande envoyée à l’administrateur',
                      );
                    },
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _LigneTotal extends StatelessWidget {
  final String libelle;
  final int montant;
  final Color? couleur;
  final bool discret;
  const _LigneTotal(this.libelle, this.montant, {this.couleur, this.discret = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = couleur ?? (discret ? p.texteDiscret : p.texteSecondaire);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(libelle, style: AppTypo.etiquette(c, taille: 14, poids: FontWeight.w500)),
          ),
          SmoothCounterText(montant, style: AppTypo.montant(c, taille: 15, poids: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ================================================================= Actions

class _Actions extends ConsumerWidget {
  final SessionTable session;
  final List<LigneCommande> aFacturer;
  final Totaux totaux;
  final Restaurant? resto;
  final List<Facture> factures;
  final JourneeCaisse? journee;
  const _Actions({
    required this.session,
    required this.aFacturer,
    required this.totaux,
    required this.resto,
    required this.factures,
    required this.journee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final s = session;
    final r = resto;
    final aEncaisser = factures.where((f) => f.statut == StatutFacture.emise).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aFacturer.isNotEmpty)
          PanneauCaisse(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TitreSection(icone: Icons.bolt_rounded, titre: 'Actions'),
                const SizedBox(height: 14),
                GradientActionButton(
                  label: 'Facture finale · ${fcfa(totaux.total)}',
                  icone: Icons.request_quote_rounded,
                  hauteur: 60,
                  onPressed: r == null ? null : () => _facturer(context, ref, r),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _BoutonSecondaire(
                        icone: Icons.receipt_long_rounded,
                        texte: 'Pré-addition',
                        onTap: r == null
                            ? null
                            : () => imprimer(context, ticketPreAddition(r, s, aFacturer, totaux.total)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BoutonSecondaire(
                        icone: Icons.percent_rounded,
                        texte: s.remise == null ? 'Remise' : 'Remise accordée',
                        onTap: s.statut == StatutSession.facturee ? null : () => _demanderRemise(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (factures.isNotEmpty) ...[
          if (aFacturer.isNotEmpty) const SizedBox(height: 16),
          PanneauCaisse(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitreSection(
                  icone: Icons.receipt_rounded,
                  titre: 'Factures',
                  trailing: aEncaisser.isEmpty ? null : Pastille('${aEncaisser.length} à encaisser', p.occupee),
                ),
                const SizedBox(height: 12),
                for (final (i, f) in factures.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaggeredEntrance(
                      index: i,
                      child: CarteFacture(facture: f, journee: journee),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _demanderRemise(BuildContext context, WidgetRef ref) async {
    var type = TypeRemise.montant;
    final valeur = TextEditingController();
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Demander une remise'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<TypeRemise>(
                  segments: const [
                    ButtonSegment(value: TypeRemise.montant, label: Text('Montant (F)')),
                    ButtonSegment(value: TypeRemise.pourcentage, label: Text('Pourcentage')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valeur,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: type == TypeRemise.montant ? 'Montant (F)' : 'Pourcentage (%)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motif,
                  decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
                ),
                const SizedBox(height: 12),
                const Text('La remise s’appliquera après validation de l’administrateur.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await essayer(
      context,
      () => ref
          .read(caisseServiceProvider)
          .demanderRemise(
            ref.read(acteurProvider)!,
            session,
            type: type,
            valeur: int.tryParse(valeur.text) ?? 0,
            motif: motif.text,
          ),
      succes: 'Demande de remise envoyée',
    );
  }

  Future<void> _facturer(BuildContext context, WidgetRef ref, Restaurant resto) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Facture finale'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          for (final (cle, icone, titre, detail) in const [
            ('tout', Icons.receipt_rounded, 'Une seule facture', 'Toute la table sur un ticket'),
            ('parts', Icons.call_split_rounded, 'Parts égales', 'Chacun paie la même somme'),
            ('articles', Icons.checklist_rounded, 'Par article', 'Chacun paie ce qu’il a pris'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoixFacture(icone: icone, titre: titre, detail: detail, onTap: () => Navigator.pop(ctx, cle)),
            ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    var parts = 1;
    Set<String>? ids;
    if (mode == 'parts') {
      final n = await demanderNombre(context, 'Nombre de parts', initial: 2);
      if (n == null || n < 2) return;
      parts = n;
    } else if (mode == 'articles') {
      ids = await _choisirLignes(context);
      if (ids == null || ids.isEmpty) return;
    }
    if (!context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    final r = await essayer(
      context,
      () => caisse.emettreFactures(
        caissier: ref.read(acteurProvider)!,
        session: session,
        restaurant: resto,
        idsLignes: ids,
        nombreParts: parts,
      ),
    );
    if (r != null && context.mounted) {
      showSuccessBurst(
        context,
        parts > 1 ? '$parts factures émises' : 'Facture émise',
        couleur: identite.tableAddition,
      );
    }
  }

  Future<Set<String>?> _choisirLignes(BuildContext context) {
    final choix = <String>{};
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final total = aFacturer.where((l) => choix.contains(l.id)).fold(0, (s, l) => s + l.montant);
          return AlertDialog(
            title: const Text('Articles de cette part'),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in aFacturer)
                    CheckboxListTile(
                      value: choix.contains(l.id),
                      onChanged: (v) => setState(() => v! ? choix.add(l.id) : choix.remove(l.id)),
                      title: Text('${l.quantite} × ${l.nom}'),
                      secondary: Text(fcfa(l.montant), style: AppTypo.chiffres(const TextStyle())),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: choix.isEmpty ? null : () => Navigator.pop(ctx, choix),
                child: Text('Facturer ${fcfa(total)}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChoixFacture extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final VoidCallback onTap;
  const _ChoixFacture({required this.icone, required this.titre, required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      label: titre,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.principale.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, color: p.principale),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: AppTypo.etiquette(p.texte, taille: 16, poids: FontWeight.w700)),
                    Text(detail, style: AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonSecondaire extends StatelessWidget {
  final IconData icone;
  final String texte;
  final VoidCallback? onTap;
  const _BoutonSecondaire({required this.icone, required this.texte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final actif = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: actif,
      label: texte,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: actif ? 1 : 0.45,
          duration: duree(context, 200),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.fond,
              borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
              border: Border.all(color: p.bordure),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: p.texte, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    texte,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypo.etiquette(p.texte, taille: 15, poids: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ Facture

/// Une facture : encaissement, ardoise, duplicata, avoir.
class CarteFacture extends ConsumerWidget {
  final Facture facture;
  final JourneeCaisse? journee;
  const CarteFacture({super.key, required this.facture, this.journee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final f = facture;
    final resto = ref.watch(restaurantProvider).value;
    final acteur = ref.watch(acteurProvider)!;
    final (String libelle, Color couleur, IconData icone) = switch (f.statut) {
      StatutFacture.emise => ('À encaisser', p.occupee, Icons.hourglass_top_rounded),
      StatutFacture.payee => ('Payée', p.libre, Icons.check_circle_rounded),
      StatutFacture.credit => ('À crédit', p.addition, Icons.menu_book_rounded),
    };
    return AnimatedContainer(
      duration: duree(context, 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(couleur.withValues(alpha: 0.05), p.surface),
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: couleur, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${f.numero}${f.partie != null ? ' · part ${f.partie}' : ''}',
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w700)),
                ),
              ),
              Pastille(libelle, couleur),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Table ${f.numeroTable} · ${dateHeure(f.date)} · ${f.nomCaissier}'
                  '${f.statut == StatutFacture.payee ? '\nReçu ${fcfa(f.montantRecu)} · rendu ${fcfa(f.monnaieRendue)}' : ''}',
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 12, poids: FontWeight.w500)),
                ),
              ),
              Text(fcfa(f.total), style: AppTypo.montant(p.texte, taille: 22)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (f.statut == StatutFacture.emise) ...[
                GradientActionButton(
                  label: 'Encaisser',
                  icone: Icons.payments_rounded,
                  hauteur: 52,
                  couleur: p.libre,
                  onPressed: resto == null ? null : () => _encaisser(context, ref, resto),
                ),
                _Mini(
                  icone: Icons.menu_book_rounded,
                  texte: 'Ardoise',
                  onTap: resto == null ? null : () => _ardoise(context, ref, resto),
                ),
              ] else
                _Mini(
                  icone: Icons.print_rounded,
                  texte: 'Duplicata',
                  onTap: resto == null
                      ? null
                      : () async {
                          await ref.read(caisseServiceProvider).noterReimpression(acteur, f);
                          if (context.mounted) await imprimer(context, ticketFacture(resto, f, duplicata: true));
                        },
                ),
              if (acteur.estAdmin && f.statut == StatutFacture.payee)
                _Mini(icone: Icons.undo_rounded, texte: 'Avoir', onTap: () => _avoir(context, ref)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref, Restaurant resto) async {
    final f = facture;
    if (journee == null) {
      afficherMessage(context, 'Ouvrez d’abord la caisse (onglet Journée)', erreur: true);
      return;
    }
    final recu = await demanderEncaissement(
      context,
      aPayer: f.total,
      titre: 'Encaisser ${f.numero}',
      sousTitre: 'Table ${f.numeroTable}${f.partie != null ? ' · part ${f.partie}' : ''}',
    );
    if (recu == null || !context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    final monnaie = await essayer(
      context,
      () => caisse.encaisser(caissier: ref.read(acteurProvider)!, facture: f, montantRecu: recu, journee: journee!),
    );
    if (monnaie == null || !context.mounted) return;
    showStamp(context, 'PAYÉE');
    afficherMessage(context, monnaie > 0 ? 'Rendre ${fcfa(monnaie)} au client' : 'Compte juste, rien à rendre');
    final payee = Facture.fromDoc(await ref.read(dbProvider).factures.doc(f.id).get());
    if (context.mounted) await imprimer(context, ticketFacture(resto, payee));
  }

  Future<void> _ardoise(BuildContext context, WidgetRef ref, Restaurant resto) async {
    final ardoises = (ref.read(ardoisesProvider).value ?? const <Ardoise>[]).where((a) => a.montantDu > 0).toList();
    final client = TextEditingController();
    final tel = TextEditingController();
    final choix = await showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mettre en ardoise'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (ardoises.isNotEmpty) ...[
                Text('Client qui a déjà une ardoise', style: AppTypo.etiquette(context.pal.texteSecondaire)),
                const SizedBox(height: 6),
                for (final a in ardoises)
                  ListTile(
                    leading: CircleAvatar(child: Text(a.client.characters.first)),
                    title: Text(a.client),
                    subtitle: Text('${a.telephone} · doit ${fcfa(a.montantDu)}'),
                    onTap: () => Navigator.pop(ctx, a),
                  ),
                const Divider(height: 24),
              ],
              Text('Nouveau client', style: AppTypo.etiquette(context.pal.texteSecondaire)),
              const SizedBox(height: 8),
              TextField(
                controller: client,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'nouveau'), child: const Text('Créer l’ardoise')),
        ],
      ),
    );
    if (choix == null || !context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    final acteur = ref.read(acteurProvider)!;
    final ok = await essayer(context, () async {
      await caisse.mettreEnArdoise(
        caissier: acteur,
        facture: facture,
        idArdoise: choix is Ardoise ? choix.id : null,
        client: client.text,
        telephone: tel.text,
      );
      return true;
    });
    if (ok != true || !context.mounted) return;
    showStamp(context, 'CRÉDIT', couleur: identite.tableAddition);
    final f = Facture.fromDoc(await ref.read(dbProvider).factures.doc(facture.id).get());
    if (context.mounted) await imprimer(context, ticketFacture(resto, f));
  }

  Future<void> _avoir(BuildContext context, WidgetRef ref) async {
    final montant = await demanderNombre(
      context,
      'Avoir sur ${facture.numero}',
      label: 'Montant à rembourser (F)',
      initial: facture.total,
    );
    if (montant == null || !context.mounted) return;
    final motif = await demanderTexte(context, 'Motif de l’avoir', label: 'Motif');
    if (motif == null || !context.mounted) return;
    await essayer(
      context,
      () => ref.read(caisseServiceProvider).creerAvoir(ref.read(acteurProvider)!, facture, montant, motif),
      succes: 'Avoir créé',
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icone;
  final String texte;
  final VoidCallback? onTap;
  const _Mini({required this.icone, required this.texte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: texte,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(identite.arrondi * 0.7),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 19, color: p.texte),
              const SizedBox(width: 8),
              Text(texte, style: AppTypo.etiquette(p.texte, taille: 15, poids: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
