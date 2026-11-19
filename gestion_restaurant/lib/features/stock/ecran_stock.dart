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
import '../../widgets/commun.dart';

/// Module Stock (section 3.3).
class EcranStock extends ConsumerWidget {
  final bool avecBarre;
  const EcranStock({super.key, this.avecBarre = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertes = (ref.watch(articlesProvider).value ?? const []).where((a) => a.actif && a.sousSeuil).length;
    final corps = DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            tabs: [
              const Tab(text: 'Articles'),
              Tab(text: 'Alertes ($alertes)'),
              const Tab(text: 'Consignes'),
              const Tab(text: 'Historique'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ListeArticles(seulementAlertes: false),
                _ListeArticles(seulementAlertes: true),
                _Consignes(),
                _Historique(),
              ],
            ),
          ),
        ],
      ),
    );
    if (!avecBarre) return corps;
    return Scaffold(
      appBar: barreBraise(title: const Text('Stock'), actions: actionsBarre(context, ref)),
      body: corps,
    );
  }
}

class _ListeArticles extends ConsumerWidget {
  final bool seulementAlertes;
  const _ListeArticles({required this.seulementAlertes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articlesProvider);
    final categories = {for (final c in ref.watch(categoriesProvider).value ?? const <Categorie>[]) c.id: c.nom};
    final portions = ref.watch(portionsProvider);
    final recettes = ref.watch(recettesProvider).value ?? const <String, Recette>{};
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (articles) {
        final liste = articles.where((a) => a.actif && (!seulementAlertes || a.sousSeuil)).toList();
        final valeur = articles
            .where((a) => a.suiviStock && a.stock > 0)
            .fold<num>(0, (s, a) => s + a.stock * a.coutMoyen);
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (!seulementAlertes)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Valeur du stock (au coût moyen) : ${fcfa(valeur)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            if (liste.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Rien à signaler')),
            for (final (i, a) in liste.indexed)
              StaggeredEntrance(
                index: i,
                child: Card(
                  child: ListTile(
                    title: Text(
                      a.aRecette
                          ? '${a.nom} · ${portions[a.id] ?? 0} portion(s) possible(s)'
                          : (a.type == TypeArticle.ingredient ? '${a.nom} (${a.unite})' : a.nom),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        categories[a.idCategorie] ?? '',
                        if (a.aRecette)
                          'fiche : ${(recettes[a.id]?.ingredients ?? const []).map((i) => '${qte(i.quantite, i.unite)} ${i.nom}').join(' + ')}'
                        else if (a.suiviStock)
                          'seuil ${qte(a.seuilAlerte, a.unite)}'
                        else
                          'stock non suivi',
                        if (a.coutMoyen > 0) 'coût ${fcfa(a.coutMoyen)}',
                        if (a.unitesParCasier > 0) '${a.unitesParCasier}/casier',
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: a.type != TypeArticle.ingredient && !a.estVendable(portions)
                          ? identite.erreur
                          : (a.sousSeuil || (a.aRecette && (portions[a.id] ?? 0) <= 3) ? couleurOccupee : couleurLibre),
                      foregroundColor: Colors.white,
                      child: Text(
                        a.aRecette ? '${portions[a.id] ?? 0}' : (a.suiviStock ? qte(a.stock) : '∞'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (a.stock < 0) Pastille('Négatif !', identite.erreur),
                        if (a.type != TypeArticle.ingredient)
                          Switch(
                            value: a.disponible,
                            onChanged: (v) => essayer(
                              context,
                              () => ref.read(stockServiceProvider).forcerDisponibilite(ref.read(acteurProvider)!, a, v),
                            ),
                          ),
                        if (!a.aRecette)
                          PopupMenuButton<String>(
                            onSelected: (c) => _action(context, ref, a, c),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'livraison', child: Text('Saisir une livraison')),
                              const PopupMenuItem(value: 'perte', child: Text('Saisir une perte')),
                              if (a.type == TypeArticle.prepare)
                                const PopupMenuItem(value: 'portions', child: Text('Portions du jour')),
                              const PopupMenuItem(value: 'inventaire', child: Text('Inventaire (compté)')),
                              const PopupMenuItem(value: 'seuil', child: Text('Régler le seuil d’alerte')),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
