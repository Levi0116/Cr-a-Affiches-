// Test d'intégration : deux appareils, le vrai serveur Node.js + MySQL,
// une coupure de réseau. Lancé seulement si MySQL et Node sont disponibles
// (variable AMANI_TEST_SERVEUR=1), sinon ignoré.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/donnees/api.dart';
import 'package:gestion_restaurant/donnees/base.dart';
import 'package:gestion_restaurant/donnees/stockage.dart';
import 'package:gestion_restaurant/donnees/synchro.dart';
import 'package:http/http.dart' as http;

/// Client HTTP qu'on peut « débrancher » pour simuler une coupure.
class ClientCoupable extends http.BaseClient {
  final _c = http.Client();
  bool coupe = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) {
    if (coupe) return Future.error(const SocketException('réseau coupé'));
    return _c.send(r);
  }
}

class Appareil {
  final Stockage stockage;
  final ClientCoupable client;
  late final BaseLocale base;
  late final Api api;
  late final Synchro synchro;
  Appareil._(this.stockage, this.client);

  static Future<Appareil> lier(int port, String code, {Stockage? stockage, String? jeton}) async {
    final a = Appareil._(stockage ?? StockageMemoire(), ClientCoupable());
    a.api = Api(base: Uri.parse('http://127.0.0.1:$port/api/'), client: a.client);
    a.api.jetonAppareil = jeton ?? (await a.api.lier(code))['jeton'] as String;
    a.base = BaseLocale(a.stockage);
    await a.base.ouvrir();
    a.synchro = Synchro(base: a.base, api: a.api, idRestaurant: 'chez-amani')..demarrer();
    return a;
  }

  Future<void> attendre(bool Function() condition, {Duration max = const Duration(seconds: 15)}) async {
    final fin = DateTime.now().add(max);
    while (!condition()) {
      if (DateTime.now().isAfter(fin)) throw TimeoutException('condition non atteinte');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Map<String, dynamic>? doc(String chemin) => base.lire('restaurants/chez-amani/$chemin');
}

void main() {
  final actif = Platform.environment['AMANI_TEST_SERVEUR'] == '1';
  late Process serveur;
  late Map<String, dynamic> infos;

  setUpAll(() async {
    if (!actif) return;
    serveur = await Process.start('node', ['test/serveur-essai.js'], workingDirectory: 'serveur');
    final ligne = await serveur.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
    infos = jsonDecode(ligne) as Map<String, dynamic>;
  });

  tearDownAll(() async {
    if (!actif) return;
    await serveur.stdin.close();
    await serveur.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        serveur.kill();
        return 0;
      },
    );
  });

  group('avec le serveur Node.js + MySQL', skip: actif ? false : 'lancer avec AMANI_TEST_SERVEUR=1 (MySQL requis)', () {
    test('hors ligne : écritures gardées, visibles tout de suite, envoyées au retour du réseau', () async {
      final port = infos['port'] as int;
      final codes = (infos['codes'] as List).cast<String>();
      final idServeuse = infos['idServeuse'] as String;
      final a = await Appareil.lier(port, codes[0]);
      final b = await Appareil.lier(port, codes[1]);
      await a.attendre(() => a.doc('articles/flag') != null);
      await b.attendre(() => b.doc('articles/flag') != null);
      expect(a.doc('articles/flag')!['stock'], 20);
      a.base.auteur = idServeuse;
      b.base.auteur = idServeuse;

      // Coupure sur la tablette A : elle vend quand même.
      a.client.coupe = true;
      final vente = a.base.batch()
        ..update(a.base.doc('restaurants/chez-amani/articles/flag'), {'stock': FieldValue.increment(-2)})
        ..update(a.base.doc('restaurants/chez-amani/tables/t1'), {'statut': 'occupee'});
      final accuse = vente.commit();
      expect(a.doc('articles/flag')!['stock'], 18, reason: 'visible tout de suite sur la tablette');
      expect(a.base.nbEnAttente, 1);

      // Pendant ce temps, la tablette B (en ligne) vend aussi.
      await (b.base.batch()
            ..update(b.base.doc('restaurants/chez-amani/articles/flag'), {'stock': FieldValue.increment(-3)}))
          .commit();
      expect(b.doc('articles/flag')!['stock'], 17);

      // Retour du réseau : les deux ventes s'additionnent, sans conflit.
      a.client.coupe = false;
      a.synchro.relancer();
      await accuse.timeout(const Duration(seconds: 15));
      await a.attendre(() => a.base.nbEnAttente == 0 && a.doc('articles/flag')!['stock'] == 15);
      await b.attendre(() => b.doc('articles/flag')!['stock'] == 15 && b.doc('tables/t1')!['statut'] == 'occupee');
      a.synchro.arreter();
      b.synchro.arreter();
    });

    test('file d’attente conservée après un redémarrage de l’appareil', () async {
      final port = infos['port'] as int;
      final codes = (infos['codes'] as List).cast<String>();
      final stockage = StockageMemoire();
      final a = await Appareil.lier(port, codes[2], stockage: stockage);
      await a.attendre(() => a.doc('articles/flag') != null);
      a.base.auteur = infos['idServeuse'] as String;
      a.client.coupe = true;
      unawaited(
        (a.base.batch()..update(a.base.doc('restaurants/chez-amani/tables/t1'), {'statut': 'addition'}))
            .commit()
            .catchError((_) {}),
      );
      a.synchro.arreter();

      // « Redémarrage » : nouvelle base sur le même stockage, réseau revenu.
      final jeton = a.api.jetonAppareil!;
      final a2 = await Appareil.lier(port, '', stockage: stockage, jeton: jeton);
      expect(a2.base.nbEnAttente, 1);
      expect(a2.doc('tables/t1')!['statut'], 'addition');
      await a2.attendre(() => a2.base.nbEnAttente == 0);
      a2.synchro.arreter();
    });

    test('écriture refusée par le serveur : erreur et retour à l’état du serveur', () async {
      final a = await Appareil.lier(infos['port'] as int, (infos['codes'] as List)[3] as String);
      await a.attendre(() => a.doc('articles/flag') != null);
      a.base.auteur = infos['idServeuse'] as String; // une serveuse ne change pas les prix
      final prix = a.doc('articles/flag')!['prix'];
      final f = (a.base.batch()..update(a.base.doc('restaurants/chez-amani/articles/flag'), {'prix': 1})).commit();
      expect(a.doc('articles/flag')!['prix'], 1);
      await expectLater(f, throwsA(isA<ErreurEcriture>()));
      expect(a.doc('articles/flag')!['prix'], prix);
      expect(a.base.nbEnAttente, 0);
      a.synchro.arreter();
    });
  });
}
