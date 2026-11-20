import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'pbkdf2.dart' if (dart.library.js_interop) 'pbkdf2_web.dart' as impl;

/// Codes PIN des employés : 6 à 10 chiffres, jamais stockés en clair.
///
/// Empreinte PBKDF2-SHA256 salée (même format que le serveur). Elle permet
/// à un appareil lié de vérifier un code quand internet est coupé ; en
/// ligne, c'est toujours le serveur qui vérifie (avec blocage après 5 erreurs).
const pinMin = 6;
const pinMax = 10;
const iterationsPin = 120000;

/// Message d'erreur si le code est trop faible, sinon null (mêmes règles que le serveur).
String? verifierFormatPin(String pin) {
  if (!RegExp(r'^\d+$').hasMatch(pin)) return 'Le code doit contenir uniquement des chiffres.';
  if (pin.length < pinMin || pin.length > pinMax) return 'Le code doit contenir de $pinMin à $pinMax chiffres.';
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return 'Code trop simple : tous les chiffres sont identiques.';
  if ('01234567890123456789'.contains(pin) || '98765432109876543210'.contains(pin)) return 'Code trop simple : suite de chiffres.';
  for (var p = 2; p <= pin.length ~/ 2; p++) {
    if (pin.length % p == 0 && pin.substring(0, p) * (pin.length ~/ p) == pin) return 'Code trop simple : motif répété.';
  }
  return null;
}

bool pinValide(String pin) => verifierFormatPin(pin) == null;

/// Empreinte au format `{algo, iter, sel, hash}` (base64).
Future<Map<String, dynamic>> hacherPin(String pin, {String? sel, int iterations = iterationsPin}) async {
  final s = sel ?? base64.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
  final h = await impl.pbkdf2Sha256(utf8.encode(pin), utf8.encode(s), iterations, 32);
  return {'algo': 'pbkdf2-sha256', 'iter': iterations, 'sel': s, 'hash': base64.encode(h)};
}

Future<bool> pinCorrect(String pin, Map<String, dynamic>? verif) async {
  if (verif == null || verif['sel'] is! String || verif['hash'] is! String) return false;
  final h = await impl.pbkdf2Sha256(utf8.encode(pin), utf8.encode(verif['sel'] as String), (verif['iter'] as num?)?.toInt() ?? iterationsPin, 32);
  final attendu = base64.decode(verif['hash'] as String);
  return _egal(h, attendu);
}

bool _egal(Uint8List a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}
