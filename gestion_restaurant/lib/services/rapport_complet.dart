import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../donnees/base.dart';
import '../theme/identite.dart';
import 'db.dart';

/// ============================================================================
///  RAPPORT COMPLET (PDF) — toutes les données du restaurant sur une période
/// ============================================================================
///
/// Construit à partir de la copie locale de l'appareil (aucune connexion
/// requise) : synthèse, service des serveuses, ventes, factures détaillées,
/// caisse (journées, encaissements), ardoises, avoirs, dépenses, stock (état,
/// mouvements, livraisons), validations, journal d'audit, menu, tables,
/// comptes de l'équipe et appareils. Les codes PIN n'y figurent jamais.

/// Période du rapport complet (`debut` inclus, `fin` exclue ; null = sans limite).
class PeriodeRapport {
  final String libelle;
  final DateTime? debut;
  final DateTime? fin;
  const PeriodeRapport(this.libelle, this.debut, this.fin);

  bool contient(DateTime? d) =>
      d != null && (debut == null || !d.isBefore(debut!)) && (fin == null || d.isBefore(fin!));
}

final _nombre = NumberFormat.decimalPattern('fr');
String _f(num v) => '${_nombre.format(v.round()).replaceAll(' ', ' ').replaceAll(' ', ' ')} F';
String _n(num v) => _nombre.format(v).replaceAll(' ', ' ').replaceAll(' ', ' ');
String _dh(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
String _j(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
DateTime? _dateDe(Map<String, dynamic> m, List<String> cles) {
  for (final c in cles) {
    final d = _date(m[c]);
    if (d != null) return d;
  }
  return null;
}

int _i(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
String _t(Object? v) => v == null ? '' : '$v'.replaceAll(' ', ' ').replaceAll(' ', ' ');

const _libellesStatut = {
  'emise': 'À encaisser',
  'payee': 'Payée',
  'ardoise': 'À crédit',
  'annulee': 'Annulée',
  'en_attente': 'En attente',
  'validee': 'Validée',
  'refusee': 'Refusée',
};
String _statut(Object? s) => _libellesStatut['$s'] ?? _t(s);

const _roles = {
  'serveuse': 'Serveuse',
  'caissier': 'Caissier',
  'gestionnaire': 'Gestionnaire de stock',
  'admin': 'Administrateur',
};

typedef _Docs = List<Map<String, dynamic>>;

Future<_Docs> _lire(CollectionReference<Map<String, dynamic>> c) async =>
    [for (final d in (await c.get()).docs) {...d.data(), '_id': d.id}];

/// Génère le PDF (octets) du rapport complet.
Future<List<int>> rapportCompletPdf(RestoDb db, PeriodeRapport periode, {String genereePar = ''}) async {
  // --- Données (copie locale)
  final resto = (await db.resto.get()).data() ?? const <String, dynamic>{};
  final factures = (await _lire(db.factures)).where((f) => periode.contient(_dateDe(f, ['date', 'heureAppareil']))).toList()
    ..sort((a, b) => _dateDe(a, ['date'])!.compareTo(_dateDe(b, ['date'])!));
  final sessions = (await _lire(db.sessions)).where((s) => periode.contient(_dateDe(s, ['ouverture', 'heureAppareil']))).toList();
  final journees = (await _lire(db.journeesCaisse)).where((j) => periode.contient(_dateDe(j, ['ouverture']))).toList()
    ..sort((a, b) => _dateDe(a, ['ouverture'])!.compareTo(_dateDe(b, ['ouverture'])!));
  List<Map<String, dynamic>> filtre(_Docs l, List<String> cles) {
    final r = l.where((x) => periode.contient(_dateDe(x, cles))).toList();
    r.sort((a, b) => (_dateDe(a, cles) ?? DateTime(2000)).compareTo(_dateDe(b, cles) ?? DateTime(2000)));
    return r;
  }

  final encaissements = filtre(await _lire(db.encaissements), ['heureAppareil', 'creeLe']);
  final mouvements = filtre(await _lire(db.mouvementsStock), ['heureAppareil', 'creeLe']);
  final livraisons = filtre(await _lire(db.livraisons), ['heureAppareil', 'creeLe']);
  final avoirs = filtre(await _lire(db.avoirs), ['heureAppareil', 'creeLe']);
  final depenses = filtre(await _lire(db.depenses), ['date', 'heureAppareil']);
  final validations = filtre(await _lire(db.demandesValidation), ['heureAppareil', 'creeLe']);
  final audit = filtre(await _lire(db.journalAudit), ['heureAppareil', 'creeLe']);
  final ardoises = await _lire(db.ardoises);
  final articles = await _lire(db.articles);
  final categories = {for (final c in await _lire(db.categories)) c['_id'] as String: _t(c['nom'])};
  final zones = {for (final z in await _lire(db.zones)) z['_id'] as String: _t(z['nom'])};
  final tables = await _lire(db.tables);
  final employes = (await _lire(db.employes)).where((e) => e['supprime'] != true).toList();
  final appareils = await _lire(db.appareils);

  // --- Calculs
  final vendues = factures.where((f) => f['statut'] == 'payee' || f['statut'] == 'ardoise').toList();
  final ca = vendues.fold<int>(0, (s, f) => s + _i(f['total']));
  final encaisse = factures.where((f) => f['statut'] == 'payee').fold<int>(0, (s, f) => s + _i(f['total']));
  final credit = factures.where((f) => f['statut'] == 'ardoise').fold<int>(0, (s, f) => s + _i(f['total']));
  final totalAvoirs = avoirs.fold<int>(0, (s, a) => s + _i(a['montant']));
  final totalDepenses = depenses.fold<int>(0, (s, d) => s + _i(d['montant']));
  final couverts = sessions.fold<int>(0, (s, x) => s + _i(x['couverts']));

  final serveuses = <String, ({int factures, int ca, Set<String> tables, int couverts, int annulations})>{};
  for (final s in sessions) {
    final nom = _t(s['nomServeuse']).isEmpty ? '—' : _t(s['nomServeuse']);
    final v = serveuses[nom] ?? (factures: 0, ca: 0, tables: <String>{}, couverts: 0, annulations: 0);
    v.tables.add(_t(s['numeroTable']));
    serveuses[nom] = (factures: v.factures, ca: v.ca, tables: v.tables, couverts: v.couverts + _i(s['couverts']), annulations: v.annulations);
  }
  final ventes = <String, ({int quantite, int montant})>{};
  final parCategorie = <String, int>{};
  final idCategorieArticle = {for (final a in articles) a['_id'] as String: _t(a['idCategorie'])};
  for (final f in vendues) {
    final nom = _t(f['nomServeuse']).isEmpty ? '—' : _t(f['nomServeuse']);
    final v = serveuses[nom] ?? (factures: 0, ca: 0, tables: <String>{}, couverts: 0, annulations: 0);
    var annul = 0;
    final partielle = f['partie'] != null && !_t(f['partie']).startsWith('1/');
    for (final l in (f['lignes'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(l as Map);
      if (m['statut'] == 'annulee') {
        annul++;
        continue;
      }
      if (partielle) continue;
      final cle = _t(m['nom']);
      final montant = m['offert'] == true ? 0 : _i(m['quantite']) * _i(m['prixUnitaire']);
      final p = ventes[cle] ?? (quantite: 0, montant: 0);
      ventes[cle] = (quantite: p.quantite + _i(m['quantite']), montant: p.montant + montant);
      final cat = categories[idCategorieArticle[_t(m['idArticle'])]] ?? 'Autres';
      parCategorie[cat] = (parCategorie[cat] ?? 0) + montant;
    }
    serveuses[nom] = (
      factures: v.factures + 1,
      ca: v.ca + _i(f['total']),
      tables: v.tables..add(_t(f['numeroTable'])),
      couverts: v.couverts,
      annulations: v.annulations + annul,
    );
  }
  final ventesTriees = ventes.entries.toList()..sort((a, b) => b.value.montant.compareTo(a.value.montant));

  // --- Mise en page
  final police = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-400.ttf'));
  final gras = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-700.ttf'));
  final marque = pw.Font.ttf(await rootBundle.load('assets/fonts/Fraunces-700-normal.ttf'));
  final italique = pw.Font.ttf(await rootBundle.load('assets/fonts/Fraunces-600-italic.ttf'));
  final logo = identite.logoAsset == null ? null : pw.MemoryImage((await rootBundle.load(identite.logoAsset!)).buffer.asUint8List());

  final vert = PdfColor.fromInt(identite.secondaire.toARGB32());
  final orange = PdfColor.fromInt(identite.principale.toARGB32());
  final creme = PdfColor.fromInt(0xFFFBF5EA);
  final nomResto = _t(resto['nom']).isEmpty ? identite.nomRestaurant : _t(resto['nom']);
  final genereLe = DateTime.now();

  final doc = pw.Document(
    title: 'Rapport complet — $nomResto — ${periode.libelle}',
    author: nomResto,
    theme: pw.ThemeData.withFont(base: police, bold: gras),
  );

  pw.Widget titre(String t, [String? sous]) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(t, style: pw.TextStyle(font: marque, fontSize: 17, color: vert)),
        if (sous != null) pw.Text(sous, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.Container(margin: const pw.EdgeInsets.only(top: 3), height: 2, width: 60, color: orange),
      ],
    ),
  );

  pw.Widget tableau(List<String> entetes, List<List<String>> lignes, {Map<int, pw.Alignment>? alignements, Map<int, pw.TableColumnWidth>? largeurs}) {
    if (lignes.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text('Aucune donnée sur la période.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );
    }
    return pw.TableHelper.fromTextArray(
      headers: entetes,
      data: lignes,
      headerStyle: pw.TextStyle(font: gras, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: vert),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: pw.BoxDecoration(color: creme),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
      cellAlignments: alignements ?? const {},
      columnWidths: largeurs,
    );
  }

  pw.Widget indicateurs(List<(String, String)> v) => pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (l, x) in v)
        pw.Container(
          width: 120,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: creme, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(l, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(x, style: pw.TextStyle(font: gras, fontSize: 12, color: vert)),
            ],
          ),
        ),
    ],
  );

  const droite = pw.Alignment.centerRight;

  // Page de garde.
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (logo != null) pw.ClipOval(child: pw.Image(logo, width: 130, height: 130)),
            pw.SizedBox(height: 18),
            pw.Text(nomResto, style: pw.TextStyle(font: marque, fontSize: 28, color: vert), textAlign: pw.TextAlign.center),
            if (identite.slogan.isNotEmpty)
              pw.Text(identite.slogan, style: pw.TextStyle(font: italique, fontSize: 13, color: orange)),
            pw.SizedBox(height: 30),
            pw.Text('RAPPORT COMPLET', style: pw.TextStyle(font: gras, fontSize: 12, letterSpacing: 3, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            pw.Text(periode.libelle, style: pw.TextStyle(font: marque, fontSize: 18)),
            pw.SizedBox(height: 30),
            pw.Text('Généré le ${_dh(genereLe)}${genereePar.isEmpty ? '' : ' par $genereePar'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (_t(resto['adresse']).isNotEmpty || _t(resto['telephone']).isNotEmpty)
              pw.Text([_t(resto['adresse']), _t(resto['telephone'])].where((x) => x.isNotEmpty).join(' · '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 24),
            pw.Text(
              'Sommaire : 1. Synthèse · 2. Service des serveuses · 3. Ventes · 4. Factures · 5. Caisse · 6. Ardoises, avoirs, dépenses · 7. Stock · 8. Validations · 9. Journal d’audit · 10. Configuration',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
      header: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$nomResto · Rapport complet', style: pw.TextStyle(font: gras, fontSize: 8, color: vert)),
            pw.Text(periode.libelle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Généré le ${_dh(genereLe)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
      build: (c) => [
        // 1. Synthèse
        titre('1. Synthèse'),
        indicateurs([
          ('Chiffre d’affaires', _f(ca)),
          ('Encaissé', _f(encaisse)),
          ('À crédit (ardoises)', _f(credit)),
          ('Factures', _n(vendues.length)),
          ('Panier moyen', _f(vendues.isEmpty ? 0 : ca / vendues.length)),
          ('Avoirs', _f(totalAvoirs)),
          ('Dépenses', _f(totalDepenses)),
          ('Résultat (CA − avoirs − dépenses)', _f(ca - totalAvoirs - totalDepenses)),
          ('Tables servies', _n(sessions.length)),
          ('Couverts', _n(couverts)),
          ('Journées de caisse', _n(journees.length)),
          ('Mouvements de stock', _n(mouvements.length)),
        ]),

        // 2. Serveuses
        titre('2. Service des serveuses', 'Tables ouvertes, couverts, factures et chiffre d’affaires par serveuse'),
        tableau(
          ['Serveuse', 'Tables', 'Couverts', 'Factures', 'Chiffre d’affaires', 'Lignes annulées'],
          [
            for (final e in (serveuses.entries.toList()..sort((a, b) => b.value.ca.compareTo(a.value.ca))))
              [e.key, _n(e.value.tables.length), _n(e.value.couverts), _n(e.value.factures), _f(e.value.ca), _n(e.value.annulations)],
          ],
          alignements: {1: droite, 2: droite, 3: droite, 4: droite, 5: droite},
        ),

        // 3. Ventes
        titre('3. Ventes par article et par catégorie'),
        tableau(
          ['Article', 'Quantité', 'Montant'],
          [for (final e in ventesTriees) [e.key, _n(e.value.quantite), _f(e.value.montant)]],
          alignements: {1: droite, 2: droite},
        ),
        pw.SizedBox(height: 8),
        tableau(
          ['Catégorie', 'Montant'],
          [for (final e in (parCategorie.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))) [e.key, _f(e.value)]],
          alignements: {1: droite},
        ),

        // 4. Factures
        titre('4. Factures', '${factures.length} facture(s) sur la période, avec le détail des articles'),
        tableau(
          ['N°', 'Date', 'Table', 'Serveuse', 'Caissier', 'Statut', 'Total', 'Reçu', 'Rendu'],
          [
            for (final f in factures)
              [
                _t(f['numero']),
                _dh(_dateDe(f, ['date'])),
                _t(f['numeroTable']),
                _t(f['nomServeuse']),
                _t(f['nomCaissier']),
                _statut(f['statut']),
                _f(_i(f['total'])),
                _i(f['montantRecu']) == 0 ? '' : _f(_i(f['montantRecu'])),
                _i(f['monnaieRendue']) == 0 ? '' : _f(_i(f['monnaieRendue'])),
              ],
          ],
          alignements: {6: droite, 7: droite, 8: droite},
        ),
        if (factures.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Détail des articles par facture', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
          pw.SizedBox(height: 4),
          tableau(
            ['Facture', 'Article', 'Qté', 'Prix unit.', 'Montant', 'Remarque'],
            [
              for (final f in factures)
                for (final l in (f['lignes'] as List? ?? const []))
                  () {
                    final m = Map<String, dynamic>.from(l as Map);
                    return [
                      _t(f['numero']),
                      _t(m['nom']),
                      _n(_i(m['quantite'])),
                      _f(_i(m['prixUnitaire'])),
                      _f(m['offert'] == true ? 0 : _i(m['quantite']) * _i(m['prixUnitaire'])),
                      [if (m['statut'] == 'annulee') 'annulée', if (m['offert'] == true) 'offert', _t(m['note'])].where((x) => x.isNotEmpty).join(' · '),
                    ];
                  }(),
            ],
            alignements: {2: droite, 3: droite, 4: droite},
          ),
        ],

        // 5. Caisse
        titre('5. Caisse', 'Ouvertures et clôtures (comptage) puis tous les encaissements'),
        tableau(
          ['Ouverture', 'Clôture', 'Caissier', 'Fond', 'Encaissé', 'Théorique', 'Compté', 'Écart'],
          [
            for (final j in journees)
              [
                _dh(_dateDe(j, ['ouverture'])),
                j['verrouillee'] == true ? _dh(_dateDe(j, ['cloture'])) : 'ouverte',
                _t(j['caissier']),
                _f(_i(j['fond'])),
                _f(_i(j['totalEncaisse'])),
                _f(_i(j['totalTheorique'])),
                j['totalCompte'] == null ? '' : _f(_i(j['totalCompte'])),
                j['ecart'] == null ? '' : _f(_i(j['ecart'])),
              ],
          ],
          alignements: {3: droite, 4: droite, 5: droite, 6: droite, 7: droite},
        ),
        pw.SizedBox(height: 8),
        tableau(
          ['Date', 'Type', 'Facture / client', 'Caissier', 'Montant', 'Reçu', 'Rendu'],
          [
            for (final e in encaissements)
              [
                _dh(_dateDe(e, ['heureAppareil', 'creeLe'])),
                _t(e['type']).isEmpty ? 'facture' : _t(e['type']),
                [_t(e['numeroFacture']), _t(e['client'])].where((x) => x.isNotEmpty).join(' · '),
                _t(e['caissier']),
                _f(_i(e['montant'])),
                _i(e['montantRecu']) == 0 ? '' : _f(_i(e['montantRecu'])),
                _i(e['monnaieRendue']) == 0 ? '' : _f(_i(e['monnaieRendue'])),
              ],
          ],
          alignements: {4: droite, 5: droite, 6: droite},
        ),

        // 6. Ardoises, avoirs, dépenses
        titre('6. Ardoises, avoirs et dépenses'),
        pw.Text('Ardoises (crédits clients, état actuel)', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
        pw.SizedBox(height: 4),
        tableau(
          ['Client', 'Téléphone', 'Factures', 'Reste dû', 'Créée le'],
          [
            for (final a in ardoises)
              [_t(a['client']), _t(a['telephone']), _n((a['idsFactures'] as List? ?? const []).length), _f(_i(a['montantDu'])), _j(_dateDe(a, ['heureAppareil', 'creeLe']))],
          ],
          alignements: {2: droite, 3: droite},
        ),
        pw.SizedBox(height: 8),
        pw.Text('Avoirs (corrections de factures)', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
        pw.SizedBox(height: 4),
        tableau(
          ['Date', 'N° avoir', 'Facture', 'Montant', 'Motif'],
          [for (final a in avoirs) [_dh(_dateDe(a, ['heureAppareil', 'creeLe'])), _t(a['numero']), _t(a['numeroFacture']), _f(_i(a['montant'])), _t(a['motif'])]],
          alignements: {3: droite},
        ),
        pw.SizedBox(height: 8),
        pw.Text('Dépenses', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
        pw.SizedBox(height: 4),
        tableau(
          ['Date', 'Catégorie', 'Description', 'Montant'],
          [for (final d in depenses) [_dh(_dateDe(d, ['date', 'heureAppareil'])), _t(d['categorie']), _t(d['description']), _f(_i(d['montant']))]],
          alignements: {3: droite},
        ),

        // 7. Stock
        titre('7. Stock', 'État actuel des articles, puis mouvements et livraisons de la période'),
        tableau(
          ['Article', 'Catégorie', 'Stock', 'Seuil', 'Unité', 'Coût moyen', 'Valeur', 'État'],
          [
            for (final a in (articles.where((a) => a['suiviStock'] != false && a['aRecette'] != true).toList()
              ..sort((x, y) => _t(x['nom']).compareTo(_t(y['nom'])))))
              () {
                final stock = _i(a['stock']);
                final seuil = _i(a['seuilAlerte']);
                return [
                  _t(a['nom']),
                  categories[_t(a['idCategorie'])] ?? '',
                  _n(stock),
                  _n(seuil),
                  _t(a['unite']),
                  _f(_i(a['coutMoyen'])),
                  _f(stock * _i(a['coutMoyen'])),
                  stock <= 0 ? 'Rupture' : (stock <= seuil ? 'Stock bas' : 'OK'),
                ];
              }(),
          ],
          alignements: {2: droite, 3: droite, 5: droite, 6: droite},
        ),
        pw.SizedBox(height: 8),
        pw.Text('Mouvements de stock', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
        pw.SizedBox(height: 4),
        tableau(
          ['Date', 'Article', 'Type', 'Quantité', 'Motif', 'Par'],
          [
            for (final m in mouvements)
              [_dh(_dateDe(m, ['heureAppareil', 'creeLe'])), _t(m['nomArticle']), _t(m['type']), _n(m['quantite'] is num ? m['quantite'] as num : 0), _t(m['motif']), _t(m['auteur'])],
          ],
          alignements: {3: droite},
        ),
        pw.SizedBox(height: 8),
        pw.Text('Livraisons', style: pw.TextStyle(font: gras, fontSize: 10, color: vert)),
        pw.SizedBox(height: 4),
        tableau(
          ['Date', 'Article', 'Casiers', 'Unités', 'Prix unitaire', 'Montant', 'Fournisseur'],
          [
            for (final l in livraisons)
              [
                _dh(_dateDe(l, ['heureAppareil', 'creeLe'])),
                _t(l['nomArticle']),
                _n(_i(l['casiers'])),
                _n(_i(l['unites'] ?? l['quantite'])),
                _f(_i(l['prixAchatUnitaire'])),
                _f(_i(l['montant'])),
                _t(l['fournisseur']),
              ],
          ],
          alignements: {2: droite, 3: droite, 4: droite, 5: droite},
        ),

        // 8. Validations
        titre('8. Validations', 'Annulations, remises, offerts et ajustements demandés à l’administrateur'),
        tableau(
          ['Date', 'Type', 'Demandeur', 'Motif', 'Statut', 'Validé par'],
          [
            for (final v in validations)
              [_dh(_dateDe(v, ['heureAppareil', 'creeLe'])), _t(v['type']), _t(v['demandeur']), _t(v['motif']), _statut(v['statut']), _t(v['valideur'])],
          ],
        ),

        // 9. Journal d'audit
        titre('9. Journal d’audit', 'Toutes les actions enregistrées (qui, quoi, quand, sur quel appareil)'),
        tableau(
          ['Date', 'Employé', 'Action', 'Détail', 'Appareil'],
          [for (final a in audit) [_dh(_dateDe(a, ['heureAppareil', 'creeLe'])), _t(a['employe']), _t(a['action']), _t(a['detail']), _t(a['appareil'])]],
          largeurs: const {0: pw.FixedColumnWidth(62), 1: pw.FixedColumnWidth(55), 2: pw.FixedColumnWidth(70), 4: pw.FixedColumnWidth(60)},
        ),

        // 10. Configuration
        titre('10. Configuration du restaurant', 'Menu et prix, tables, comptes de l’équipe (sans les codes) et appareils liés'),
        tableau(
          ['Catégorie', 'Article', 'Prix', 'Disponible'],
          [
            for (final a in (articles.where((a) => a['idCategorie'] != 'c-ingredients').toList()
              ..sort((x, y) => '${categories[_t(x['idCategorie'])]}${_t(x['nom'])}'.compareTo('${categories[_t(y['idCategorie'])]}${_t(y['nom'])}'))))
              [categories[_t(a['idCategorie'])] ?? '', _t(a['nom']), _f(_i(a['prixVente'])), a['actif'] == false ? 'retiré du menu' : (a['disponible'] == false ? 'non' : 'oui')],
          ],
          alignements: {2: droite},
        ),
        pw.SizedBox(height: 8),
        tableau(
          ['Zone', 'Table', 'Places', 'Active'],
          [
            for (final t in (tables.toList()..sort((a, b) => (int.tryParse(_t(a['numero'])) ?? 999).compareTo(int.tryParse(_t(b['numero'])) ?? 999))))
              [zones[_t(t['idZone'])] ?? '', _t(t['numero']), _n(_i(t['capacite'])), t['active'] == false ? 'non' : 'oui'],
          ],
        ),
        pw.SizedBox(height: 8),
        tableau(
          ['Employé', 'Rôle', 'Compte'],
          [for (final e in employes) [_t(e['nom']), _roles[_t(e['role'])] ?? _t(e['role']), e['actif'] == false ? 'désactivé' : 'actif']],
        ),
        pw.SizedBox(height: 8),
        tableau(
          ['Appareil', 'Type', 'Administrateur', 'Lié le', 'État'],
          [
            for (final a in appareils)
              [_t(a['nom']), _t(a['type']), a['admin'] == true ? 'oui' : 'non', _j(_dateDe(a, ['lieLe'])), a['revoque'] == true ? 'retiré' : 'actif'],
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
