import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../services/commande_service.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
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
    if (!a.vendable) return;
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
      return ref.read(commandeServiceProvider).validerTour(
            serveuse: acteur,
            panier: List.of(_panier),
            table: widget.table,
            session: session,
            couverts: widget.couverts,
            libelleAEmporter: libelle,
          );
    }, succes: 'Commande envoyée à la caisse');
    if (!mounted) return;
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
    final categories = ref.watch(categoriesProvider).value ?? const [];
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
      appBar: AppBar(title: Text(titre), actions: actionsBarre(context, ref)),
      body: large
          ? Row(children: [
              Expanded(flex: 3, child: grille),
              const VerticalDivider(width: 1),
              SizedBox(width: 380, child: panneau),
            ])
          : Column(children: [
              Expanded(flex: 3, child: grille),
              const Divider(height: 1),
              Expanded(flex: 2, child: panneau),
            ]),
    );
  }
}

class _GrilleArticles extends StatelessWidget {
  final List<Article> articles;
  final List<Categorie> categories;
  final String categorie;
  final String favoris;
  final ValueChanged<String> onCategorie;
  final ValueChanged<Article> onArticle;
  const _GrilleArticles({
    required this.articles,
    required this.categories,
    required this.categorie,
    required this.favoris,
    required this.onCategorie,
    required this.onArticle,
  });

  @override
  Widget build(BuildContext context) {
    final actifs = articles.where((a) => a.actif).toList();
    final List<Article> affiches;
    if (categorie == favoris) {
      // Articles favoris : les plus vendus en premier.
      affiches = [...actifs]..sort((a, b) => b.nbVentes.compareTo(a.nbVentes));
    } else {
      affiches = actifs.where((a) => a.idCategorie == categorie).toList();
    }
    return Column(children: [
      SizedBox(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: [
            _onglet('★ Favoris', favoris),
            for (final c in categories) _onglet(c.nom, c.id),
          ],
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 170,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
          ),
          itemCount: categorie == favoris ? affiches.length.clamp(0, 24) : affiches.length,
          itemBuilder: (context, i) => _BoutonArticle(article: affiches[i], onTap: onArticle),
        ),
      ),
    ]);
  }

  Widget _onglet(String nom, String id) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(nom, style: const TextStyle(fontSize: 16)),
          selected: categorie == id,
          onSelected: (_) => onCategorie(id),
        ),
      );
}

class _BoutonArticle extends StatelessWidget {
  final Article article;
  final ValueChanged<Article> onTap;
  const _BoutonArticle({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = article;
    final ok = a.vendable;
    final faible = ok && a.suiviStock && a.stock <= a.seuilAlerte;
    return Material(
      color: ok ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ok ? () => onTap(a) : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(a.nom,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ok ? null : Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(fcfa(a.prixVente), style: const TextStyle(fontSize: 15)),
              if (!ok)
                const Text('Indisponible',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              if (faible)
                Text('reste ${a.stock}',
                    style: const TextStyle(color: couleurOccupee, fontWeight: FontWeight.bold)),
            ],
          ),
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
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (panier.isNotEmpty) ...[
              const Text('Nouveau tour (non envoyé)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              for (final e in panier) _LignePanier(element: e, panier: panier, onChange: onChange),
              const Divider(),
            ],
            if (s != null) ...[
              Row(children: [
                Text('Addition · ${s.nbTours} tour${s.nbTours > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (!ouverte) const Pastille('Addition demandée', couleurAddition),
              ]),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(children: [
          if (s != null)
            Row(children: [
              const Text('Total table', style: TextStyle(fontSize: 18)),
              const Spacer(),
              Text(fcfa(s.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            if (s != null && ouverte)
              Expanded(
                child: OutlinedButton(
                  onPressed: panier.isNotEmpty
                      ? null
                      : () async {
                          final ok = await confirmer(context, 'Demander l’addition',
                              'La table passera en bleu et la caisse sera prévenue.');
                          if (!ok || !context.mounted) return;
                          await essayer(
                              context,
                              () => ref
                                  .read(commandeServiceProvider)
                                  .demanderAddition(ref.read(acteurProvider)!, s),
                              succes: 'Addition demandée');
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
          ]),
        ]),
      ),
    ]);
  }
}

class _LignePanier extends StatelessWidget {
  final ElementPanier element;
  final List<ElementPanier> panier;
  final VoidCallback onChange;
  const _LignePanier({required this.element, required this.panier, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final e = element;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(e.article.nom),
      subtitle: Text(e.note.isEmpty ? fcfa(e.montant) : '« ${e.note} » · ${fcfa(e.montant)}'),
      onTap: () async {
        final note = await demanderTexte(context, 'Note pour ${e.article.nom}',
            label: 'ex. bien glacée, sans piment', initial: e.note, obligatoire: false);
        if (note != null) {
          e.note = note;
          onChange();
        }
      },
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.remove),
          onPressed: () {
            e.quantite--;
            if (e.quantite <= 0) panier.remove(e);
            onChange();
          },
        ),
        SizedBox(
          width: 32,
          child: Text('${e.quantite}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.add),
          onPressed: () {
            e.quantite++;
            onChange();
          },
        ),
      ]),
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
    final style = l.annulee
        ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
        : null;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 14, child: Text('${l.tour}', style: const TextStyle(fontSize: 12))),
      title: Text('${l.quantite} × ${l.nom}${l.offert ? ' (offert)' : ''}', style: style),
      subtitle: Text(
        [
          heure(l.heure),
          if (l.note.isNotEmpty) '« ${l.note} »',
          if (l.annulee) 'annulé : ${l.motifAnnulation ?? ''} (validé par ${l.validePar ?? ''})',
        ].join(' · '),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(fcfa(l.montant), style: style),
        if (!l.annulee && l.idFacture == null)
          IconButton(
            tooltip: 'Demander l’annulation',
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () async {
              final motif = await demanderTexte(context, 'Annuler ${l.quantite} × ${l.nom} ?',
                  label: 'Motif (obligatoire)');
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
      ]),
    );
  }
}
