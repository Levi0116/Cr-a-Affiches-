import '../donnees/base.dart';

import '../core/stock_calc.dart';
import '../models/modeles.dart';
import 'db.dart';

/// Un article dans le panier local de la serveuse, avant validation.
class ElementPanier {
  final Article article;
  int quantite;
  String note;
  ElementPanier(this.article, {this.quantite = 1, this.note = ''});
  int get montant => article.prixVente * quantite;
}

/// Module Serveuse (section 3.1) : ouverture, tours, addition, transfert,
/// fusion, demande d'annulation, vente à emporter.
class CommandeService {
  final RestoDb db;
  CommandeService(this.db);

  /// Valide un tour de commande en une seule écriture groupée (phase 5.3) :
  /// lignes, mouvements de stock, décréments du stock et total de la session.
  /// Retourne l'identifiant de la session (créée si la table était libre).
  Future<String> validerTour({
    required Acteur serveuse,
    required List<ElementPanier> panier,
    TableResto? table,
    SessionTable? session,
    int couverts = 0,
    String? libelleAEmporter,
  }) async {
    final elements = panier.where((e) => e.quantite > 0).toList();
    if (elements.isEmpty) throw ErreurMetier('Le panier est vide');
    for (final e in elements) {
      if (!e.article.vendable) {
        throw ErreurMetier('${e.article.nom} est indisponible');
      }
    }
    if (session != null && session.statut != StatutSession.ouverte) {
      throw ErreurMetier("L'addition a déjà été demandée : impossible d'ajouter des articles");
    }

    // Fiches techniques des plats concernés (lues dans la copie locale).
    final recettes = <String, Recette>{};
    for (final e in elements.where((e) => e.article.aRecette)) {
      final r = Recette.fromDoc(await db.recettes.doc(e.article.id).get());
      if (r.ingredients.isNotEmpty) recettes[e.article.id] = r;
    }

    final b = db.fs.batch();
    final maintenant = DateTime.now();
    final String idSession;
    final int tour;
    if (session == null) {
      idSession = db.nouvelId();
      tour = 1;
      b.set(db.sessions.doc(idSession), {
        ...db.meta(serveuse),
        'idTable': table?.id,
        'numeroTable': table?.numero ?? libelleAEmporter ?? 'À emporter',
        'idServeuse': serveuse.id,
        'nomServeuse': serveuse.nom,
        'ouverture': Timestamp.fromDate(maintenant),
        'statut': StatutSession.ouverte.name,
        'total': 0,
        'couverts': couverts,
        'nbTours': 0,
        'aEmporter': table == null,
        'idsFactures': <String>[],
      });
      if (table != null) {
        b.update(db.tables.doc(table.id), {'statut': StatutTable.occupee.name, 'idSession': idSession});
      }
    } else {
      idSession = session.id;
      tour = session.nbTours + 1;
    }

    var total = 0;
    for (final e in elements) {
      final art = e.article;
      // Plat à fiche technique : on déduit chaque ingrédient.
      final recette = recettes[art.id];
      final deductions = recette == null ? const <Ingredient>[] : deductionsPour(recette, e.quantite);
      final ligne = LigneCommande(
        id: db.nouvelId(),
        idArticle: art.id,
        nom: art.nom,
        quantite: e.quantite,
        prixUnitaire: art.prixVente,
        note: e.note,
        tour: tour,
        auteur: serveuse.nom,
        heure: maintenant,
        deductions: deductions,
      );
      total += ligne.montant;
      b.set(db.lignes(idSession).doc(ligne.id), {...db.meta(serveuse), ...ligne.toMap()});
      final majArticle = <String, dynamic>{'nbVentes': FieldValue.increment(e.quantite)};
      final motif =
          '${e.quantite} × ${art.nom} · table ${table?.numero ?? session?.numeroTable ?? 'à emporter'}, tour $tour';
      if (recette != null) {
        for (final d in deductions) {
          b.set(db.mouvementsStock.doc(db.nouvelId()), {
            ...db.meta(serveuse),
            'idArticle': d.idArticle,
            'nomArticle': d.nom,
            'type': 'vente',
            'quantite': -d.quantite,
            'auteur': serveuse.nom,
            'motif': motif,
            'idSession': idSession,
          });
          b.update(db.articles.doc(d.idArticle), {'stock': FieldValue.increment(-d.quantite)});
        }
      } else if (art.suiviStock) {
        // Le stock ne se modifie jamais directement : un mouvement + un
        // décrément, qui s'additionnent sans conflit même hors ligne.
        majArticle['stock'] = FieldValue.increment(-e.quantite);
        b.set(db.mouvementsStock.doc(db.nouvelId()), {
          ...db.meta(serveuse),
          'idArticle': art.id,
          'nomArticle': art.nom,
          'type': 'vente',
          'quantite': -e.quantite,
          'auteur': serveuse.nom,
          'motif': motif,
          'idSession': idSession,
        });
      }
      // Bouteille consignée : un vide de plus à rendre au fournisseur.
      if (art.consigne) majArticle['vides'] = FieldValue.increment(e.quantite);
      b.update(db.articles.doc(art.id), majArticle);
    }
    b.update(db.sessions.doc(idSession), {
      'total': FieldValue.increment(total),
      'nbTours': FieldValue.increment(1),
      'dernierTour': Timestamp.fromDate(maintenant),
    });
    await db.envoyerSansBloquer(b);
    return idSession;
  }

  /// La table passe en bleu et la caisse est prévenue.
  Future<void> demanderAddition(Acteur a, SessionTable s) async {
    if (s.statut != StatutSession.ouverte) return;
    final b = db.fs.batch();
    b.update(db.sessions.doc(s.id), {
      'statut': StatutSession.addition.name,
      'additionDemandeeLe': Timestamp.now(),
      ...db.modif(a),
    });
    if (s.idTable != null) {
      b.update(db.tables.doc(s.idTable), {'statut': StatutTable.addition.name});
    }
    await db.envoyerSansBloquer(b);
  }

  /// Le client change de place : la session suit vers une table libre.
  Future<void> transferer(Acteur a, SessionTable s, TableResto destination) async {
    if (destination.statut != StatutTable.libre) {
      throw ErreurMetier('La table ${destination.numero} est occupée');
    }
    final b = db.fs.batch();
    b.update(db.sessions.doc(s.id), {'idTable': destination.id, 'numeroTable': destination.numero, ...db.modif(a)});
    b.update(db.tables.doc(destination.id), {
      'statut': s.statut == StatutSession.ouverte ? StatutTable.occupee.name : StatutTable.addition.name,
      'idSession': s.id,
    });
    if (s.idTable != null) {
      b.update(db.tables.doc(s.idTable), {'statut': StatutTable.libre.name, 'idSession': null});
    }
    db.audit(b, a, 'transfert', 'Table ${s.numeroTable} → ${destination.numero}');
    await db.envoyerSansBloquer(b);
  }

  /// Fusionne la session [source] dans [cible] : les lignes sont recopiées,
  /// la table source est libérée.
  Future<void> fusionner(Acteur a, SessionTable source, SessionTable cible) async {
    if (source.id == cible.id) return;
    if (source.statut != StatutSession.ouverte || cible.statut != StatutSession.ouverte) {
      throw ErreurMetier('Fusion possible seulement entre tables ouvertes');
    }
    final lignes = await db.lignes(source.id).get();
    final b = db.fs.batch();
    for (final l in lignes.docs) {
      b.set(db.lignes(cible.id).doc(l.id), {...l.data(), 'fusionDepuis': source.numeroTable});
    }
    b.update(db.sessions.doc(cible.id), {
      'total': FieldValue.increment(source.total),
      'nbTours': FieldValue.increment(source.nbTours),
      'couverts': FieldValue.increment(source.couverts),
    });
    b.update(db.sessions.doc(source.id), {
      'statut': StatutSession.fusionnee.name,
      'fusionneeDans': cible.id,
      ...db.modif(a),
    });
    if (source.idTable != null) {
      b.update(db.tables.doc(source.idTable), {'statut': StatutTable.libre.name, 'idSession': null});
    }
    db.audit(b, a, 'fusion', 'Table ${source.numeroTable} fusionnée dans ${cible.numeroTable}');
    await db.envoyerSansBloquer(b);
  }

  /// Demande d'annulation d'un article déjà validé : part vers l'admin.
  Future<void> demanderAnnulation(Acteur a, SessionTable s, LigneCommande l, String motif) async {
    if (motif.trim().isEmpty) throw ErreurMetier('Le motif est obligatoire');
    if (l.annulee) return;
    final b = db.fs.batch();
    b.set(db.demandesValidation.doc(db.nouvelId()), {
      ...db.meta(a),
      'type': TypeValidation.annulation.name,
      'demandeur': a.nom,
      'motif': motif.trim(),
      'statut': StatutValidation.enAttente.name,
      'detail': {
        'idSession': s.id,
        'numeroTable': s.numeroTable,
        'idLigne': l.id,
        'idArticle': l.idArticle,
        'nom': l.nom,
        'quantite': l.quantite,
        'montant': l.montant,
      },
    });
    b.update(db.lignes(s.id).doc(l.id), {'annulationDemandee': true});
    db.audit(b, a, 'demande_annulation', '${l.quantite} × ${l.nom} (table ${s.numeroTable}) : $motif');
    await db.envoyerSansBloquer(b);
  }
}
