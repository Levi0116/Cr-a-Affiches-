import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/theme/app_theme.dart';
import 'package:gestion_restaurant/widgets/animated_table_card.dart';
import 'package:material_ui/material_ui.dart';

/// La carte de table « vole » et s'agrandit jusqu'à devenir l'en-tête.
void main() {
  testWidgets('Hero carte de table → en-tête : taille intermédiaire pendant le vol, sans erreur', (tester) async {
    final cleNav = GlobalKey<NavigatorState>();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: cleNav,
        theme: AppTheme.sombre,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              height: 180,
              child: FondTableHero(idTable: 't-1', couleur: Colors.green, rayon: BorderRadius.all(Radius.circular(20))),
            ),
          ),
        ),
      ),
    );
    Rect fond() => tester.getRect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FondTable').last);
    final carte = fond();
    expect(carte.width, 180);

    cleNav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: FondTableHero(
                  idTable: 't-1',
                  couleur: Colors.orange,
                  rayon: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(); // démarrage du vol
    await tester.pump(const Duration(milliseconds: 150)); // milieu du vol
    final milieu = fond();
    expect(milieu.width, greaterThan(180));
    expect(milieu.width, lessThan(1280));

    await tester.pumpAndSettle();
    final entete = fond();
    expect(entete.width, 1280);
    expect(entete.height, 150);
    expect(tester.takeException(), isNull);

    // Retour : l'en-tête redevient la carte.
    cleNav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(fond().width, inExclusiveRange(180, 1280));
    await tester.pumpAndSettle();
    expect(fond().width, 180);
    await tester.binding.setSurfaceSize(null);
  });
}
