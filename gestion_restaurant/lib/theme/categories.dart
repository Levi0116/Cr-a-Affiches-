import 'package:material_ui/material_ui.dart';

import 'identite.dart';

/// Icône devinée à partir du nom de la catégorie.
IconData iconeCategorie(String nom) {
  final n = nom.toLowerCase();
  if (n.contains('favori')) return Icons.star_rounded;
  if (n.contains('bière') || n.contains('biere') || n.contains('alcool') || n.contains('vin')) {
    return Icons.sports_bar_rounded;
  }
  if (n.contains('sucrerie') || n.contains('soda') || n.contains('jus') || n.contains('boisson')) {
    return Icons.local_drink_rounded;
  }
  if (n.contains('eau')) return Icons.water_drop_rounded;
  if (n.contains('grill') || n.contains('brochette') || n.contains('braise')) return Icons.outdoor_grill_rounded;
  if (n.contains('plat') || n.contains('cuisine') || n.contains('repas')) return Icons.restaurant_rounded;
  if (n.contains('cigarette') || n.contains('tabac')) return Icons.smoking_rooms_rounded;
  if (n.contains('dessert') || n.contains('glace')) return Icons.icecream_rounded;
  if (n.contains('café') || n.contains('cafe') || n.contains('thé')) return Icons.coffee_rounded;
  return Icons.fastfood_rounded;
}

/// Teinte de catégorie, tirée d'une palette dérivée de l'identité.
Color couleurCategorie(int index) {
  final palette = [
    identite.principale,
    identite.accent,
    identite.tableAddition,
    identite.tableLibre,
    const Color(0xFF8E3B5E), // prune
    const Color(0xFF5B6B2F), // olive
    identite.tableOccupee,
  ];
  return palette[index % palette.length];
}
