import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Les codes PIN ne sont jamais stockés en clair (section 6.6).
/// Le hachage est salé avec l'identifiant du restaurant et de l'employé,
/// pour que deux employés ayant le même PIN n'aient pas le même hash.
String hacherPin({required String idRestaurant, required String idEmploye, required String pin}) =>
    sha256.convert(utf8.encode('$idRestaurant:$idEmploye:$pin')).toString();

bool pinValide(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
