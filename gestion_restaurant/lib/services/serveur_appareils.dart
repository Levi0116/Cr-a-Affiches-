import 'dart:async';
import 'dart:math';

import '../core/pin.dart';
import '../donnees/api.dart';
import '../donnees/base.dart';
import '../models/modeles.dart';
import 'db.dart';

/// Code de liaison à usage unique, affiché en QR code (valable 15 minutes).
class CodeLiaison {
  final String code;
  final DateTime expire;
  const CodeLiaison({required this.code, required this.expire});

  /// Contenu du QR code.
  String get contenuQr => 'AMANI-LIAISON:$code';

  static String? lireQr(String brut) {
    final m = RegExp(r'([A-Z2-9]{8})$').firstMatch(brut.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9:]'), ''));
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

/// Résultat d'une connexion par code PIN.
class Connexion {
  final Employe employe;

  /// Vrai si le serveur a vérifié le code (session ouverte en ligne).
  final bool enLigne;
  const Connexion(this.employe, {required this.enLigne});
}

/// Opérations de sécurité : connexion des employés, comptes (réservés à
/// l'administrateur), liaison et retrait des appareils.
abstract class ServeurAppareils {
  /// Téléphone du gérant : droits administrateur permanents.
  bool get appareilAdmin;

  /// Droits administrateur utilisables maintenant (session vérifiée en ligne
  /// ou téléphone du gérant).
  bool droitsAdmin(Employe? e);

  Future<Connexion> connecter(Employe e, String pin);
  void deconnecter();

  Future<void> creerEmploye({required String nom, required Role role, required String pin});
  Future<void> modifierEmploye(String id, {String? nom, Role? role, bool? actif, String? pin});
  Future<void> supprimerEmploye(String id);

  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false});
  Future<void> revoquer(String idAppareil);
}

String _texte(Object e) => e is ErreurApi ? e.message : '$e';

// ============================================================ Serveur Node.js

class ServeurApi implements ServeurAppareils {
  final Api api;
  final BaseLocale base;
  @override
  final bool appareilAdmin;
  bool _sessionEnLigne = false;
  ServeurApi({required this.api, required this.base, required this.appareilAdmin});

  @override
  bool droitsAdmin(Employe? e) => e?.role == Role.admin && (appareilAdmin || _sessionEnLigne);

  @override
  Future<Connexion> connecter(Employe e, String pin) async {
    try {
      final r = await api.connexion(e.id, pin).timeout(const Duration(seconds: 10));
      api.session = r['session'] as String;
      base
        ..auteur = e.id
        ..session = api.session;
      _sessionEnLigne = true;
      return Connexion(e, enLigne: true);
    } on ErreurApi catch (err) {
      if (!err.horsLigne) throw ErreurMetier(err.message);
    } on TimeoutException {
      // serveur injoignable : vérification locale ci-dessous
    }
    // Hors ligne : vérification sur l'appareil (empreinte salée).
    if (!await pinCorrect(pin, e.pinVerif)) throw ErreurMetier('Code incorrect');
    api.session = null;
    base
      ..auteur = e.id
      ..session = null;
    _sessionEnLigne = false;
    return Connexion(e, enLigne: false);
  }

  @override
  void deconnecter() {
    api.session = null;
    base
      ..auteur = null
      ..session = null;
    _sessionEnLigne = false;
  }

  Future<T> _admin<T>(Future<T> Function() f) async {
    if (!_sessionEnLigne) throw ErreurMetier('Action réservée à l’administrateur connecté en ligne : vérifiez internet puis reconnectez-vous.');
    try {
      return await f();
    } on ErreurApi catch (e) {
      throw ErreurMetier(_texte(e));
    }
  }

  @override
  Future<void> creerEmploye({required String nom, required Role role, required String pin}) {
    final e = verifierFormatPin(pin);
    if (e != null) throw ErreurMetier(e);
    return _admin(() => api.creerEmploye(nom: nom.trim(), role: role.name, pin: pin));
  }

  @override
  Future<void> modifierEmploye(String id, {String? nom, Role? role, bool? actif, String? pin}) {
    if (pin != null) {
      final e = verifierFormatPin(pin);
      if (e != null) throw ErreurMetier(e);
    }
    return _admin(
      () => api.modifierEmploye(id, {
        if (nom != null) 'nom': nom.trim(),
        if (role != null) 'role': role.name,
        if (actif != null) 'actif': actif,
        if (pin != null) 'pin': pin,
      }),
    );
  }

  @override
  Future<void> supprimerEmploye(String id) => _admin(() => api.supprimerEmploye(id));

  @override
  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false}) => _admin(() async {
    final r = await api.creerCodeLiaison(type: type.name, nom: nom.trim(), admin: admin);
    return CodeLiaison(code: r['code'] as String, expire: DateTime.parse(r['expire'] as String).toLocal());
  });

  @override
  Future<void> revoquer(String idAppareil) => _admin(() => api.retirerAppareil(idAppareil));
}

// ======================================================= Démonstration

/// Mode démonstration (sans serveur) : mêmes règles, simulées sur la base locale.
class ServeurDemo implements ServeurAppareils {
  final RestoDb db;
  ServeurDemo(this.db);

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  @override
  bool get appareilAdmin => false;

  @override
  bool droitsAdmin(Employe? e) => e?.role == Role.admin;

  @override
  Future<Connexion> connecter(Employe e, String pin) async {
    if (!await pinCorrect(pin, e.pinVerif)) throw ErreurMetier('Code incorrect');
    db.fs.auteur = e.id;
    return Connexion(e, enLigne: true);
  }

  @override
  void deconnecter() => db.fs.auteur = null;

  Future<List<Employe>> _actifs() async =>
      (await db.employes.get()).docs.map(Employe.fromDoc).where((e) => !e.supprime).toList();

  Future<void> _pinLibre(String pin, [String? sauf]) async {
    for (final e in await _actifs()) {
      if (e.id != sauf && await pinCorrect(pin, e.pinVerif)) throw ErreurMetier('Ce code est déjà utilisé par un autre employé.');
    }
  }

  Future<void> _resteUnAdmin(String sauf) async {
    if (!(await _actifs()).any((e) => e.id != sauf && e.role == Role.admin && e.actif)) {
      throw ErreurMetier('Il doit toujours rester au moins un administrateur actif.');
    }
  }

  @override
  Future<void> creerEmploye({required String nom, required Role role, required String pin}) async {
    final err = verifierFormatPin(pin);
    if (err != null) throw ErreurMetier(err);
    if (nom.trim().length < 2) throw ErreurMetier('Nom trop court.');
    await _pinLibre(pin);
    await db.employes.doc(db.nouvelId()).set({
      'nom': nom.trim(),
      'role': role.name,
      'actif': true,
      'supprime': false,
      'pinVerif': await hacherPin(pin),
      'creeLe': Timestamp.now(),
    });
  }

  @override
  Future<void> modifierEmploye(String id, {String? nom, Role? role, bool? actif, String? pin}) async {
    final avant = Employe.fromDoc(await db.employes.doc(id).get());
    if (pin != null) {
      final err = verifierFormatPin(pin);
      if (err != null) throw ErreurMetier(err);
      await _pinLibre(pin, id);
    }
    if (avant.role == Role.admin && ((role != null && role != Role.admin) || actif == false)) await _resteUnAdmin(id);
    await db.employes.doc(id).set({
      if (nom != null) 'nom': nom.trim(),
      if (role != null) 'role': role.name,
      if (actif != null) 'actif': actif,
      if (pin != null) 'pinVerif': await hacherPin(pin),
      'modifieLe': Timestamp.now(),
    }, const SetOptions(merge: true));
  }

  @override
  Future<void> supprimerEmploye(String id) async {
    if (id == db.fs.auteur) throw ErreurMetier('Vous ne pouvez pas supprimer votre propre compte.');
    final e = Employe.fromDoc(await db.employes.doc(id).get());
    if (e.role == Role.admin) await _resteUnAdmin(id);
    await db.employes.doc(id).set({'actif': false, 'supprime': true, 'pinVerif': null}, const SetOptions(merge: true));
  }

  @override
  Future<CodeLiaison> creerCode({required String nom, required TypeAppareil type, bool admin = false}) async {
    if (nom.trim().isEmpty) throw ErreurMetier('Donnez un nom à l’appareil.');
    final r = Random.secure();
    final code = List.generate(8, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    // En démonstration, l'appareil apparaît aussitôt dans la liste.
    await db.appareils.doc('demo-${code.toLowerCase()}').set({
      'nom': nom.trim(),
      'type': type.name,
      'admin': admin && type == TypeAppareil.telephone,
      'revoque': false,
      'lieLe': Timestamp.now(),
    });
    return CodeLiaison(code: code, expire: DateTime.now().add(const Duration(minutes: 15)));
  }

  @override
  Future<void> revoquer(String idAppareil) =>
      db.appareils.doc(idAppareil).set({'revoque': true, 'revoqueLe': Timestamp.now()}, const SetOptions(merge: true));
}
