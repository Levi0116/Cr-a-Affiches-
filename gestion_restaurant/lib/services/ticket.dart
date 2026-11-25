import '../core/format.dart';
import '../models/modeles.dart';

/// Ticket thermique 80 mm (section 4.5) : mis en page en HTML avec
/// `@page { size: 80mm auto; }`, environ 48 caractères par ligne.
String _e(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

const _style = '''
@page { size: 80mm auto; margin: 0; }
* { box-sizing: border-box; }
body { width: 80mm; margin: 0; padding: 3mm 4mm; font-family: 'Courier New', monospace;
  font-size: 12px; line-height: 1.35; color: #000; }
.c { text-align: center; } .b { font-weight: bold; }
.nom { font-size: 16px; font-weight: bold; }
.logo { max-width: 40mm; max-height: 20mm; }
hr { border: none; border-top: 1px dashed #000; margin: 4px 0; }
table { width: 100%; border-collapse: collapse; }
td { vertical-align: top; padding: 1px 0; } td.r { text-align: right; white-space: nowrap; }
.total td { font-size: 18px; font-weight: bold; padding-top: 4px; }
.barre { text-decoration: line-through; }
.dup { font-size: 16px; font-weight: bold; border: 2px solid #000; padding: 2px; margin: 4px 0; }
''';

String _entete(Restaurant r) =>
    '''
<div class="c">
${r.logoUrl.isNotEmpty ? '<img class="logo" src="${_e(r.logoUrl)}"><br>' : ''}
<div class="nom">${_e(r.nom)}</div>
${r.adresse.isNotEmpty ? '<div>${_e(r.adresse)}</div>' : ''}
${r.telephone.isNotEmpty ? '<div>Tél : ${_e(r.telephone)}</div>' : ''}
${r.mentionsFacture.isNotEmpty ? '<div>${_e(r.mentionsFacture)}</div>' : ''}
</div><hr>''';

String _lignes(List<LigneCommande> lignes) {
  final sb = StringBuffer('<table>');
  for (final l in lignes) {
    final cls = l.annulee ? ' class="barre"' : '';
    final suffixe = l.annulee ? ' (annulé)' : (l.offert ? ' (offert)' : '');
    sb.write(
      '<tr$cls><td>${l.quantite} × ${_e(l.nom)}$suffixe'
      '<br><small>${fcfa(l.prixUnitaire)}</small></td>'
      '<td class="r">${fcfa(l.montant)}</td></tr>',
    );
  }
  sb.write('</table>');
  return sb.toString();
}

String _page(String corps) =>
    '<!doctype html><html><head><meta charset="utf-8"><style>$_style</style></head><body>$corps</body></html>';

/// Facture finale (ou duplicata).
String ticketFacture(Restaurant r, Facture f, {bool duplicata = false}) {
  final sb = StringBuffer(_entete(r));
  if (duplicata) sb.write('<div class="c dup">DUPLICATA</div>');
  sb.write(
    '<div class="b">Facture ${_e(f.numero)}'
    '${f.partie != null ? ' (part ${f.partie})' : ''}</div>',
  );
  sb.write('<div>${dateHeure(f.date)}</div>');
  sb.write('<div>Table : ${_e(f.numeroTable)}</div>');
  sb.write('<div>Serveuse : ${_e(f.nomServeuse)} · Caisse : ${_e(f.nomCaissier)}</div><hr>');
  sb.write(_lignes(f.lignes));
  sb.write('<hr><table>');
  sb.write('<tr><td>Sous-total</td><td class="r">${fcfa(f.sousTotal)}</td></tr>');
  if (f.remise > 0) {
    sb.write(
      '<tr><td>Remise${f.motifRemise != null ? ' (${_e(f.motifRemise!)})' : ''}</td>'
      '<td class="r">-${fcfa(f.remise)}</td></tr>',
    );
  }
  if (f.partie != null) {
    sb.write('<tr><td>Total table</td><td class="r">${fcfa(f.sousTotal - f.remise)}</td></tr>');
  }
  if (f.tva > 0) {
    sb.write('<tr><td>dont TVA</td><td class="r">${fcfa(f.tva)}</td></tr>');
  }
  sb.write(
    '<tr class="total"><td>TOTAL${f.partie != null ? ' PART' : ''}</td>'
    '<td class="r">${fcfa(f.total)}</td></tr>',
  );
  if (f.statut == StatutFacture.payee) {
    sb.write('<tr><td>Montant reçu</td><td class="r">${fcfa(f.montantRecu)}</td></tr>');
    sb.write('<tr><td>Monnaie rendue</td><td class="r">${fcfa(f.monnaieRendue)}</td></tr>');
  } else if (f.statut == StatutFacture.credit) {
    sb.write('<tr><td colspan="2" class="b">À CRÉDIT (ardoise)</td></tr>');
  }
  sb.write('</table><hr><div class="c">${_e(r.messageBasTicket)}</div>');
  return _page(sb.toString());
}

/// Pré-addition : « à titre indicatif », sans numéro de facture.
String ticketPreAddition(Restaurant r, SessionTable s, List<LigneCommande> lignes, int total) {
  final sb = StringBuffer(_entete(r));
  sb.write('<div class="c b">PRÉ-ADDITION<br>à titre indicatif</div>');
  sb.write('<div>${dateHeure(DateTime.now())}</div>');
  sb.write('<div>Table : ${_e(s.numeroTable)} · Serveuse : ${_e(s.nomServeuse)}</div><hr>');
  sb.write(_lignes(lignes.where((l) => !l.annulee).toList()));
  sb.write('<hr><table><tr class="total"><td>TOTAL</td><td class="r">${fcfa(total)}</td></tr></table>');
  sb.write('<hr><div class="c">Ce document n\'est pas une facture</div>');
  return _page(sb.toString());
}

/// Rapport de clôture de caisse.
String ticketCloture(Restaurant r, JourneeCaisse j, {required int nbFactures}) {
  final sb = StringBuffer(_entete(r));
  sb.write('<div class="c b">CLÔTURE DE CAISSE</div>');
  sb.write('<div>Ouverture : ${dateHeure(j.ouverture)}</div>');
  if (j.cloture != null) sb.write('<div>Clôture : ${dateHeure(j.cloture!)}</div>');
  sb.write('<div>Caissier : ${_e(j.caissier)}</div><hr><table>');
  sb.write('<tr><td>Fond de caisse</td><td class="r">${fcfa(j.fond)}</td></tr>');
  sb.write('<tr><td>Encaissements ($nbFactures)</td><td class="r">${fcfa(j.totalEncaisse)}</td></tr>');
  sb.write('<tr class="b"><td>Total théorique</td><td class="r">${fcfa(j.totalTheorique)}</td></tr>');
  sb.write('<tr><td>Argent compté</td><td class="r">${fcfa(j.totalCompte ?? 0)}</td></tr>');
  sb.write('<tr class="total"><td>ÉCART</td><td class="r">${fcfa(j.ecart ?? 0)}</td></tr>');
  sb.write('</table><hr><div class="c">Journée verrouillée</div>');
  return _page(sb.toString());
}
