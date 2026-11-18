import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/db.dart';
import '../theme/identite.dart';

/// Couleurs d'état des tables (section 3.1), lues dans l'identité visuelle.
final Color couleurLibre = identite.tableLibre;
final Color couleurOccupee = identite.tableOccupee;
final Color couleurAddition = identite.tableAddition;

void afficherMessage(BuildContext context, String message, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: erreur ? identite.erreur : null,
      ),
    );
}

/// Exécute une action et affiche l'erreur métier éventuelle.
Future<T?> essayer<T>(BuildContext context, Future<T> Function() action, {String? succes}) async {
  try {
    final r = await action();
    if (succes != null && context.mounted) afficherMessage(context, succes);
    return r;
  } on ErreurMetier catch (e) {
    if (context.mounted) afficherMessage(context, e.message, erreur: true);
  } on ArgumentError catch (e) {
    if (context.mounted) afficherMessage(context, '${e.message}', erreur: true);
  } catch (e) {
    if (context.mounted) afficherMessage(context, 'Erreur : $e', erreur: true);
  }
  return null;
}

Future<String?> demanderTexte(
  BuildContext context,
  String titre, {
  String label = '',
  String initial = '',
  bool obligatoire = true,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (obligatoire && ctrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<int?> demanderNombre(BuildContext context, String titre, {String label = '', int? initial, String? aide}) async {
  final ctrl = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aide != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(aide)),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(labelText: label),
            onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('OK')),
      ],
    ),
  );
}

/// Lit « 0,5 » ou « 0.5 » ; renvoie un entier quand c'est possible.
num? lireDecimal(String v) {
  final d = double.tryParse(v.replaceAll(',', '.').trim());
  if (d == null) return null;
  return d == d.roundToDouble() ? d.round() : d;
}

/// Quantité décimale (« 0,5 » kg) : virgule ou point acceptés.
Future<num?> demanderQuantite(BuildContext context, String titre, {String label = '', num? initial, String? aide}) {
  final ctrl = TextEditingController(text: initial == null ? '' : '$initial'.replaceAll('.', ','));
  num? lire(String v) {
    final d = double.tryParse(v.replaceAll(',', '.').trim());
    if (d == null) return null;
    return d == d.roundToDouble() ? d.round() : d;
  }

  return showDialog<num>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aide != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(aide)),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(labelText: label),
            onSubmitted: (v) => Navigator.pop(ctx, lire(v)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, lire(ctrl.text)), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirmer(BuildContext context, String titre, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    ) ??
    false;

/// Affiche un AsyncValue sans répéter la gestion chargement / erreur.
class Chargement extends StatelessWidget {
  final Object? erreur;
  const Chargement({super.key, this.erreur});
  @override
  Widget build(BuildContext context) => Center(
    child: erreur == null
        ? const CircularProgressIndicator()
        : Text('Erreur : $erreur', style: const TextStyle(color: Colors.red)),
  );
}

class Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  const Pastille(this.texte, this.couleur, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: couleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: couleur.withValues(alpha: 0.35)),
    ),
    child: Text(
      texte,
      style: TextStyle(color: couleur, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
