import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// PBKDF2-HMAC-SHA256 par le moteur cryptographique du navigateur (rapide).
Future<Uint8List> pbkdf2Sha256(List<int> motDePasse, List<int> sel, int iterations, int longueur) async {
  final subtle = web.window.crypto.subtle;
  final cle = await subtle
      .importKey('raw', Uint8List.fromList(motDePasse).toJS, 'PBKDF2'.toJS, false, ['deriveBits'.toJS].toJS)
      .toDart;
  final params = JSObject()
    ..setProperty('name'.toJS, 'PBKDF2'.toJS)
    ..setProperty('hash'.toJS, 'SHA-256'.toJS)
    ..setProperty('salt'.toJS, Uint8List.fromList(sel).toJS)
    ..setProperty('iterations'.toJS, iterations.toJS);
  final bits = await subtle.deriveBits(params, cle, longueur * 8).toDart;
  return bits.toDart.asUint8List();
}
