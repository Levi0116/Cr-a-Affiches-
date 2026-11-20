import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/features/caisse/comptage.dart';
import 'package:gestion_restaurant/features/caisse/encaissement.dart';
import 'package:gestion_restaurant/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

/// Ouvre le pavé dans une petite application et renvoie le futur résultat.
Future<Future<int?>> ouvrir(WidgetTester t, Future<int?> Function(BuildContext) ouvrir) async {
  await t.binding.setSurfaceSize(const Size(1280, 900));
  late Future<int?> resultat;
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.clair,
      home: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => resultat = ouvrir(context), child: const Text('go')),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  return resultat;
}

Finder touche(String libelle) => find.bySemanticsLabel(libelle);

/// Fait défiler jusqu'à l'élément puis le touche.
Future<void> toucher(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('billets cumulés, validation bloquée tant que c’est insuffisant', (t) async {
    final r = await ouvrir(t, (c) => demanderEncaissement(c, aPayer: 6700));
    expect(find.text('Saisissez le montant reçu'), findsOneWidget);

    await toucher(t, touche('Ajouter un billet de 5 000 F'));
    expect(find.text('Il manque'), findsOneWidget);
    // Bouton de validation inactif : rien ne se passe.
    await toucher(t, touche('Valider le paiement'));
    expect(find.text('Il manque'), findsOneWidget);

    await toucher(t, touche('Ajouter un billet de 2 000 F'));
    expect(find.text('Monnaie à rendre'), findsOneWidget);
    expect(find.text('300 F'), findsOneWidget);

    await toucher(t, touche('Valider le paiement'));
    expect(await r, 7000);
    await t.binding.setSurfaceSize(null);
  });

  testWidgets('clavier physique : chiffres, retour arrière, Entrée', (t) async {
    final r = await ouvrir(t, (c) => demanderEncaissement(c, aPayer: 1500));
    for (final k in [LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit0]) {
      await t.sendKeyEvent(k);
    }
    await t.sendKeyEvent(LogicalKeyboardKey.backspace); // 20
    await t.sendKeyEvent(LogicalKeyboardKey.digit0); // 200
    await t.sendKeyEvent(LogicalKeyboardKey.digit0); // 2000
    await t.pumpAndSettle();
    expect(find.text('2 000 F'), findsWidgets);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(await r, 2000);
    await t.binding.setSurfaceSize(null);
  });

  testWidgets('remboursement partiel d’ardoise accepté', (t) async {
    final r = await ouvrir(t, (c) => demanderEncaissement(c, aPayer: 3000, partiel: true));
    await toucher(t, touche('Ajouter un billet de 1 000 F'));
    expect(find.text('Reste dû après ce versement'), findsOneWidget);
    await toucher(t, touche('Valider le paiement'));
    expect(await r, 1000);
    await t.binding.setSurfaceSize(null);
  });

  testWidgets('comptage de caisse : écart avec le théorique', (t) async {
    final r = await ouvrir(
      t,
      (c) => demanderComptage(c, titre: 'Clôture', theorique: 20500, libelleBouton: 'Clôturer'),
    );
    // 2 billets de 10 000 + 1 pièce de 500 = 20 500 → caisse juste.
    final plus = touche('Ajouter');
    await toucher(t, plus.at(0));
    await toucher(t, plus.at(0));
    expect(find.textContaining('Manquant'), findsOneWidget);
    await toucher(t, plus.at(5)); // pièce de 500
    await t.pumpAndSettle();
    expect(find.textContaining('Caisse juste'), findsOneWidget);
    await toucher(t, touche('Clôturer'));
    expect(await r, 20500);
    await t.binding.setSurfaceSize(null);
  });
}
