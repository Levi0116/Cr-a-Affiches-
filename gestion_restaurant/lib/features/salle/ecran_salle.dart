import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../../widgets/animated_table_card.dart';
import '../../widgets/barre_etat.dart';
import '../../widgets/commun.dart';
import '../commande/ecran_commande.dart';

/// ============================================================================
///  PLAN DE SALLE (section 3.1) — ambiance sombre « obsidienne Amani »
/// ============================================================================
///
/// - Cartes de table animées (émeraude libre, ambre occupée, bleu addition),
///   regroupées par zone, qui apparaissent en cascade.
/// - Résumé en direct : tables libres / occupées / addition, montant en cours.
/// - Barre flottante en verre dépoli, à portée de pouce : zones + « À emporter ».
/// - Toucher une table : sa carte s'agrandit et devient l'en-tête de la commande.
/// - Appui long sur une table occupée : transférer ou fusionner.
class EcranSalle extends StatelessWidget {
  /// false quand l'écran est intégré dans l'espace administrateur.
  final bool avecBarre;
  const EcranSalle({super.key, this.avecBarre = true});

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.sombre,
    child: _PlanDeSalle(avecBarre: avecBarre),
  );
}

class _PlanDeSalle extends ConsumerStatefulWidget {
  final bool avecBarre;
  const _PlanDeSalle({required this.avecBarre});
  @override
  ConsumerState<_PlanDeSalle> createState() => _PlanDeSalleState();
}

class _PlanDeSalleState extends ConsumerState<_PlanDeSalle> {
  /// Zone affichée (null = toutes).
  String? _zone;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tablesAsync = ref.watch(tablesProvider);
    final zones = ref.watch(zonesProvider).value ?? const <Zone>[];
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final parTable = {
      for (final s in sessions)
        if (s.idTable != null) s.idTable!: s,
    };
    final aEmporter = sessions.where((s) => s.aEmporter).toList();
    final largeur = MediaQuery.sizeOf(context).width;
    final marge = largeur < 600 ? 14.0 : 24.0;

    return Scaffold(
      backgroundColor: p.fond,
      body: Stack(
        children: [
          // Lueur d'ambiance très discrète en haut (orange du logo).
          Positioned(
            top: -220,
            left: -120,
            right: -120,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [p.principale.withValues(alpha: 0.10), Colors.transparent]),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: tablesAsync.when(
              loading: () => _ChargementSalle(marge: marge),
              error: (e, _) => Chargement(erreur: e),
              data: (toutes) {
                final actives = toutes.where((t) => t.active).toList();
                final visibles = actives.where((t) => _zone == null || t.idZone == _zone).toList();
                final groupes = <Zone?, List<TableResto>>{};
                for (final z in [...zones, null]) {
                  final liste = visibles
                      .where((t) => z == null ? !zones.any((x) => x.id == t.idZone) : t.idZone == z.id)
                      .toList();
                  if (liste.isNotEmpty) groupes[z] = liste;
                }
                // Rang de départ de chaque zone pour la cascade (calculé ici :
                // la grille construit ses cartes à la demande, dans le désordre).
                final debuts = <Zone?, int>{};
                var compteur = 0;
                for (final e in groupes.entries) {
                  debuts[e.key] = compteur;
                  compteur += e.value.length;
                }
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _EnTeteSalle(avecBarre: widget.avecBarre, marge: marge),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(marge, 4, marge, 8),
                        child: _ResumeSalle(tables: actives, parTable: parTable),
                      ),
                    ),
                    if (aEmporter.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _BandeAEmporter(
                          sessions: aEmporter,
                          marge: marge,
                          onOuvrir: (s) => _ouvrir(context, null, s),
                        ),
                      ),
                    if (visibles.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Aucune table dans cette zone',
                            style: AppTypo.etiquette(p.texteSecondaire, taille: 16),
                          ),
                        ),
                      ),
                    for (final e in groupes.entries) ...[
                      SliverToBoxAdapter(
                        child: _TitreZone(
                          nom: e.key?.nom ?? 'Autres tables',
                          tables: e.value,
                          parTable: parTable,
                          marge: marge,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: marge),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 18,
                            childAspectRatio: 0.98,
                          ),
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final t = e.value[i];
                            final s = parTable[t.id];
                            return StaggeredEntrance(
                              // Clé stable : l'animation d'entrée ne rejoue pas
                              // à chaque mise à jour temps réel.
                              key: ValueKey('entree-${t.id}-$_zone'),
                              index: debuts[e.key]! + i,
                              child: AnimatedTableCard(
                                table: t,
                                session: s,
                                onTap: () => _ouvrir(context, t, s),
                                onLongPress: s == null ? null : () => _actionsTable(context, t, s, toutes, parTable),
                              ),
                            );
                          }, childCount: e.value.length),
                        ),
                      ),
                    ],
                    // Place pour la barre flottante.
                    const SliverToBoxAdapter(child: SizedBox(height: 132)),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: marge,
            right: marge,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _BarreFlottante(
              zones: zones,
              zone: _zone,
              onZone: (z) => setState(() => _zone = z),
              onAEmporter: () => _ouvrir(context, null, null),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Navigation

  Future<void> _ouvrir(BuildContext context, TableResto? t, SessionTable? s) async {
    var couverts = 0;
    if (t != null && s == null) {
      final c = await _demanderCouverts(context, t);
      if (c == null) return;
      couverts = c;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranCommande(table: t, idSession: s?.id, couverts: couverts),
      ),
    );
  }

  /// Ouverture d'une table libre : couverts (facultatif), en une touche.
  Future<int?> _demanderCouverts(BuildContext context, TableResto t) {
    final p = context.pal;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (ctx) => _FeuilleVerre(
        titre: 'Ouvrir la table ${t.numero}',
        sousTitre: 'Combien de couverts ? (facultatif)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (var i = 1; i <= 8; i++)
                  StaggeredEntrance(
                    index: i,
                    child: _BoutonChoix(texte: '$i', surligne: i <= t.capacite, onTap: () => Navigator.pop(ctx, i)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientActionButton(
                label: 'Ouvrir sans préciser',
                icone: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.pop(ctx, 0),
              ),
            ),
            const SizedBox(height: 4),
            Text('${t.capacite} places à cette table', style: AppTypo.etiquette(p.texteDiscret)),
          ],
        ),
      ),
    );
  }

  Future<void> _actionsTable(
    BuildContext context,
    TableResto t,
    SessionTable s,
    List<TableResto> toutes,
    Map<String, SessionTable> parTable,
  ) async {
    final acteur = ref.read(acteurProvider)!;
    final svc = ref.read(commandeServiceProvider);
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) => _FeuilleVerre(
        titre: 'Table ${t.numero}',
        sousTitre: '${fcfa(s.total)} · ${s.nomServeuse} · ouverte à ${heure(s.ouverture)}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LigneAction(
              icone: Icons.swap_horiz_rounded,
              titre: 'Transférer',
              detail: 'Le client change de place',
              onTap: () => Navigator.pop(ctx, 'transfert'),
            ),
            const SizedBox(height: 10),
            _LigneAction(
              icone: Icons.merge_type_rounded,
              titre: 'Fusionner',
              detail: 'Regrouper avec une autre table',
              onTap: () => Navigator.pop(ctx, 'fusion'),
            ),
          ],
        ),
      ),
    );
    if (choix == null || !context.mounted) return;
    final transfert = choix == 'transfert';
    final candidates = transfert
        ? toutes.where((x) => x.active && x.statut == StatutTable.libre && parTable[x.id] == null).toList()
        : toutes.where((x) => x.id != t.id && parTable[x.id]?.statut == StatutSession.ouverte).toList();
    if (candidates.isEmpty) {
      afficherMessage(context, 'Aucune table disponible', erreur: true);
      return;
    }
    final dest = await showModalBottomSheet<TableResto>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (ctx) => _FeuilleVerre(
        titre: transfert ? 'Transférer vers…' : 'Fusionner la table ${t.numero} dans…',
        sousTitre: transfert ? 'Tables libres' : 'Tables occupées',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, c) in candidates.indexed)
              SizedBox(
                width: 84,
                height: 64,
                child: StaggeredEntrance(
                  index: i,
                  child: _BoutonChoix(texte: c.numero, onTap: () => Navigator.pop(ctx, c)),
                ),
              ),
          ],
        ),
      ),
    );
    if (dest == null || !context.mounted) return;
    final ok = await essayer(context, () async {
      if (transfert) {
        await svc.transferer(acteur, s, dest);
      } else {
        await svc.fusionner(acteur, s, parTable[dest.id]!);
      }
      return true;
    });
    if (ok == true && context.mounted) {
      showSuccessBurst(context, transfert ? 'Table ${dest.numero}' : 'Tables fusionnées');
    }
  }
}

// ============================================================== En-tête

class _EnTeteSalle extends ConsumerWidget {
  final bool avecBarre;
  final double marge;
  const _EnTeteSalle({required this.avecBarre, required this.marge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final resto = ref.watch(restaurantProvider).value;
    final e = ref.watch(utilisateurProvider);
    final etroit = MediaQuery.sizeOf(context).width < 640;
    return Padding(
      padding: EdgeInsets.fromLTRB(marge, 14, marge, 10),
      child: Row(
        children: [
          if (avecBarre) ...[
            Hero(
              tag: 'logo',
              child: LogoResto(nom: resto?.nom ?? '', taille: 52),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan de salle', style: AppTypo.titre(p.texte, taille: etroit ? 22 : 26)),
                Text(
                  resto?.nom ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500),
                ),
              ],
            ),
          ),
          IndicateurConnexion(compact: etroit),
          if (avecBarre && e != null) ...[const SizedBox(width: 10), _PuceUtilisateur(nom: e.nom)],
        ],
      ),
    );
  }
}

class _PuceUtilisateur extends ConsumerWidget {
  final String nom;
  const _PuceUtilisateur({required this.nom});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: '$nom, changer d’utilisateur',
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          ref.read(utilisateurProvider.notifier).deconnecter();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: p.principale,
                child: Text(nom.characters.first, style: AppTypo.titre(Colors.white, taille: 15)),
              ),
              const SizedBox(width: 8),
              Text(nom, style: AppTypo.etiquette(p.texte, taille: 15)),
              const SizedBox(width: 6),
              Icon(Icons.logout_rounded, size: 18, color: p.texteDiscret),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================== Résumé

/// Compteurs en direct. Chaque état porte une icône et un libellé : la
/// couleur n'est jamais le seul indice.
class _ResumeSalle extends StatelessWidget {
  final List<TableResto> tables;
  final Map<String, SessionTable> parTable;
  const _ResumeSalle({required this.tables, required this.parTable});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    var libres = 0, occupees = 0, additions = 0, enCours = 0;
    for (final t in tables) {
      final s = parTable[t.id];
      switch (etatDe(s)) {
        case EtatTable.libre:
          libres++;
        case EtatTable.occupee:
          occupees++;
        case EtatTable.addition:
          additions++;
      }
      enCours += s?.total ?? 0;
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Compteur(etat: EtatTable.libre, valeur: libres, libelle: 'libres'),
        _Compteur(etat: EtatTable.occupee, valeur: occupees, libelle: 'occupées'),
        _Compteur(etat: EtatTable.addition, valeur: additions, libelle: 'addition', alerte: additions > 0),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_rounded, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Text('En cours ', style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
              SmoothCounterText(enCours, style: AppTypo.montant(p.texte, taille: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Compteur extends StatelessWidget {
  final EtatTable etat;
  final int valeur;
  final String libelle;
  final bool alerte;
  const _Compteur({required this.etat, required this.valeur, required this.libelle, this.alerte = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = etat.couleur(p);
    final rayon = BorderRadius.circular(30);
    return PulseGlow(
      active: alerte,
      couleur: c,
      rayon: rayon,
      child: AnimatedContainer(
        duration: duree(context, 300),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: alerte ? 0.24 : 0.12),
          borderRadius: rayon,
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(etat.icone, size: 18, color: c),
            const SizedBox(width: 8),
            SmoothCounterText.nombre(valeur, style: AppTypo.montant(p.texte, taille: 17)),
            const SizedBox(width: 5),
            Text(libelle, style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
          ],
        ),
      ),
    );
  }
}

class _TitreZone extends StatelessWidget {
  final String nom;
  final List<TableResto> tables;
  final Map<String, SessionTable> parTable;
  final double marge;
  const _TitreZone({required this.nom, required this.tables, required this.parTable, required this.marge});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final libres = tables.where((t) => parTable[t.id] == null).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(marge, 22, marge, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: p.principale, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Text(nom, style: AppTypo.titre(p.texte, taille: 18, poids: FontWeight.w700)),
          const SizedBox(width: 10),
          Text(
            '$libres libre${libres > 1 ? 's' : ''} sur ${tables.length}',
            style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 13, poids: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: p.bordure)),
        ],
      ),
    );
  }
}

// ===================================================== Ventes à emporter

class _BandeAEmporter extends StatelessWidget {
  final List<SessionTable> sessions;
  final double marge;
  final ValueChanged<SessionTable> onOuvrir;
  const _BandeAEmporter({required this.sessions, required this.marge, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: marge, vertical: 8),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = sessions[i];
          final addition = s.statut != StatutSession.ouverte;
          final c = addition ? p.addition : p.principale;
          return StaggeredEntrance(
            index: i,
            child: PulseGlow(
              active: addition,
              couleur: c,
              rayon: BorderRadius.circular(18),
              child: BouncyTapWrapper(
                onTap: () => onOuvrir(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_rounded, color: c),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.numeroTable, style: AppTypo.chiffres(AppTypo.etiquette(p.texte, taille: 14))),
                          SmoothCounterText(s.total, style: AppTypo.montant(p.texte, taille: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =================================================== Barre flottante

class _BarreFlottante extends StatelessWidget {
  final List<Zone> zones;
  final String? zone;
  final ValueChanged<String?> onZone;
  final VoidCallback onAEmporter;
  const _BarreFlottante({required this.zones, required this.zone, required this.onZone, required this.onAEmporter});

  @override
  Widget build(BuildContext context) {
    final etroit = MediaQuery.sizeOf(context).width < 640;
    final onglets = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OngletZone(nom: 'Toutes', icone: Icons.grid_view_rounded, actif: zone == null, onTap: () => onZone(null)),
          for (final z in zones)
            _OngletZone(nom: z.nom, icone: _iconeZone(z.nom), actif: zone == z.id, onTap: () => onZone(z.id)),
        ],
      ),
    );
    final bouton = GradientActionButton(label: 'À emporter', icone: Icons.shopping_bag_rounded, onPressed: onAEmporter);
    return GlassPanel(
      padding: const EdgeInsets.all(8),
      child: etroit
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                onglets,
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: bouton),
              ],
            )
          : Row(
              children: [
                Expanded(child: onglets),
                const SizedBox(width: 8),
                bouton,
              ],
            ),
    );
  }

  IconData _iconeZone(String nom) {
    final n = nom.toLowerCase();
    if (n.contains('terrasse') || n.contains('jardin') || n.contains('cour')) return Icons.deck_rounded;
    if (n.contains('vip') || n.contains('salon')) return Icons.diamond_rounded;
    if (n.contains('bar') || n.contains('comptoir')) return Icons.local_bar_rounded;
    return Icons.table_restaurant_rounded;
  }
}

class _OngletZone extends StatelessWidget {
  final String nom;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;
  const _OngletZone({required this.nom, required this.icone, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: actif,
        label: 'Zone $nom',
        excludeSemantics: true,
        child: BouncyTapWrapper(
          onTap: onTap,
          child: AnimatedContainer(
            duration: duree(context, 280),
            curve: Curves.easeOutCubic,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: actif ? p.texte : Colors.transparent,
              borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 20, color: actif ? p.fond : p.texteSecondaire),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: duree(context, 280),
                  style: AppTypo.etiquette(actif ? p.fond : p.texteSecondaire, taille: 16, poids: FontWeight.w700),
                  child: Text(nom),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================= Feuilles modales

/// Feuille du bas en verre dépoli, poignée et titre.
class _FeuilleVerre extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final Widget child;
  const _FeuilleVerre({required this.titre, this.sousTitre, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(color: p.texteDiscret, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(titre, style: AppTypo.titre(p.texte, taille: 22)),
                if (sousTitre != null) ...[
                  const SizedBox(height: 2),
                  Text(sousTitre!, style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 14))),
                ],
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonChoix extends StatelessWidget {
  final String texte;
  final bool surligne;
  final VoidCallback onTap;
  const _BoutonChoix({required this.texte, required this.onTap, this.surligne = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: texte,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: surligne ? p.surfaceElevee : p.surface,
            borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
            border: Border.all(color: surligne ? p.accent.withValues(alpha: 0.35) : p.bordure),
          ),
          child: Text(texte, style: AppTypo.montant(p.texte, taille: 24)),
        ),
      ),
    );
  }
}

class _LigneAction extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final VoidCallback onTap;
  const _LigneAction({required this.icone, required this.titre, required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: titre,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.principale.withValues(alpha: 0.16),
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

// =========================================================== Chargement

/// Squelette du plan de salle pendant le chargement (reflet shimmer).
class _ChargementSalle extends StatelessWidget {
  final double marge;
  const _ChargementSalle({required this.marge});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(marge, 18, marge, 0),
    child: ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ShimmerBlock(largeur: 52, hauteur: 52, rayon: 26),
              SizedBox(width: 14),
              ShimmerBlock(largeur: 220, hauteur: 30),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              for (final l in [120.0, 140.0, 130.0, 180.0]) ShimmerBlock(largeur: l, hauteur: 48, rayon: 24),
            ],
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 0.98,
            ),
            itemCount: 12,
            itemBuilder: (_, _) => ShimmerBlock(rayon: identite.arrondi),
          ),
        ],
      ),
    ),
  );
}
