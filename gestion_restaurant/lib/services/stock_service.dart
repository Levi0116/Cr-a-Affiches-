import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/calculs.dart';
import '../models/modeles.dart';
import 'db.dart';

/// Module Stock (section 3.3). Le stock ne se modifie jamais directement :
/// chaque variation crée un document dans `mouvementsStock` et applique un
/// incrément au champ `stock` de l'article.
class StockService {
  final RestoDb db;
  StockService(this.db);

  void _mouvement(WriteBatch b, Acteur a, Article art, String type, num qte,
      String motif) {
    b.set(db.mouvementsStock.doc(db.nouvelId()), {
      ...db.meta(a),
      'idArticle': art.id,
      'nomArticle': art.nom,
      'type': type,
      'quantite': qte,
      'auteur': a.nom,
      'motif': motif,
    });
    b.update(db.articles.doc(art.id), {'stock': FieldValue.increment(qte)});
  }

  /// Livraison fournisseur, saisie en casiers et/ou unités.
  /// Le coût moyen est recalculé pour les marges.
  Future<void> saisirLivraison({
    required Acteur a,
    required Article article,
    int casiers = 0,
    int unites = 0,
    required int prixAchatUnitaire,
    String fournisseur = '',
  }) async {
    final qte = casiersEnUnites(
        casiers: casiers,
        unitesParCasier: article.unitesParCasier,
        unitesIsolees: unites);
    if (qte <= 0) throw ErreurMetier('Quantité nulle');
    final cout = nouveauCoutMoyen(
        stockActuel: article.stock,
        coutMoyenActuel: article.coutMoyen,
        quantiteEntree: qte,
        prixAchatUnitaire: prixAchatUnitaire);
    final b = db.fs.batch();
    final idLivraison = db.nouvelId();
    b.set(db.livraisons.doc(idLivraison), {
      ...db.meta(a),
      'fournisseur': fournisseur,
      'idArticle': article.id,
      'nomArticle': article.nom,
      'casiers': casiers,
      'unites': unites,
      'quantite': qte,
      'prixAchatUnitaire': prixAchatUnitaire,
      'montant': qte * prixAchatUnitaire,
    });
    _mouvement(b, a, article, 'entree', qte,
        'Livraison${fournisseur.isEmpty ? '' : ' $fournisseur'}');
    b.update(db.articles.doc(article.id), {'coutMoyen': cout});
    await db.envoyerSansBloquer(b);
  }

  /// Perte : casse, produit périmé, article offert… toujours avec un motif.
  Future<void> saisirPerte(
      Acteur a, Article article, num quantite, String motif) async {
    if (quantite <= 0) throw ErreurMetier('Quantité invalide');
    if (motif.trim().isEmpty) throw ErreurMetier('Le motif est obligatoire');
    final b = db.fs.batch();
    _mouvement(b, a, article, 'perte', -quantite, motif.trim());
    db.audit(b, a, 'perte', '$quantite × ${article.nom} : $motif');
    await db.envoyerSansBloquer(b);
  }

  /// Portions du jour pour un plat géré en « portions disponibles ».
  Future<void> definirPortions(Acteur a, Article article, int portions) async {
    final b = db.fs.batch();
    _mouvement(b, a, article, 'ajustement', portions - article.stock,
        'Portions du jour : $portions');
    await db.envoyerSansBloquer(b);
  }

  Future<void> forcerDisponibilite(
      Acteur a, Article article, bool disponible) async {
    final b = db.fs.batch();
    b.update(db.articles.doc(article.id), {
      'disponible': disponible,
      ...db.modif(a),
    });
    db.audit(b, a, disponible ? 'remise_en_vente' : 'forcer_indisponible',
        article.nom);
    await db.envoyerSansBloquer(b);
  }

  Future<void> reglerSeuil(Acteur a, Article article, num seuil) async {
    final b = db.fs.batch();
    b.update(db.articles.doc(article.id), {'seuilAlerte': seuil, ...db.modif(a)});
    await db.envoyerSansBloquer(b);
  }

  /// Inventaire : le gestionnaire saisit le compté, l'écart avec le stock
  /// théorique part en validation chez l'administrateur.
  Future<void> soumettreInventaire(
      Acteur a, Article article, num quantiteComptee) async {
    if (quantiteComptee < 0) throw ErreurMetier('Quantité invalide');
    final ecart = quantiteComptee - article.stock;
    if (ecart == 0) return;
    final b = db.fs.batch();
    b.set(db.demandesValidation.doc(db.nouvelId()), {
      ...db.meta(a),
      'type': TypeValidation.ajustement.name,
      'demandeur': a.nom,
      'motif': 'Inventaire',
      'statut': StatutValidation.enAttente.name,
      'detail': {
        'idArticle': article.id,
        'nom': article.nom,
        'theorique': article.stock,
        'compte': quantiteComptee,
        'ecart': ecart,
      },
    });
    await db.envoyerSansBloquer(b);
  }
}
