import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (implémentation Dart : tests et plateformes hors web).
Future<Uint8List> pbkdf2Sha256(List<int> motDePasse, List<int> sel, int iterations, int longueur) async {
  final hmac = Hmac(sha256, motDePasse);
  final resultat = BytesBuilder();
  var bloc = 1;
  while (resultat.length < longueur) {
    final entree = Uint8List.fromList([...sel, (bloc >> 24) & 0xff, (bloc >> 16) & 0xff, (bloc >> 8) & 0xff, bloc & 0xff]);
    var u = hmac.convert(entree).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    resultat.add(t);
    bloc++;
  }
  return Uint8List.fromList(resultat.toBytes().sublist(0, longueur));
}
