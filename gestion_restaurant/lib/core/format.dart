import 'package:intl/intl.dart';

final _f = NumberFormat.decimalPattern('fr');

/// 12500 → "12 500 F"
String fcfa(num montant) => '${_f.format(montant.round()).replaceAll(' ', ' ').replaceAll(' ', ' ')} F';

String heure(DateTime d) => DateFormat('HH:mm').format(d);
String dateHeure(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
String dateCourte(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String dateJour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String dateJourFr(DateTime d) => DateFormat('d MMMM yyyy', 'fr').format(d);
String moisFr(DateTime d) => DateFormat('MMMM yyyy', 'fr').format(d);

/// Compare deux versions « 1.2.10 » (négatif si a < b, 0 si égales).
int comparerVersions(String a, String b) {
  List<int> p(String v) => v.split('+').first.split('.').map((x) => int.tryParse(x) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}
