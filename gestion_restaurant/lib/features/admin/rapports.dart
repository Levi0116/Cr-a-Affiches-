import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/rapports.dart';
import '../../models/modeles.dart';
import '../../services/export_rapport.dart';
import '../../services/impression/impression.dart';
import '../../services/impression/telechargement.dart';
import '../../state/providers.dart';
import '../../theme/animations.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';

typedef CleRapport = ({TypePeriode type, DateTime debut});

/// Rapport de la période et de la période précédente (pour la comparaison).
final rapportProvider = FutureProvider.autoDispose.family<(Rapport, Rapport), CleRapport>((ref, cle) async {
  final db = ref.watch(dbProvider);
  final p = Periode.contenant(cle.type, cle.debut);
  final prec = p.precedente;
  final debut = Timestamp.fromDate(prec.debut);
  final fin = Timestamp.fromDate(p.fin);
  final articles = ref.watch(articlesProvider).value ?? const <Article>[];
  final recettes = ref.watch(recettesProvider).value ?? const <String, Recette>{};
  final categories = {for (final c in ref.watch(categoriesProvider).value ?? const <Categorie>[]) c.id: c.nom};

  final factures = (await db.factures.where('date', isGreaterThanOrEqualTo: debut).where('date', isLessThan: fin).get())
      .docs
      .map(Facture.fromDoc)
      .toList();
  DateTime date(Map<String, dynamic> m, String champ) => (m[champ] as Timestamp?)?.toDate() ?? DateTime(2000);
  final depenses = [
    for (final d in (await db.depenses.where('date', isGreaterThanOrEqualTo: debut).get()).docs)
      (
        categorie: d.data()['categorie'] as String? ?? 'Autre',
        montant: (d.data()['montant'] as num?)?.toInt() ?? 0,
        date: date(d.data(), 'date'),
      ),
  ];
  final avoirs = [
    for (final d in (await db.avoirs.where('heureAppareil', isGreaterThanOrEqualTo: debut).get()).docs)
      (montant: (d.data()['montant'] as num?)?.toInt() ?? 0, date: date(d.data(), 'heureAppareil')),
  ];
  final annulations = [
    for (final d in (await db.demandesValidation.where('statut', isEqualTo: StatutValidation.validee.name).get()).docs)
      if (d.data()['type'] == TypeValidation.annulation.name)
        (demandeur: d.data()['demandeur'] as String? ?? '', date: date(d.data(), 'heureAppareil')),
  ];
  Rapport calc(Periode per) => calculerRapport(
    periode: per,
    factures: factures,
    articles: articles,
    recettes: recettes,
    depenses: depenses,
    avoirs: avoirs,
    annulations: annulations,
    nomsCategories: categories,
  );
  return (calc(p), calc(prec));
});

class EcranRapports extends ConsumerStatefulWidget {
  const EcranRapports({super.key});
  @override
  ConsumerState<EcranRapports> createState() => _EcranRapportsState();
}

class _EcranRapportsState extends ConsumerState<EcranRapports> {
  TypePeriode _type = TypePeriode.jour;
  DateTime _date = DateTime.now();

  Periode get _periode => Periode.contenant(_type, _date);

  @override
  Widget build(BuildContext context) {
    final cle = (type: _type, debut: _periode.debut);
    final async = ref.watch(rapportProvider(cle));
    final resto = ref.watch(restaurantProvider).value;
    final futur =
        !_periode.suivante.debut.isBefore(DateTime.now().add(const Duration(days: 1))) &&
        _periode.contient(DateTime.now());
    return Column(
      children: [
        // Filtres : une seule rangée au-dessus des graphiques.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<TypePeriode>(
                segments: const [
                  ButtonSegment(value: TypePeriode.jour, label: Text('Jour')),
                  ButtonSegment(value: TypePeriode.semaine, label: Text('Semaine')),
                  ButtonSegment(value: TypePeriode.mois, label: Text('Mois')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Période précédente',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _date = _periode.precedente.debut),
                  ),
                  Text(libellePeriode(_periode), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(
                    tooltip: 'Période suivante',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: futur ? null : () => setState(() => _date = _periode.suivante.debut),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(rapportProvider(cle)),
              ),
              if (async.hasValue && resto != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text('Excel'),
                  onPressed: () async {
                    final (r, p) = async.value!;
                    final ok = await telecharger(
                      '${nomFichier(r.periode)}.xlsx',
                      rapportExcel(resto, r, p),
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );
                    if (!ok && context.mounted) afficherMessage(context, 'Export disponible sur l’ordinateur (web)');
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                  onPressed: () async {
                    final (r, p) = async.value!;
                    final ok = await imprimerHtml(rapportHtml(resto, r, p));
                    if (!ok && context.mounted) afficherMessage(context, 'Export disponible sur l’ordinateur (web)');
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Chargement(),
            error: (e, _) => Chargement(erreur: e),
            data: (d) => _Contenu(rapport: d.$1, precedent: d.$2),
          ),
        ),
      ],
    );
  }
}

class _Contenu extends StatelessWidget {
  final Rapport rapport;
  final Rapport precedent;
  const _Contenu({required this.rapport, required this.precedent});

  @override
  Widget build(BuildContext context) {
    final r = rapport, p = precedent;
    final nomPrec = switch (r.periode.type) {
      TypePeriode.jour => 'la veille',
      TypePeriode.semaine => 'la semaine précédente',
      TypePeriode.mois => 'le mois précédent',
    };
    var i = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Chiffre d’affaires', r.chiffreAffaires, p.chiffreAffaires, nomPrec, index: i++),
            _Kpi('Factures', r.nbFactures, p.nbFactures, nomPrec, index: i++, monnaie: false),
            _Kpi('Panier moyen', r.panierMoyen, p.panierMoyen, nomPrec, index: i++),
            _Kpi('Marge brute', r.margeBrute, p.margeBrute, nomPrec, index: i++),
            _Kpi('Dépenses', r.depenses, p.depenses, nomPrec, index: i++, hausseFavorable: false),
            _Kpi('Bénéfice estimé', r.beneficeEstime, p.beneficeEstime, nomPrec, index: i++, mis: true),
          ],
        ),
        const SizedBox(height: 20),
        _Carte(
          titre: 'Ventes par heure',
          sousTitre: 'Pour repérer les heures de pointe',
          child: _GraphiqueHeures(r.ventesParHeure),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final articles = _Carte(
              titre: 'Meilleures ventes',
              sousTitre: 'Montant vendu et marge par article',
              child: _BarresHorizontales([
                for (final v in r.articles.take(10))
                  (v.nom, v.montant, '${v.quantite} vendu(s) · marge ${(v.tauxMarge * 100).round()} %'),
              ]),
            );
            final categories = _Carte(
              titre: 'Par catégorie',
              child: _BarresHorizontales([for (final e in r.ventesParCategorie.entries) (e.key, e.value, null)]),
            );
            if (c.maxWidth < 900) return Column(children: [articles, categories]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: articles),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: categories),
              ],
            );
          },
        ),
        _Carte(titre: 'Du chiffre d’affaires au bénéfice', child: _Cascade(r)),
        _Carte(
          titre: 'Performance par serveuse',
          child: r.serveuses.isEmpty
              ? const _Vide()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Serveuse')),
                      DataColumn(label: Text('Tables servies'), numeric: true),
                      DataColumn(label: Text('Montant vendu'), numeric: true),
                      DataColumn(label: Text('Annulations'), numeric: true),
                    ],
                    rows: [
                      for (final s in r.serveuses)
                        DataRow(
                          cells: [
                            DataCell(Text(s.nom)),
                            DataCell(Text('${s.tables.length}')),
                            DataCell(Text(fcfa(s.montant))),
                            DataCell(Text('${s.annulations}')),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        _Carte(
          titre: 'Tableau complet des articles',
          child: r.articles.isEmpty
              ? const _Vide()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Article')),
                      DataColumn(label: Text('Qté'), numeric: true),
                      DataColumn(label: Text('Ventes'), numeric: true),
                      DataColumn(label: Text('Coût'), numeric: true),
                      DataColumn(label: Text('Marge'), numeric: true),
                    ],
                    rows: [
                      for (final v in r.articles)
                        DataRow(
                          cells: [
                            DataCell(Text(v.nom)),
                            DataCell(Text('${v.quantite}')),
                            DataCell(Text(fcfa(v.montant))),
                            DataCell(Text(fcfa(v.cout))),
                            DataCell(Text('${fcfa(v.marge)} · ${(v.tauxMarge * 100).round()} %')),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        if (r.nonVendus.isNotEmpty)
          _Carte(
            titre: 'Articles qui ne se sont pas vendus',
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final a in r.nonVendus) Chip(label: Text(a.nom))]),
          ),
      ],
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text('Aucune vente sur la période', style: TextStyle(color: identite.texte.withValues(alpha: 0.6))),
  );
}

class _Carte extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final Widget child;
  const _Carte({required this.titre, this.sousTitre, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: Theme.of(context).textTheme.titleLarge),
          if (sousTitre != null) Text(sousTitre!, style: TextStyle(color: identite.texte.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Tuile d'indicateur avec comparaison à la période précédente.
/// L'évolution porte une flèche ET un signe : jamais la couleur seule.
class _Kpi extends StatelessWidget {
  final String titre;
  final int valeur;
  final int precedent;
  final String nomPrec;
  final int index;
  final bool monnaie;
  final bool hausseFavorable;
  final bool mis;
  const _Kpi(
    this.titre,
    this.valeur,
    this.precedent,
    this.nomPrec, {
    required this.index,
    this.monnaie = true,
    this.hausseFavorable = true,
    this.mis = false,
  });

  @override
  Widget build(BuildContext context) {
    final e = evolution(valeur, precedent);
    final favorable = e == null || e == 0 ? null : (e > 0) == hausseFavorable;
    final couleurEvo = favorable == null
        ? identite.texte.withValues(alpha: 0.55)
        : (favorable ? identite.tableLibre : identite.erreur);
    final style = TextStyle(
      fontFamily: identite.policeTitres,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: mis ? Colors.white : identite.texte,
    );
    return Apparition(
      index: index,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: mis ? identite.nuit : identite.surface,
          borderRadius: BorderRadius.circular(identite.arrondi),
          border: Border.all(color: mis ? identite.accent : identite.texte.withValues(alpha: 0.08), width: mis ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: TextStyle(color: mis ? identite.accent : identite.texte.withValues(alpha: 0.65))),
            const SizedBox(height: 4),
            monnaie ? MontantAnime(valeur, style: style) : Text('$valeur', style: style),
            const SizedBox(height: 4),
            Row(
              children: [
                if (e != null && e != 0)
                  Icon(e > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: couleurEvo),
                Flexible(
                  child: Text(
                    e == null ? 'pas de comparaison' : '${e >= 0 ? '+' : ''}${e.toStringAsFixed(0)} % vs $nomPrec',
                    style: TextStyle(
                      color: mis && favorable == null ? Colors.white70 : couleurEvo,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barres verticales des ventes par heure : une seule série, une seule
/// couleur ; info-bulle au survol ou au toucher de chaque colonne.
class _GraphiqueHeures extends StatelessWidget {
  final List<int> heures;
  const _GraphiqueHeures(this.heures);

  @override
  Widget build(BuildContext context) {
    final actives = [
      for (var h = 0; h < 24; h++)
        if (heures[h] > 0) h,
    ];
    if (actives.isEmpty) return const _Vide();
    // Fenêtre d'au moins 12 heures autour des ventes, pour garder des
    // barres fines même quand tout s'est vendu en une heure.
    var debut = (actives.first - 1).clamp(0, 23);
    var fin = (actives.last + 1).clamp(0, 23);
    while (fin - debut < 11) {
      if (fin < 23) fin++;
      if (fin - debut < 11 && debut > 0) debut--;
    }
    final max = heures.reduce((a, b) => a > b ? a : b);
    final pointe = heures.indexOf(max);
    final graduations = [max, max ~/ 2];
    const hauteur = 200.0;
    final texteDiscret = TextStyle(fontSize: 11, color: identite.texte.withValues(alpha: 0.55));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heure de pointe : ${pointe}h – ${pointe + 1}h (${fcfa(max)})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: hauteur + 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Axe vertical discret.
              SizedBox(
                width: 64,
                height: hauteur,
                child: Stack(
                  children: [
                    for (final g in graduations)
                      Positioned(
                        top: (hauteur * (1 - g / max) - 7).clamp(0, hauteur),
                        right: 6,
                        child: Text(fcfa(g), style: texteDiscret),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    for (final g in [...graduations, 0])
                      Positioned(
                        top: hauteur * (1 - g / max),
                        left: 0,
                        right: 0,
                        child: Container(height: 1, color: identite.texte.withValues(alpha: g == 0 ? 0.25 : 0.07)),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var h = debut; h <= fin; h++)
                          Expanded(
                            child: Tooltip(
                              message: '${h}h – ${h + 1}h : ${fcfa(heures[h])}',
                              waitDuration: Duration.zero,
                              triggerMode: TooltipTriggerMode.tap,
                              child: Padding(
                                // 2 px d'espace entre barres voisines.
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: hauteur,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: heures[h] / max),
                                          duration: duree(context, 700 + (h - debut) * 30),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, v, _) => FractionallySizedBox(
                                            heightFactor: v,
                                            widthFactor: 0.72,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: identite.principale,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text((h - debut).isEven ? '${h}h' : '', style: texteDiscret),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barres horizontales (une seule série) avec étiquettes directes.
class _BarresHorizontales extends StatelessWidget {
  final List<(String, int, String?)> lignes;
  const _BarresHorizontales(this.lignes);

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) return const _Vide();
    final max = lignes.map((l) => l.$2).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final (i, (nom, montant, detail)) in lignes.indexed)
          Tooltip(
            message: '$nom : ${fcfa(montant)}${detail == null ? '' : ' · $detail'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nom,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(fcfa(montant), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, c) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: max == 0 ? 0 : montant / max),
                      duration: duree(context, 650 + i * 50),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: identite.texte.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 10,
                            width: c.maxWidth * v,
                            decoration: BoxDecoration(
                              color: identite.principale,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(detail, style: TextStyle(fontSize: 12, color: identite.texte.withValues(alpha: 0.6))),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Du chiffre d'affaires au bénéfice, ligne par ligne.
class _Cascade extends StatelessWidget {
  final Rapport r;
  const _Cascade(this.r);
  @override
  Widget build(BuildContext context) {
    Widget ligne(String lib, int montant, {bool total = false, bool moins = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: total
          ? BoxDecoration(
              border: Border(top: BorderSide(color: identite.texte.withValues(alpha: 0.2))),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              lib,
              style: TextStyle(fontWeight: total ? FontWeight.w800 : FontWeight.w500, fontSize: total ? 17 : 15),
            ),
          ),
          Text(
            '${moins ? '− ' : ''}${fcfa(montant)}',
            style: TextStyle(
              fontFamily: total ? identite.policeTitres : null,
              fontWeight: total ? FontWeight.w800 : FontWeight.w600,
              fontSize: total ? 20 : 15,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        ligne('Chiffre d’affaires (dont ${fcfa(r.aCredit)} à crédit)', r.chiffreAffaires),
        if (r.avoirs > 0) ligne('Avoirs', r.avoirs, moins: true),
        ligne('Coût des marchandises vendues', r.coutMarchandises, moins: true),
        ligne('Marge brute', r.margeBrute, total: true),
        for (final e in r.depensesParCategorie.entries) ligne('Dépense : ${e.key}', e.value, moins: true),
        ligne('Bénéfice estimé', r.beneficeEstime, total: true),
        const SizedBox(height: 6),
        Text(
          'Coûts calculés au coût moyen d’achat actuel (fiches techniques pour les plats).',
          style: TextStyle(fontSize: 12, color: identite.texte.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}
