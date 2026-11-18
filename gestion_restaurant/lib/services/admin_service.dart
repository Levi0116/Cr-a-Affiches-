import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/pin.dart';
import '../models/modeles.dart';
import 'db.dart';

/// Module Administrateur (section 3.4) et validations (section 5.2).
class AdminService {
  final RestoDb db;
  AdminService(this.db);

  void _exigerAdmin(Acteur a) {
    if (!a.estAdmin) throw ErreurMetier('Réservé à l’administrateur');
  }

  // ------------------------------------------------------------ Validations

  Future<void> traiterDemande(Acteur admin, DemandeValidation d, bool accepter) async {
    _exigerAdmin(admin);
    final frais = DemandeValidation.fromDoc(await db.demandesValidation.doc(d.id).get());
    if (frais.statut != StatutValidation.enAttente) {
      throw ErreurMetier('Demande déjà traitée');
    }
    final b = db.fs.batch();
    b.update(db.demandesValidation.doc(d.id), {
      'statut': accepter ? StatutValidation.validee.name : StatutValidation.refusee.name,
      'valideur': admin.nom,
      'traiteeLe': Timestamp.now(),
    });
    final det = d.detail;
    if (!accepter) {
      if (d.type == TypeValidation.annulation) {
        b.update(db.lignes(det['idSession'] as String).doc(det['idLigne'] as String), {'annulationDemandee': false});
      }
      db.audit(b, admin, 'refus_${d.type.name}', '${_resume(d)} (demandé par ${d.demandeur})');
      await db.envoyerSansBloquer(b);
      return;
    }
    switch (d.type) {
      case TypeValidation.annulation:
        await _appliquerAnnulation(b, admin, d);
      case TypeValidation.offert:
        await _appliquerOffert(b, admin, d);
      case TypeValidation.remise:
        await _verifierSessionModifiable(det['idSession'] as String);
        b.update(db.sessions.doc(det['idSession'] as String), {
          'remise': {'type': det['typeRemise'], 'valeur': det['valeur'], 'motif': d.motif, 'validePar': admin.nom},
        });
      case TypeValidation.ajustement:
        b.set(db.mouvementsStock.doc(db.nouvelId()), {
          ...db.meta(admin),
          'idArticle': det['idArticle'],
          'nomArticle': det['nom'],
          'type': 'inventaire',
          'quantite': det['ecart'],
          'auteur': d.demandeur,
          'motif': 'Inventaire validé par ${admin.nom}',
        });
        b.update(db.articles.doc(det['idArticle'] as String), {'stock': FieldValue.increment(det['ecart'] as num)});
    }
    db.audit(b, admin, 'validation_${d.type.name}', '${_resume(d)} (demandé par ${d.demandeur}, motif : ${d.motif})');
    await db.envoyerSansBloquer(b);
  }

  String _resume(DemandeValidation d) {
    final det = d.detail;
    return switch (d.type) {
      TypeValidation.annulation ||
      TypeValidation.offert => '${det['quantite']} × ${det['nom']} table ${det['numeroTable']}',
      TypeValidation.remise =>
        'Remise ${det['valeur']}${det['typeRemise'] == 'pourcentage' ? ' %' : ' F'} table ${det['numeroTable']}',
      TypeValidation.ajustement => '${det['nom']} : écart ${det['ecart']}',
    };
  }

  Future<SessionTable> _verifierSessionModifiable(String idSession) async {
    final s = SessionTable.fromDoc(await db.sessions.doc(idSession).get());
    if (s.statut != StatutSession.ouverte && s.statut != StatutSession.addition) {
      throw ErreurMetier('La facture de cette table est déjà émise : faites un avoir après paiement');
    }
    return s;
  }

  /// Ligne marquée « annulée » (jamais supprimée), stock remis, total corrigé.
  Future<void> _appliquerAnnulation(WriteBatch b, Acteur admin, DemandeValidation d) async {
    final det = d.detail;
    final idSession = det['idSession'] as String;
    await _verifierSessionModifiable(idSession);
    final ref = db.lignes(idSession).doc(det['idLigne'] as String);
    final ligne = LigneCommande.fromDoc(await ref.get());
    if (ligne.annulee) throw ErreurMetier('Ligne déjà annulée');
    b.update(ref, {
      'statut': StatutLigne.annulee.name,
      'motifAnnulation': d.motif,
      'demandeePar': d.demandeur,
      'validePar': admin.nom,
      'annulationDemandee': false,
    });
    b.update(db.sessions.doc(idSession), {'total': FieldValue.increment(-ligne.montant)});
    final art = await db.articles.doc(ligne.idArticle).get();
    if (art.exists && Article.fromDoc(art).suiviStock) {
      b.set(db.mouvementsStock.doc(db.nouvelId()), {
        ...db.meta(admin),
        'idArticle': ligne.idArticle,
        'nomArticle': ligne.nom,
        'type': 'annulation',
        'quantite': ligne.quantite,
        'auteur': d.demandeur,
        'motif': d.motif,
      });
      b.update(db.articles.doc(ligne.idArticle), {
        'stock': FieldValue.increment(ligne.quantite),
        'nbVentes': FieldValue.increment(-ligne.quantite),
      });
    }
  }

  Future<void> _appliquerOffert(WriteBatch b, Acteur admin, DemandeValidation d) async {
    final det = d.detail;
    final idSession = det['idSession'] as String;
    await _verifierSessionModifiable(idSession);
    final ref = db.lignes(idSession).doc(det['idLigne'] as String);
    final ligne = LigneCommande.fromDoc(await ref.get());
    if (ligne.offert || ligne.annulee) return;
    b.update(ref, {'offert': true, 'motifOffert': d.motif, 'validePar': admin.nom});
    b.update(db.sessions.doc(idSession), {'total': FieldValue.increment(-ligne.montant)});
  }

  // ------------------------------------------------------------------- Menu

  Future<void> enregistrerCategorie(Acteur a, {String? id, required String nom, required int ordre}) async {
    _exigerAdmin(a);
    final b = db.fs.batch();
    b.set(db.categories.doc(id ?? db.nouvelId()), {
      'nom': nom,
      'ordre': ordre,
      ...db.modif(a),
    }, SetOptions(merge: true));
    await db.envoyerSansBloquer(b);
  }

  /// Création ou modification d'un article. Les changements de prix sont
  /// historisés et tracés dans le journal d'audit.
  Future<void> enregistrerArticle(Acteur a, Article art, {Article? ancien, num stockInitial = 0}) async {
    _exigerAdmin(a);
    if (art.nom.trim().isEmpty) throw ErreurMetier('Nom obligatoire');
    if (art.prixVente < 0) throw ErreurMetier('Prix invalide');
    final b = db.fs.batch();
    final id = ancien?.id ?? db.nouvelId();
    final data = {...art.toMap(), ...db.modif(a)};
    if (ancien == null) {
      data.addAll({...db.meta(a), 'stock': 0, 'coutMoyen': 0, 'nbVentes': 0});
      b.set(db.articles.doc(id), data);
      if (stockInitial != 0) {
        b.set(db.mouvementsStock.doc(db.nouvelId()), {
          ...db.meta(a),
          'idArticle': id,
          'nomArticle': art.nom,
          'type': 'ajustement',
          'quantite': stockInitial,
          'auteur': a.nom,
          'motif': 'Stock initial',
        });
        b.update(db.articles.doc(id), {'stock': FieldValue.increment(stockInitial)});
      }
    } else {
      b.update(db.articles.doc(id), data);
      if (ancien.prixVente != art.prixVente) {
        b.set(db.historiquePrix.doc(db.nouvelId()), {
          ...db.meta(a),
          'idArticle': id,
          'nom': art.nom,
          'ancienPrix': ancien.prixVente,
          'nouveauPrix': art.prixVente,
        });
        db.audit(b, a, 'changement_prix', '${art.nom} : ${ancien.prixVente} F → ${art.prixVente} F');
      }
    }
    await db.envoyerSansBloquer(b);
  }

  // ----------------------------------------------------------------- Salle

  Future<void> enregistrerZone(Acteur a, {String? id, required String nom, int ordre = 0}) async {
    _exigerAdmin(a);
    final b = db.fs.batch();
    b.set(db.zones.doc(id ?? db.nouvelId()), {'nom': nom, 'ordre': ordre}, SetOptions(merge: true));
    await db.envoyerSansBloquer(b);
  }

  Future<void> enregistrerTable(
    Acteur a, {
    String? id,
    required String numero,
    required String idZone,
    int capacite = 4,
    bool active = true,
  }) async {
    _exigerAdmin(a);
    final b = db.fs.batch();
    final ref = db.tables.doc(id ?? db.nouvelId());
    b.set(ref, {
      'numero': numero,
      'idZone': idZone,
      'capacite': capacite,
      'active': active,
      if (id == null) 'statut': StatutTable.libre.name,
    }, SetOptions(merge: true));
    await db.envoyerSansBloquer(b);
  }

  // -------------------------------------------------------------- Employés

  Future<void> enregistrerEmploye(
    Acteur a, {
    String? id,
    required String nom,
    required Role role,
    String? nouveauPin,
    bool actif = true,
  }) async {
    _exigerAdmin(a);
    if (nom.trim().isEmpty) throw ErreurMetier('Nom obligatoire');
    if (id == null && nouveauPin == null) {
      throw ErreurMetier('Code PIN obligatoire');
    }
    if (nouveauPin != null && !pinValide(nouveauPin)) {
      throw ErreurMetier('Le code PIN doit comporter 4 chiffres');
    }
    final idE = id ?? db.nouvelId();
    final b = db.fs.batch();
    b.set(db.employes.doc(idE), {
      'nom': nom.trim(),
      'role': role.name,
      'actif': actif,
      if (nouveauPin != null) 'pinHash': hacherPin(idRestaurant: db.idRestaurant, idEmploye: idE, pin: nouveauPin),
      ...db.modif(a),
    }, SetOptions(merge: true));
    db.audit(
      b,
      a,
      id == null ? 'creation_employe' : 'modification_employe',
      '$nom (${role.libelle})${actif ? '' : ' désactivé'}',
    );
    await db.envoyerSansBloquer(b);
  }

  // ------------------------------------------------------------- Paramètres

  Future<void> enregistrerParametres(Acteur a, Restaurant r) async {
    _exigerAdmin(a);
    final b = db.fs.batch();
    b.set(db.resto, {...r.toMap(), ...db.modif(a)}, SetOptions(merge: true));
    db.audit(b, a, 'parametres', 'Paramètres du restaurant modifiés');
    await db.envoyerSansBloquer(b);
  }

  Future<void> saisirDepense(
    Acteur a, {
    required String categorie,
    required int montant,
    String description = '',
  }) async {
    _exigerAdmin(a);
    if (montant <= 0) throw ErreurMetier('Montant invalide');
    final b = db.fs.batch();
    b.set(db.depenses.doc(db.nouvelId()), {
      ...db.meta(a),
      'categorie': categorie,
      'montant': montant,
      'description': description,
      'date': Timestamp.now(),
    });
    await db.envoyerSansBloquer(b);
  }
}
