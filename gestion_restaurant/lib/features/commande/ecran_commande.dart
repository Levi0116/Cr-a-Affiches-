import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/stock_calc.dart';
import '../../models/modeles.dart';
import '../../services/commande_service.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/categories.dart';
import '../../theme/identite.dart';
import '../../widgets/animated_table_card.dart';
import '../../widgets/barre_etat.dart';
import '../../widgets/commun.dart';

/// ============================================================================
///  PRISE DE COMMANDE (section 3.1) — ambiance sombre
/// ============================================================================
///
/// En-tête = la carte de la table, agrandie (Hero). Catégories en onglets,
/// grille d'articles (1 touche = 1 unité), ticket à droite (ou en bas sur
/// téléphone) qui défile tout seul jusqu'au dernier ajout. Trois touches
/// maximum pour ajouter un article : catégorie → article → valider.
class EcranCommande extends StatelessWidget {
  final TableResto? table; // null = vente « à emporter »
  final String? idSession;
  final int couverts;
  const EcranCommande({super.key, this.table, this.idSession, this.couverts = 0});

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.sombre,
    child: _Commande(table: table, idSession: idSession, couverts: couverts),
  );
}

class _Commande extends ConsumerStatefulWidget {
  final TableResto? table;
  final String? idSession;
  final int couverts;
  const _Commande({required this.table, required this.idSession, required this.couverts});

  @override
  ConsumerState<_Commande> createState() => _CommandeState();
}

class _CommandeState extends ConsumerState<_Commande> {
  static const _favoris = '__favoris__';
  final _defilementTicket = ScrollController();
  String? _idSession;
  String _categorie = _favoris;
  final List<ElementPanier> _panier = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _idSession = widget.idSession;
  }

  @override
  void dispose() {
    _defilementTicket.dispose();
    super.dispose();
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
    _defilerEnBas();
  }

  /// Fait glisser doucement le ticket jusqu'au dernier article ajouté.
  void _defilerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilementTicket.hasClients) return;
      final d = duree(context, 380);
      final cible = _defilementTicket.position.maxScrollExtent;
      if (d == Duration.zero) {
        _defilementTicket.jumpTo(cible);
      } else {
        _defilementTicket.animateTo(cible, duration: d, curve: Curves.easeOutCubic);
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
    if (id != null) showSuccessBurst(context, 'Envoyé en caisse');
    setState(() {
      _envoi = false;
      if (id != null) {
        _idSession = id;
        _panier.clear();
      }
    });
    _defilerEnBas();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final session = sessions.where((s) => s.id == _idSession).firstOrNull;
    final articles = ref.watch(articlesProvider).value ?? const <Article>[];
    // Seules les catégories qui ont des articles au menu (pas « Ingrédients »).
    final categories = (ref.watch(categoriesProvider).value ?? const <Categorie>[])
        .where((c) => articles.any((a) => a.auMenu && a.idCategorie == c.id))
        .toList();
    final large = MediaQuery.sizeOf(context).width >= 860;

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
    final ticket = _Ticket(
      session: session,
      panier: _panier,
      totalPanier: _totalPanier,
      envoi: _envoi,
      defilement: _defilementTicket,
      onChange: () => setState(() {}),
      onValider: () => _valider(session),
    );

    return Scaffold(
      backgroundColor: p.fond,
      body: Column(
        children: [
          _EnTeteCommande(table: widget.table, session: session, couvertsAnnonces: widget.couverts),
          Expanded(
            child: large
                ? Row(
                    children: [
                      Expanded(child: grille),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 14, 14),
                        child: SizedBox(width: 400, child: ticket),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 5, child: grille),
                      Expanded(
                        flex: 4,
                        child: Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: ticket),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================== En-tête

/// La carte de la table, agrandie : même fond (Hero), même couleur d'état.
class _EnTeteCommande extends ConsumerWidget {
  final TableResto? table;
  final SessionTable? session;
  final int couvertsAnnonces;
  const _EnTeteCommande({required this.table, required this.session, required this.couvertsAnnonces});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final s = session;
    final etat = etatDe(s);
    final couleur = table == null ? p.principale : etat.couleur(p);
    const rayon = BorderRadius.vertical(bottom: Radius.circular(30));
    final etroit = MediaQuery.sizeOf(context).width < 640;
    final titre = table != null ? 'Table ${s?.numeroTable ?? table!.numero}' : (s?.numeroTable ?? 'À emporter');
    final couverts = s?.couverts ?? couvertsAnnonces;
    final details = [
      if (s != null) s.nomServeuse,
      if (s != null) 'ouverte à ${heure(s.ouverture)}',
      if (couverts > 0) '$couverts couvert${couverts > 1 ? 's' : ''}',
      if (s != null && s.nbTours > 0) '${s.nbTours} tour${s.nbTours > 1 ? 's' : ''}',
    ].join(' · ');
    final blancDoux = Colors.white.withValues(alpha: 0.85);

    return SizedBox(
      height: (etroit ? 132 : 150) + MediaQuery.paddingOf(context).top,
      child: Stack(
        children: [
          Positioned.fill(
            child: table != null
                ? FondTableHero(idTable: table!.id, couleur: couleur, rayon: rayon)
                : DecoratedBox(
                    decoration: BoxDecoration(gradient: degradePrincipal(couleur), borderRadius: rayon),
                  ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 8, etroit ? 14 : 22, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _BoutonRond(
                      icone: Icons.arrow_back_rounded,
                      label: 'Retour au plan de salle',
                      onTap: () => Navigator.maybePop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(table == null ? Icons.shopping_bag_rounded : etat.icone, color: blancDoux, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              table == null ? 'Vente à emporter' : etat.libelle,
                              style: AppTypo.etiquette(blancDoux, taille: 14, poids: FontWeight.w700),
                            ),
                          ],
                        ),
                        Text(
                          titre,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypo.chiffres(AppTypo.titre(Colors.white, taille: etroit ? 30 : 38)),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypo.chiffres(AppTypo.etiquette(blancDoux, taille: 14, poids: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IndicateurConnexion(compact: etroit),
                          const SizedBox(width: 8),
                          _BoutonRond(
                            icone: Icons.logout_rounded,
                            label: 'Changer d’utilisateur',
                            onTap: () {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                              ref.read(utilisateurProvider.notifier).deconnecter();
                            },
                          ),
                        ],
                      ),
                      if (s != null) ...[
                        Text('Total table', style: AppTypo.etiquette(blancDoux, taille: 13)),
                        SmoothCounterText(s.total, style: AppTypo.montant(Colors.white, taille: etroit ? 24 : 30)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;
  const _BoutonRond({required this.icone, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    excludeSemantics: true,
    child: BouncyTapWrapper(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Icon(icone, color: Colors.white),
      ),
    ),
  );
}

// ============================================================ Articles

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
    final p = context.pal;
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
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            children: [
              _onglet(context, 'Favoris', favoris, Icons.star_rounded, p.accent),
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
            duration: duree(context, 220),
            switchInCurve: Curves.easeOutCubic,
            child: GridView.builder(
              key: ValueKey(categorie),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.12,
              ),
              itemCount: affiches.length,
              itemBuilder: (context, i) {
                final a = affiches[i];
                return StaggeredEntrance(
                  index: i,
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
    final p = context.pal;
    final actif = categorie == id;
    // Texte lisible quelle que soit la teinte de l'onglet actif (crème → sombre).
    final surActif = couleur.computeLuminance() > 0.5 ? identite.secondaire : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        container: true,
        button: true,
        selected: actif,
        label: nom,
        excludeSemantics: true,
        child: BouncyTapWrapper(
          onTap: () => onCategorie(id),
          child: AnimatedContainer(
            duration: duree(context, 250),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: actif ? couleur : p.surface,
              borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
              border: Border.all(color: actif ? couleur : p.bordure),
              boxShadow: actif ? AppOmbres.lueur(couleur, force: 0.8) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 20, color: actif ? surActif : couleur),
                const SizedBox(width: 8),
                Text(nom, style: AppTypo.etiquette(actif ? surActif : p.texte, taille: 16, poids: FontWeight.w700)),
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
    final p = context.pal;
    final a = article;
    final ok = a.estVendable(portions);
    final reste = a.reste(portions);
    final faible = ok && reste != null && reste <= (a.aRecette ? 3 : a.seuilAlerte);
    final rayon = BorderRadius.circular(identite.arrondi);
    final choisi = quantite > 0;
    return Semantics(
      container: true,
      button: true,
      enabled: ok,
      label: '${a.nom} ${fcfa(a.prixVente)}${ok ? '' : ' Indisponible'}${choisi ? ', $quantite dans le panier' : ''}',
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: ok ? () => onTap(a) : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: duree(context, 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: ok
                    ? (choisi ? Color.alphaBlend(couleur.withValues(alpha: 0.14), p.surface) : p.surface)
                    : p.fond,
                borderRadius: rayon,
                border: Border.all(color: choisi ? couleur : p.bordure, width: choisi ? 2 : 1),
                boxShadow: ok ? AppOmbres.douce(p, force: 0.6) : null,
              ),
              child: ClipRRect(
                borderRadius: rayon,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (ok ? couleur : p.texteDiscret).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icone, size: 20, color: ok ? couleur : p.texteDiscret),
                      ),
                      const Spacer(),
                      Text(
                        a.nom,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypo.etiquette(ok ? p.texte : p.texteDiscret, taille: 16, poids: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(fcfa(a.prixVente), style: AppTypo.montant(ok ? p.accent : p.texteDiscret, taille: 16)),
                          const Spacer(),
                          if (!ok)
                            Text(
                              'Indisponible',
                              style: AppTypo.etiquette(p.erreur, taille: 12, poids: FontWeight.w700),
                            ),
                          if (faible)
                            Text(
                              'reste ${qte(reste)}',
                              style: AppTypo.chiffres(AppTypo.etiquette(p.occupee, taille: 12, poids: FontWeight.w800)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(right: -6, top: -8, child: QuantityBadge(quantite, couleur: couleur)),
          ],
        ),
      ),
    );
  }
}

// =============================================================== Ticket

class _Ticket extends ConsumerWidget {
  final SessionTable? session;
  final List<ElementPanier> panier;
  final int totalPanier;
  final bool envoi;
  final ScrollController defilement;
  final VoidCallback onChange;
  final VoidCallback onValider;
  const _Ticket({
    required this.session,
    required this.panier,
    required this.totalPanier,
    required this.envoi,
    required this.defilement,
    required this.onChange,
    required this.onValider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final s = session;
    final lignes = s == null
        ? const <LigneCommande>[]
        : (ref.watch(lignesProvider(s.id)).value ?? const <LigneCommande>[]);
    final ouverte = s == null || s.statut == StatutSession.ouverte;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi * 1.2),
        border: Border.all(color: p.bordure),
        boxShadow: AppOmbres.douce(p),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: p.accent, size: 20),
                const SizedBox(width: 8),
                Text('Ticket', style: AppTypo.titre(p.texte, taille: 18, poids: FontWeight.w700)),
                const Spacer(),
                if (!ouverte) Pastille('Addition demandée', p.addition),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: defilement,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                // Tours déjà envoyés à la caisse.
                for (final l in lignes) _LigneValidee(ligne: l, session: s!),
                // Nouveau tour, en bas, juste au-dessus du bouton Valider.
                AnimatedSize(
                  duration: duree(context, 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: panier.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Material(
                            color: p.principale.withValues(alpha: 0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(identite.arrondi),
                              side: BorderSide(color: p.principale.withValues(alpha: 0.45)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.edit_note_rounded, color: p.principale),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Nouveau tour · pas encore envoyé',
                                        style: AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w700),
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
                if (s == null && panier.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 40, color: p.texteDiscret),
                        const SizedBox(height: 10),
                        Text(
                          'Touchez un article pour l’ajouter',
                          textAlign: TextAlign.center,
                          style: AppTypo.etiquette(p.texteSecondaire, taille: 15),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.bordure)),
            ),
            child: Row(
              children: [
                if (s != null && ouverte) ...[
                  Expanded(
                    flex: 2,
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
                                () => ref.read(commandeServiceProvider).demanderAddition(ref.read(acteurProvider)!, s),
                                succes: 'Addition demandée',
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: const Text('Addition', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (ouverte)
                  Expanded(
                    flex: 3,
                    child: GradientActionButton(
                      label: panier.isEmpty ? 'Valider' : 'Valider · ${fcfa(totalPanier)}',
                      icone: Icons.send_rounded,
                      onPressed: panier.isEmpty || envoi ? null : onValider,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    final p = context.pal;
    final e = element;
    return StaggeredEntrance(
      index: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.article.nom, style: AppTypo.etiquette(p.texte, taille: 15)),
                    Text(
                      e.note.isEmpty ? fcfa(e.montant) : '« ${e.note} » · ${fcfa(e.montant)}',
                      style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              _BoutonQuantite(
                icone: Icons.remove_rounded,
                label: 'Retirer un ${e.article.nom}',
                onTap: () {
                  e.quantite--;
                  if (e.quantite <= 0) panier.remove(e);
                  onChange();
                },
              ),
              SizedBox(width: 38, child: RollingNumber(e.quantite, style: AppTypo.montant(p.texte, taille: 20))),
              _BoutonQuantite(
                icone: Icons.add_rounded,
                label: 'Ajouter un ${e.article.nom}',
                plein: true,
                onTap: () {
                  e.quantite++;
                  onChange();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonQuantite extends StatelessWidget {
  final IconData icone;
  final String label;
  final bool plein;
  final VoidCallback onTap;
  const _BoutonQuantite({required this.icone, required this.label, required this.onTap, this.plein = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        scale: 0.88,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: plein ? p.principale : p.surfaceElevee,
            border: Border.all(color: plein ? Colors.transparent : p.bordure),
          ),
          child: Icon(icone, color: plein ? Colors.white : p.texte),
        ),
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
    final p = context.pal;
    final l = ligne;
    final barre = l.annulee ? TextDecoration.lineThrough : null;
    final couleurTexte = l.annulee ? p.texteDiscret : p.texte;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceElevee,
              shape: BoxShape.circle,
              border: Border.all(color: p.bordure),
            ),
            child: Text(
              '${l.tour}',
              style: AppTypo.chiffres(AppTypo.etiquette(p.accent, taille: 12, poids: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.quantite} × ${l.nom}${l.offert ? ' (offert)' : ''}',
                  style: AppTypo.etiquette(couleurTexte, taille: 14).copyWith(decoration: barre),
                ),
                Text(
                  [
                    heure(l.heure),
                    if (l.note.isNotEmpty) '« ${l.note} »',
                    if (l.annulee) 'annulé : ${l.motifAnnulation ?? ''} (validé par ${l.validePar ?? ''})',
                  ].join(' · '),
                  style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 12, poids: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Text(fcfa(l.montant), style: AppTypo.montant(couleurTexte, taille: 14).copyWith(decoration: barre)),
          if (!l.annulee && l.idFacture == null)
            IconButton(
              tooltip: 'Demander l’annulation',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(Icons.remove_circle_outline_rounded, color: p.erreur),
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
