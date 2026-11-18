import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/calculs.dart';
import '../models/modeles.dart';
import 'db.dart';

/// Module Caisse (section 3.2) et facturation (section 4).
class CaisseService {
  final RestoDb db;
  CaisseService(this.db);

  // ---------------------------------------------------------------- Journée

  Future<JourneeCaisse?> journeeOuverte() async {
    final q = await db.journeesCaisse.where('verrouillee', isEqualTo: false).limit(1).get();
    return q.docs.isEmpty ? null : JourneeCaisse.fromDoc(q.docs.first);
  }

  /// Ouverture de caisse : saisie du fond de caisse.
  Future<String> ouvrirCaisse(Acteur caissier, int fond) async {
    if (fond < 0) throw ErreurMetier('Fond de caisse invalide');
    if (await journeeOuverte() != null) {
      throw ErreurMetier('Une journée de caisse est déjà ouverte');
    }
    final id = db.nouvelId();
    final b = db.fs.batch();
    b.set(db.journeesCaisse.doc(id), {
      ...db.meta(caissier),
      'ouverture': Timestamp.now(),
      'fond': fond,
      'totalEncaisse': 0,
      'totalTheorique': fond,
      'caissier': caissier.nom,
      'verrouillee': false,
    });
    db.audit(b, caissier, 'ouverture_caisse', 'Fond : $fond F');
    await db.envoyerSansBloquer(b);
    return id;
  }

  /// Clôture : total théorique = fond + encaissements ; l'écart s'affiche et
  /// la journée est verrouillée.
  Future<JourneeCaisse> cloturerCaisse(Acteur caissier, JourneeCaisse j, int totalCompte) async {
    if (j.verrouillee) throw ErreurMetier('Journée déjà clôturée');
    final frais = JourneeCaisse.fromDoc(await db.journeesCaisse.doc(j.id).get());
    final theorique = frais.fond + frais.totalEncaisse;
    final ecart = totalCompte - theorique;
    final b = db.fs.batch();
    b.update(db.journeesCaisse.doc(j.id), {
      'totalTheorique': theorique,
      'totalCompte': totalCompte,
      'ecart': ecart,
      'verrouillee': true,
      'cloture': Timestamp.now(),
      'cloturePar': caissier.nom,
    });
    db.audit(b, caissier, 'cloture_caisse', 'Théorique $theorique F, compté $totalCompte F, écart $ecart F');
    await db.envoyerSansBloquer(b);
    return JourneeCaisse.fromDoc(await db.journeesCaisse.doc(j.id).get());
  }

  // --------------------------------------------------------------- Factures

  Future<List<LigneCommande>> lignesSession(String idSession) async {
    final q = await db.lignes(idSession).get();
    final l = q.docs.map(LigneCommande.fromDoc).toList()..sort((a, b) => a.heure.compareTo(b.heure));
    return l;
  }

  /// Attribue le prochain numéro de la série (facture ou avoir).
  ///
  /// Seule la caisse émet les factures : le compteur est lu (depuis le cache
  /// si hors ligne) puis réécrit dans le même lot que la facture, ce qui
  /// garde une suite continue même sans connexion.
  Future<int> _prochainNumero(WriteBatch b, String serie, int annee) async {
    final snap = await db.compteurs.get();
    final m = snap.data() ?? {};
    final anneeCompteur = (m['annee_$serie'] as num?)?.toInt();
    final dernier = anneeCompteur == annee ? (m[serie] as num?)?.toInt() ?? 0 : 0;
    final n = dernier + 1;
    b.set(db.compteurs, {serie: n, 'annee_$serie': annee}, SetOptions(merge: true));
    return n;
  }

  /// Facture finale : « photo » figée des lignes au moment de l'addition.
  ///
  /// [idsLignes] limite la facture à certaines lignes (partage par article).
  /// [nombreParts] crée une facture par part égale.
  Future<List<String>> emettreFactures({
    required Acteur caissier,
    required SessionTable session,
    required Restaurant restaurant,
    Set<String>? idsLignes,
    int nombreParts = 1,
  }) async {
    if (!session.enCours) throw ErreurMetier('Cette addition est close');
    final toutes = await lignesSession(session.id);
    final restantes = toutes.where((l) => !l.annulee && l.idFacture == null).toList();
    final choisies = idsLignes == null ? restantes : restantes.where((l) => idsLignes.contains(l.id)).toList();
    if (choisies.isEmpty) throw ErreurMetier('Aucun article à facturer');
    final partielle = choisies.length < restantes.length;
    if (partielle && nombreParts > 1) {
      throw ErreurMetier('Choisissez soit le partage par article, soit en parts');
    }
    final remise = partielle ? null : session.remise;
    final tot = calculerTotaux(choisies.map((l) => l.calcul), remise: remise, tauxTva: restaurant.tauxTvaEffectif);
    final parts = partsEgales(tot.total, nombreParts);

    final b = db.fs.batch();
    final annee = DateTime.now().year;
    final premier = await _prochainNumero(b, 'facture', annee);
    final ids = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final id = db.nouvelId();
      ids.add(id);
      final numero = numeroFacture(annee, premier + i);
      b.set(db.factures.doc(id), {
        ...db.meta(caissier),
        'numero': numero,
        'idSession': session.id,
        'numeroTable': session.numeroTable,
        'nomServeuse': session.nomServeuse,
        'idServeuse': session.idServeuse,
        'nomCaissier': caissier.nom,
        'lignes': [
          for (final l in choisies) {'id': l.id, ...l.toMap()},
        ],
        'sousTotal': tot.sousTotal,
        'remise': tot.remise,
        if (remise != null) 'motifRemise': remise.motif,
        if (remise != null) 'remiseValideePar': remise.validePar,
        'tva': tvaIncluse(parts[i], restaurant.tauxTvaEffectif),
        'total': parts[i],
        if (parts.length > 1) 'partie': '${i + 1}/${parts.length}',
        'statut': StatutFacture.emise.name,
        'date': Timestamp.now(),
        'nbImpressions': 1,
      });
    }
    if (parts.length > 1) {
      b.set(db.compteurs, {'facture': premier + parts.length - 1}, SetOptions(merge: true));
    }
    for (final l in choisies) {
      b.update(db.lignes(session.id).doc(l.id), {'idFacture': ids.first});
    }
    b.update(db.sessions.doc(session.id), {
      'idsFactures': FieldValue.arrayUnion(ids),
      if (!partielle) 'statut': StatutSession.facturee.name,
    });
    if (session.idTable != null) {
      b.update(db.tables.doc(session.idTable), {'statut': StatutTable.addition.name});
    }
    await db.envoyerSansBloquer(b);
    return ids;
  }

  /// Encaissement : montant reçu, monnaie à rendre, facture « Payée ».
  Future<int> encaisser({
    required Acteur caissier,
    required Facture facture,
    required int montantRecu,
    required JourneeCaisse journee,
  }) async {
    if (journee.verrouillee) throw ErreurMetier('La caisse est clôturée');
    if (facture.statut != StatutFacture.emise) {
      throw ErreurMetier('Facture déjà réglée');
    }
    final monnaie = monnaieARendre(montantRecu, facture.total);
    final b = db.fs.batch();
    b.update(db.factures.doc(facture.id), {
      'statut': StatutFacture.payee.name,
      'montantRecu': montantRecu,
      'monnaieRendue': monnaie,
      'payeeLe': Timestamp.now(),
      'idJournee': journee.id,
    });
    b.set(db.encaissements.doc(db.nouvelId()), {
      ...db.meta(caissier),
      'type': 'facture',
      'idFacture': facture.id,
      'numeroFacture': facture.numero,
      'montant': facture.total,
      'montantRecu': montantRecu,
      'monnaieRendue': monnaie,
      'caissier': caissier.nom,
      'idJournee': journee.id,
    });
    b.update(db.journeesCaisse.doc(journee.id), {'totalEncaisse': FieldValue.increment(facture.total)});
    await _libererSiSoldee(b, facture.idSession, facture.id, StatutFacture.payee);
    await db.envoyerSansBloquer(b);
    return monnaie;
  }

  /// Vente à crédit : la facture est rattachée à une ardoise client.
  Future<void> mettreEnArdoise({
    required Acteur caissier,
    required Facture facture,
    String? idArdoise,
    String? client,
    String? telephone,
  }) async {
    if (facture.statut != StatutFacture.emise) {
      throw ErreurMetier('Facture déjà réglée');
    }
    final b = db.fs.batch();
    final id = idArdoise ?? db.nouvelId();
    if (idArdoise == null) {
      if (client == null || client.trim().isEmpty) {
        throw ErreurMetier('Nom du client obligatoire');
      }
      b.set(db.ardoises.doc(id), {
        ...db.meta(caissier),
        'client': client.trim(),
        'telephone': telephone?.trim() ?? '',
        'montantDu': facture.total,
        'idsFactures': [facture.id],
      });
    } else {
      b.update(db.ardoises.doc(id), {
        'montantDu': FieldValue.increment(facture.total),
        'idsFactures': FieldValue.arrayUnion([facture.id]),
      });
    }
    b.update(db.factures.doc(facture.id), {'statut': StatutFacture.credit.name, 'idArdoise': id});
    db.audit(b, caissier, 'ardoise', '${facture.numero} (${facture.total} F) à crédit');
    await _libererSiSoldee(b, facture.idSession, facture.id, StatutFacture.credit);
    await db.envoyerSansBloquer(b);
  }

  /// Remboursement (partiel ou total) d'une ardoise, compté dans la caisse.
  Future<void> rembourserArdoise({
    required Acteur caissier,
    required Ardoise ardoise,
    required int montant,
    required JourneeCaisse journee,
  }) async {
    if (montant <= 0 || montant > ardoise.montantDu) {
      throw ErreurMetier('Montant invalide');
    }
    if (journee.verrouillee) throw ErreurMetier('La caisse est clôturée');
    final b = db.fs.batch();
    b.update(db.ardoises.doc(ardoise.id), {'montantDu': FieldValue.increment(-montant)});
    b.set(db.ardoises.doc(ardoise.id).collection('remboursements').doc(db.nouvelId()), {
      ...db.meta(caissier),
      'montant': montant,
    });
    b.set(db.encaissements.doc(db.nouvelId()), {
      ...db.meta(caissier),
      'type': 'remboursement_ardoise',
      'idArdoise': ardoise.id,
      'client': ardoise.client,
      'montant': montant,
      'montantRecu': montant,
      'monnaieRendue': 0,
      'caissier': caissier.nom,
      'idJournee': journee.id,
    });
    b.update(db.journeesCaisse.doc(journee.id), {'totalEncaisse': FieldValue.increment(montant)});
    await db.envoyerSansBloquer(b);
  }

  /// Si toutes les lignes sont facturées et toutes les factures réglées,
  /// l'addition est close et la table redevient libre.
  Future<void> _libererSiSoldee(
    WriteBatch b,
    String idSession,
    String idFactureReglee,
    StatutFacture nouveauStatut,
  ) async {
    final s = SessionTable.fromDoc(await db.sessions.doc(idSession).get());
    if (s.statut != StatutSession.facturee) return;
    final fact = await db.factures.where('idSession', isEqualTo: idSession).get();
    final toutesReglees = fact.docs.every(
      (d) => d.id == idFactureReglee || d.data()['statut'] != StatutFacture.emise.name,
    );
    if (!toutesReglees) return;
    final credit =
        nouveauStatut == StatutFacture.credit ||
        fact.docs.any((d) => d.id != idFactureReglee && d.data()['statut'] == StatutFacture.credit.name);
    b.update(db.sessions.doc(idSession), {
      'statut': credit ? StatutSession.credit.name : StatutSession.payee.name,
      'fermeture': Timestamp.now(),
    });
    if (s.idTable != null) {
      b.update(db.tables.doc(s.idTable), {'statut': StatutTable.libre.name, 'idSession': null});
    }
  }

  /// Réimpression : tracée dans le journal, ticket marqué « DUPLICATA ».
  Future<void> noterReimpression(Acteur a, Facture f) async {
    final b = db.fs.batch();
    b.update(db.factures.doc(f.id), {'nbImpressions': FieldValue.increment(1)});
    db.audit(b, a, 'reimpression', f.numero);
    await db.envoyerSansBloquer(b);
  }

  /// Demande de remise (montant ou %) soumise à l'administrateur.
  Future<void> demanderRemise(
    Acteur a,
    SessionTable s, {
    required TypeRemise type,
    required int valeur,
    required String motif,
  }) async {
    if (motif.trim().isEmpty) throw ErreurMetier('Le motif est obligatoire');
    if (valeur <= 0 || (type == TypeRemise.pourcentage && valeur > 100)) {
      throw ErreurMetier('Valeur de remise invalide');
    }
    final b = db.fs.batch();
    b.set(db.demandesValidation.doc(db.nouvelId()), {
      ...db.meta(a),
      'type': TypeValidation.remise.name,
      'demandeur': a.nom,
      'motif': motif.trim(),
      'statut': StatutValidation.enAttente.name,
      'detail': {'idSession': s.id, 'numeroTable': s.numeroTable, 'typeRemise': type.name, 'valeur': valeur},
    });
    await db.envoyerSansBloquer(b);
  }

  /// Demande qu'une ligne soit offerte, soumise à l'administrateur.
  Future<void> demanderOffert(Acteur a, SessionTable s, LigneCommande l, String motif) async {
    if (motif.trim().isEmpty) throw ErreurMetier('Le motif est obligatoire');
    final b = db.fs.batch();
    b.set(db.demandesValidation.doc(db.nouvelId()), {
      ...db.meta(a),
      'type': TypeValidation.offert.name,
      'demandeur': a.nom,
      'motif': motif.trim(),
      'statut': StatutValidation.enAttente.name,
      'detail': {
        'idSession': s.id,
        'numeroTable': s.numeroTable,
        'idLigne': l.id,
        'nom': l.nom,
        'quantite': l.quantite,
        'montant': l.montant,
      },
    });
    await db.envoyerSansBloquer(b);
  }

  /// Avoir : une facture payée n'est jamais modifiée, on émet une facture
  /// négative liée à l'originale (administrateur uniquement).
  Future<String> creerAvoir(Acteur admin, Facture origine, int montant, String motif) async {
    if (!admin.estAdmin) throw ErreurMetier('Réservé à l’administrateur');
    if (montant <= 0 || montant > origine.total) {
      throw ErreurMetier('Montant invalide');
    }
    if (motif.trim().isEmpty) throw ErreurMetier('Le motif est obligatoire');
    final b = db.fs.batch();
    final annee = DateTime.now().year;
    final n = await _prochainNumero(b, 'avoir', annee);
    final numero = numeroAvoir(annee, n);
    b.set(db.avoirs.doc(db.nouvelId()), {
      ...db.meta(admin),
      'numero': numero,
      'idFacture': origine.id,
      'numeroFacture': origine.numero,
      'montant': -montant,
      'motif': motif.trim(),
      'validePar': admin.nom,
    });
    db.audit(b, admin, 'avoir', '$numero sur ${origine.numero} : -$montant F');
    await db.envoyerSansBloquer(b);
    return numero;
  }
}
