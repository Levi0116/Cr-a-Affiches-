import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modeles.dart';
import '../services/admin_service.dart';
import '../services/caisse_service.dart';
import '../services/commande_service.dart';
import '../services/db.dart';
import '../services/stock_service.dart';

/// Remplacé au démarrage (main.dart) par l'accès au restaurant lié.
final dbProvider = Provider<RestoDb>((ref) => throw UnimplementedError());

final commandeServiceProvider =
    Provider((ref) => CommandeService(ref.watch(dbProvider)));
final caisseServiceProvider =
    Provider((ref) => CaisseService(ref.watch(dbProvider)));
final stockServiceProvider =
    Provider((ref) => StockService(ref.watch(dbProvider)));
final adminServiceProvider =
    Provider((ref) => AdminService(ref.watch(dbProvider)));

/// Employé connecté sur cet appareil (null = écran de connexion).
class UtilisateurConnecte extends Notifier<Employe?> {
  @override
  Employe? build() => null;
  void connecter(Employe e) => state = e;
  void deconnecter() => state = null;
}

final utilisateurProvider =
    NotifierProvider<UtilisateurConnecte, Employe?>(UtilisateurConnecte.new);

final acteurProvider = Provider<Acteur?>((ref) {
  final e = ref.watch(utilisateurProvider);
  return e == null ? null : Acteur.de(e);
});

List<T> _docs<T>(QuerySnapshot<Map<String, dynamic>> q,
        T Function(DocumentSnapshot<Map<String, dynamic>>) f) =>
    q.docs.map(f).toList();

int _num(String s) => int.tryParse(s) ?? 1 << 20;

final restaurantProvider = StreamProvider<Restaurant>((ref) =>
    ref.watch(dbProvider).resto.snapshots().map(Restaurant.fromDoc));

final employesProvider = StreamProvider<List<Employe>>((ref) => ref
    .watch(dbProvider)
    .employes
    .snapshots()
    .map((q) => _docs(q, Employe.fromDoc)..sort((a, b) => a.nom.compareTo(b.nom))));

final zonesProvider = StreamProvider<List<Zone>>((ref) => ref
    .watch(dbProvider)
    .zones
    .snapshots()
    .map((q) => _docs(q, Zone.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))));

final tablesProvider = StreamProvider<List<TableResto>>((ref) => ref
    .watch(dbProvider)
    .tables
    .snapshots()
    .map((q) => _docs(q, TableResto.fromDoc)
      ..sort((a, b) {
        final c = _num(a.numero).compareTo(_num(b.numero));
        return c != 0 ? c : a.numero.compareTo(b.numero);
      })));

final categoriesProvider = StreamProvider<List<Categorie>>((ref) => ref
    .watch(dbProvider)
    .categories
    .snapshots()
    .map((q) => _docs(q, Categorie.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))));

final articlesProvider = StreamProvider<List<Article>>((ref) => ref
    .watch(dbProvider)
    .articles
    .snapshots()
    .map((q) => _docs(q, Article.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))));

/// Additions en cours (ouvertes, addition demandée, facturées non réglées).
final sessionsEnCoursProvider = StreamProvider<List<SessionTable>>((ref) => ref
    .watch(dbProvider)
    .sessions
    .where('statut', whereIn: [
      StatutSession.ouverte.name,
      StatutSession.addition.name,
      StatutSession.facturee.name,
    ])
    .snapshots()
    .map((q) => _docs(q, SessionTable.fromDoc)
      ..sort((a, b) => a.ouverture.compareTo(b.ouverture))));

final lignesProvider =
    StreamProvider.family<List<LigneCommande>, String>((ref, idSession) => ref
        .watch(dbProvider)
        .lignes(idSession)
        .snapshots()
        .map((q) => _docs(q, LigneCommande.fromDoc)
          ..sort((a, b) {
            final c = a.tour.compareTo(b.tour);
            return c != 0 ? c : a.heure.compareTo(b.heure);
          })));

final facturesSessionProvider =
    StreamProvider.family<List<Facture>, String>((ref, idSession) => ref
        .watch(dbProvider)
        .factures
        .where('idSession', isEqualTo: idSession)
        .snapshots()
        .map((q) => _docs(q, Facture.fromDoc)..sort((a, b) => a.numero.compareTo(b.numero))));

DateTime debutJour([DateTime? d]) {
  final n = d ?? DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Factures depuis une date (par défaut : aujourd'hui).
final facturesDepuisProvider =
    StreamProvider.family<List<Facture>, DateTime>((ref, depuis) => ref
        .watch(dbProvider)
        .factures
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis))
        .snapshots()
        .map((q) => _docs(q, Facture.fromDoc)..sort((a, b) => b.numero.compareTo(a.numero))));

final journeeOuverteProvider = StreamProvider<JourneeCaisse?>((ref) => ref
    .watch(dbProvider)
    .journeesCaisse
    .where('verrouillee', isEqualTo: false)
    .snapshots()
    .map((q) => q.docs.isEmpty ? null : JourneeCaisse.fromDoc(q.docs.first)));

final journeesProvider = StreamProvider<List<JourneeCaisse>>((ref) => ref
    .watch(dbProvider)
    .journeesCaisse
    .snapshots()
    .map((q) => _docs(q, JourneeCaisse.fromDoc)..sort((a, b) => b.ouverture.compareTo(a.ouverture))));

final demandesEnAttenteProvider = StreamProvider<List<DemandeValidation>>((ref) => ref
    .watch(dbProvider)
    .demandesValidation
    .where('statut', isEqualTo: StatutValidation.enAttente.name)
    .snapshots()
    .map((q) => _docs(q, DemandeValidation.fromDoc)..sort((a, b) => a.date.compareTo(b.date))));

final ardoisesProvider = StreamProvider<List<Ardoise>>((ref) => ref
    .watch(dbProvider)
    .ardoises
    .snapshots()
    .map((q) => _docs(q, Ardoise.fromDoc)..sort((a, b) => a.creeLe.compareTo(b.creeLe))));

final mouvementsProvider = StreamProvider<List<MouvementStock>>((ref) => ref
    .watch(dbProvider)
    .mouvementsStock
    .orderBy('heureAppareil', descending: true)
    .limit(300)
    .snapshots()
    .map((q) => _docs(q, MouvementStock.fromDoc)));

final auditProvider = StreamProvider<List<EntreeAudit>>((ref) => ref
    .watch(dbProvider)
    .journalAudit
    .orderBy('heureAppareil', descending: true)
    .limit(300)
    .snapshots()
    .map((q) => _docs(q, EntreeAudit.fromDoc)));
