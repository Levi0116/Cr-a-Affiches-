import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur renvoyée par le serveur, avec un message lisible.
class ErreurApi implements Exception {
  final int statut;
  final String message;
  final String code;
  ErreurApi(this.statut, this.message, [this.code = 'erreur']);
  bool get horsLigne => statut == 0;
  bool get appareilRetire => code == 'appareil_revoque' || code == 'appareil_absent';
  @override
  String toString() => message;
}

/// Client de l'API Node.js (même origine que la PWA par défaut).
class Api {
  final Uri base;
  final http.Client _http;
  String? jetonAppareil;
  String? session;

  Api({Uri? base, http.Client? client, this.jetonAppareil})
    : base = base ?? Uri.base.resolve('/api/'),
      _http = client ?? http.Client();

  /// Adresse du serveur : `--dart-define=API=https://…/api/`, sinon même origine.
  static Uri adresseParDefaut() {
    const configuree = String.fromEnvironment('API');
    return configuree.isEmpty ? Uri.base.resolve('/api/') : Uri.parse(configuree.endsWith('/') ? configuree : '$configuree/');
  }

  Map<String, String> get _entetes => {
    'content-type': 'application/json',
    if (jetonAppareil != null) 'authorization': 'Appareil $jetonAppareil',
    if (session != null) 'x-session': session!,
  };

  Future<Map<String, dynamic>> appel(String methode, String chemin, {Object? corps, Duration delai = const Duration(seconds: 20)}) async {
    final uri = base.resolve(chemin);
    http.Response r;
    try {
      final req = http.Request(methode, uri)..headers.addAll(_entetes);
      if (corps != null) req.body = jsonEncode(corps);
      r = await http.Response.fromStream(await _http.send(req).timeout(delai));
    } catch (_) {
      throw ErreurApi(0, 'Pas de connexion au serveur.', 'hors_ligne');
    }
    Map<String, dynamic> json;
    try {
      json = r.body.isEmpty ? {} : jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ErreurApi(r.statusCode, 'Réponse inattendue du serveur (${r.statusCode}).');
    }
    if (r.statusCode >= 400) {
      throw ErreurApi(r.statusCode, json['erreur'] as String? ?? 'Erreur ${r.statusCode}', json['code'] as String? ?? 'erreur');
    }
    return json;
  }

  Future<Map<String, dynamic>> lier(String code) => appel('POST', 'liaison', corps: {'code': code});
  Future<Map<String, dynamic>> etatAppareil() => appel('GET', 'appareil');
  Future<Map<String, dynamic>> connexion(String idEmploye, String pin) =>
      appel('POST', 'connexion', corps: {'employeId': idEmploye, 'pin': pin});

  Future<Map<String, dynamic>> creerEmploye({required String nom, required String role, required String pin}) =>
      appel('POST', 'employes', corps: {'nom': nom, 'role': role, 'pin': pin});
  Future<Map<String, dynamic>> modifierEmploye(String id, Map<String, Object?> champs) => appel('PATCH', 'employes/$id', corps: champs);
  Future<Map<String, dynamic>> supprimerEmploye(String id) => appel('DELETE', 'employes/$id');

  Future<Map<String, dynamic>> creerCodeLiaison({required String type, required String nom, bool admin = false}) =>
      appel('POST', 'appareils/codes', corps: {'type': type, 'nom': nom, 'admin': admin});
  Future<Map<String, dynamic>> retirerAppareil(String id) => appel('DELETE', 'appareils/$id');

  Future<Map<String, dynamic>> pull(int depuis) => appel('GET', 'sync/pull?depuis=$depuis', delai: const Duration(seconds: 60));
  Future<Map<String, dynamic>> attendre(int depuis) => appel('GET', 'sync/attendre?depuis=$depuis', delai: const Duration(seconds: 40));
  Future<Map<String, dynamic>> push(List<Map<String, dynamic>> lots) =>
      appel('POST', 'sync/push', corps: {'lots': lots}, delai: const Duration(seconds: 60));
}
