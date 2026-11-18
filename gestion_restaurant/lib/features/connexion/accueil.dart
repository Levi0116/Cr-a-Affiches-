import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pin.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../widgets/commun.dart';
import '../admin/ecran_admin.dart';
import '../caisse/ecran_caisse.dart';
import '../salle/ecran_salle.dart';
import '../stock/ecran_stock.dart';

/// Racine : écran de connexion, ou espace de l'employé connecté, avec
/// déconnexion automatique après quelques minutes d'inactivité (section 2.1).
class Accueil extends ConsumerStatefulWidget {
  const Accueil({super.key});
  @override
  ConsumerState<Accueil> createState() => _AccueilState();
}

class _AccueilState extends ConsumerState<Accueil> {
  Timer? _minuteur;

  void _relancer() {
    _minuteur?.cancel();
    if (ref.read(utilisateurProvider) == null) return;
    final minutes = ref.read(restaurantProvider).value?.deconnexionMinutes ?? 5;
    _minuteur = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(utilisateurProvider.notifier).deconnecter();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(utilisateurProvider, (_, _) => _relancer());
    final e = ref.watch(utilisateurProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _relancer(),
      child: e == null ? const EcranConnexion() : EspaceEmploye(employe: e),
    );
  }
}

class EspaceEmploye extends StatelessWidget {
  final Employe employe;
  const EspaceEmploye({super.key, required this.employe});

  @override
  Widget build(BuildContext context) => switch (employe.role) {
        Role.serveuse => const EcranSalle(),
        Role.caissier => const EcranCaisse(),
        Role.gestionnaire => const EcranStock(),
        Role.admin => const EcranAdmin(),
      };
}

class EcranConnexion extends ConsumerStatefulWidget {
  const EcranConnexion({super.key});
  @override
  ConsumerState<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends ConsumerState<EcranConnexion> {
  Employe? _choisi;
  String _pin = '';
  String? _erreur;

  void _touche(String c) {
    setState(() {
      _erreur = null;
      if (c == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length < 4) _pin += c;
    });
    if (_pin.length == 4) _verifier();
  }

  void _verifier() {
    final e = _choisi!;
    final db = ref.read(dbProvider);
    // Vérification locale du code haché : fonctionne hors ligne.
    final ok = hacherPin(idRestaurant: db.idRestaurant, idEmploye: e.id, pin: _pin) ==
        e.pinHash;
    if (ok) {
      ref.read(utilisateurProvider.notifier).connecter(e);
    } else {
      setState(() {
        _pin = '';
        _erreur = 'Code incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final employes = ref.watch(employesProvider);
    final resto = ref.watch(restaurantProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(resto?.nom ?? 'Connexion'),
        actions: const [IndicateurConnexion(), SizedBox(width: 12)],
      ),
      body: employes.when(
        loading: () => const Chargement(),
        error: (e, _) => Chargement(erreur: e),
        data: (liste) {
          final actifs = liste.where((e) => e.actif).toList();
          if (_choisi == null) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text('Qui êtes-vous ?', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final e in actifs)
                        SizedBox(
                          width: 170,
                          height: 110,
                          child: FilledButton.tonal(
                            onPressed: () => setState(() => _choisi = e),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(e.nom, style: const TextStyle(fontSize: 22)),
                              Text(e.role.libelle, style: const TextStyle(fontSize: 13)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
            );
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_choisi!.nom, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Tapez votre code à 4 chiffres'),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        margin: const EdgeInsets.all(8),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  height: 24,
                  child: _erreur == null
                      ? null
                      : Text(_erreur!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                ),
                SizedBox(
                  width: 300,
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final c in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
                        c.isEmpty
                            ? const SizedBox()
                            : FilledButton.tonal(
                                onPressed: () => _touche(c),
                                child: Text(c, style: const TextStyle(fontSize: 28)),
                              ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _choisi = null;
                    _pin = '';
                    _erreur = null;
                  }),
                  child: const Text('← Changer de personne'),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
