import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/format.dart';
import '../core/stock_calc.dart';
import '../models/modeles.dart';
import '../services/admin_service.dart';
import '../services/caisse_service.dart';
import '../services/commande_service.dart';
import '../services/db.dart';
import '../services/serveur_appareils.dart';
import '../services/stock_service.dart';

/// Remplacé au démarrage (main.dart) par l'accès au restaurant lié.
final dbProvider = Provider<RestoDb>((ref) => throw UnimplementedError());

final commandeServiceProvider = Provider((ref) => CommandeService(ref.watch(dbProvider)));
final caisseServiceProvider = Provider((ref) => CaisseService(ref.watch(dbProvider)));
final stockServiceProvider = Provider((ref) => StockService(ref.watch(dbProvider)));
final adminServiceProvider = Provider((ref) => AdminService(ref.watch(dbProvider)));

/// Employé connecté sur cet appareil (null = écran de connexion).
class UtilisateurConnecte extends Notifier<Employe?> {
  @override
  Employe? build() => null;
  void connecter(Employe e) => state = e;
  void deconnecter() => state = null;
}

final utilisateurProvider = NotifierProvider<UtilisateurConnecte, Employe?>(UtilisateurConnecte.new);

final acteurProvider = Provider<Acteur?>((ref) {
  final e = ref.watch(utilisateurProvider);
  return e == null ? null : Acteur.de(e);
});

List<T> _docs<T>(QuerySnapshot<Map<String, dynamic>> q, T Function(DocumentSnapshot<Map<String, dynamic>>) f) =>
    q.docs.map(f).toList();

int _num(String s) => int.tryParse(s) ?? 1 << 20;

final restaurantProvider = StreamProvider<Restaurant>(
  (ref) => ref.watch(dbProvider).resto.snapshots().map(Restaurant.fromDoc),
);

final employesProvider = StreamProvider<List<Employe>>(
  (ref) => ref
      .watch(dbProvider)
      .employes
      .snapshots()
      .map((q) => _docs(q, Employe.fromDoc)..sort((a, b) => a.nom.compareTo(b.nom))),
);

final zonesProvider = StreamProvider<List<Zone>>(
  (ref) => ref
      .watch(dbProvider)
      .zones
      .snapshots()
      .map((q) => _docs(q, Zone.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))),
);

final tablesProvider = StreamProvider<List<TableResto>>(
  (ref) => ref
      .watch(dbProvider)
      .tables
      .snapshots()
      .map(
        (q) => _docs(q, TableResto.fromDoc)
          ..sort((a, b) {
            final c = _num(a.numero).compareTo(_num(b.numero));
            return c != 0 ? c : a.numero.compareTo(b.numero);
          }),
      ),
);

final categoriesProvider = StreamProvider<List<Categorie>>(
  (ref) => ref
      .watch(dbProvider)
      .categories
      .snapshots()
      .map((q) => _docs(q, Categorie.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))),
);

final articlesProvider = StreamProvider<List<Article>>(
  (ref) => ref
      .watch(dbProvider)
      .articles
      .snapshots()
      .map((q) => _docs(q, Article.fromDoc)..sort((a, b) => a.ordre.compareTo(b.ordre))),
);

/// Additions en cours (ouvertes, addition demandée, facturées non réglées).
final sessionsEnCoursProvider = StreamProvider<List<SessionTable>>(
  (ref) => ref
      .watch(dbProvider)
      .sessions
      .where('statut', whereIn: [StatutSession.ouverte.name, StatutSession.addition.name, StatutSession.facturee.name])
      .snapshots()
      .map((q) => _docs(q, SessionTable.fromDoc)..sort((a, b) => a.ouverture.compareTo(b.ouverture))),
);

final lignesProvider = StreamProvider.family<List<LigneCommande>, String>(
  (ref, idSession) => ref
      .watch(dbProvider)
      .lignes(idSession)
      .snapshots()
      .map(
        (q) => _docs(q, LigneCommande.fromDoc)
          ..sort((a, b) {
            final c = a.tour.compareTo(b.tour);
            return c != 0 ? c : a.heure.compareTo(b.heure);
          }),
      ),
);

final facturesSessionProvider = StreamProvider.family<List<Facture>, String>(
  (ref, idSession) => ref
      .watch(dbProvider)
      .factures
      .where('idSession', isEqualTo: idSession)
      .snapshots()
      .map((q) => _docs(q, Facture.fromDoc)..sort((a, b) => a.numero.compareTo(b.numero))),
);

DateTime debutJour([DateTime? d]) {
  final n = d ?? DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Factures depuis une date (par défaut : aujourd'hui).
final facturesDepuisProvider = StreamProvider.family<List<Facture>, DateTime>(
  (ref, depuis) => ref
      .watch(dbProvider)
      .factures
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis))
      .snapshots()
      .map((q) => _docs(q, Facture.fromDoc)..sort((a, b) => b.numero.compareTo(a.numero))),
);

final journeeOuverteProvider = StreamProvider<JourneeCaisse?>(
  (ref) => ref
      .watch(dbProvider)
      .journeesCaisse
      .where('verrouillee', isEqualTo: false)
      .snapshots()
      .map((q) => q.docs.isEmpty ? null : JourneeCaisse.fromDoc(q.docs.first)),
);

final journeesProvider = StreamProvider<List<JourneeCaisse>>(
  (ref) => ref
      .watch(dbProvider)
      .journeesCaisse
      .snapshots()
      .map((q) => _docs(q, JourneeCaisse.fromDoc)..sort((a, b) => b.ouverture.compareTo(a.ouverture))),
);

final demandesEnAttenteProvider = StreamProvider<List<DemandeValidation>>(
  (ref) => ref
      .watch(dbProvider)
      .demandesValidation
      .where('statut', isEqualTo: StatutValidation.enAttente.name)
      .snapshots()
      .map((q) => _docs(q, DemandeValidation.fromDoc)..sort((a, b) => a.date.compareTo(b.date))),
);

final ardoisesProvider = StreamProvider<List<Ardoise>>(
  (ref) => ref
      .watch(dbProvider)
      .ardoises
      .snapshots()
      .map((q) => _docs(q, Ardoise.fromDoc)..sort((a, b) => a.creeLe.compareTo(b.creeLe))),
);

final mouvementsProvider = StreamProvider<List<MouvementStock>>(
  (ref) => ref
      .watch(dbProvider)
      .mouvementsStock
      .orderBy('heureAppareil', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => _docs(q, MouvementStock.fromDoc)),
);

final auditProvider = StreamProvider<List<EntreeAudit>>(
  (ref) => ref
      .watch(dbProvider)
      .journalAudit
      .orderBy('heureAppareil', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => _docs(q, EntreeAudit.fromDoc)),
);

/// Fiches techniques des plats, par identifiant de plat.
final recettesProvider = StreamProvider<Map<String, Recette>>(
  (ref) => ref.watch(dbProvider).recettes.snapshots().map((q) => {for (final d in q.docs) d.id: Recette.fromDoc(d)}),
);

/// Portions encore possibles pour chaque plat à fiche technique.
final portionsProvider = Provider<Map<String, int>>((ref) {
  final recettes = ref.watch(recettesProvider).value ?? const {};
  final articles = {for (final a in ref.watch(articlesProvider).value ?? const <Article>[]) a.id: a};
  return {
    for (final e in recettes.entries)
      if (articles[e.key]?.aRecette ?? false) e.key: portionsPossibles(e.value, articles),
  };
});

/// Connexion réseau de l'appareil (Wi-Fi, données mobiles ou câble).
final reseauProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool connecte(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  try {
    yield connecte(await c.checkConnectivity());
  } catch (_) {
    yield true; // plateforme sans détection : on suppose connecté
  }
  yield* c.onConnectivityChanged.map(connecte);
});

/// Horloge partagée, une mise à jour par minute (« ouverte depuis 42 min »).
/// Un seul minuteur pour toute l'application, au lieu d'un par carte.
final horlogeProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

// ============================================================ Appareils

/// Opérations serveur (liaison, élévation admin, retrait) — remplacé au
/// démarrage par ServeurFirebase ou ServeurDemo.
final serveurAppareilsProvider = Provider<ServeurAppareils>((ref) => throw UnimplementedError());

class Appareil {
  final String uid;
  final String nom;
  final TypeAppareil type;
  final bool admin;
  final bool actif;
  final DateTime? lieLe;
  const Appareil({
    required this.uid,
    required this.nom,
    required this.type,
    required this.admin,
    required this.actif,
    this.lieLe,
  });
  factory Appareil.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final l = m['lieLe'];
    return Appareil(
      uid: d.id,
      nom: m['nom'] as String? ?? 'Appareil',
      type: TypeAppareil.values.asNameMap()[m['type']] ?? TypeAppareil.tablette,
      admin: m['admin'] as bool? ?? false,
      actif: m['actif'] as bool? ?? true,
      lieLe: l is Timestamp ? l.toDate() : (l is DateTime ? l : null),
    );
  }
}

final appareilsProvider = StreamProvider<List<Appareil>>(
  (ref) => ref
      .watch(dbProvider)
      .appareils
      .snapshots()
      .map(
        (q) =>
            q.docs.map(Appareil.fromDoc).toList()
              ..sort((a, b) => (b.lieLe ?? DateTime(2000)).compareTo(a.lieLe ?? DateTime(2000))),
      ),
);

// ======================================================= Élévation admin

enum StatutElevation { inutile, enCours, active, horsLigne, refusee }

class EtatElevation {
  final StatutElevation statut;
  final DateTime? jusqua;
  final String? message;
  const EtatElevation(this.statut, {this.jusqua, this.message});
}

/// Sur l'ordinateur partagé, l'administrateur qui se connecte reçoit des
/// droits serveur pour 15 minutes (PIN vérifié par la Cloud Function), et
/// ils sont renouvelés tant qu'il reste connecté. Le PIN n'est gardé en
/// mémoire que pendant sa session.
class Elevation extends Notifier<EtatElevation> {
  Timer? _minuteur;
  String? _id;
  String? _pin;

  @override
  EtatElevation build() {
    ref.listen(utilisateurProvider, (_, e) {
      if (e == null || e.role != Role.admin) arreter();
    });
    ref.onDispose(() => _minuteur?.cancel());
    return const EtatElevation(StatutElevation.inutile);
  }

  Future<void> demarrer(Employe e, String pin) async {
    if (e.role != Role.admin) return;
    _id = e.id;
    _pin = pin;
    final etat = await ref.read(serveurAppareilsProvider).etat().catchError((_) => const EtatAppareil(uid: ''));
    if (etat.admin) {
      state = const EtatElevation(StatutElevation.active); // téléphone du gérant : droits permanents
      return;
    }
    await _demander();
  }

  Future<void> _demander() async {
    final id = _id, pin = _pin;
    if (id == null || pin == null) return;
    state = const EtatElevation(StatutElevation.enCours);
    _minuteur?.cancel();
    try {
      final jusqua = await ref
          .read(serveurAppareilsProvider)
          .elevationAdmin(idEmploye: id, pin: pin)
          .timeout(const Duration(seconds: 15));
      if (_id == null) return;
      state = EtatElevation(StatutElevation.active, jusqua: jusqua);
      final avant = jusqua.difference(DateTime.now()) - const Duration(minutes: 2);
      _minuteur = Timer(avant.isNegative ? const Duration(seconds: 30) : avant, _demander);
    } on ErreurMetier catch (e) {
      state = EtatElevation(StatutElevation.refusee, message: e.message);
    } catch (_) {
      // Hors ligne : on réessaie chaque minute.
      state = const EtatElevation(StatutElevation.horsLigne);
      _minuteur = Timer(const Duration(minutes: 1), _demander);
    }
  }

  void arreter() {
    _minuteur?.cancel();
    final etaitActive = state.statut == StatutElevation.active && state.jusqua != null;
    _id = null;
    _pin = null;
    if (etaitActive) ref.read(serveurAppareilsProvider).finElevation().ignore();
    if (state.statut != StatutElevation.inutile) state = const EtatElevation(StatutElevation.inutile);
  }
}

final elevationProvider = NotifierProvider<Elevation, EtatElevation>(Elevation.new);

// ======================================================== Notifications

class NotificationApp {
  final String id;
  final String type;
  final String titre;
  final String message;
  final bool lue;
  final DateTime date;
  const NotificationApp({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    required this.lue,
    required this.date,
  });
}

/// Notifications créées par les Cloud Functions (non lues, plus récentes d'abord).
final notificationsProvider = StreamProvider<List<NotificationApp>>(
  (ref) => ref
      .watch(dbProvider)
      .notifications
      .where('lue', isEqualTo: false)
      .snapshots()
      .map(
        (q) => q.docs.map((d) {
          final m = d.data();
          final h = m['heureAppareil'] ?? m['creeLe'];
          return NotificationApp(
            id: d.id,
            type: m['type'] as String? ?? '',
            titre: m['titre'] as String? ?? '',
            message: m['message'] as String? ?? '',
            lue: m['lue'] as bool? ?? false,
            date: h is Timestamp ? h.toDate() : DateTime.now(),
          );
        }).toList()..sort((a, b) => b.date.compareTo(a.date)),
      ),
);

/// Alerte affichée sous la cloche : calculée en direct (fonctionne aussi
/// hors ligne et en démonstration) + notifications du serveur.
class Alerte {
  final String titre;
  final String detail;
  final String type; // stock, validation, serveur
  final String? idNotification;
  const Alerte({required this.titre, required this.detail, required this.type, this.idNotification});
}

final alertesProvider = Provider<List<Alerte>>((ref) {
  final articles = ref.watch(articlesProvider).value ?? const <Article>[];
  final demandes = ref.watch(demandesEnAttenteProvider).value ?? const <DemandeValidation>[];
  final serveur = ref.watch(notificationsProvider).value ?? const <NotificationApp>[];
  return [
    if (demandes.isNotEmpty)
      Alerte(
        titre: '${demandes.length} validation${demandes.length > 1 ? 's' : ''} en attente',
        detail: demandes.take(3).map((d) => '${d.demandeur} : ${d.motif}').join(' · '),
        type: 'validation',
      ),
    for (final a in articles.where((a) => a.actif && a.sousSeuil))
      Alerte(
        titre: a.stock <= 0 ? 'Rupture : ${a.nom}' : 'Stock bas : ${a.nom}',
        detail: 'Reste ${qte(a.stock, a.unite)} (seuil ${qte(a.seuilAlerte)})',
        type: 'stock',
      ),
    // Notifications serveur qui ne doublonnent pas les alertes calculées.
    for (final n in serveur.where((n) => !n.type.startsWith('stock') && n.type != 'validation'))
      Alerte(titre: n.titre, detail: n.message, type: 'serveur', idNotification: n.id),
  ];
});

// ============================================================== Version

class InfosVersion {
  final String actuelle;
  final String? derniere;
  final String? minimale;
  final String? urlApk;
  final String? notes;
  const InfosVersion({required this.actuelle, this.derniere, this.minimale, this.urlApk, this.notes});
  bool get miseAJourDisponible => derniere != null && comparerVersions(derniere!, actuelle) > 0;
  bool get obligatoire => minimale != null && comparerVersions(minimale!, actuelle) > 0;
}

final versionAppProvider = FutureProvider<String>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return '1.0.0';
  }
});

final infosVersionProvider = StreamProvider<InfosVersion>((ref) {
  final actuelle = ref.watch(versionAppProvider).value ?? '1.0.0';
  return ref.watch(dbProvider).configVersion.snapshots().map((d) {
    final m = d.data() ?? const {};
    return InfosVersion(
      actuelle: actuelle,
      derniere: m['derniere'] as String?,
      minimale: m['minimale'] as String?,
      urlApk: m['urlApk'] as String?,
      notes: m['notes'] as String?,
    );
  });
});
