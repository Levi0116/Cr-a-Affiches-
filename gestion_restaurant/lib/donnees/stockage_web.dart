import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'stockage.dart';

const _magasin = 'kv';

Future<T?> _attendre<T extends JSAny?>(web.IDBRequest r) {
  final c = Completer<T?>();
  r.onsuccess = ((web.Event _) => c.complete(r.result as T?)).toJS;
  r.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB : ${r.error?.message}'))).toJS;
  return c.future;
}

Future<void> _fin(web.IDBTransaction t) {
  final c = Completer<void>();
  t.oncomplete = ((web.Event _) => c.complete()).toJS;
  t.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB : ${t.error?.message}'))).toJS;
  t.onabort = ((web.Event _) => c.completeError(StateError('IndexedDB : transaction annulée'))).toJS;
  return c.future;
}

Future<Stockage> ouvrirStockage(String nom) async {
  final req = web.window.indexedDB.open(nom, 1);
  req.onupgradeneeded = ((web.Event _) {
    final db = req.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_magasin)) db.createObjectStore(_magasin);
  }).toJS;
  final db = await _attendre<web.IDBDatabase>(req);
  // Demande au navigateur de ne pas effacer ces données en cas de manque de place.
  try {
    unawaited(web.window.navigator.storage.persist().toDart);
  } catch (_) {}
  return _StockageIdb(db!);
}

class _StockageIdb implements Stockage {
  final web.IDBDatabase db;
  _StockageIdb(this.db);

  web.IDBObjectStore _ouvrir(web.IDBTransaction t) => t.objectStore(_magasin);

  @override
  Future<Map<String, String>> toutLire() async {
    final t = db.transaction(_magasin.toJS, 'readonly');
    final s = _ouvrir(t);
    final cles = await _attendre<JSArray<JSAny?>>(s.getAllKeys());
    final valeurs = await _attendre<JSArray<JSAny?>>(s.getAll());
    final k = cles!.toDart;
    final v = valeurs!.toDart;
    return {for (var i = 0; i < k.length; i++) (k[i] as JSString).toDart: (v[i] as JSString).toDart};
  }

  @override
  Future<void> ecrire(String cle, String valeur) => ecrireTout({cle: valeur});

  @override
  Future<void> ecrireTout(Map<String, String> valeurs) async {
    if (valeurs.isEmpty) return;
    final t = db.transaction(_magasin.toJS, 'readwrite');
    final s = _ouvrir(t);
    valeurs.forEach((k, v) => s.put(v.toJS, k.toJS));
    await _fin(t);
  }

  @override
  Future<void> supprimerTout(List<String> cles) async {
    if (cles.isEmpty) return;
    final t = db.transaction(_magasin.toJS, 'readwrite');
    final s = _ouvrir(t);
    for (final k in cles) {
      s.delete(k.toJS);
    }
    await _fin(t);
  }

  @override
  Future<void> vider() async {
    final t = db.transaction(_magasin.toJS, 'readwrite');
    _ouvrir(t).clear();
    await _fin(t);
  }
}
