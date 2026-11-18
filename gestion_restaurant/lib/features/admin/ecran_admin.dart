import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/stock_calc.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animations.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';
import '../caisse/ecran_caisse.dart';
import '../salle/ecran_salle.dart';
import '../stock/ecran_stock.dart';
import 'rapports.dart';

/// Espace administrateur (section 3.4) : tout, plus les validations.
class EcranAdmin extends ConsumerStatefulWidget {
  const EcranAdmin({super.key});
  @override
  ConsumerState<EcranAdmin> createState() => _EcranAdminState();
}

class _EcranAdminState extends ConsumerState<EcranAdmin> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final attente = ref.watch(demandesEnAttenteProvider).value?.length ?? 0;
    final pages = <(IconData, String, Widget)>[
      (Icons.dashboard, 'Tableau de bord', const _TableauDeBord()),
      (Icons.verified, 'Validations${attente > 0 ? ' ($attente)' : ''}', const _Validations()),
      (Icons.insights_rounded, 'Rapports', const EcranRapports()),
      (Icons.point_of_sale, 'Caisse', const EcranCaisse(avecBarre: false)),
      (Icons.table_restaurant, 'Salle', const EcranSalle(avecBarre: false)),
      (Icons.inventory_2, 'Stock', const EcranStock(avecBarre: false)),
      (Icons.restaurant_menu, 'Menu', const _Menu()),
      (Icons.grid_view, 'Tables', const _Tables()),
      (Icons.people, 'Employés', const _Employes()),
      (Icons.settings, 'Paramètres', const _Parametres()),
      (Icons.history, 'Journal d’audit', const _Audit()),
    ];
    final large = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: barreBraise(title: Text(pages[_index].$2), actions: actionsBarre(context, ref)),
      drawer: large
          ? null
          : Drawer(
              child: ListView(
                children: [
                  for (var i = 0; i < pages.length; i++)
                    ListTile(
                      leading: Badge(
                        isLabelVisible: i == 1 && attente > 0,
                        label: Text('$attente'),
                        child: Icon(pages[i].$1),
                      ),
                      title: Text(pages[i].$2),
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
      body: large
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (var i = 0; i < pages.length; i++)
                      NavigationRailDestination(
                        icon: Badge(
                          isLabelVisible: i == 1 && attente > 0,
                          label: Text('$attente'),
                          child: Icon(pages[i].$1),
                        ),
                        label: Text(pages[i].$2.split(' (').first),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[_index].$3),
              ],
            )
          : pages[_index].$3,
    );
  }
}

// ----------------------------------------------------------- Tableau de bord

class _TableauDeBord extends ConsumerWidget {
  const _TableauDeBord();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factures = ref.watch(facturesDepuisProvider(debutJour())).value ?? const [];
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const [];
    final articles = ref.watch(articlesProvider).value ?? const [];
    final ardoises = ref.watch(ardoisesProvider).value ?? const [];
    final demandes = ref.watch(demandesEnAttenteProvider).value ?? const [];
    final vendues = factures.where((f) => f.statut != StatutFacture.emise).toList();
    final ca = vendues.fold(0, (s, f) => s + f.total);
    final enCours = sessions.fold(0, (s, x) => s + x.total);
    final ventes = <String, (int, int)>{};
    final parServeuse = <String, int>{};
    for (final f in vendues) {
      parServeuse[f.nomServeuse] = (parServeuse[f.nomServeuse] ?? 0) + f.total;
      if (f.partie != null && f.partie != '1/${f.partie!.split('/').last}') continue;
      for (final l in f.lignes.where((l) => !l.annulee)) {
        final (q, m) = ventes[l.nom] ?? (0, 0);
        ventes[l.nom] = (q + l.quantite, m + l.montant);
      }
    }
    final top = ventes.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final sousSeuil = articles.where((a) => a.actif && a.sousSeuil).toList();

    var n = 0;
    Widget tuile(String titre, IconData icone, Widget valeur, {Color? couleur}) {
      final c = couleur ?? identite.principale;
      return Apparition(
        index: n++,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: identite.surface,
            borderRadius: BorderRadius.circular(identite.arrondi),
            border: Border.all(color: identite.texte.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(color: identite.nuit.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: Icon(icone, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: TextStyle(color: identite.texte.withValues(alpha: 0.6), fontSize: 13)),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontFamily: identite.policeTitres,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: identite.texte,
                      ),
                      child: valeur,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stTitre = TextStyle(
      fontFamily: identite.policeTitres,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: identite.texte,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            tuile('Chiffre d’affaires du jour', Icons.trending_up_rounded, MontantAnime(ca, style: stTitre)),
            tuile('Factures du jour', Icons.receipt_long_rounded, Text('${vendues.length}'), couleur: identite.accent),
            tuile(
              'En cours (${sessions.length} tables)',
              Icons.table_restaurant_rounded,
              MontantAnime(enCours, style: stTitre),
              couleur: couleurOccupee,
            ),
            tuile(
              'Validations en attente',
              Icons.verified_rounded,
              Text('${demandes.length}'),
              couleur: demandes.isEmpty ? couleurLibre : couleurOccupee,
            ),
            tuile(
              'Articles sous le seuil',
              Icons.warning_amber_rounded,
              Text('${sousSeuil.length}'),
              couleur: sousSeuil.isEmpty ? couleurLibre : identite.erreur,
            ),
            tuile(
              'Ardoises en cours',
              Icons.menu_book_rounded,
              MontantAnime(ardoises.fold(0, (s, a) => s + a.montantDu), style: stTitre),
              couleur: couleurAddition,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Meilleures ventes du jour', style: Theme.of(context).textTheme.titleMedium),
        if (top.isEmpty) const Text('Pas encore de vente'),
        for (final e in top.take(10))
          ListTile(
            dense: true,
            title: Text(e.key),
            subtitle: Text('${e.value.$1} vendu(s)'),
            trailing: Text(fcfa(e.value.$2)),
          ),
        const SizedBox(height: 16),
        Text('Ventes par serveuse', style: Theme.of(context).textTheme.titleMedium),
        for (final e in parServeuse.entries) ListTile(dense: true, title: Text(e.key), trailing: Text(fcfa(e.value))),
        if (sousSeuil.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Stock sous le seuil', style: Theme.of(context).textTheme.titleMedium),
          for (final a in sousSeuil)
            ListTile(dense: true, title: Text(a.nom), trailing: Text('${a.stock} (seuil ${a.seuilAlerte})')),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- Validations

class _Validations extends ConsumerWidget {
  const _Validations();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(demandesEnAttenteProvider);
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        if (liste.isEmpty) return const Center(child: Text('Aucune demande en attente'));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final (i, d) in liste.indexed)
              Apparition(
                index: i,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_titre(d), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Demandé par ${d.demandeur} à ${dateHeure(d.date)}'),
                        Text('Motif : ${d.motif}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Valider'),
                              onPressed: () => essayer(context, () async {
                                await ref.read(adminServiceProvider).traiterDemande(ref.read(acteurProvider)!, d, true);
                                if (context.mounted) celebrer(context, 'Validé');
                              }),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Refuser'),
                              onPressed: () => essayer(
                                context,
                                () =>
                                    ref.read(adminServiceProvider).traiterDemande(ref.read(acteurProvider)!, d, false),
                                succes: 'Refusé',
                              ),
                            ),
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

  String _titre(DemandeValidation d) {
    final x = d.detail;
    return switch (d.type) {
      TypeValidation.annulation =>
        'Annulation : ${x['quantite']} × ${x['nom']} (${fcfa(x['montant'] as num)}) · table ${x['numeroTable']}',
      TypeValidation.offert => 'Offert : ${x['quantite']} × ${x['nom']} · table ${x['numeroTable']}',
      TypeValidation.remise =>
        'Remise : ${x['valeur']}${x['typeRemise'] == 'pourcentage' ? ' %' : ' F'} · table ${x['numeroTable']}',
      TypeValidation.ajustement =>
        'Inventaire : ${x['nom']} · théorique ${x['theorique']}, compté ${x['compte']} (écart ${x['ecart']})',
    };
  }
}

// ---------------------------------------------------------------------- Menu

class _Menu extends ConsumerWidget {
  const _Menu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final articles = ref.watch(articlesProvider).value ?? const [];
    final acteur = ref.watch(acteurProvider)!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Article'),
              onPressed: categories.isEmpty ? null : () => _editerArticle(context, ref, categories, null),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Catégorie'),
              onPressed: () async {
                final nom = await demanderTexte(context, 'Nouvelle catégorie', label: 'Nom');
                if (nom == null || !context.mounted) return;
                await essayer(
                  context,
                  () => ref.read(adminServiceProvider).enregistrerCategorie(acteur, nom: nom, ordre: categories.length),
                );
              },
            ),
          ],
        ),
        for (final c in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              children: [
                Text(c.nom, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final nom = await demanderTexte(context, 'Renommer la catégorie', initial: c.nom);
                    if (nom == null || !context.mounted) return;
                    await essayer(
                      context,
                      () => ref
                          .read(adminServiceProvider)
                          .enregistrerCategorie(acteur, id: c.id, nom: nom, ordre: c.ordre),
                    );
                  },
                ),
              ],
            ),
          ),
          for (final a in articles.where((a) => a.idCategorie == c.id))
            ListTile(
              title: Text(a.nom, style: TextStyle(color: a.actif ? null : Colors.grey)),
              subtitle: Text(
                '${switch (a.type) {
                  TypeArticle.revendu => a.consigne ? 'Revendu · consigné' : 'Revendu',
                  TypeArticle.prepare => a.aRecette ? 'Plat · fiche technique' : 'Plat · portions du jour',
                  TypeArticle.ingredient => 'Ingrédient · ${qte(a.stock, a.unite)} en stock',
                }}'
                '${a.actif ? '' : ' · retiré du menu'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (a.type == TypeArticle.prepare)
                    TextButton.icon(
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Fiche technique'),
                      onPressed: () => _editerRecette(context, ref, a, articles),
                    ),
                  if (a.type != TypeArticle.ingredient)
                    Text(fcfa(a.prixVente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              onTap: () => _editerArticle(context, ref, categories, a),
            ),
        ],
      ],
    );
  }

  Future<void> _editerArticle(BuildContext context, WidgetRef ref, List<Categorie> categories, Article? a) async {
    final nom = TextEditingController(text: a?.nom ?? '');
    final prix = TextEditingController(text: a == null ? '' : '${a.prixVente}');
    final seuil = TextEditingController(text: '${a?.seuilAlerte ?? 0}');
    final casier = TextEditingController(text: '${a?.unitesParCasier ?? 0}');
    final stockInit = TextEditingController(text: '0');
    final photo = TextEditingController(text: a?.photoUrl ?? '');
    var cat = a?.idCategorie ?? categories.first.id;
    var type = a?.type ?? TypeArticle.revendu;
    var suivi = a?.suiviStock ?? true;
    var consigne = a?.consigne ?? false;
    final unite = TextEditingController(text: a?.type == TypeArticle.ingredient ? a!.unite : 'kg');
    final decimales = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    var actif = a?.actif ?? true;
    final chiffres = [FilteringTextInputFormatter.digitsOnly];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(a == null ? 'Nouvel article' : 'Modifier ${a.nom}'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: nom,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.nom))],
                  onChanged: (v) => cat = v!,
                ),
                TextField(
                  controller: prix,
                  keyboardType: TextInputType.number,
                  inputFormatters: chiffres,
                  decoration: const InputDecoration(labelText: 'Prix de vente TTC (F)'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TypeArticle>(
                  segments: const [
                    ButtonSegment(value: TypeArticle.revendu, label: Text('Revendu tel quel')),
                    ButtonSegment(value: TypeArticle.prepare, label: Text('Plat préparé')),
                    ButtonSegment(value: TypeArticle.ingredient, label: Text('Ingrédient')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                if (type == TypeArticle.ingredient)
                  TextField(
                    controller: unite,
                    decoration: const InputDecoration(labelText: 'Unité (kg, pièce, litre, portion…)'),
                  ),
                if (type == TypeArticle.prepare && (a?.aRecette ?? false))
                  const ListTile(
                    leading: Icon(Icons.menu_book_rounded),
                    title: Text('Géré par fiche technique'),
                    subtitle: Text('Les portions sont calculées à partir du stock des ingrédients.'),
                  )
                else if (type != TypeArticle.ingredient)
                  SwitchListTile(
                    title: const Text('Suivre le stock'),
                    subtitle: Text(type == TypeArticle.prepare ? 'en portions disponibles' : 'à l’unité'),
                    value: suivi,
                    onChanged: (v) => setState(() => suivi = v),
                  ),
                if (type == TypeArticle.revendu)
                  SwitchListTile(
                    title: const Text('Bouteille consignée'),
                    subtitle: const Text('Suivre les vides à rendre au fournisseur'),
                    value: consigne,
                    onChanged: (v) => setState(() => consigne = v),
                  ),
                if (suivi || type == TypeArticle.ingredient) ...[
                  TextField(
                    controller: seuil,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimales,
                    decoration: const InputDecoration(labelText: 'Seuil d’alerte'),
                  ),
                  if (type == TypeArticle.revendu)
                    TextField(
                      controller: casier,
                      keyboardType: TextInputType.number,
                      inputFormatters: chiffres,
                      decoration: const InputDecoration(labelText: 'Unités par casier (12, 24…)'),
                    ),
                  if (a == null)
                    TextField(
                      controller: stockInit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimales,
                      decoration: const InputDecoration(labelText: 'Stock initial'),
                    ),
                ],
                TextField(
                  controller: photo,
                  decoration: const InputDecoration(labelText: 'Adresse de la photo (facultatif)'),
                ),
                SwitchListTile(
                  title: const Text('Actif (visible au menu)'),
                  value: actif,
                  onChanged: (v) => setState(() => actif = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final nouveau = Article(
      id: a?.id ?? '',
      nom: nom.text.trim(),
      idCategorie: cat,
      prixVente: int.tryParse(prix.text) ?? 0,
      type: type,
      unite: type == TypeArticle.ingredient
          ? (unite.text.trim().isEmpty ? 'unité' : unite.text.trim())
          : (type == TypeArticle.revendu ? 'bouteille' : 'portion'),
      seuilAlerte: lireDecimal(seuil.text) ?? 0,
      disponible: a?.disponible ?? true,
      actif: actif,
      suiviStock: type == TypeArticle.ingredient || suivi,
      consigne: type == TypeArticle.revendu && consigne,
      unitesParCasier: int.tryParse(casier.text) ?? 0,
      ordre: a?.ordre ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      photoUrl: photo.text.trim(),
    );
    await essayer(
      context,
      () => ref
          .read(adminServiceProvider)
          .enregistrerArticle(
            ref.read(acteurProvider)!,
            nouveau,
            ancien: a,
            stockInitial: lireDecimal(stockInit.text) ?? 0,
          ),
      succes: 'Article enregistré',
    );
  }

  /// Fiche technique d'un plat : ingrédients et quantités par portion.
  Future<void> _editerRecette(BuildContext context, WidgetRef ref, Article plat, List<Article> articles) async {
    final existante = ref.read(recettesProvider).value?[plat.id];
    final choix = articles
        .where((a) => a.id != plat.id && (a.type == TypeArticle.ingredient || a.type == TypeArticle.revendu))
        .toList();
    final lignes = <(String?, TextEditingController)>[
      for (final i in existante?.ingredients ?? const <Ingredient>[])
        (i.idArticle, TextEditingController(text: '${i.quantite}'.replaceAll('.', ','))),
    ];
    if (lignes.isEmpty) lignes.add((null, TextEditingController()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Fiche technique : ${plat.nom}'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('Ingrédients pour UNE portion. Chaque vente les retire du stock.'),
                const SizedBox(height: 12),
                for (var i = 0; i < lignes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: lignes[i].$1,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Ingrédient'),
                            items: [
                              for (final a in choix)
                                DropdownMenuItem(value: a.id, child: Text('${a.nom} (${a.unite})')),
                            ],
                            onChanged: (v) => setState(() => lignes[i] = (v, lignes[i].$2)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lignes[i].$2,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantité',
                              suffixText: choix.where((a) => a.id == lignes[i].$1).firstOrNull?.unite,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => lignes.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un ingrédient'),
                    onPressed: () => setState(() => lignes.add((null, TextEditingController()))),
                  ),
                ),
                const Text(
                  'Pour revenir aux « portions du jour » saisies chaque matin, retirez tous les ingrédients.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final ingredients = [
      for (final (id, ctrl) in lignes)
        if (id != null && (lireDecimal(ctrl.text) ?? 0) > 0)
          Ingredient(
            idArticle: id,
            nom: choix.firstWhere((a) => a.id == id).nom,
            quantite: lireDecimal(ctrl.text)!,
            unite: choix.firstWhere((a) => a.id == id).unite,
          ),
    ];
    await essayer(
      context,
      () => ref.read(adminServiceProvider).enregistrerRecette(ref.read(acteurProvider)!, plat, ingredients),
      succes: ingredients.isEmpty ? 'Plat repassé en portions du jour' : 'Fiche technique enregistrée',
    );
  }
}

// -------------------------------------------------------------------- Tables

class _Tables extends ConsumerWidget {
  const _Tables();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider).value ?? const [];
    final tables = ref.watch(tablesProvider).value ?? const [];
    final acteur = ref.watch(acteurProvider)!;
    final svc = ref.read(adminServiceProvider);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Zone'),
              onPressed: () async {
                final nom = await demanderTexte(context, 'Nouvelle zone', label: 'Salle, terrasse, VIP…');
                if (nom == null || !context.mounted) return;
                await essayer(context, () => svc.enregistrerZone(acteur, nom: nom, ordre: zones.length));
              },
            ),
          ],
        ),
        for (final z in zones) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Text(z.nom, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Table'),
                  onPressed: () async {
                    final num = await demanderTexte(context, 'Nouvelle table (${z.nom})', label: 'Numéro ou nom');
                    if (num == null || !context.mounted) return;
                    if (tables.any((t) => t.numero == num)) {
                      afficherMessage(context, 'La table $num existe déjà', erreur: true);
                      return;
                    }
                    await essayer(context, () => svc.enregistrerTable(acteur, numero: num, idZone: z.id));
                  },
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tables.where((t) => t.idZone == z.id))
                InputChip(
                  label: Text('Table ${t.numero}'),
                  selected: t.active,
                  showCheckmark: false,
                  onPressed: () async {
                    if (t.statut != StatutTable.libre) {
                      afficherMessage(context, 'Table occupée', erreur: true);
                      return;
                    }
                    final ok = await confirmer(
                      context,
                      'Table ${t.numero}',
                      t.active ? 'Désactiver cette table ?' : 'Réactiver cette table ?',
                    );
                    if (!ok || !context.mounted) return;
                    await essayer(
                      context,
                      () =>
                          svc.enregistrerTable(acteur, id: t.id, numero: t.numero, idZone: t.idZone, active: !t.active),
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ Employés

class _Employes extends ConsumerWidget {
  const _Employes();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employes = ref.watch(employesProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Nouvel employé'),
          onPressed: () => _editer(context, ref, null),
        ),
        const SizedBox(height: 8),
        for (final e in employes)
          ListTile(
            leading: CircleAvatar(child: Text(e.nom.characters.first)),
            title: Text(e.nom, style: TextStyle(color: e.actif ? null : Colors.grey)),
            subtitle: Text('${e.role.libelle}${e.actif ? '' : ' · désactivé'}'),
            onTap: () => _editer(context, ref, e),
          ),
      ],
    );
  }

  Future<void> _editer(BuildContext context, WidgetRef ref, Employe? e) async {
    final nom = TextEditingController(text: e?.nom ?? '');
    final pin = TextEditingController();
    var role = e?.role ?? Role.serveuse;
    var actif = e?.actif ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(e == null ? 'Nouvel employé' : e.nom),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nom,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              DropdownButtonFormField<Role>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.libelle))],
                onChanged: (v) => role = v!,
              ),
              TextField(
                controller: pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: e == null ? 'Code PIN (4 chiffres)' : 'Nouveau code PIN (laisser vide pour garder)',
                ),
              ),
              if (e != null)
                SwitchListTile(
                  title: const Text('Actif'),
                  subtitle: const Text('Désactivé : ne peut plus se connecter, son historique reste'),
                  value: actif,
                  onChanged: (v) => setState(() => actif = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await essayer(
      context,
      () => ref
          .read(adminServiceProvider)
          .enregistrerEmploye(
            ref.read(acteurProvider)!,
            id: e?.id,
            nom: nom.text,
            role: role,
            nouveauPin: pin.text.isEmpty ? null : pin.text,
            actif: actif,
          ),
      succes: 'Employé enregistré',
    );
  }
}

// ---------------------------------------------------------------- Paramètres

class _Parametres extends ConsumerStatefulWidget {
  const _Parametres();
  @override
  ConsumerState<_Parametres> createState() => _ParametresState();
}

class _ParametresState extends ConsumerState<_Parametres> {
  Restaurant? _r;
  final _c = <String, TextEditingController>{};
  bool _tva = false;

  TextEditingController _ctrl(String k, String v) => _c.putIfAbsent(k, () => TextEditingController(text: v));

  @override
  Widget build(BuildContext context) {
    final r = _r ??= ref.watch(restaurantProvider).value;
    if (r == null) return const Chargement();
    if (_c.isEmpty) _tva = r.soumisTva;
    Widget champ(String k, String label, String v, {bool nombre = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrl(k, v),
        keyboardType: nombre ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        champ('nom', 'Nom du restaurant', r.nom),
        champ('adresse', 'Adresse', r.adresse),
        champ('telephone', 'Téléphone', r.telephone),
        champ('logo', 'Adresse du logo (image)', r.logoUrl),
        champ('mentions', 'Mentions sur la facture (RCCM, NCC…)', r.mentionsFacture),
        champ('message', 'Message de bas de ticket', r.messageBasTicket),
        champ('deconnexion', 'Déconnexion automatique (minutes)', '${r.deconnexionMinutes}', nombre: true),
        SwitchListTile(
          title: const Text('Soumis à la TVA'),
          subtitle: const Text('Les prix du menu sont saisis TTC'),
          value: _tva,
          onChanged: (v) => setState(() => _tva = v),
        ),
        if (_tva) champ('tva', 'Taux de TVA (%)', '${r.tauxTva}', nombre: true),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => essayer(
            context,
            () => ref
                .read(adminServiceProvider)
                .enregistrerParametres(
                  ref.read(acteurProvider)!,
                  Restaurant(
                    id: r.id,
                    nom: _c['nom']!.text.trim(),
                    adresse: _c['adresse']!.text.trim(),
                    telephone: _c['telephone']!.text.trim(),
                    logoUrl: _c['logo']!.text.trim(),
                    mentionsFacture: _c['mentions']!.text.trim(),
                    messageBasTicket: _c['message']!.text.trim(),
                    deconnexionMinutes: int.tryParse(_c['deconnexion']!.text) ?? 5,
                    soumisTva: _tva,
                    tauxTva: double.tryParse(_c['tva']?.text.replaceAll(',', '.') ?? '') ?? r.tauxTva,
                  ),
                ),
            succes: 'Paramètres enregistrés',
          ),
          child: const Text('Enregistrer'),
        ),
        const SizedBox(height: 24),
        Text('Dépenses', style: Theme.of(context).textTheme.titleMedium),
        const Text('Gaz, électricité, salaires, transport : pour calculer le bénéfice réel.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Saisir une dépense'),
          onPressed: () async {
            final cat = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Catégorie'),
                children: [
                  for (final c in ['Gaz', 'Électricité', 'Eau', 'Salaires', 'Transport', 'Autre'])
                    SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c)),
                ],
              ),
            );
            if (cat == null || !context.mounted) return;
            final m = await demanderNombre(context, 'Dépense : $cat', label: 'Montant (F)');
            if (m == null || !context.mounted) return;
            await essayer(
              context,
              () => ref.read(adminServiceProvider).saisirDepense(ref.read(acteurProvider)!, categorie: cat, montant: m),
              succes: 'Dépense enregistrée',
            );
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- Journal d'audit

class _Audit extends ConsumerStatefulWidget {
  const _Audit();
  @override
  ConsumerState<_Audit> createState() => _AuditState();
}

class _AuditState extends ConsumerState<_Audit> {
  String? _employe;
  String? _action;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditProvider);
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final employes = liste.map((e) => e.employe).toSet().toList()..sort();
        final actions = liste.map((e) => e.action).toSet().toList()..sort();
        final f = liste
            .where((e) => (_employe == null || e.employe == _employe) && (_action == null || e.action == _action))
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 16,
                children: [
                  DropdownButton<String?>(
                    value: _employe,
                    hint: const Text('Tous les employés'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les employés')),
                      for (final e in employes) DropdownMenuItem(value: e, child: Text(e)),
                    ],
                    onChanged: (v) => setState(() => _employe = v),
                  ),
                  DropdownButton<String?>(
                    value: _action,
                    hint: const Text('Toutes les actions'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les actions')),
                      for (final a in actions) DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) => setState(() => _action = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: f.isEmpty
                  ? const Center(child: Text('Aucune action enregistrée'))
                  : ListView.builder(
                      itemCount: f.length,
                      itemBuilder: (context, i) {
                        final e = f[i];
                        return ListTile(
                          dense: true,
                          title: Text('${e.action} · ${e.detail}'),
                          subtitle: Text('${dateHeure(e.date)} · ${e.employe} · ${e.appareil}'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
