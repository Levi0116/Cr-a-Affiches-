import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animations.dart';
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
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              const Tab(text: 'Articles'),
              Tab(text: 'Alertes ($alertes)'),
              const Tab(text: 'Historique'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ListeArticles(seulementAlertes: false),
                _ListeArticles(seulementAlertes: true),
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
              Apparition(
                index: i,
                child: Card(
                  child: ListTile(
                    title: Text(a.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        categories[a.idCategorie] ?? '',
                        if (a.suiviStock) 'seuil ${a.seuilAlerte}' else 'stock non suivi',
                        if (a.coutMoyen > 0) 'coût ${fcfa(a.coutMoyen)}',
                        if (a.unitesParCasier > 0) '${a.unitesParCasier}/casier',
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: !a.vendable ? identite.erreur : (a.sousSeuil ? couleurOccupee : couleurLibre),
                      foregroundColor: Colors.white,
                      child: Text(
                        a.suiviStock ? '${a.stock}' : '∞',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (a.stock < 0) Pastille('Négatif !', identite.erreur),
                        Switch(
                          value: a.disponible,
                          onChanged: (v) => essayer(
                            context,
                            () => ref.read(stockServiceProvider).forcerDisponibilite(ref.read(acteurProvider)!, a, v),
                          ),
                        ),
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
        final q = await demanderNombre(context, 'Perte : ${a.nom}', label: 'Quantité');
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
        final q = await demanderNombre(
          context,
          'Inventaire : ${a.nom}',
          label: 'Quantité comptée',
          aide: 'Stock théorique : ${a.stock}',
        );
        if (q == null || !context.mounted) return;
        await essayer(
          context,
          () => svc.soumettreInventaire(acteur, a, q),
          succes: q == a.stock ? 'Aucun écart' : 'Écart ${q - a.stock} envoyé en validation',
        );
      case 'seuil':
        final s = await demanderNombre(context, 'Seuil d’alerte : ${a.nom}', initial: a.seuilAlerte.toInt());
        if (s == null || !context.mounted) return;
        await essayer(context, () => svc.reglerSeuil(acteur, a, s));
    }
  }

  Future<void> _livraison(BuildContext context, WidgetRef ref, Article a) async {
    final casiers = TextEditingController(text: '0');
    final unites = TextEditingController(text: '0');
    final prix = TextEditingController(text: a.coutMoyen > 0 ? '${a.coutMoyen}' : '');
    final fournisseur = TextEditingController();
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
          ),
      succes: 'Livraison enregistrée',
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
