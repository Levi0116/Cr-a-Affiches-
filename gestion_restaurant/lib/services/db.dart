import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/modeles.dart';

/// Qui fait l'action (traçabilité : section 1.3 et 5.2).
class Acteur {
  final String id;
  final String nom;
  final Role role;
  const Acteur({required this.id, required this.nom, required this.role});
  factory Acteur.de(Employe e) => Acteur(id: e.id, nom: e.nom, role: e.role);
  bool get estAdmin => role == Role.admin;
}

/// Accès à Firestore pour un restaurant donné.
///
/// Toutes les écritures passent par [envoyer] : elles sont appliquées tout de
/// suite dans le cache local (donc visibles même hors ligne) puis envoyées au
/// serveur dès que la connexion le permet. [enAttente] compte les envois non
/// encore confirmés, pour l'indicateur « Hors ligne – N actions en attente ».
class RestoDb {
  final FirebaseFirestore fs;
  final String idRestaurant;
  final String appareil;
  final ValueNotifier<int> enAttente = ValueNotifier(0);
  final ValueNotifier<String?> derniereErreur = ValueNotifier(null);
  static const _uuid = Uuid();

  RestoDb({required this.fs, required this.idRestaurant, required this.appareil});

  DocumentReference<Map<String, dynamic>> get resto => fs.collection('restaurants').doc(idRestaurant);

  CollectionReference<Map<String, dynamic>> col(String nom) => resto.collection(nom);

  CollectionReference<Map<String, dynamic>> get employes => col('employes');
  CollectionReference<Map<String, dynamic>> get zones => col('zones');
  CollectionReference<Map<String, dynamic>> get tables => col('tables');
  CollectionReference<Map<String, dynamic>> get categories => col('categories');
  CollectionReference<Map<String, dynamic>> get articles => col('articles');
  CollectionReference<Map<String, dynamic>> get recettes => col('recettes');
  CollectionReference<Map<String, dynamic>> get appareils => col('appareils');
  CollectionReference<Map<String, dynamic>> get notifications => col('notifications');
  CollectionReference<Map<String, dynamic>> get rapportsJour => col('rapportsJour');

  /// Version minimale / dernière version de l'application (hors restaurant).
  DocumentReference<Map<String, dynamic>> get configVersion => fs.collection('config').doc('version');
  CollectionReference<Map<String, dynamic>> get sessions => col('sessions');
  CollectionReference<Map<String, dynamic>> lignes(String idSession) => sessions.doc(idSession).collection('lignes');
  CollectionReference<Map<String, dynamic>> get factures => col('factures');
  CollectionReference<Map<String, dynamic>> get encaissements => col('encaissements');
  CollectionReference<Map<String, dynamic>> get avoirs => col('avoirs');
  CollectionReference<Map<String, dynamic>> get mouvementsStock => col('mouvementsStock');
  CollectionReference<Map<String, dynamic>> get fournisseurs => col('fournisseurs');
  CollectionReference<Map<String, dynamic>> get livraisons => col('livraisons');
  CollectionReference<Map<String, dynamic>> get journeesCaisse => col('journeesCaisse');
  CollectionReference<Map<String, dynamic>> get ardoises => col('ardoises');
  CollectionReference<Map<String, dynamic>> get depenses => col('depenses');
  CollectionReference<Map<String, dynamic>> get demandesValidation => col('demandesValidation');
  CollectionReference<Map<String, dynamic>> get journalAudit => col('journalAudit');
  CollectionReference<Map<String, dynamic>> get historiquePrix => col('historiquePrix');
  DocumentReference<Map<String, dynamic>> get compteurs => col('compteurs').doc('principal');

  /// Identifiant unique créé sur l'appareil (évite les doublons, section 6.4).
  String nouvelId() => _uuid.v4();

  /// Champs présents dans chaque document : heure serveur + heure appareil.
  Map<String, dynamic> meta(Acteur a) => {
    'creeLe': FieldValue.serverTimestamp(),
    'heureAppareil': Timestamp.now(),
    'creePar': a.id,
    'appareil': appareil,
  };

  Map<String, dynamic> modif(Acteur a) => {'modifieLe': FieldValue.serverTimestamp(), 'modifiePar': a.id};

  /// Ajoute une entrée au journal d'audit dans le même lot d'écriture.
  void audit(WriteBatch b, Acteur a, String action, String detail) {
    b.set(journalAudit.doc(nouvelId()), {
      ...meta(a),
      'employe': a.nom,
      'idEmploye': a.id,
      'action': action,
      'detail': detail,
    });
  }

  /// Envoie un lot d'écritures (tout ou rien).
  ///
  /// Hors ligne, le Future ne se termine qu'au retour de la connexion :
  /// l'interface ne doit donc pas l'attendre pour continuer.
  Future<void> envoyer(WriteBatch b) {
    enAttente.value++;
    return b
        .commit()
        .catchError((Object e) {
          derniereErreur.value = '$e';
          throw e;
        })
        .whenComplete(() => enAttente.value--);
  }

  /// Pour les actions faisables hors ligne : on n'attend pas l'accusé du
  /// serveur, l'écriture est déjà dans le cache local. On remonte seulement
  /// les erreurs immédiates (règles de sécurité, données invalides).
  Future<void> envoyerSansBloquer(WriteBatch b) async {
    final f = envoyer(b);
    f.ignore();
    await Future.any([f, Future<void>.delayed(const Duration(milliseconds: 300))]);
  }
}

/// Erreur métier affichable à l'utilisateur.
class ErreurMetier implements Exception {
  final String message;
  ErreurMetier(this.message);
  @override
  String toString() => message;
}
