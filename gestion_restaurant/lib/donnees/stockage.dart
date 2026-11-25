import 'stockage_memoire.dart' if (dart.library.js_interop) 'stockage_web.dart' as impl;

/// Espace de stockage clé → texte de la copie locale.
/// Navigateur (PWA) : IndexedDB, qui survit aux redémarrages et fonctionne
/// hors ligne. Tests : mémoire.
abstract class Stockage {
  Future<Map<String, String>> toutLire();
  Future<void> ecrire(String cle, String valeur);
  Future<void> ecrireTout(Map<String, String> valeurs);
  Future<void> supprimerTout(List<String> cles);
  Future<void> vider();

  /// Stockage persistant de la plateforme (IndexedDB sur le web).
  static Future<Stockage> persistant(String nom) => impl.ouvrirStockage(nom);
}

class StockageMemoire implements Stockage {
  final Map<String, String> _m = {};
  @override
  Future<Map<String, String>> toutLire() async => Map.of(_m);
  @override
  Future<void> ecrire(String cle, String valeur) async => _m[cle] = valeur;
  @override
  Future<void> ecrireTout(Map<String, String> valeurs) async => _m.addAll(valeurs);
  @override
  Future<void> supprimerTout(List<String> cles) async => cles.forEach(_m.remove);
  @override
  Future<void> vider() async => _m.clear();
}
