/// Base de données locale « d'abord hors ligne ».
///
/// Toutes les lectures se font sur la copie locale (instantané, même sans
/// réseau). Les écritures sont appliquées tout de suite sur cette copie puis
/// placées dans une file d'attente persistante ([Lot]) que la [Synchro]
/// envoie au serveur Node.js dès que possible. Les modifications des autres
/// appareils arrivent par la même synchronisation.
///
/// L'API reprend volontairement le vocabulaire de Firestore (collection,
/// doc, where, snapshots, batch, FieldValue…) utilisé par la version 1 :
/// les services métier n'ont presque pas changé.
library;

import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'stockage.dart';

// ============================================================== Valeurs

/// Horodatage (précision : milliseconde).
class Timestamp implements Comparable<Timestamp> {
  final int millisecondsSinceEpoch;
  const Timestamp.fromMillisecondsSinceEpoch(this.millisecondsSinceEpoch);
  Timestamp.fromDate(DateTime d) : millisecondsSinceEpoch = d.millisecondsSinceEpoch;
  factory Timestamp.now() => Timestamp.fromDate(DateTime.now());
  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  @override
  int compareTo(Timestamp o) => millisecondsSinceEpoch.compareTo(o.millisecondsSinceEpoch);
  @override
  bool operator ==(Object o) => o is Timestamp && o.millisecondsSinceEpoch == millisecondsSinceEpoch;
  @override
  int get hashCode => millisecondsSinceEpoch.hashCode;
  @override
  String toString() => 'Timestamp(${toDate().toIso8601String()})';
}

/// Valeurs calculées au moment de l'écriture (côté appareil puis serveur).
class FieldValue {
  final String _op;
  final Object? _valeur;
  const FieldValue._(this._op, [this._valeur]);
  static FieldValue increment(num n) => FieldValue._('inc', n);
  static FieldValue serverTimestamp() => const FieldValue._('now');
  static FieldValue arrayUnion(List<Object?> v) => FieldValue._('union', v);
  static FieldValue delete() => const FieldValue._('del');
}

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

/// Erreur renvoyée quand le serveur refuse une écriture (droits).
class ErreurEcriture implements Exception {
  final String message;
  ErreurEcriture(this.message);
  @override
  String toString() => message;
}

// ------------------------------------------------ Encodage JSON (serveur)

Object? encoder(Object? v) {
  if (v is Timestamp) return {'__t': v.millisecondsSinceEpoch};
  if (v is DateTime) return {'__t': v.millisecondsSinceEpoch};
  if (v is FieldValue) {
    return switch (v._op) {
      'inc' => {'__op': 'inc', 'n': v._valeur},
      'union' => {'__op': 'union', 'v': encoder(v._valeur)},
      _ => {'__op': v._op},
    };
  }
  if (v is Map) return {for (final e in v.entries) '${e.key}': encoder(e.value)};
  if (v is Iterable) return [for (final x in v) encoder(x)];
  return v;
}

Object? decoder(Object? v) {
  if (v is Map) {
    if (v.length == 1 && v['__t'] is num) return Timestamp.fromMillisecondsSinceEpoch((v['__t'] as num).toInt());
    return <String, dynamic>{for (final e in v.entries) '${e.key}': decoder(e.value)};
  }
  if (v is List) return [for (final x in v) decoder(x)];
  return v;
}

Map<String, dynamic> _decoderDoc(Object? v) => (decoder(v) as Map<String, dynamic>?) ?? <String, dynamic>{};

/// Applique une valeur encodée (`__op`) sur l'ancienne valeur (mêmes règles que le serveur).
Object? _resoudre(Object? v, Object? ancien, int maintenant) {
  if (v is Map && v['__op'] is String) {
    switch (v['__op']) {
      case 'now':
        return Timestamp.fromMillisecondsSinceEpoch(maintenant);
      case 'inc':
        final n = v['n'] as num? ?? 0;
        return (ancien is num ? ancien : 0) + n;
      case 'union':
        final base = ancien is List ? [...ancien] : <Object?>[];
        for (final x in (v['v'] as List? ?? const [])) {
          final d = decoder(x);
          if (!base.any((b) => jsonEncode(encoder(b)) == jsonEncode(encoder(d)))) base.add(d);
        }
        return base;
      case 'del':
        return _supprime;
    }
  }
  if (v is Map && !(v.length == 1 && v.containsKey('__t'))) {
    final r = <String, dynamic>{};
    v.forEach((k, x) {
      final y = _resoudre(x, ancien is Map ? ancien[k] : null, maintenant);
      if (!identical(y, _supprime)) r['$k'] = y;
    });
    return r;
  }
  return decoder(v);
}

const _supprime = Object();

Map<String, dynamic>? appliquerOp(Map<String, dynamic>? existant, Map<String, dynamic> op, int maintenant) {
  final donnees = (op['donnees'] as Map?) ?? const {};
  if (op['type'] == 'set' && !(op['fusion'] == true && existant != null)) {
    return _resoudre(donnees, null, maintenant) as Map<String, dynamic>;
  }
  if (op['type'] == 'update' && existant == null) return null; // refusé par le serveur aussi
  final r = Map<String, dynamic>.of(existant ?? {});
  donnees.forEach((k, v) {
    final y = _resoudre(v, r[k], maintenant);
    if (identical(y, _supprime)) {
      r.remove(k);
    } else {
      r['$k'] = y;
    }
  });
  return r;
}

// ================================================================ Lots

/// Écritures groupées (tout ou rien), conservées jusqu'à l'accord du serveur.
class Lot {
  final String id;
  final List<Map<String, dynamic>> ops; // {type, chemin, donnees, fusion} encodés
  final String? auteur;
  final String? session;
  final int faitLe;
  Lot({required this.id, required this.ops, this.auteur, this.session, required this.faitLe});

  Map<String, dynamic> versJson() => {'id': id, 'ops': ops, 'auteur': auteur, 'session': session, 'faitLe': faitLe};
  factory Lot.deJson(Map<String, dynamic> j) => Lot(
    id: j['id'] as String,
    ops: [for (final o in j['ops'] as List) Map<String, dynamic>.from(o as Map)],
    auteur: j['auteur'] as String?,
    session: j['session'] as String?,
    faitLe: (j['faitLe'] as num).toInt(),
  );
}

// ========================================================= Base locale

class BaseLocale {
  final Stockage stockage;
  BaseLocale(this.stockage);

  /// Base en mémoire, sans serveur (démonstration et tests) : chaque écriture
  /// est acceptée immédiatement.
  factory BaseLocale.autonome() {
    final b = BaseLocale(StockageMemoire());
    b.surNouveauLot = () => scheduleMicrotask(() => b.accepterLocalement());
    return b;
  }

  /// Documents confirmés par le serveur (chemin complet → données).
  final Map<String, Map<String, dynamic>> _base = {};

  /// Lots non encore confirmés, dans l'ordre.
  final List<Lot> _attente = [];

  /// Vue visible = base + lots en attente rejoués.
  final Map<String, Map<String, dynamic>> _vue = {};

  final _changements = StreamController<Set<String>>.broadcast(sync: true);
  final Map<String, Completer<void>> _accuses = {};
  int revision = 0;

  /// Auteur et session des prochaines écritures (employé connecté).
  String? auteur;
  String? session;

  /// Appelé à chaque nouveau lot (la synchronisation se réveille).
  void Function()? surNouveauLot;

  static const _uuid = Uuid();

  int get nbEnAttente => _attente.length;
  List<Lot> get lotsEnAttente => List.unmodifiable(_attente);

  /// Recharge la copie locale enregistrée (au démarrage).
  Future<void> ouvrir() async {
    final tout = await stockage.toutLire();
    for (final e in tout.entries) {
      if (e.key.startsWith('d:')) {
        _base[e.key.substring(2)] = _decoderDoc(jsonDecode(e.value));
      } else if (e.key.startsWith('l:')) {
        _attente.add(Lot.deJson(jsonDecode(e.value) as Map<String, dynamic>));
      } else if (e.key == 'rev') {
        revision = int.tryParse(e.value) ?? 0;
      }
    }
    _attente.sort((a, b) => a.faitLe.compareTo(b.faitLe));
    _recalculer(null);
  }

  CollectionReference<Map<String, dynamic>> collection(String chemin) => CollectionReference._(this, chemin);
  DocumentReference<Map<String, dynamic>> doc(String chemin) => DocumentReference._(this, chemin);
  WriteBatch batch() => WriteBatch._(this);

  // ---------------------------------------------------------------- écriture

  Future<void> _valider(List<Map<String, dynamic>> ops) {
    if (ops.isEmpty) return Future.value();
    final lot = Lot(id: _uuid.v4(), ops: ops, auteur: auteur, session: session, faitLe: DateTime.now().millisecondsSinceEpoch);
    _attente.add(lot);
    final c = Completer<void>();
    _accuses[lot.id] = c;
    unawaited(stockage.ecrire('l:${lot.id}', jsonEncode(lot.versJson())));
    _recalculer({for (final o in ops) o['chemin'] as String});
    surNouveauLot?.call();
    return c.future;
  }

  // ---------------------------------------------------- synchronisation

  /// Documents reçus du serveur (chemins complets).
  Future<void> recevoir(Map<String, Map<String, dynamic>> docs, int rev) async {
    for (final e in docs.entries) {
      _base[e.key] = e.value;
    }
    revision = rev;
    await stockage.ecrireTout({
      for (final e in docs.entries) 'd:${e.key}': jsonEncode(encoder(e.value)),
      'rev': '$rev',
    });
    _recalculer(docs.keys.toSet());
  }

  /// Le serveur a accepté (ou refusé) des lots : ils quittent la file.
  Future<void> acquitter(Map<String, String?> resultats) async {
    final touches = <String>{};
    _attente.removeWhere((l) {
      if (!resultats.containsKey(l.id)) return false;
      touches.addAll(l.ops.map((o) => o['chemin'] as String));
      return true;
    });
    // La vue est à jour AVANT de prévenir ceux qui attendaient l'accusé.
    _recalculer(touches);
    for (final e in resultats.entries) {
      final c = _accuses.remove(e.key);
      if (c != null && !c.isCompleted) {
        e.value == null ? c.complete() : c.completeError(ErreurEcriture(e.value!));
      }
    }
    await stockage.supprimerTout([for (final id in resultats.keys) 'l:$id']);
  }

  /// Mode démonstration : tout est accepté tout de suite, sans serveur.
  Future<void> accepterLocalement() async {
    final maintenant = DateTime.now().millisecondsSinceEpoch;
    final res = <String, String?>{};
    final docs = <String, Map<String, dynamic>>{};
    for (final l in _attente) {
      for (final o in l.ops) {
        final ch = o['chemin'] as String;
        final r = appliquerOp(docs[ch] ?? _base[ch], o, maintenant);
        if (r != null) docs[ch] = r;
      }
      res[l.id] = null;
    }
    docs.forEach((k, v) => _base[k] = v);
    await acquitter(res);
  }

  // ---------------------------------------------------------------- vue

  void _recalculer(Set<String>? chemins) {
    final maintenant = DateTime.now().millisecondsSinceEpoch;
    final cibles = chemins ?? {..._base.keys, for (final l in _attente) ...l.ops.map((o) => o['chemin'] as String)};
    for (final ch in cibles) {
      Map<String, dynamic>? d = _base[ch];
      for (final l in _attente) {
        for (final o in l.ops) {
          if (o['chemin'] == ch) d = appliquerOp(d, o, maintenant) ?? d;
        }
      }
      if (d == null) {
        _vue.remove(ch);
      } else {
        _vue[ch] = d;
      }
    }
    _changements.add(cibles);
  }

  Map<String, dynamic>? lire(String chemin) => _vue[chemin];

  Iterable<MapEntry<String, Map<String, dynamic>>> _enfants(String collection) sync* {
    final prefixe = '$collection/';
    for (final e in _vue.entries) {
      if (e.key.startsWith(prefixe) && !e.key.substring(prefixe.length).contains('/')) yield e;
    }
  }

  Stream<Set<String>> get changements => _changements.stream;
}

// ============================================================ Références

int _comparer(Object? a, Object? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (a is num && b is num) return a.compareTo(b);
  if (a is Timestamp && b is Timestamp) return a.compareTo(b);
  if (a is String && b is String) return a.compareTo(b);
  if (a is bool && b is bool) return (a ? 1 : 0) - (b ? 1 : 0);
  return '$a'.compareTo('$b');
}

class _Filtre {
  final String champ;
  final String op;
  final Object? valeur;
  const _Filtre(this.champ, this.op, this.valeur);

  bool accepte(Map<String, dynamic> d) {
    final v = d[champ];
    switch (op) {
      case '==':
        return v == valeur || (v is num && valeur is num && v == valeur);
      case '!=':
        return v != valeur;
      case 'in':
        return (valeur as Iterable).contains(v);
      case '>=':
        return v != null && _comparer(v, valeur) >= 0;
      case '>':
        return v != null && _comparer(v, valeur) > 0;
      case '<=':
        return v != null && _comparer(v, valeur) <= 0;
      case '<':
        return v != null && _comparer(v, valeur) < 0;
      case 'contient':
        return v is List && v.contains(valeur);
    }
    return false;
  }
}

class Query<T extends Object?> {
  final BaseLocale _base;
  final String chemin;
  final List<_Filtre> _filtres;
  final List<(String, bool)> _tri;
  final int? _limite;
  const Query._(this._base, this.chemin, [this._filtres = const [], this._tri = const [], this._limite]);

  Query<T> where(
    String champ, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? whereIn,
  }) {
    final f = <_Filtre>[
      if (isEqualTo != null) _Filtre(champ, '==', isEqualTo),
      if (isNotEqualTo != null) _Filtre(champ, '!=', isNotEqualTo),
      if (isGreaterThan != null) _Filtre(champ, '>', isGreaterThan),
      if (isGreaterThanOrEqualTo != null) _Filtre(champ, '>=', isGreaterThanOrEqualTo),
      if (isLessThan != null) _Filtre(champ, '<', isLessThan),
      if (isLessThanOrEqualTo != null) _Filtre(champ, '<=', isLessThanOrEqualTo),
      if (arrayContains != null) _Filtre(champ, 'contient', arrayContains),
      if (whereIn != null) _Filtre(champ, 'in', whereIn.toList()),
    ];
    return Query._(_base, chemin, [..._filtres, ...f], _tri, _limite);
  }

  Query<T> orderBy(String champ, {bool descending = false}) =>
      Query._(_base, chemin, _filtres, [..._tri, (champ, descending)], _limite);

  Query<T> limit(int n) => Query._(_base, chemin, _filtres, _tri, n);

  QuerySnapshot<T> _executer() {
    var docs = [
      for (final e in _base._enfants(chemin))
        if (_filtres.every((f) => f.accepte(e.value))) QueryDocumentSnapshot<T>._(_base, e.key, e.value),
    ];
    if (_tri.isNotEmpty) {
      docs.sort((a, b) {
        for (final (champ, desc) in _tri) {
          final c = _comparer(a._donnees[champ], b._donnees[champ]);
          if (c != 0) return desc ? -c : c;
        }
        return 0;
      });
    }
    if (_limite != null && docs.length > _limite) docs = docs.sublist(0, _limite);
    return QuerySnapshot._(docs);
  }

  Future<QuerySnapshot<T>> get() async => _executer();

  Stream<QuerySnapshot<T>> snapshots() {
    late StreamController<QuerySnapshot<T>> c;
    StreamSubscription<Set<String>>? abo;
    final prefixe = '$chemin/';
    c = StreamController<QuerySnapshot<T>>(
      onListen: () {
        scheduleMicrotask(() {
          if (!c.isClosed) c.add(_executer());
        });
        abo = _base.changements.listen((chemins) {
          if (chemins.any((ch) => ch.startsWith(prefixe) && !ch.substring(prefixe.length).contains('/'))) c.add(_executer());
        });
      },
      onCancel: () => abo?.cancel(),
    );
    return c.stream;
  }
}

class CollectionReference<T extends Object?> extends Query<T> {
  CollectionReference._(BaseLocale base, String chemin) : super._(base, chemin);

  String get id => chemin.split('/').last;

  DocumentReference<T> doc([String? id]) => DocumentReference._(_base, '$chemin/${id ?? BaseLocale._uuid.v4()}');

  Future<DocumentReference<T>> add(Map<String, dynamic> donnees) async {
    final ref = doc();
    final b = _base.batch()..set(ref, donnees);
    unawaited(b.commit());
    return ref;
  }
}

class DocumentReference<T extends Object?> {
  final BaseLocale _base;
  final String path;
  const DocumentReference._(this._base, this.path);

  String get id => path.split('/').last;

  CollectionReference<Map<String, dynamic>> collection(String nom) => CollectionReference._(_base, '$path/$nom');

  Future<DocumentSnapshot<T>> get() async => DocumentSnapshot._(_base, path, _base.lire(path));

  Stream<DocumentSnapshot<T>> snapshots() {
    late StreamController<DocumentSnapshot<T>> c;
    StreamSubscription<Set<String>>? abo;
    c = StreamController<DocumentSnapshot<T>>(
      onListen: () {
        scheduleMicrotask(() {
          if (!c.isClosed) c.add(DocumentSnapshot._(_base, path, _base.lire(path)));
        });
        abo = _base.changements.listen((chemins) {
          if (chemins.contains(path)) c.add(DocumentSnapshot._(_base, path, _base.lire(path)));
        });
      },
      onCancel: () => abo?.cancel(),
    );
    return c.stream;
  }

  Future<void> set(Map<String, dynamic> donnees, [SetOptions? options]) => (_base.batch()..set(this, donnees, options)).commit();
  Future<void> update(Map<String, dynamic> donnees) => (_base.batch()..update(this, donnees)).commit();

  @override
  bool operator ==(Object o) => o is DocumentReference && o.path == path;
  @override
  int get hashCode => path.hashCode;
}

class DocumentSnapshot<T extends Object?> {
  final BaseLocale _base;
  final String _chemin;
  final Map<String, dynamic>? _donneesOuNull;
  DocumentSnapshot._(this._base, this._chemin, Map<String, dynamic>? d) : _donneesOuNull = d == null ? null : Map.of(d);

  String get id => _chemin.split('/').last;
  bool get exists => _donneesOuNull != null;
  DocumentReference<T> get reference => DocumentReference._(_base, _chemin);
  T? data() => _donneesOuNull as T?;
  Map<String, dynamic> get _donnees => _donneesOuNull ?? const {};
  dynamic get(String champ) => _donnees[champ];
}

class QueryDocumentSnapshot<T extends Object?> extends DocumentSnapshot<T> {
  QueryDocumentSnapshot._(super.base, super.chemin, Map<String, dynamic> super.d) : super._();
  @override
  T data() => _donnees as T;
}

class QuerySnapshot<T extends Object?> {
  final List<QueryDocumentSnapshot<T>> docs;
  const QuerySnapshot._(this.docs);
  int get size => docs.length;
}

class WriteBatch {
  final BaseLocale _base;
  final List<Map<String, dynamic>> _ops = [];
  bool _envoye = false;
  WriteBatch._(this._base);

  void set<T>(DocumentReference<T> ref, Map<String, dynamic> donnees, [SetOptions? options]) {
    _ops.add({'type': 'set', 'chemin': ref.path, 'donnees': encoder(donnees), if (options?.merge == true) 'fusion': true});
  }

  void update<T>(DocumentReference<T> ref, Map<String, dynamic> donnees) {
    _ops.add({'type': 'update', 'chemin': ref.path, 'donnees': encoder(donnees)});
  }

  void delete<T>(DocumentReference<T> ref) {
    throw UnsupportedError('Rien n’est jamais supprimé : utiliser un statut (annulé, désactivé…).');
  }

  /// Applique localement tout de suite ; le Future se termine quand le
  /// serveur a accepté le lot (ou en erreur s'il l'a refusé).
  Future<void> commit() {
    if (_envoye) throw StateError('Lot déjà envoyé');
    _envoye = true;
    return _base._valider(_ops);
  }
}
