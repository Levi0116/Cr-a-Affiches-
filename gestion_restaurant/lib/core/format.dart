import 'package:intl/intl.dart';

final _f = NumberFormat.decimalPattern('fr');

/// 12500 → "12 500 F"
String fcfa(num montant) => '${_f.format(montant.round()).replaceAll(' ', ' ').replaceAll(' ', ' ')} F';

String heure(DateTime d) => DateFormat('HH:mm').format(d);
String dateHeure(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
String dateJour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
