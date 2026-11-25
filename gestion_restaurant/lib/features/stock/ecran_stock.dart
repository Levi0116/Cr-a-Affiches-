import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/stock_calc.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/identite.dart';
import '../../theme/app_theme.dart';
import '../../theme/motif.dart';
import '../../widgets/cloche_alertes.dart';
import '../../widgets/commun.dart';
import '../../widgets/panneaux.dart';

/// ============================================================================
///  STOCK (section 3.3) — ambiance claire « crème Amani »
/// ============================================================================
///
/// En-tête à indicateurs (valeur du stock, alertes, vides à rendre) et cloche
/// d'alertes ; sections Articles / Alertes / Consignes / Historique ; cartes
/// d'articles avec jauge de stock animée et actions en une touche.
class EcranStock extends ConsumerStatefulWidget {
  final bool avecBarre;
  const EcranStock({super.key, this.avecBarre = true});
  @override
  ConsumerState<EcranStock> createState() => _EcranStockState();
}

enum _SectionStock { articles, alertes, consignes, historique }

class _EcranStockState extends ConsumerState<EcranStock> {
  _SectionStock _section = _SectionStock.articles;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final articles = ref.watch(articlesProvider).value ?? const <Article>[];
    final alertes = articles.where((a) => a.actif && a.sousSeuil).length;
    final vides = articles.where((a) => a.consigne).fold<num>(0, (s, a) => s + a.vides);
    final valeur = articles.where((a) => a.suiviStock && a.stock > 0).fold<num>(0, (s, a) => s + a.stock * a.coutMoyen);
    final corps = switch (_section) {
      _SectionStock.articles => const _ListeArticles(seulementAlertes: false),
      _SectionStock.alertes => const _ListeArticles(seulementAlertes: true),
      _SectionStock.consignes => const _Consignes(),
      _SectionStock.historique => const _Historique(),
    };
    final resto = ref.watch(restaurantProvider).value;
    final e = ref.watch(utilisateurProvider);
    final etroit = MediaQuery.sizeOf(context).width < 900;
    final indicateurs = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Indic(
          icone: Icons.account_balance_wallet_rounded,
          titre: 'Valeur du stock',
          couleur: p.libre,
          valeur: SmoothCounterText(valeur.round(), style: AppTypo.montant(p.texte, taille: 17)),
        ),
        PulseGlow(
          active: alertes > 0,
          couleur: p.occupee,
          rayon: BorderRadius.circular(identite.arrondi),
          child: _Indic(
            icone: Icons.warning_amber_rounded,
            titre: 'Sous le seuil',
            couleur: alertes > 0 ? p.occupee : p.texteDiscret,
            valeur: SmoothCounterText.nombre(alertes, style: AppTypo.montant(p.texte, taille: 17)),
          ),
        ),
        _Indic(
          icone: Icons.recycling_rounded,
          titre: 'Vides à rendre',
          couleur: p.addition,
          valeur: Text(qte(vides), style: AppTypo.montant(p.texte, taille: 17)),
        ),
      ],
    );
    return Theme(
      data: AppTheme.clair,
      child: Scaffold(
        backgroundColor: p.fond,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (widget.avecBarre) ...[
                          Hero(
                            tag: 'logo',
                            child: LogoResto(nom: resto?.nom ?? '', taille: 52),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stock', style: AppTypo.marque(p.texte, taille: 30)),
                                Text(
                                  resto?.nom ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (!etroit) ...[indicateurs, const SizedBox(width: 12)],
                        if (widget.avecBarre) ...[const ClocheAlertes(), const SizedBox(width: 10)],
                        if (widget.avecBarre) IndicateurConnexion(compact: etroit),
                        if (widget.avecBarre && e != null) ...[
                          const SizedBox(width: 10),
                          IconButton.outlined(
                            tooltip: '${e.nom} · changer d’utilisateur',
                            iconSize: 22,
                            onPressed: () {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                              ref.read(utilisateurProvider.notifier).deconnecter();
                            },
                            icon: const Icon(Icons.logout_rounded),
                          ),
                        ],
                      ],
                    ),
                    if (etroit) ...[const SizedBox(height: 12), indicateurs],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SelecteurSections<_SectionStock>(
                  valeur: _section,
                  onChange: (s) => setState(() => _section = s),
                  items: [
                    ItemSection(_SectionStock.articles, Icons.inventory_2_rounded, 'Articles'),
                    ItemSection(_SectionStock.alertes, Icons.warning_amber_rounded, 'Alertes', alertes),
                    ItemSection(_SectionStock.consignes, Icons.recycling_rounded, 'Consignes', vides.round()),
                    const ItemSection(_SectionStock.historique, Icons.history_rounded, 'Historique'),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duree(context, 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_section), child: corps),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indic extends StatelessWidget {
  final IconData icone;
  final String titre;
  final Color couleur;
  final Widget valeur;
  const _Indic({required this.icone, required this.titre, required this.couleur, required this.valeur});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: p.bordure),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 12)),
              valeur,
            ],
          ),
        ],
      ),
    );
  }
}

class _ListeArticles extends ConsumerStatefulWidget {
  final bool seulementAlertes;
  const _ListeArticles({required this.seulementAlertes});
  @override
  ConsumerState<_ListeArticles> createState() => _ListeArticlesState();
}

class _ListeArticlesState extends ConsumerState<_ListeArticles> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final async = ref.watch(articlesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Categorie>[];
    final portions = ref.watch(portionsProvider);
    final recettes = ref.watch(recettesProvider).value ?? const <String, Recette>{};
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (articles) {
        final q = _recherche.trim().toLowerCase();
        final liste = articles
            .where(
              (a) =>
                  a.actif &&
                  (!widget.seulementAlertes || a.sousSeuil) &&
                  (q.isEmpty || a.nom.toLowerCase().contains(q)),
            )
            .toList();
        final groupes = <Categorie?, List<Article>>{};
        for (final c in [...categories, null]) {
          final l = liste
              .where((a) => c == null ? !categories.any((x) => x.id == a.idCategorie) : a.idCategorie == c.id)
              .toList();
          if (l.isNotEmpty) groupes[c] = l;
        }
        var index = 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (!widget.seulementAlertes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    onChanged: (v) => setState(() => _recherche = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Rechercher un article',
                    ),
                  ),
                ),
              ),
            if (liste.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 42, color: p.libre),
                      const SizedBox(height: 8),
                      Text(
                        widget.seulementAlertes ? 'Aucun article sous le seuil' : 'Aucun article',
                        style: AppTypo.etiquette(p.texteSecondaire, taille: 15),
                      ),
                    ],
                  ),
                ),
              ),
            for (final g in groupes.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(color: p.principale, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Text(g.key?.nom ?? 'Autres', style: AppTypo.titre(p.texte, taille: 17, poids: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('${g.value.length}', style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 13))),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final colonnes = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
                  final l = (c.maxWidth - (colonnes - 1) * 12) / colonnes;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final a in g.value)
                        SizedBox(
                          width: l,
                          child: StaggeredEntrance(
                            key: ValueKey('st-${a.id}'),
                            index: index++,
                            child: _CarteArticle(
                              article: a,
                              portions: portions,
                              recette: recettes[a.id],
                              onAction: (act) => _action(context, ref, a, act),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, Article a, String c) async {
    final svc = ref.read(stockServiceProvider);
    final acteur = ref.read(acteurProvider)!;
    switch (c) {
      case 'livraison':
        await _livraison(context, ref, a);
      case 'perte':
        final q = await demanderQuantite(context, 'Perte : ${a.nom}', label: 'Quantité (${a.unite})');
        if (q == null || !context.mounted) return;
        final motif = await demanderTexte(context, 'Motif de la perte', label: 'casse, périmé, offert…');
        if (motif == null || !context.mounted) return;
        await essayer(context, () => svc.saisirPerte(acteur, a, q, motif), succes: 'Perte enregistrée');
      case 'portions':
        final p = await demanderNombre(
          context,
          'Portions disponibles aujourd’hui : ${a.nom}',
          initial: a.stock.toInt(),
        );
        if (p == null || !context.mounted) return;
        await essayer(context, () => svc.definirPortions(acteur, a, p), succes: 'Portions enregistrées');
      case 'inventaire':
        final q = await demanderQuantite(
          context,
          'Inventaire : ${a.nom}',
          label: 'Quantité comptée (${a.unite})',
          aide: 'Stock théorique : ${qte(a.stock, a.unite)}',
        );
        if (q == null || !context.mounted) return;
        await essayer(
          context,
          () => svc.soumettreInventaire(acteur, a, q),
          succes: q == a.stock ? 'Aucun écart' : 'Écart ${qte(q - a.stock)} envoyé en validation',
        );
      case 'seuil':
        final s = await demanderQuantite(context, 'Seuil d’alerte : ${a.nom}', initial: a.seuilAlerte);
        if (s == null || !context.mounted) return;
        await essayer(context, () => svc.reglerSeuil(acteur, a, s));
    }
  }

  Future<void> _livraison(BuildContext context, WidgetRef ref, Article a) async {
    final casiers = TextEditingController(text: '0');
    final unites = TextEditingController(text: '0');
    final prix = TextEditingController(text: a.coutMoyen > 0 ? '${a.coutMoyen}' : '');
    final fournisseur = TextEditingController();
    final vides = TextEditingController(text: a.vides > 0 ? '${a.vides}' : '0');
    final fournisseurs = await ref.read(dbProvider).fournisseurs.get();
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final total = (int.tryParse(casiers.text) ?? 0) * a.unitesParCasier + (int.tryParse(unites.text) ?? 0);
          Widget champ(TextEditingController c, String l) => TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l),
            onChanged: (_) => setState(() {}),
          );
          return AlertDialog(
            title: Text('Livraison : ${a.nom}'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (v) => fournisseurs.docs
                        .map((d) => d.data()['nom'] as String)
                        .where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
                    onSelected: (v) => fournisseur.text = v,
                    fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(labelText: 'Fournisseur'),
                      onChanged: (v) => fournisseur.text = v,
                    ),
                  ),
                  if (a.unitesParCasier > 0) champ(casiers, 'Casiers (${a.unitesParCasier} par casier)'),
                  champ(unites, 'Unités isolées'),
                  champ(prix, 'Prix d’achat par unité (F)'),
                  if (a.consigne) champ(vides, 'Bouteilles vides rendues (${qte(a.vides)} en attente)'),
                  const SizedBox(height: 12),
                  Text(
                    'Entrée : $total ${a.unite}(s)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
            ],
          );
        },
      ),
    );
    if (ok != true || !context.mounted) return;
    await essayer(
      context,
      () => ref
          .read(stockServiceProvider)
          .saisirLivraison(
            a: ref.read(acteurProvider)!,
            article: a,
            casiers: int.tryParse(casiers.text) ?? 0,
            unites: int.tryParse(unites.text) ?? 0,
            prixAchatUnitaire: int.tryParse(prix.text) ?? 0,
            fournisseur: fournisseur.text.trim(),
            videsRendus: a.consigne ? (int.tryParse(vides.text) ?? 0).clamp(0, a.vides.toInt()) : 0,
          ),
      succes: 'Livraison enregistrée',
    );
  }
}

/// Carte d'article : état (icône + libellé, jamais la couleur seule), jauge
/// de stock animée, interrupteur « En vente » et actions en une touche.
class _CarteArticle extends ConsumerWidget {
  final Article article;
  final Map<String, int> portions;
  final Recette? recette;
  final ValueChanged<String> onAction;
  const _CarteArticle({required this.article, required this.portions, required this.recette, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final a = article;
    final ingredient = a.type == TypeArticle.ingredient;
    final reste = a.aRecette ? (portions[a.id] ?? 0) : a.stock;
    final vendable = ingredient || a.estVendable(portions);
    final (String etat, Color c, IconData icone) = !vendable
        ? (a.disponible ? 'Rupture' : 'Retiré de la vente', p.erreur, Icons.block_rounded)
        : (a.stock < 0
              ? ('Stock négatif', p.erreur, Icons.error_rounded)
              : (a.sousSeuil || (a.aRecette && reste <= 3)
                    ? ('Stock bas', p.occupee, Icons.trending_down_rounded)
                    : (a.suiviStock || a.aRecette
                          ? ('En stock', p.libre, Icons.check_circle_rounded)
                          : ('Non suivi', p.texteSecondaire, Icons.all_inclusive_rounded))));
    // Jauge : plein = 3 fois le seuil (ou le stock actuel s'il est plus haut).
    final plein = [a.seuilAlerte * 3, reste, 1].reduce((x, y) => x > y ? x : y);
    final jauge = (a.suiviStock || a.aRecette) ? (reste / plein).clamp(0, 1).toDouble() : 1.0;
    final details = [
      if (a.aRecette)
        'Fiche : ${(recette?.ingredients ?? const []).map((i) => '${qte(i.quantite, i.unite)} ${i.nom}').join(' + ')}'
      else if (a.suiviStock)
        'Seuil ${qte(a.seuilAlerte, a.unite)}',
      if (a.coutMoyen > 0) 'coût ${fcfa(a.coutMoyen)}',
      if (a.unitesParCasier > 0) '${a.unitesParCasier}/casier',
    ].join(' · ');
    return PanneauCaisse(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(icone, color: c, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypo.etiquette(p.texte, taille: 15, poids: FontWeight.w700),
                    ),
                    Text(etat, style: AppTypo.etiquette(c, taille: 12, poids: FontWeight.w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(a.suiviStock || a.aRecette ? qte(reste) : '∞', style: AppTypo.montant(p.texte, taille: 22)),
                  Text(
                    a.aRecette ? 'portions possibles' : a.unite,
                    style: AppTypo.etiquette(p.texteDiscret, taille: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: jauge),
            duration: duree(context, 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 7,
                color: c,
                backgroundColor: p.texte.withValues(alpha: 0.06),
              ),
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 12, poids: FontWeight.w500)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (!ingredient) ...[
                Switch(
                  value: a.disponible,
                  onChanged: (v) => essayer(
                    context,
                    () => ref.read(stockServiceProvider).forcerDisponibilite(ref.read(acteurProvider)!, a, v),
                  ),
                ),
                Text('En vente', style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
              ],
              const Spacer(),
              if (!a.aRecette) ...[
                TextButton.icon(
                  onPressed: () => onAction('livraison'),
                  icon: const Icon(Icons.local_shipping_rounded, size: 18),
                  label: const Text('Livraison'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Autres actions',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'perte', child: Text('Saisir une perte')),
                    if (a.type == TypeArticle.prepare)
                      const PopupMenuItem(value: 'portions', child: Text('Portions du jour')),
                    const PopupMenuItem(value: 'inventaire', child: Text('Inventaire (compté)')),
                    const PopupMenuItem(value: 'seuil', child: Text('Régler le seuil d’alerte')),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Consignes (section 3.3) : bouteilles et casiers vides à rendre.
class _Consignes extends ConsumerWidget {
  const _Consignes();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = (ref.watch(articlesProvider).value ?? const <Article>[]).where((a) => a.consigne).toList();
    final total = articles.fold<num>(0, (s, a) => s + a.vides);
    if (articles.isEmpty) {
      return const Center(child: Text('Aucun article consigné (à activer dans le menu)'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('${qte(total)} bouteille(s) vide(s) à rendre', style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final (i, a) in articles.indexed)
          StaggeredEntrance(
            index: i,
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: identite.accent.withValues(alpha: 0.2),
                  foregroundColor: identite.texte,
                  child: Text(qte(a.vides), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                title: Text(a.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  a.unitesParCasier > 0
                      ? '${a.vides ~/ a.unitesParCasier} casier(s) complet(s) + ${a.vides % a.unitesParCasier} bouteille(s)'
                      : 'bouteilles vides',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final n = await demanderNombre(
                          context,
                          'Corriger les vides : ${a.nom}',
                          label: 'Vides comptés',
                          initial: a.vides.toInt(),
                        );
                        if (n == null || !context.mounted) return;
                        final motif = await demanderTexte(context, 'Motif', label: 'casse, perte…');
                        if (motif == null || !context.mounted) return;
                        await essayer(
                          context,
                          () => ref.read(stockServiceProvider).corrigerVides(ref.read(acteurProvider)!, a, n, motif),
                        );
                      },
                      child: const Text('Corriger'),
                    ),
                    FilledButton(
                      onPressed: a.vides <= 0
                          ? null
                          : () async {
                              final n = await demanderNombre(
                                context,
                                'Rendre des vides : ${a.nom}',
                                label: 'Bouteilles rendues',
                                initial: a.vides.toInt(),
                              );
                              if (n == null || !context.mounted) return;
                              await essayer(
                                context,
                                () => ref.read(stockServiceProvider).rendreVides(ref.read(acteurProvider)!, a, n),
                                succes: 'Retour enregistré',
                              );
                            },
                      child: const Text('Rendre'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Historique extends ConsumerStatefulWidget {
  const _Historique();
  @override
  ConsumerState<_Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends ConsumerState<_Historique> {
  String? _article;
  @override
  Widget build(BuildContext context) {
    final mvts = ref.watch(mouvementsProvider);
    final articles = ref.watch(articlesProvider).value ?? const [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: DropdownButton<String?>(
            value: _article,
            isExpanded: true,
            hint: const Text('Tous les articles'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les articles')),
              for (final a in articles) DropdownMenuItem(value: a.id, child: Text(a.nom)),
            ],
            onChanged: (v) => setState(() => _article = v),
          ),
        ),
        Expanded(
          child: mvts.when(
            loading: () => const Chargement(),
            error: (e, _) => Chargement(erreur: e),
            data: (liste) {
              final f = liste.where((m) => _article == null || m.idArticle == _article).toList();
              return ListView.builder(
                itemCount: f.length,
                itemBuilder: (context, i) {
                  final m = f[i];
                  return ListTile(
                    dense: true,
                    leading: Text(
                      m.quantite > 0 ? '+${m.quantite}' : '${m.quantite}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: m.quantite > 0 ? couleurLibre : Colors.red,
                      ),
                    ),
                    title: Text('${m.nomArticle} · ${m.type}'),
                    subtitle: Text('${dateHeure(m.date)} · ${m.auteur}${m.motif.isEmpty ? '' : ' · ${m.motif}'}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
