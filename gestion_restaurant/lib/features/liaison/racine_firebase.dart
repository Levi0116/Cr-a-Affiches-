import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/db.dart';
import '../../services/serveur_appareils.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../connexion/accueil.dart';
import 'ecran_liaison.dart';

/// Démarrage en mode Firebase : l'appareil est-il lié à un restaurant ?
///
/// - non → écran de liaison (code ou QR fourni par l'administrateur) ;
/// - oui → l'application, branchée sur les données de ce restaurant.
///
/// Hors ligne, le dernier restaurant connu (gardé sur l'appareil) suffit à
/// démarrer : Firestore travaille alors sur sa copie locale.
class RacineFirebase extends StatefulWidget {
  final FirebaseFirestore fs;
  final ServeurAppareils serveur;
  const RacineFirebase({super.key, required this.fs, required this.serveur});

  @override
  State<RacineFirebase> createState() => _RacineFirebaseState();
}

class _RacineFirebaseState extends State<RacineFirebase> {
  static const _cleResto = 'restaurantId';
  static const _cleUid = 'uidAppareil';
  EtatAppareil? _etat;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    final prefs = await SharedPreferences.getInstance();
    EtatAppareil? etat;
    try {
      etat = await widget.serveur.etat(rafraichir: true).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Hors ligne : on reprend le dernier restaurant connu.
      final rid = prefs.getString(_cleResto);
      if (rid != null) etat = EtatAppareil(uid: prefs.getString(_cleUid) ?? 'hors-ligne', restaurantId: rid);
    }
    if (etat != null && etat.lie) {
      await prefs.setString(_cleResto, etat.restaurantId!);
      await prefs.setString(_cleUid, etat.uid);
      await _abonnerNotifications(etat);
    }
    if (!mounted) return;
    setState(() {
      _etat = etat;
      _chargement = false;
    });
  }

  /// Notifications poussées (Android) : le téléphone du gérant reçoit les
  /// alertes de stock et les demandes de validation.
  Future<void> _abonnerNotifications(EtatAppareil etat) async {
    if (kIsWeb || !etat.admin) return;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      await m.subscribeToTopic('${etat.restaurantId}-admin');
      await m.subscribeToTopic('${etat.restaurantId}-stock');
    } catch (_) {
      // Notifications indisponibles : les alertes restent visibles dans l'application.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const _Demarrage();
    final etat = _etat;
    if (etat == null || !etat.lie) {
      return EcranLiaison(
        serveur: widget.serveur,
        onLie: (e) {
          setState(() => _chargement = true);
          _verifier();
        },
      );
    }
    final db = RestoDb(
      fs: widget.fs,
      idRestaurant: etat.restaurantId!,
      appareil: kIsWeb ? 'caisse-web-${etat.uid.substring(0, 6)}' : 'tablette-${etat.uid.substring(0, 6)}',
    );
    return ProviderScope(
      overrides: [dbProvider.overrideWithValue(db), serveurAppareilsProvider.overrideWithValue(widget.serveur)],
      child: const Accueil(),
    );
  }
}

class _Demarrage extends StatelessWidget {
  const _Demarrage();
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.sombre,
    child: Scaffold(
      backgroundColor: identite.nuit,
      body: FondMotif(
        couleurFond: identite.nuit,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: duree(context, 900),
                curve: Curves.elasticOut,
                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                child: const LogoResto(nom: '', taille: 150),
              ),
              const SizedBox(height: 24),
              SizedBox(width: 180, child: LinearProgressIndicator(color: identite.principale, minHeight: 3)),
            ],
          ),
        ),
      ),
    ),
  );
}
