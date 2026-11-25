import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../donnees/api.dart';
import '../../donnees/base.dart';
import '../../donnees/stockage.dart';
import '../../donnees/synchro.dart';
import '../../services/db.dart';
import '../../services/serveur_appareils.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../connexion/accueil.dart';
import 'ecran_liaison.dart';

/// Ce que l'appareil garde de sa liaison (dans IndexedDB, séparé des données).
class _Liaison {
  final String jeton;
  final String idRestaurant;
  final String idAppareil;
  final String nomAppareil;
  final String type;
  final bool admin;
  const _Liaison(this.jeton, this.idRestaurant, this.idAppareil, this.nomAppareil, this.type, this.admin);
}

/// Démarrage de la PWA reliée au serveur Node.js :
///
/// - appareil non lié → écran de liaison (code ou QR fourni par l'administrateur) ;
/// - appareil lié → copie locale chargée tout de suite (fonctionne sans
///   internet), puis synchronisation en arrière-plan.
class RacineServeur extends StatefulWidget {
  const RacineServeur({super.key});

  @override
  State<RacineServeur> createState() => _RacineServeurState();
}

class _RacineServeurState extends State<RacineServeur> {
  Stockage? _reglages;
  _Liaison? _liaison;
  RestoDb? _db;
  Synchro? _synchro;
  ServeurApi? _serveur;
  bool _chargement = true;
  final _api = Api(base: Api.adresseParDefaut());

  @override
  void initState() {
    super.initState();
    unawaited(_demarrer());
  }

  @override
  void dispose() {
    _synchro?.arreter();
    super.dispose();
  }

  Future<void> _demarrer() async {
    final r = _reglages = await Stockage.persistant('amani-reglages');
    final v = await r.toutLire();
    // Adresse du serveur : config.json (si présent), sinon la dernière connue
    // (démarrage hors ligne), sinon la même adresse que l'application.
    final configuree = await Api.lireConfiguration();
    if (configuree != null) {
      _api.base = configuree;
      await r.ecrire('api', configuree.toString());
    } else if (v['api'] != null) {
      _api.base = Uri.parse(v['api']!);
    }
    if (v['jeton'] != null && v['restaurant'] != null) {
      _liaison = _Liaison(v['jeton']!, v['restaurant']!, v['appareil'] ?? '', v['nomAppareil'] ?? '', v['type'] ?? 'tablette', v['admin'] == '1');
      await _ouvrir();
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _lier(String code) async {
    final r = await _api.lier(code);
    final a = r['appareil'] as Map<String, dynamic>;
    final resto = r['restaurant'] as Map<String, dynamic>;
    await _reglages!.ecrireTout({
      'jeton': r['jeton'] as String,
      'restaurant': resto['id'] as String,
      'appareil': a['id'] as String,
      'nomAppareil': a['nom'] as String,
      'type': a['type'] as String,
      'admin': a['admin'] == true ? '1' : '0',
    });
    _liaison = _Liaison(r['jeton'] as String, resto['id'] as String, a['id'] as String, a['nom'] as String, a['type'] as String, a['admin'] == true);
  }

  Future<void> _ouvrir() async {
    final l = _liaison!;
    _api.jetonAppareil = l.jeton;
    final base = BaseLocale(await Stockage.persistant('amani-donnees-${l.idRestaurant}'));
    await base.ouvrir();
    final db = RestoDb(fs: base, idRestaurant: l.idRestaurant, appareil: '${l.type}-${l.idAppareil.substring(0, 6)}');
    final serveur = ServeurApi(api: _api, base: base, appareilAdmin: l.admin);
    db.adminConfirme = () => serveur.appareilAdmin || _api.session != null;
    final synchro = Synchro(base: base, api: _api, idRestaurant: l.idRestaurant)..surAppareilRetire = _appareilRetire;
    synchro.etat.addListener(() {
      db.enLigne.value = synchro.etat.value.enLigne;
      db.enAttente.value = synchro.etat.value.enAttente;
      final err = synchro.etat.value.derniereErreur;
      if (err != null) db.derniereErreur.value = err;
    });
    // Premier démarrage : on attend les données avant d'afficher l'accueil.
    if (base.revision == 0) {
      try {
        await synchro.recevoir().timeout(const Duration(seconds: 30));
      } catch (_) {}
    }
    synchro.demarrer();
    _db = db;
    _synchro = synchro;
    _serveur = serveur;
  }

  /// L'administrateur a retiré cet appareil : on efface tout ce qu'il gardait.
  Future<void> _appareilRetire() async {
    final l = _liaison;
    _synchro?.arreter();
    await _reglages?.vider();
    if (l != null) await (await Stockage.persistant('amani-donnees-${l.idRestaurant}')).vider();
    if (!mounted) return;
    setState(() {
      _liaison = null;
      _db = null;
      _synchro = null;
      _serveur = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const _Demarrage();
    if (_db == null) {
      return EcranLiaison(
        lier: _lier,
        onLie: () async {
          setState(() => _chargement = true);
          await _ouvrir();
          if (mounted) setState(() => _chargement = false);
        },
      );
    }
    return ProviderScope(
      overrides: [dbProvider.overrideWithValue(_db!), serveurAppareilsProvider.overrideWithValue(_serveur!)],
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
