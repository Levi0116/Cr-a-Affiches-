import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/pin.dart';
import 'db.dart';

/// État de liaison de cet appareil (jetons du compte Firebase).
class EtatAppareil {
  final String uid;
  final String? restaurantId;
  final bool admin;
  final DateTime? adminJusqua;
  const EtatAppareil({required this.uid, this.restaurantId, this.admin = false, this.adminJusqua});

  bool get lie => restaurantId != null;
  bool get adminActif => admin || (adminJusqua?.isAfter(DateTime.now()) ?? false);
}

/// Code de liaison à usage unique, affiché en QR code (valable 15 minutes).
class CodeLiaison {
  final String code;
  final DateTime expire;
  final String restaurantId;
  const CodeLiaison({required this.code, required this.expire, required this.restaurantId});

  /// Contenu du QR code : préfixe + code (le restaurant est déduit côté serveur).
  String get contenuQr => 'AMANI-LIAISON:$code';

  static String? lireQr(String brut) {
    final m = RegExp(r'([A-Z2-9]{6})$').firstMatch(brut.trim().toUpperCase());
    return m?.group(1);
  }
}

enum TypeAppareil {
  tablette('Tablette serveuse'),
  caisse('Ordinateur de caisse'),
  telephone('Téléphone');

  final String libelle;
  const TypeAppareil(this.libelle);
}

/// Opérations de sécurité qui passent par le serveur (Cloud Functions).
abstract class ServeurAppareils {
  Future<EtatAppareil> etat({bool rafraichir = false});
  Future<EtatAppareil> lier(String code);
  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false});

  /// Droits administrateur temporaires après vérification du PIN côté serveur.
  Future<DateTime> elevationAdmin({required String idEmploye, required String pin});
  Future<void> finElevation();
  Future<void> revoquer(String uid);
}

// ============================================================ Firebase

/// Implémentation réelle : compte anonyme Firebase + Cloud Functions.
class ServeurFirebase implements ServeurAppareils {
  final FirebaseAuth auth;
  final FirebaseFunctions fonctions;
  ServeurFirebase({FirebaseAuth? auth, FirebaseFunctions? fonctions, String region = 'europe-west1'})
    : auth = auth ?? FirebaseAuth.instance,
      fonctions = fonctions ?? FirebaseFunctions.instanceFor(region: region);

  Future<User> _utilisateur() async => auth.currentUser ?? (await auth.signInAnonymously()).user!;

  @override
  Future<EtatAppareil> etat({bool rafraichir = false}) async {
    final u = await _utilisateur();
    final r = await u.getIdTokenResult(rafraichir);
    final c = r.claims ?? const {};
    final jusqua = c['adminJusqua'];
    return EtatAppareil(
      uid: u.uid,
      restaurantId: c['restaurantId'] as String?,
      admin: c['admin'] == true,
      adminJusqua: jusqua is num ? DateTime.fromMillisecondsSinceEpoch((jusqua * 1000).round()) : null,
    );
  }

  Future<Map<String, dynamic>> _appeler(String nom, Map<String, dynamic> donnees) async {
    await _utilisateur();
    try {
      final r = await fonctions.httpsCallable(nom).call<Object?>(donnees);
      return Map<String, dynamic>.from((r.data as Map?) ?? const {});
    } on FirebaseFunctionsException catch (e) {
      throw ErreurMetier(e.message ?? 'Erreur du serveur (${e.code})');
    }
  }

  @override
  Future<EtatAppareil> lier(String code) async {
    await _appeler('lierAppareil', {'code': code});
    return etat(rafraichir: true);
  }

  @override
  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false}) async {
    final r = await _appeler('creerCodeLiaison', {'nom': nom, 'type': type.name, 'admin': admin});
    return CodeLiaison(
      code: r['code'] as String,
      expire: DateTime.fromMillisecondsSinceEpoch((r['expire'] as num).toInt()),
      restaurantId: r['restaurantId'] as String,
    );
  }

  @override
  Future<DateTime> elevationAdmin({required String idEmploye, required String pin}) async {
    final r = await _appeler('elevationAdmin', {'idEmploye': idEmploye, 'pin': pin});
    await etat(rafraichir: true); // les règles Firestore voient le nouveau jeton
    return DateTime.fromMillisecondsSinceEpoch((r['jusqua'] as num).toInt());
  }

  @override
  Future<void> finElevation() async {
    await _appeler('finElevationAdmin', const {});
    await etat(rafraichir: true);
  }

  @override
  Future<void> revoquer(String uid) => _appeler('revoquerAppareil', {'uid': uid});
}

// ======================================================= Démonstration

/// Mode démonstration : même comportement, simulé sur la base en mémoire.
class ServeurDemo implements ServeurAppareils {
  final RestoDb db;
  final _codes = <String, CodeLiaison>{};
  ServeurDemo(this.db);

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  @override
  Future<EtatAppareil> etat({bool rafraichir = false}) async =>
      EtatAppareil(uid: 'appareil-demo', restaurantId: db.idRestaurant, admin: true);

  @override
  Future<EtatAppareil> lier(String code) async {
    final c = _codes.remove(code.toUpperCase());
    if (c == null) throw ErreurMetier('Code inconnu.');
    if (c.expire.isBefore(DateTime.now())) throw ErreurMetier('Ce code a expiré.');
    return etat();
  }

  @override
  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false}) async {
    if (nom.trim().isEmpty) throw ErreurMetier('Donnez un nom à l’appareil.');
    final r = Random.secure();
    final code = List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    final c = CodeLiaison(
      code: code,
      expire: DateTime.now().add(const Duration(minutes: 15)),
      restaurantId: db.idRestaurant,
    );
    _codes[code] = c;
    // En démonstration, l'appareil est « lié » aussitôt pour peupler la liste.
    await db.appareils.doc('demo-${code.toLowerCase()}').set({
      'nom': nom.trim(),
      'type': type.name,
      'admin': admin && type == TypeAppareil.telephone,
      'actif': true,
      'lieLe': DateTime.now(),
    });
    return c;
  }

  @override
  Future<DateTime> elevationAdmin({required String idEmploye, required String pin}) async {
    final e = (await db.employes.doc(idEmploye).get()).data();
    final ok =
        e != null &&
        e['role'] == 'admin' &&
        e['pinHash'] == hacherPin(idRestaurant: db.idRestaurant, idEmploye: idEmploye, pin: pin);
    if (!ok) throw ErreurMetier('Code incorrect.');
    return DateTime.now().add(const Duration(minutes: 15));
  }

  @override
  Future<void> finElevation() async {}

  @override
  Future<void> revoquer(String uid) async {
    await db.appareils.doc(uid).update({'actif': false, 'retireLe': DateTime.now()});
  }
}
