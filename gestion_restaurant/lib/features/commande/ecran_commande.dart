import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/stock_calc.dart';
import '../../models/modeles.dart';
import '../../services/commande_service.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animations.dart';
import '../../theme/categories.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';

/// Prise de commande (section 3.1) : catégories, grille d'articles, panier
/// local modifiable librement avant validation, tours horodatés.
class EcranCommande extends ConsumerStatefulWidget {
  final TableResto? table; // null = vente « à emporter »
  final String? idSession;
  final int couverts;
  const EcranCommande({super.key, this.table, this.idSession, this.couverts = 0});

  @override
  ConsumerState<EcranCommande> createState() => _EcranCommandeState();
}

class _EcranCommandeState extends ConsumerState<EcranCommande> {
  static const _favoris = '__favoris__';
  String? _idSession;
  String _categorie = _favoris;
  final List<ElementPanier> _panier = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _idSession = widget.idSession;
  }

  int get _totalPanier => _panier.fold(0, (s, e) => s + e.montant);

  void _ajouter(Article a) {
    if (!a.estVendable(ref.read(portionsProvider))) return;
    setState(() {
      final existant = _panier.where((e) => e.article.id == a.id && e.note.isEmpty);
      if (existant.isNotEmpty) {
        existant.first.quantite++;
      } else {
        _panier.add(ElementPanier(a));
      }
    });
  }

  Future<void> _valider(SessionTable? session) async {
    if (_panier.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    final acteur = ref.read(acteurProvider)!;
    final id = await essayer(context, () async {
      String? libelle;
      if (widget.table == null && session == null) {
        libelle = 'À emporter ${heure(DateTime.now())}';
      }
      return ref
          .read(commandeServiceProvider)
          .validerTour(
            serveuse: acteur,
            panier: List.of(_panier),
            table: widget.table,
            session: session,
            couverts: widget.couverts,
            libelleAEmporter: libelle,
          );
    });
    if (!mounted) return;
    if (id != null) celebrer(context, 'Envoyé en caisse');
    setState(() {
      _envoi = false;
      if (id != null) {
        _idSession = id;
        _panier.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const [];
    final session = sessions.where((s) => s.id == _idSession).firstOrNull;
    final articles = ref.watch(articlesProvider).value ?? const [];
    // Seules les catégories qui ont des articles au menu (pas « Ingrédients »).
    final categories = (ref.watch(categoriesProvider).value ?? const <Categorie>[])
        .where((c) => articles.any((a) => a.auMenu && a.idCategorie == c.id))
        .toList();
    final titre = widget.table != null
        ? 'Table ${session?.numeroTable ?? widget.table!.numero}'
        : (session?.numeroTable ?? 'À emporter');
    final large = MediaQuery.sizeOf(context).width >= 760;

    final grille = _GrilleArticles(
      articles: articles,
      categories: categories,
      categorie: _categorie,
      onCategorie: (c) => setState(() => _categorie = c),
      onArticle: _ajouter,
      favoris: _favoris,
      portions: ref.watch(portionsProvider),
      quantites: {
        for (final e in _panier)
          e.article.id: _panier.where((x) => x.article.id == e.article.id).fold(0, (n, x) => n + x.quantite),
      },
    );
    final panneau = _PanneauAddition(
      session: session,
      panier: _panier,
      totalPanier: _totalPanier,
      envoi: _envoi,
      onChange: () => setState(() {}),
      onValider: () => _valider(session),
    );

    return Scaffold(
      appBar: barreBraise(title: Text(titre), actions: actionsBarre(context, ref)),
      body: large
          ? Row(
              children: [
                Expanded(flex: 3, child: grille),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: panneau),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: grille),
                const Divider(height: 1),
                Expanded(flex: 2, child: panneau),
              ],
            ),
    );
  }
}

class _GrilleArticles extends StatelessWidget {
  final List<Article> articles;
  final List<Categorie> categories;
  final String categorie;
  final String favoris;
  final Map<String, int> quantites;
  final Map<String, int> portions;
  final ValueChanged<String> onCategorie;
  final ValueChanged<Article> onArticle;
  const _GrilleArticles({
    required this.articles,
    required this.categories,
    required this.categorie,
    required this.favoris,
    required this.quantites,
    required this.portions,
    required this.onCategorie,
    required this.onArticle,
  });

  @override
  Widget build(BuildContext context) {
    final actifs = articles.where((a) => a.auMenu).toList();
    final indexCat = {for (var i = 0; i < categories.length; i++) categories[i].id: i};
    final List<Article> affiches;
    if (categorie == favoris) {
      // Articles favoris : les plus vendus en premier.
      affiches = ([...actifs]..sort((a, b) => b.nbVentes.compareTo(a.nbVentes))).take(24).toList();
    } else {
      affiches = actifs.where((a) => a.idCategorie == categorie).toList();
    }
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              _onglet(context, '★ Favoris', favoris, Icons.star_rounded, identite.accent),
              for (var i = 0; i < categories.length; i++)
                _onglet(
                  context,
                  categories[i].nom,
                  categories[i].id,
                  iconeCategorie(categories[i].nom),
                  couleurCategorie(i),
                ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: duree(context, 250),
            child: GridView.builder(
              key: ValueKey(categorie),
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 175,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: affiches.length,
              itemBuilder: (context, i) {
                final a = affiches[i];
                return Apparition(
                  index: i,
                  distance: 14,
                  child: _BoutonArticle(
                    article: a,
                    couleur: couleurCategorie(indexCat[a.idCategorie] ?? 0),
                    icone: iconeCategorie(categories.where((c) => c.id == a.idCategorie).firstOrNull?.nom ?? ''),
                    quantite: quantites[a.id] ?? 0,
                    portions: portions,
                    onTap: onArticle,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _onglet(BuildContext context, String nom, String id, IconData icone, Color couleur) {
    final actif = categorie == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: actif,
        label: nom,
        excludeSemantics: true,
        child: Pression(
          onTap: () => onCategorie(id),
          child: AnimatedContainer(
            duration: duree(context, 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: actif ? couleur : identite.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: actif ? couleur : identite.texte.withValues(alpha: 0.12)),
              boxShadow: actif
                  ? [BoxShadow(color: couleur.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 19, color: actif ? Colors.white : couleur),
                const SizedBox(width: 6),
                Text(
                  nom.replaceFirst('★ ', ''),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: actif ? Colors.white : identite.texte,
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

class _BoutonArticle extends StatelessWidget {
  final Article article;
  final Color couleur;
  final IconData icone;
  final int quantite;
  final Map<String, int> portions;
  final ValueChanged<Article> onTap;
  const _BoutonArticle({
    required this.portions,
    required this.article,
    required this.couleur,
    required this.icone,
    required this.quantite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = article;
    final ok = a.estVendable(portions);
    final reste = a.reste(portions);
    final faible = ok && reste != null && reste <= (a.aRecette ? 3 : a.seuilAlerte);
    final rayon = BorderRadius.circular(identite.arrondi);
    return Semantics(
      button: true,
      enabled: ok,
      label: '${a.nom} ${fcfa(a.prixVente)}${ok ? '' : ' Indisponible'}',
      excludeSemantics: true,
      child: Pression(
        onTap: ok ? () => onTap(a) : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: duree(context, 250),
              decoration: BoxDecoration(
                color: ok ? identite.surface : identite.texte.withValues(alpha: 0.06),
                borderRadius: rayon,
                border: Border.all(
                  color: quantite > 0 ? couleur : identite.texte.withValues(alpha: 0.08),
                  width: quantite > 0 ? 2.5 : 1,
                ),
                boxShadow: ok
                    ? [
                        BoxShadow(
                          color: identite.nuit.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: rayon,
                child: Column(
                  children: [
                    Container(height: 6, color: ok ? couleur : identite.texte.withValues(alpha: 0.15)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icone, size: 20, color: ok ? couleur : identite.texte.withValues(alpha: 0.3)),
                            const Spacer(),
                            Text(
                              a.nom,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: ok ? identite.texte : identite.texte.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  fcfa(a.prixVente),
                                  style: TextStyle(
                                    fontFamily: identite.policeTitres,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ok ? identite.principale : identite.texte.withValues(alpha: 0.4),
                                  ),
                                ),
                                const Spacer(),
                                if (!ok)
                                  Text(
                                    'Indisponible',
                                    style: TextStyle(color: identite.erreur, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                if (faible)
                                  Text(
                                    'reste ${qte(reste)}',
                                    style: TextStyle(color: couleurOccupee, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(right: -6, top: -8, child: BulleQuantite(quantite)),
          ],
        ),
      ),
    );
  }
}

class _PanneauAddition extends ConsumerWidget {
  final SessionTable? session;
  final List<ElementPanier> panier;
  final int totalPanier;
  final bool envoi;
  final VoidCallback onChange;
  final VoidCallback onValider;
  const _PanneauAddition({
    required this.session,
    required this.panier,
    required this.totalPanier,
    required this.envoi,
    required this.onChange,
    required this.onValider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final lignes = s == null ? const <LigneCommande>[] : (ref.watch(lignesProvider(s.id)).value ?? const []);
    final ouverte = s == null || s.statut == StatutSession.ouverte;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              AnimatedSize(
                duration: duree(context, 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: panier.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Color.alphaBlend(identite.accent.withValues(alpha: 0.12), identite.surface),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(identite.arrondi),
                            side: BorderSide(color: identite.accent.withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, color: identite.principale),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Nouveau tour (pas encore envoyé)',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ],
                                ),
                                for (final e in panier)
                                  _LignePanier(key: ObjectKey(e), element: e, panier: panier, onChange: onChange),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              if (s != null) ...[
                Row(
                  children: [
                    Text(
                      'Addition · ${s.nbTours} tour${s.nbTours > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    if (!ouverte) Pastille('Addition demandée', couleurAddition),
                  ],
                ),
                for (final l in lignes) _LigneValidee(ligne: l, session: s),
              ],
              if (s == null && panier.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Touchez un article pour l’ajouter', textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: identite.surface,
            border: Border(top: BorderSide(color: identite.texte.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              if (s != null)
                Row(
                  children: [
                    const Text('Total table', style: TextStyle(fontSize: 18)),
                    const Spacer(),
                    MontantAnime(
                      s.total,
                      style: TextStyle(
                        fontFamily: identite.policeTitres,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: identite.principale,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (s != null && ouverte)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: panier.isNotEmpty
                            ? null
                            : () async {
                                final ok = await confirmer(
                                  context,
                                  'Demander l’addition',
                                  'La table passera en bleu et la caisse sera prévenue.',
                                );
                                if (!ok || !context.mounted) return;
                                await essayer(
                                  context,
                                  () =>
                                      ref.read(commandeServiceProvider).demanderAddition(ref.read(acteurProvider)!, s),
                                  succes: 'Addition demandée',
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                        child: const Text('Demander l’addition'),
                      ),
                    ),
                  if (s != null && ouverte) const SizedBox(width: 8),
                  if (ouverte)
                    Expanded(
                      child: FilledButton(
                        onPressed: panier.isEmpty || envoi ? null : onValider,
                        child: Text(panier.isEmpty ? 'Valider' : 'Valider · ${fcfa(totalPanier)}'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LignePanier extends StatelessWidget {
  final ElementPanier element;
  final List<ElementPanier> panier;
  final VoidCallback onChange;
  const _LignePanier({super.key, required this.element, required this.panier, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final e = element;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(e.article.nom),
      subtitle: Text(e.note.isEmpty ? fcfa(e.montant) : '« ${e.note} » · ${fcfa(e.montant)}'),
      onTap: () async {
        final note = await demanderTexte(
          context,
          'Note pour ${e.article.nom}',
          label: 'ex. bien glacée, sans piment',
          initial: e.note,
          obligatoire: false,
        );
        if (note != null) {
          e.note = note;
          onChange();
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.remove),
            onPressed: () {
              e.quantite--;
              if (e.quantite <= 0) panier.remove(e);
              onChange();
            },
          ),
          SizedBox(
            width: 34,
            child: ChiffreDefilant(
              e.quantite,
              style: TextStyle(fontFamily: identite.policeTitres, fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.add),
            onPressed: () {
              e.quantite++;
              onChange();
            },
          ),
        ],
      ),
    );
  }
}

class _LigneValidee extends ConsumerWidget {
  final LigneCommande ligne;
  final SessionTable session;
  const _LigneValidee({required this.ligne, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ligne;
    final style = l.annulee ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: identite.nuit,
        foregroundColor: identite.accent,
        child: Text('${l.tour}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
      title: Text('${l.quantite} × ${l.nom}${l.offert ? ' (offert)' : ''}', style: style),
      subtitle: Text(
        [
          heure(l.heure),
          if (l.note.isNotEmpty) '« ${l.note} »',
          if (l.annulee) 'annulé : ${l.motifAnnulation ?? ''} (validé par ${l.validePar ?? ''})',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fcfa(l.montant), style: style),
          if (!l.annulee && l.idFacture == null)
            IconButton(
              tooltip: 'Demander l’annulation',
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () async {
                final motif = await demanderTexte(
                  context,
                  'Annuler ${l.quantite} × ${l.nom} ?',
                  label: 'Motif (obligatoire)',
                );
                if (motif == null || !context.mounted) return;
                await essayer(
                  context,
                  () => ref
                      .read(commandeServiceProvider)
                      .demanderAnnulation(ref.read(acteurProvider)!, session, l, motif),
                  succes: 'Demande envoyée à l’administrateur',
                );
              },
            ),
        ],
      ),
    );
  }
}
