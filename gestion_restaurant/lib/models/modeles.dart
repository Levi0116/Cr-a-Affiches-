/// Modèle de données (section 7 du cahier des charges).
///
/// Toutes les collections sont rangées sous `restaurants/{idRestaurant}/...`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/calculs.dart';

DateTime _date(Object? v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
        ? v
        : DateTime.fromMillisecondsSinceEpoch(0);
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _dbl(Object? v) => (v as num?)?.toDouble() ?? 0;

enum Role {
  serveuse('Serveuse'),
  caissier('Caissier'),
  gestionnaire('Gestionnaire de stock'),
  admin('Administrateur');

  final String libelle;
  const Role(this.libelle);
}

class Restaurant {
  final String id;
  final String nom;
  final String adresse;
  final String telephone;
  final String mentionsFacture;
  final String messageBasTicket;
  final bool soumisTva;
  final double tauxTva;
  final int deconnexionMinutes;
  final String logoUrl;

  const Restaurant({
    required this.id,
    required this.nom,
    this.adresse = '',
    this.telephone = '',
    this.mentionsFacture = '',
    this.messageBasTicket = 'Merci et à bientôt',
    this.soumisTva = false,
    this.tauxTva = 18,
    this.deconnexionMinutes = 5,
    this.logoUrl = '',
  });

  double get tauxTvaEffectif => soumisTva ? tauxTva : 0;

  factory Restaurant.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Restaurant(
      id: d.id,
      nom: m['nom'] as String? ?? 'Mon restaurant',
      adresse: m['adresse'] as String? ?? '',
      telephone: m['telephone'] as String? ?? '',
      mentionsFacture: m['mentionsFacture'] as String? ?? '',
      messageBasTicket: m['messageBasTicket'] as String? ?? 'Merci et à bientôt',
      soumisTva: m['soumisTva'] as bool? ?? false,
      tauxTva: m['tauxTva'] == null ? 18 : _dbl(m['tauxTva']),
      deconnexionMinutes: m['deconnexionMinutes'] == null
          ? 5
          : _int(m['deconnexionMinutes']),
      logoUrl: m['logoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'adresse': adresse,
        'telephone': telephone,
        'mentionsFacture': mentionsFacture,
        'messageBasTicket': messageBasTicket,
        'soumisTva': soumisTva,
        'tauxTva': tauxTva,
        'deconnexionMinutes': deconnexionMinutes,
        'logoUrl': logoUrl,
      };
}

class Employe {
  final String id;
  final String nom;
  final Role role;
  final String pinHash;
  final bool actif;
  const Employe({
    required this.id,
    required this.nom,
    required this.role,
    required this.pinHash,
    this.actif = true,
  });

  factory Employe.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Employe(
      id: d.id,
      nom: m['nom'] as String,
      role: Role.values.byName(m['role'] as String),
      pinHash: m['pinHash'] as String? ?? '',
      actif: m['actif'] as bool? ?? true,
    );
  }
}

class Zone {
  final String id;
  final String nom;
  final int ordre;
  const Zone({required this.id, required this.nom, this.ordre = 0});
  factory Zone.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Zone(id: d.id, nom: m['nom'] as String, ordre: _int(m['ordre']));
  }
}

enum StatutTable { libre, occupee, addition }

class TableResto {
  final String id;
  final String numero;
  final String idZone;
  final int capacite;
  final StatutTable statut;
  final String? idSession;
  final bool active;
  const TableResto({
    required this.id,
    required this.numero,
    required this.idZone,
    this.capacite = 4,
    this.statut = StatutTable.libre,
    this.idSession,
    this.active = true,
  });
  factory TableResto.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return TableResto(
      id: d.id,
      numero: m['numero'] as String,
      idZone: m['idZone'] as String? ?? '',
      capacite: _int(m['capacite']),
      statut: StatutTable.values.byName(m['statut'] as String? ?? 'libre'),
      idSession: m['idSession'] as String?,
      active: m['active'] as bool? ?? true,
    );
  }
}

class Categorie {
  final String id;
  final String nom;
  final int ordre;
  const Categorie({required this.id, required this.nom, this.ordre = 0});
  factory Categorie.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Categorie(id: d.id, nom: m['nom'] as String, ordre: _int(m['ordre']));
  }
}

/// revendu : bière, sucrerie… une vente retire une unité.
/// prepare : plat ; au début géré en « portions disponibles ».
enum TypeArticle { revendu, prepare }

class Article {
  final String id;
  final String nom;
  final String idCategorie;
  final int prixVente;
  final TypeArticle type;
  final String unite;
  final num stock;
  final num seuilAlerte;
  /// false = forcé indisponible à la main par le gestionnaire.
  final bool disponible;
  /// false = article retiré du menu par l'administrateur.
  final bool actif;
  /// true = le stock est suivi (déduction, rupture automatique à 0).
  final bool suiviStock;
  final int coutMoyen;
  final int unitesParCasier;
  final int ordre;
  final int nbVentes;
  final String photoUrl;

  const Article({
    required this.id,
    required this.nom,
    required this.idCategorie,
    required this.prixVente,
    this.type = TypeArticle.revendu,
    this.unite = 'unité',
    this.stock = 0,
    this.seuilAlerte = 0,
    this.disponible = true,
    this.actif = true,
    this.suiviStock = true,
    this.coutMoyen = 0,
    this.unitesParCasier = 0,
    this.ordre = 0,
    this.nbVentes = 0,
    this.photoUrl = '',
  });

  /// Indisponible si forcé à la main, ou si le stock suivi est épuisé.
  bool get vendable => actif && disponible && (!suiviStock || stock > 0);
  bool get sousSeuil => suiviStock && stock <= seuilAlerte;

  factory Article.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Article(
      id: d.id,
      nom: m['nom'] as String,
      idCategorie: m['idCategorie'] as String? ?? '',
      prixVente: _int(m['prixVente']),
      type: TypeArticle.values.byName(m['type'] as String? ?? 'revendu'),
      unite: m['unite'] as String? ?? 'unité',
      stock: (m['stock'] as num?) ?? 0,
      seuilAlerte: (m['seuilAlerte'] as num?) ?? 0,
      disponible: m['disponible'] as bool? ?? true,
      actif: m['actif'] as bool? ?? true,
      suiviStock: m['suiviStock'] as bool? ?? true,
      coutMoyen: _int(m['coutMoyen']),
      unitesParCasier: _int(m['unitesParCasier']),
      ordre: _int(m['ordre']),
      nbVentes: _int(m['nbVentes']),
      photoUrl: m['photoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'idCategorie': idCategorie,
        'prixVente': prixVente,
        'type': type.name,
        'unite': unite,
        'seuilAlerte': seuilAlerte,
        'disponible': disponible,
        'actif': actif,
        'suiviStock': suiviStock,
        'unitesParCasier': unitesParCasier,
        'ordre': ordre,
        'photoUrl': photoUrl,
      };
}

/// ouverte → addition (demandée) → facturee → payee | credit.
/// transferee : session fusionnée dans une autre table.
enum StatutSession { ouverte, addition, facturee, payee, credit, fusionnee }

class SessionTable {
  final String id;
  final String? idTable;
  final String numeroTable;
  final String idServeuse;
  final String nomServeuse;
  final DateTime ouverture;
  final StatutSession statut;
  final int total;
  final int couverts;
  final int nbTours;
  final bool aEmporter;
  final Remise? remise;
  final List<String> idsFactures;
  const SessionTable({
    required this.id,
    required this.idTable,
    required this.numeroTable,
    required this.idServeuse,
    required this.nomServeuse,
    required this.ouverture,
    required this.statut,
    this.total = 0,
    this.couverts = 0,
    this.nbTours = 0,
    this.aEmporter = false,
    this.remise,
    this.idsFactures = const [],
  });

  bool get enCours =>
      statut == StatutSession.ouverte ||
      statut == StatutSession.addition ||
      statut == StatutSession.facturee;

  factory SessionTable.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return SessionTable(
      id: d.id,
      idTable: m['idTable'] as String?,
      numeroTable: m['numeroTable'] as String? ?? '',
      idServeuse: m['idServeuse'] as String? ?? '',
      nomServeuse: m['nomServeuse'] as String? ?? '',
      ouverture: _date(m['ouverture']),
      statut: StatutSession.values.byName(m['statut'] as String),
      total: _int(m['total']),
      couverts: _int(m['couverts']),
      nbTours: _int(m['nbTours']),
      aEmporter: m['aEmporter'] as bool? ?? false,
      remise: Remise.fromMap(m['remise']),
      idsFactures: List<String>.from(m['idsFactures'] as List? ?? const []),
    );
  }
}

enum StatutLigne { validee, annulee }

class LigneCommande {
  final String id;
  final String idArticle;
  final String nom;
  final int quantite;
  final int prixUnitaire;
  final String note;
  final int tour;
  final StatutLigne statut;
  final String auteur;
  final DateTime heure;
  final bool offert;
  final String? motifAnnulation;
  final String? validePar;
  /// Ligne déjà affectée à une facture partielle (partage par article).
  final String? idFacture;
  const LigneCommande({
    required this.id,
    required this.idArticle,
    required this.nom,
    required this.quantite,
    required this.prixUnitaire,
    this.note = '',
    required this.tour,
    this.statut = StatutLigne.validee,
    this.auteur = '',
    required this.heure,
    this.offert = false,
    this.motifAnnulation,
    this.validePar,
    this.idFacture,
  });

  bool get annulee => statut == StatutLigne.annulee;
  int get montant => annulee || offert ? 0 : quantite * prixUnitaire;
  LigneCalcul get calcul =>
      LigneCalcul(quantite, offert ? 0 : prixUnitaire, annulee: annulee);

  factory LigneCommande.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      LigneCommande.fromMap(d.id, d.data()!);

  factory LigneCommande.fromMap(String id, Map<String, dynamic> m) =>
      LigneCommande(
        id: id,
        idArticle: m['idArticle'] as String? ?? '',
        nom: m['nom'] as String,
        quantite: _int(m['quantite']),
        prixUnitaire: _int(m['prixUnitaire']),
        note: m['note'] as String? ?? '',
        tour: _int(m['tour']),
        statut: StatutLigne.values.byName(m['statut'] as String? ?? 'validee'),
        auteur: m['auteur'] as String? ?? '',
        heure: _date(m['heure']),
        offert: m['offert'] as bool? ?? false,
        motifAnnulation: m['motifAnnulation'] as String?,
        validePar: m['validePar'] as String?,
        idFacture: m['idFacture'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'idArticle': idArticle,
        'nom': nom,
        'quantite': quantite,
        'prixUnitaire': prixUnitaire,
        'note': note,
        'tour': tour,
        'statut': statut.name,
        'auteur': auteur,
        'heure': Timestamp.fromDate(heure),
        'offert': offert,
        if (motifAnnulation != null) 'motifAnnulation': motifAnnulation,
        if (validePar != null) 'validePar': validePar,
      };
}

enum StatutFacture { emise, payee, credit }

class Facture {
  final String id;
  final String numero;
  final String idSession;
  final String numeroTable;
  final String nomServeuse;
  final String nomCaissier;
  final List<LigneCommande> lignes;
  final int sousTotal;
  final int remise;
  final String? motifRemise;
  final int tva;
  final int total;
  final StatutFacture statut;
  final DateTime date;
  final int montantRecu;
  final int monnaieRendue;
  final String? idArdoise;
  final int nbImpressions;
  final String? partie; // « 1/3 » pour un partage
  const Facture({
    required this.id,
    required this.numero,
    required this.idSession,
    required this.numeroTable,
    required this.nomServeuse,
    required this.nomCaissier,
    required this.lignes,
    required this.sousTotal,
    required this.remise,
    this.motifRemise,
    required this.tva,
    required this.total,
    required this.statut,
    required this.date,
    this.montantRecu = 0,
    this.monnaieRendue = 0,
    this.idArdoise,
    this.nbImpressions = 0,
    this.partie,
  });

  factory Facture.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final lignes = (m['lignes'] as List? ?? const [])
        .cast<Map>()
        .map((l) => LigneCommande.fromMap(
            l['id'] as String? ?? '', Map<String, dynamic>.from(l)))
        .toList();
    return Facture(
      id: d.id,
      numero: m['numero'] as String,
      idSession: m['idSession'] as String? ?? '',
      numeroTable: m['numeroTable'] as String? ?? '',
      nomServeuse: m['nomServeuse'] as String? ?? '',
      nomCaissier: m['nomCaissier'] as String? ?? '',
      lignes: lignes,
      sousTotal: _int(m['sousTotal']),
      remise: _int(m['remise']),
      motifRemise: m['motifRemise'] as String?,
      tva: _int(m['tva']),
      total: _int(m['total']),
      statut: StatutFacture.values.byName(m['statut'] as String),
      date: _date(m['date']),
      montantRecu: _int(m['montantRecu']),
      monnaieRendue: _int(m['monnaieRendue']),
      idArdoise: m['idArdoise'] as String?,
      nbImpressions: _int(m['nbImpressions']),
      partie: m['partie'] as String?,
    );
  }
}

class MouvementStock {
  final String id;
  final String idArticle;
  final String nomArticle;
  final String type; // vente, entree, perte, inventaire, annulation, ajustement
  final num quantite;
  final String auteur;
  final String motif;
  final DateTime date;
  const MouvementStock({
    required this.id,
    required this.idArticle,
    required this.nomArticle,
    required this.type,
    required this.quantite,
    required this.auteur,
    required this.motif,
    required this.date,
  });
  factory MouvementStock.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MouvementStock(
      id: d.id,
      idArticle: m['idArticle'] as String? ?? '',
      nomArticle: m['nomArticle'] as String? ?? '',
      type: m['type'] as String,
      quantite: (m['quantite'] as num?) ?? 0,
      auteur: m['auteur'] as String? ?? '',
      motif: m['motif'] as String? ?? '',
      date: _date(m['heureAppareil']),
    );
  }
}

class JourneeCaisse {
  final String id;
  final DateTime ouverture;
  final int fond;
  final int totalEncaisse;
  final int totalTheorique;
  final int? totalCompte;
  final int? ecart;
  final String caissier;
  final bool verrouillee;
  final DateTime? cloture;
  const JourneeCaisse({
    required this.id,
    required this.ouverture,
    required this.fond,
    required this.totalEncaisse,
    required this.totalTheorique,
    this.totalCompte,
    this.ecart,
    required this.caissier,
    required this.verrouillee,
    this.cloture,
  });
  factory JourneeCaisse.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return JourneeCaisse(
      id: d.id,
      ouverture: _date(m['ouverture']),
      fond: _int(m['fond']),
      totalEncaisse: _int(m['totalEncaisse']),
      totalTheorique: _int(m['totalTheorique']),
      totalCompte: m['totalCompte'] == null ? null : _int(m['totalCompte']),
      ecart: m['ecart'] == null ? null : _int(m['ecart']),
      caissier: m['caissier'] as String? ?? '',
      verrouillee: m['verrouillee'] as bool? ?? false,
      cloture: m['cloture'] == null ? null : _date(m['cloture']),
    );
  }
}

class Ardoise {
  final String id;
  final String client;
  final String telephone;
  final int montantDu;
  final List<String> idsFactures;
  final DateTime creeLe;
  const Ardoise({
    required this.id,
    required this.client,
    required this.telephone,
    required this.montantDu,
    required this.idsFactures,
    required this.creeLe,
  });
  factory Ardoise.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Ardoise(
      id: d.id,
      client: m['client'] as String,
      telephone: m['telephone'] as String? ?? '',
      montantDu: _int(m['montantDu']),
      idsFactures: List<String>.from(m['idsFactures'] as List? ?? const []),
      creeLe: _date(m['heureAppareil']),
    );
  }
}

enum TypeValidation { annulation, remise, offert, ajustement }

enum StatutValidation { enAttente, validee, refusee }

class DemandeValidation {
  final String id;
  final TypeValidation type;
  final String demandeur;
  final String motif;
  final Map<String, dynamic> detail;
  final StatutValidation statut;
  final String? valideur;
  final DateTime date;
  const DemandeValidation({
    required this.id,
    required this.type,
    required this.demandeur,
    required this.motif,
    required this.detail,
    required this.statut,
    this.valideur,
    required this.date,
  });
  factory DemandeValidation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return DemandeValidation(
      id: d.id,
      type: TypeValidation.values.byName(m['type'] as String),
      demandeur: m['demandeur'] as String? ?? '',
      motif: m['motif'] as String? ?? '',
      detail: Map<String, dynamic>.from(m['detail'] as Map? ?? const {}),
      statut: StatutValidation.values.byName(m['statut'] as String),
      valideur: m['valideur'] as String?,
      date: _date(m['heureAppareil']),
    );
  }
}

class EntreeAudit {
  final String id;
  final String employe;
  final String appareil;
  final String action;
  final String detail;
  final DateTime date;
  const EntreeAudit({
    required this.id,
    required this.employe,
    required this.appareil,
    required this.action,
    required this.detail,
    required this.date,
  });
  factory EntreeAudit.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return EntreeAudit(
      id: d.id,
      employe: m['employe'] as String? ?? '',
      appareil: m['appareil'] as String? ?? '',
      action: m['action'] as String? ?? '',
      detail: m['detail'] as String? ?? '',
      date: _date(m['heureAppareil']),
    );
  }
}
