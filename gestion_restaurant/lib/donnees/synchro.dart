import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'base.dart';

/// État affiché par l'indicateur de connexion.
@immutable
class EtatSynchro {
  final bool enLigne;
  final int enAttente;
  final DateTime? derniereSynchro;
  final String? derniereErreur;
  const EtatSynchro({this.enLigne = false, this.enAttente = 0, this.derniereSynchro, this.derniereErreur});
  EtatSynchro copier({bool? enLigne, int? enAttente, DateTime? derniereSynchro, String? derniereErreur, bool effacerErreur = false}) =>
      EtatSynchro(
        enLigne: enLigne ?? this.enLigne,
        enAttente: enAttente ?? this.enAttente,
        derniereSynchro: derniereSynchro ?? this.derniereSynchro,
        derniereErreur: effacerErreur ? null : (derniereErreur ?? this.derniereErreur),
      );
}

/// Échanges avec le serveur : envoi de la file d'attente, réception des
/// changements, écoute en temps réel. Reprend tout seul après une coupure.
class Synchro {
  final BaseLocale base;
  final Api api;
  final String idRestaurant;

  /// Appelé si le serveur indique que cet appareil a été retiré.
  void Function()? surAppareilRetire;

  final ValueNotifier<EtatSynchro> etat = ValueNotifier(const EtatSynchro());
  bool _actif = false;
  Completer<void>? _reveil;
  Future<void>? _pullEnCours;
  bool _pushEnCours = false;
  int _echecs = 0;

  Synchro({required this.base, required this.api, required this.idRestaurant}) {
    base.surNouveauLot = () {
      _majCompteur();
      unawaited(_envoyer());
    };
  }

  String get _prefixe => 'restaurants/$idRestaurant';

  /// Chemin serveur (« sessions/x ») ↔ chemin local (« restaurants/rid/sessions/x »).
  String versServeur(String chemin) {
    if (chemin == _prefixe) return '@';
    if (chemin.startsWith('$_prefixe/')) return chemin.substring(_prefixe.length + 1);
    return chemin; // config/version
  }

  String versLocal(String chemin) {
    if (chemin == '@') return _prefixe;
    if (chemin.startsWith('config/')) return chemin;
    return '$_prefixe/$chemin';
  }

  void demarrer() {
    if (_actif) return;
    _actif = true;
    _majCompteur();
    unawaited(_boucleEcoute());
    unawaited(_envoyer());
  }

  void arreter() {
    _actif = false;
    _reveiller();
  }

  void _majCompteur() => etat.value = etat.value.copier(enAttente: base.nbEnAttente);

  void _reveiller() {
    final r = _reveil;
    if (r != null && !r.isCompleted) r.complete();
  }

  Future<void> _pause(Duration d) {
    _reveil = Completer<void>();
    return Future.any([_reveil!.future, Future<void>.delayed(d)]);
  }

  Duration get _attenteApresEchec => Duration(milliseconds: min(30000, 1000 * pow(2, min(_echecs, 5)).toInt()));

  void _succes() {
    _echecs = 0;
    etat.value = etat.value.copier(enLigne: true, derniereSynchro: DateTime.now());
  }

  void _echec(Object e) {
    _echecs++;
    if (e is ErreurApi && e.appareilRetire) {
      _actif = false;
      surAppareilRetire?.call();
    }
    etat.value = etat.value.copier(enLigne: e is ErreurApi && !e.horsLigne);
    if (e is ErreurApi && e.horsLigne) etat.value = etat.value.copier(enLigne: false);
  }

  /// Reçoit tout ce qui a changé depuis la dernière révision connue.
  Future<void> recevoir() => _pullEnCours ??= _pull().whenComplete(() => _pullEnCours = null);

  Future<void> _pull() async {
    var plus = true;
    while (plus) {
      final r = await api.pull(base.revision);
      final docs = <String, Map<String, dynamic>>{
        for (final d in (r['docs'] as List).cast<Map<String, dynamic>>())
          versLocal(d['chemin'] as String): (decoder(d['donnees']) as Map<String, dynamic>),
      };
      await base.recevoir(docs, (r['rev'] as num).toInt());
      plus = r['plus'] == true;
    }
  }

  /// Envoie la file d'attente (par paquets de 50 lots, dans l'ordre).
  Future<void> _envoyer() async {
    if (_pushEnCours || !_actif) return;
    _pushEnCours = true;
    try {
      while (_actif && base.nbEnAttente > 0) {
        final lots = base.lotsEnAttente.take(50).toList();
        try {
          final r = await api.push([
            for (final l in lots)
              {
                ...l.versJson(),
                'ops': [for (final o in l.ops) {...o, 'chemin': versServeur(o['chemin'] as String)}],
              },
          ]);
          // On reçoit d'abord le nouvel état (qui contient nos écritures)
          // avant de retirer les lots : l'écran ne « clignote » pas.
          await recevoir();
          final resultats = <String, String?>{
            for (final x in (r['resultats'] as List).cast<Map<String, dynamic>>())
              x['id'] as String: x['ok'] == true ? null : (x['erreur'] as String? ?? 'refusé'),
          };
          final refus = resultats.values.whereType<String>().toList();
          await base.acquitter(resultats);
          _succes();
          if (refus.isNotEmpty) etat.value = etat.value.copier(derniereErreur: refus.first);
          _majCompteur();
        } catch (e) {
          _echec(e);
          _majCompteur();
          if (!_actif) break;
          await _pause(_attenteApresEchec);
        }
      }
    } finally {
      _pushEnCours = false;
    }
  }

  /// Écoute permanente : le serveur répond dès qu'il y a du nouveau.
  Future<void> _boucleEcoute() async {
    while (_actif) {
      try {
        await recevoir();
        _succes();
        if (base.nbEnAttente > 0) unawaited(_envoyer());
        final r = await api.attendre(base.revision);
        if ((r['rev'] as num).toInt() > base.revision) await recevoir();
      } catch (e) {
        _echec(e);
        if (!_actif) break;
        await _pause(_attenteApresEchec);
      }
    }
  }

  /// Relance immédiate (retour du réseau, bouton « réessayer »).
  void relancer() {
    _echecs = 0;
    _reveiller();
    unawaited(_envoyer());
  }
}
