import 'package:excel/excel.dart';

import '../core/format.dart';
import '../core/rapports.dart';
import '../models/modeles.dart';

String libellePeriode(Periode p) => switch (p.type) {
  TypePeriode.jour => 'Journée du ${dateJourFr(p.debut)}',
  TypePeriode.semaine => 'Semaine du ${dateJourFr(p.debut)} au ${dateJourFr(p.fin.subtract(const Duration(days: 1)))}',
  TypePeriode.mois => 'Mois de ${moisFr(p.debut)}',
};

String nomFichier(Periode p) => 'rapport-${dateJour(p.debut)}-${p.type.name}';

/// Classeur Excel (.xlsx) du rapport : une feuille par thème.
List<int> rapportExcel(Restaurant resto, Rapport r, Rapport precedent) {
  final x = Excel.createExcel();
  CellValue t(String s) => TextCellValue(s);
  CellValue n(num v) => v is int ? IntCellValue(v) : DoubleCellValue(v.toDouble());

  final synth = x['Synthèse'];
  synth.appendRow([t(resto.nom)]);
  synth.appendRow([t(libellePeriode(r.periode))]);
  synth.appendRow([]);
  synth.appendRow([t('Indicateur'), t('Période'), t('Période précédente')]);
  for (final (lib, a, b) in [
    ('Chiffre d’affaires (F)', r.chiffreAffaires, precedent.chiffreAffaires),
    ('Nombre de factures', r.nbFactures, precedent.nbFactures),
    ('Panier moyen (F)', r.panierMoyen, precedent.panierMoyen),
    ('Encaissé (F)', r.encaisse, precedent.encaisse),
    ('À crédit (F)', r.aCredit, precedent.aCredit),
    ('Avoirs (F)', r.avoirs, precedent.avoirs),
    ('Coût des marchandises vendues (F)', r.coutMarchandises, precedent.coutMarchandises),
    ('Marge brute (F)', r.margeBrute, precedent.margeBrute),
    ('Dépenses (F)', r.depenses, precedent.depenses),
    ('Bénéfice estimé (F)', r.beneficeEstime, precedent.beneficeEstime),
  ]) {
    synth.appendRow([t(lib), n(a), n(b)]);
  }

  final art = x['Articles'];
  art.appendRow([t('Article'), t('Quantité'), t('Ventes (F)'), t('Coût (F)'), t('Marge (F)'), t('Taux de marge')]);
  for (final v in r.articles) {
    art.appendRow([
      t(v.nom),
      n(v.quantite),
      n(v.montant),
      n(v.cout),
      n(v.marge),
      t('${(v.tauxMarge * 100).round()} %'),
    ]);
  }
  art.appendRow([]);
  art.appendRow([t('Articles qui ne se sont pas vendus')]);
  for (final a in r.nonVendus) {
    art.appendRow([t(a.nom)]);
  }

  final cat = x['Catégories'];
  cat.appendRow([t('Catégorie'), t('Ventes (F)')]);
  for (final e in r.ventesParCategorie.entries) {
    cat.appendRow([t(e.key), n(e.value)]);
  }

  final h = x['Heures'];
  h.appendRow([t('Heure'), t('Ventes (F)')]);
  for (var i = 0; i < 24; i++) {
    if (r.ventesParHeure[i] > 0) h.appendRow([t('${i}h – ${i + 1}h'), n(r.ventesParHeure[i])]);
  }

  final s = x['Serveuses'];
  s.appendRow([t('Serveuse'), t('Tables servies'), t('Montant vendu (F)'), t('Annulations')]);
  for (final p in r.serveuses) {
    s.appendRow([t(p.nom), n(p.tables.length), n(p.montant), n(p.annulations)]);
  }

  final d = x['Dépenses'];
  d.appendRow([t('Catégorie'), t('Montant (F)')]);
  for (final e in r.depensesParCategorie.entries) {
    d.appendRow([t(e.key), n(e.value)]);
  }

  x.setDefaultSheet('Synthèse');
  x.delete('Sheet1');
  return x.encode()!;
}

String _e(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Rapport en page A4 imprimable (« Enregistrer au format PDF »).
String rapportHtml(Restaurant resto, Rapport r, Rapport precedent) {
  String evo(num a, num b) {
    final e = evolution(a, b);
    if (e == null) return '—';
    return '${e >= 0 ? '+' : ''}${e.toStringAsFixed(0)} %';
  }

  final sb = StringBuffer()
    ..write(
      '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>${_e(nomFichier(r.periode))}</title><style>
@page { size: A4; margin: 14mm; }
body { font-family: 'Segoe UI', Arial, sans-serif; color: #222; font-size: 12px; }
h1 { font-size: 22px; margin: 0; } h2 { font-size: 15px; margin: 18px 0 6px; border-bottom: 2px solid #C4512B; padding-bottom: 3px; }
.sous { color: #666; margin-bottom: 12px; }
table { width: 100%; border-collapse: collapse; } th, td { padding: 4px 6px; border-bottom: 1px solid #e3e3e3; text-align: left; }
th { background: #f6f1ea; } td.n, th.n { text-align: right; white-space: nowrap; }
.kpi { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.kpi div { border: 1px solid #e3e3e3; border-radius: 8px; padding: 8px; } .kpi b { display: block; font-size: 17px; }
</style></head><body>''',
    )
    ..write(
      '<h1>${_e(resto.nom)}</h1><div class="sous">${_e(libellePeriode(r.periode))} · édité le ${dateHeure(DateTime.now())}</div>',
    )
    ..write('<div class="kpi">');
  for (final (lib, a, b) in [
    ('Chiffre d’affaires', r.chiffreAffaires, precedent.chiffreAffaires),
    ('Factures', r.nbFactures, precedent.nbFactures),
    ('Panier moyen', r.panierMoyen, precedent.panierMoyen),
    ('Marge brute', r.margeBrute, precedent.margeBrute),
    ('Dépenses', r.depenses, precedent.depenses),
    ('Bénéfice estimé', r.beneficeEstime, precedent.beneficeEstime),
  ]) {
    final val = lib == 'Factures' ? '$a' : fcfa(a);
    sb.write('<div>${_e(lib)}<b>$val</b>${evo(a, b)} vs période précédente</div>');
  }
  sb.write('</div>');
  sb.write(
    '<h2>Ventes par article</h2><table><tr><th>Article</th><th class="n">Qté</th><th class="n">Ventes</th>'
    '<th class="n">Coût</th><th class="n">Marge</th></tr>',
  );
  for (final v in r.articles) {
    sb.write(
      '<tr><td>${_e(v.nom)}</td><td class="n">${v.quantite}</td><td class="n">${fcfa(v.montant)}</td>'
      '<td class="n">${fcfa(v.cout)}</td><td class="n">${fcfa(v.marge)} (${(v.tauxMarge * 100).round()} %)</td></tr>',
    );
  }
  sb.write('</table>');
  if (r.nonVendus.isNotEmpty) {
    sb.write('<p><b>Ne se sont pas vendus :</b> ${_e(r.nonVendus.map((a) => a.nom).join(', '))}</p>');
  }
  sb.write('<h2>Ventes par heure</h2><table><tr><th>Heure</th><th class="n">Ventes</th></tr>');
  for (var i = 0; i < 24; i++) {
    if (r.ventesParHeure[i] > 0) {
      sb.write('<tr><td>${i}h – ${i + 1}h</td><td class="n">${fcfa(r.ventesParHeure[i])}</td></tr>');
    }
  }
  sb.write(
    '</table><h2>Serveuses</h2><table><tr><th>Serveuse</th><th class="n">Tables</th><th class="n">Vendu</th>'
    '<th class="n">Annulations</th></tr>',
  );
  for (final p in r.serveuses) {
    sb.write(
      '<tr><td>${_e(p.nom)}</td><td class="n">${p.tables.length}</td><td class="n">${fcfa(p.montant)}</td>'
      '<td class="n">${p.annulations}</td></tr>',
    );
  }
  sb.write('</table>');
  if (r.depensesParCategorie.isNotEmpty) {
    sb.write('<h2>Dépenses</h2><table>');
    for (final e in r.depensesParCategorie.entries) {
      sb.write('<tr><td>${_e(e.key)}</td><td class="n">${fcfa(e.value)}</td></tr>');
    }
    sb.write('</table>');
  }
  sb.write('</body></html>');
  return sb.toString();
}
